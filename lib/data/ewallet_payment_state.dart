import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'app_data.dart';
import 'booking_state.dart';
import 'business_repository.dart';
import 'payment_models.dart';
import 'payment_return_link.dart';

typedef WalletLauncher = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// The e-wallet attempt this device is waiting on, kept so a return link or app resume can find it.
class EwalletPointer {
  const EwalletPointer(this.bookingGuid, this.attemptGuid, this.channel);
  final String bookingGuid;
  final String attemptGuid;
  final String channel;

  static String storageKey(String userGuid) => 'ewallet_pointer_$userGuid';

  static EwalletPointer? decode(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map &&
          data['booking_guid'] is String &&
          data['attempt_guid'] is String &&
          data['channel'] is String) {
        return EwalletPointer(data['booking_guid'] as String,
            data['attempt_guid'] as String, data['channel'] as String);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String encode() => jsonEncode({
        'booking_guid': bookingGuid,
        'attempt_guid': attemptGuid,
        'channel': channel
      });

  static Future<EwalletPointer?> load(String userGuid,
          {FlutterSecureStorage storage =
              const FlutterSecureStorage()}) async =>
      decode(await storage.read(key: storageKey(userGuid)));
}

enum EwalletPhase {
  /// Nothing in flight; a new attempt may be started if the server allows it.
  idle,

  /// The wallet attempt is waiting for the customer or for provider confirmation.
  pending,

  /// The server could not yet resolve the provider state. Never start a second attempt.
  unknown,
  failed,
  expired,

  /// Server-verified: booking confirmed and attempt paid.
  confirmed,

  /// Paid at the provider but not applied (or reversed): the operator must investigate.
  review,

  /// Another payment method already owns the booking.
  otherMethod,
}

/// Wallet payment lifecycle for one booking. Redirects, links and resumes only trigger server reads;
/// success is whatever the server's authenticated status inquiry produced.
class EwalletPaymentState extends ChangeNotifier with WidgetsBindingObserver {
  EwalletPaymentState(this.repository, this.bookingGuid,
      {WalletLauncher? launcher,
      FlutterSecureStorage? storage,
      this.pollInterval = const Duration(seconds: 5),
      this.pollWindow = const Duration(minutes: 3)})
      : launcher = launcher ?? _launchExternal,
        _storage = storage ?? const FlutterSecureStorage(),
        _generation = repository.api.session.sessionGeneration,
        _userGuid = currentUser?.id {
    repository.api.session.sessionChanges.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  final BusinessRepository repository;
  final String bookingGuid;
  final WalletLauncher launcher;
  final Duration pollInterval;
  final Duration pollWindow;
  final FlutterSecureStorage _storage;
  final int _generation;
  final String? _userGuid;
  static final _mutating = <String>{};
  static final _refreshing = <String>{};

  Booking? booking;
  PaymentSnapshot? intent;
  PaymentSnapshot? methods;
  EwalletPointer? pointer;
  Json? operation;
  PaymentReturnHint hint = PaymentReturnHint.none;
  bool busy = false;
  bool reconciled = false;
  bool polling = false;
  bool walletOpened = false;
  String? error;
  bool _disposed = false;
  bool _resumePending = false;
  Timer? _timer;
  int _ticks = 0;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    } else {
      stopPolling();
    }
  }

  String get _operationKey => 'ewallet_operation_${_userGuid}_$bookingGuid';
  String get _pointerKey => EwalletPointer.storageKey(_userGuid ?? '');

  bool get valid =>
      !_disposed &&
      _userGuid != null &&
      currentUser?.id == _userGuid &&
      repository.api.session.role == 0 &&
      repository.api.session.authenticated.value &&
      repository.api.session.deviceSessionReady &&
      repository.api.session.isCurrentGeneration(_generation);

  /// Every server signal must agree before the UI says "paid".
  bool get confirmed =>
      booking?.status == 'confirmed' &&
      booking?.paymentStatus == 'paid' &&
      intent?.isDoku == true &&
      intent?.intentStatus == 'paid' &&
      intent?.attemptStatus == 'paid';

  bool get _ewalletAttempt => intent?.attemptMethod == 'ewallet';

  EwalletPhase get phase {
    if (confirmed) return EwalletPhase.confirmed;
    final status = intent?.attemptStatus;
    if (status == null) return EwalletPhase.idle;
    if (!_ewalletAttempt) {
      return const ['failed', 'expired'].contains(status)
          ? EwalletPhase.idle
          : EwalletPhase.otherMethod;
    }
    if (intent?.intentStatus == 'needs_review' || status == 'reversed') {
      return EwalletPhase.review;
    }
    return switch (status) {
      'initiating' || 'pending' || 'paid' => EwalletPhase.pending,
      'unknown' => EwalletPhase.unknown,
      'failed' => EwalletPhase.failed,
      'expired' => EwalletPhase.expired,
      _ => EwalletPhase.unknown,
    };
  }

  bool get isActive =>
      const [EwalletPhase.pending, EwalletPhase.unknown].contains(phase);
  List<String> get channels => methods?.availableEwalletChannels ?? const [];
  bool get canStart =>
      valid &&
      reconciled &&
      !busy &&
      booking?.status == 'awaiting_payment' &&
      channels.isNotEmpty &&
      const [EwalletPhase.idle, EwalletPhase.failed, EwalletPhase.expired]
          .contains(phase);

  /// The attempt a refresh should target: the persisted pointer, else the server's current ewallet attempt.
  String? get _attemptGuid =>
      pointer?.bookingGuid == bookingGuid ? pointer?.attemptGuid : null;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
    if (_resumePending && !busy) {
      _resumePending = false;
      onResumed();
    }
  }

  void _requireValid() {
    if (!valid) throw const ApiException('Sesi pembayaran telah berubah.', 401);
  }

  void _sessionChanged() {
    stopPolling();
    booking = null;
    intent = null;
    methods = null;
    operation = null;
    pointer = null;
    reconciled = false;
    error = 'Sesi berubah. Buka kembali pembayaran.';
    _notify();
  }

  /// Read-only: booking, intent and methods, then reconcile the local pointer with the server.
  Future<void> _read() async {
    _requireValid();
    reconciled = false;
    Object? failure;
    Booking? freshBooking;
    PaymentSnapshot? freshIntent;
    PaymentSnapshot? freshMethods;
    await Future.wait([
      () async {
        try {
          freshBooking = await repository.booking(bookingGuid);
        } catch (e) {
          failure ??= e;
        }
      }(),
      () async {
        try {
          freshIntent = await repository.paymentIntent(bookingGuid);
        } catch (e) {
          failure ??= e;
        }
      }(),
      () async {
        try {
          freshMethods = await repository.paymentMethods(bookingGuid);
        } catch (e) {
          failure ??= e;
        }
      }(),
    ]);
    _requireValid();
    if (failure != null) throw failure!;
    if (freshBooking?.guid != bookingGuid ||
        freshIntent?.bookingGuid != bookingGuid ||
        freshMethods?.bookingGuid != bookingGuid) {
      throw const ApiException(
          'Respons pembayaran tidak cocok.', null, 'invalid_response');
    }
    booking = freshBooking;
    intent = freshIntent;
    methods = freshMethods;
    await _syncPointer();
    final saved = await _storage.read(key: _operationKey);
    _requireValid();
    operation = saved == null ? null : _decodeOperation(saved);
    // A different attempt than the one the unfinished operation started from means the POST landed.
    if (operation != null &&
        intent?.attemptGuid != null &&
        intent?.attemptGuid != operation!['base_attempt_guid']) {
      await _storage.delete(key: _operationKey);
      _requireValid();
      operation = null;
    }
    reconciled = true;
  }

  Json? _decodeOperation(String raw) {
    try {
      final data = jsonDecode(raw);
      return data is Json && data['key'] is String ? data : null;
    } on FormatException {
      return null;
    }
  }

  /// Keeps the pointer only for an unfinished wallet attempt of this booking.
  Future<void> _syncPointer() async {
    final stored =
        await EwalletPointer.load(_userGuid ?? '', storage: _storage);
    _requireValid();
    pointer = stored;
    final attemptGuid = intent?.attemptGuid;
    final live = _ewalletAttempt &&
        intent?.isDoku == true &&
        attemptGuid != null &&
        isActive;
    if (live) {
      // Also adopts an attempt started before a reinstall or storage reset.
      if (pointer?.bookingGuid != bookingGuid ||
          pointer?.attemptGuid != attemptGuid) {
        pointer = EwalletPointer(
            bookingGuid, attemptGuid, intent?.attemptChannel ?? '');
        await _storage.write(key: _pointerKey, value: pointer!.encode());
      }
    } else if (pointer?.bookingGuid == bookingGuid) {
      await _storage.delete(key: _pointerKey);
      pointer = null;
    }
    _requireValid();
  }

  /// Read-only, safe on resume and rebuild. Never creates or refreshes a provider payment.
  Future<void> recover() async {
    if (busy || !valid || _mutating.contains(_operationKey)) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _read();
      if (confirmed) BookingEvents.notify();
    } catch (e) {
      if (valid) {
        reconciled = false;
        error = paymentError(e);
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Asks the server to re-check the provider (authenticated inquiry), then re-reads authoritative state.
  /// A failed refresh never changes payment state and never starts another payment.
  Future<void> refresh() async {
    if (busy || !valid) return;
    final attemptGuid =
        (_ewalletAttempt ? intent?.attemptGuid : null) ?? _attemptGuid;
    if (attemptGuid == null) return recover();
    if (!_refreshing.add(attemptGuid)) return;
    busy = true;
    error = null;
    _notify();
    try {
      try {
        await repository.refreshPaymentAttempt(bookingGuid, attemptGuid);
      } catch (e) {
        if (valid) error = paymentError(e);
      }
      _requireValid();
      try {
        await _read();
        if (confirmed) BookingEvents.notify();
      } catch (e) {
        if (valid) {
          reconciled = false;
          error ??= paymentError(e);
        }
      }
    } finally {
      _refreshing.remove(attemptGuid);
      busy = false;
      _notify();
    }
  }

  /// App came back to the foreground: one server refresh, but only for a known unfinished attempt.
  Future<void> onResumed() async {
    if (!valid || !_foreground) return;
    if (busy) {
      _resumePending = true;
      return;
    }
    final stored =
        await EwalletPointer.load(_userGuid ?? '', storage: _storage);
    if (!valid || !_foreground || stored?.bookingGuid != bookingGuid) return;
    pointer = stored;
    await refresh();
    if (isActive) startPolling();
  }

  /// Bounded foreground polling; stops on terminal state, dispose, session change or after [pollWindow].
  void startPolling() {
    if (polling || !valid || !_foreground) return;
    polling = true;
    _ticks = 0;
    final maxTicks = max(
        1, pollWindow.inMilliseconds ~/ max(1, pollInterval.inMilliseconds));
    _timer = Timer.periodic(pollInterval, (_) async {
      if (!valid || !_foreground || !isActive || ++_ticks > maxTicks) {
        stopPolling();
        return;
      }
      await refresh();
      if (!isActive) stopPolling();
    });
    _notify();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    if (polling) {
      polling = false;
      _notify();
    }
  }

  Future<void> _saveOperation(String channel) async {
    final random = Random.secure();
    final key = List.generate(
            32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    operation = {
      'key': key,
      'channel': channel,
      'base_attempt_guid': intent?.attemptGuid,
    };
    await _storage.write(key: _operationKey, value: jsonEncode(operation));
    _requireValid();
  }

  /// Explicit user action. The Idempotency-Key is stored before the POST and reused until the
  /// server shows the new attempt, so an uncertain response can never create a second payment.
  Future<void> start(String channel) async {
    if (busy || !valid || !_mutating.add(_operationKey)) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _read();
      if (confirmed) return;
      if (isActive) {
        // Already waiting on the server: reopen instead of creating another payment.
        await _openWallet();
        return;
      }
      if (operation == null && !canStartAfterRead(channel)) {
        throw const ApiException(
            'Periksa status pembayaran dan kelayakan booking sebelum melanjutkan.');
      }
      if (operation != null && operation!['channel'] != channel) {
        throw ApiException(
            'Percobaan sebelumnya belum pasti. Lanjutkan dengan ${_label(operation!['channel'] as String)}.');
      }
      if (operation == null) await _saveOperation(channel);
      _requireValid();
      final response = await repository.initiateEwalletPayment(
          bookingGuid, operation!['key'] as String, channel);
      _requireValid();
      if (response['booking_guid'] != bookingGuid ||
          response['provider'] != 'doku' ||
          response['method_code'] != 'ewallet' ||
          response['channel'] != channel ||
          response['attempt_guid'] is! String) {
        throw const ApiException('Respons pembayaran belum dapat dipastikan.',
            null, 'invalid_response');
      }
      final status = response['status'];
      if (status == 'pending' || status == 'unknown') {
        pointer = EwalletPointer(
            bookingGuid, response['attempt_guid'] as String, channel);
        await _storage.write(key: _pointerKey, value: pointer!.encode());
        _requireValid();
      }
      await _storage.delete(key: _operationKey);
      _requireValid();
      operation = null;
      final redirect = _redirectFrom(response['instruction']);
      if (status == 'pending' && redirect != null) {
        await _read();
        await _openWallet();
      } else {
        await _read();
        error = status == 'failed'
            ? 'Pembayaran ditolak. Coba lagi atau pilih dompet digital lain.'
            : 'Status pembayaran belum pasti. Periksa kembali; jangan membayar ulang.';
      }
      BookingEvents.notify();
    } catch (e) {
      if (valid) {
        error = paymentError(e);
        // No automatic second POST, even on 409/network/5xx: the stored key stays for an explicit retry.
        try {
          await _read();
        } catch (_) {
          reconciled = false;
        }
      }
    } finally {
      _mutating.remove(_operationKey);
      busy = false;
      _notify();
    }
  }

  bool canStartAfterRead(String channel) =>
      valid &&
      booking?.status == 'awaiting_payment' &&
      channels.contains(channel) &&
      const [EwalletPhase.idle, EwalletPhase.failed, EwalletPhase.expired]
          .contains(phase);

  /// Opens the wallet again for the pending attempt using the URL the server still holds.
  Future<void> reopen() async {
    if (busy || !valid) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _read();
      await _openWallet();
    } catch (e) {
      if (valid) error = paymentError(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _openWallet() async {
    if (phase != EwalletPhase.pending) {
      error = phase == EwalletPhase.unknown
          ? 'Status pembayaran belum pasti. Periksa kembali; jangan membayar ulang.'
          : null;
      return;
    }
    final redirect = intent?.redirectUrl;
    if (redirect == null) {
      error = 'Tautan dompet digital tidak lagi tersedia. Periksa status.';
      return;
    }
    await _open(redirect);
  }

  Future<void> _open(Uri redirect) async {
    if (redirect.scheme != 'https') {
      error = 'Tautan dompet digital tidak aman dan tidak dibuka.';
      return;
    }
    bool opened;
    try {
      opened = await launcher(redirect);
    } catch (_) {
      opened = false;
    }
    walletOpened = opened;
    if (!opened) {
      error =
          'Aplikasi dompet digital tidak dapat dibuka. Coba lagi dari tombol Buka Dompet Digital.';
    }
  }

  Uri? _redirectFrom(Object? instruction) {
    if (instruction is! Map ||
        instruction['presentation_type'] != 'ewallet_redirect') {
      return null;
    }
    final value = instruction['redirect_url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  static String _label(String channel) =>
      channel == 'shopeepay' ? 'ShopeePay' : 'DANA';
  static String channelLabel(String channel) => _label(channel);

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    repository.api.session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}
