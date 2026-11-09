import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'app_data.dart';
import 'booking_state.dart';
import 'business_repository.dart';
import 'payment_models.dart';
import 'ticket_models.dart';

typedef DocumentSaver = Future<SavedDocument> Function(
    BusinessRepository repository, String bookingGuid, String type,
    {String? bookingNumber});

/// What the payment page should show. Derived only from the server's booking and payment snapshot.
enum PaymentPhase {
  /// Nothing read yet.
  loading,

  /// The first read failed; nothing is known about the payment.
  loadFailed,

  /// The booking cannot be paid now (not awaiting payment, window closed, other provider...).
  blocked,

  /// No attempt yet: choose BNI VA or QRIS.
  choose,

  /// A pending attempt with a usable VA number or QR.
  awaiting,

  /// The server is still resolving: initiating, unknown, a pending attempt past its window, or a
  /// provider-paid attempt the booking has not confirmed yet. Never a reason to create again.
  verifying,

  /// Needs the operator; shown inline, watched read-only.
  review,
  failed,
  expired,
  cancelled,

  /// Reversal/refund after the provider reported paid.
  adjusted,

  /// Verified paid: booking, payment, intent and applied attempt all agree.
  paid,
}

/// Payment lifecycle for one booking (BNI virtual account and QRIS).
///
/// Success is never inferred from a redirect, a create response, a QR on screen or a local timer: it
/// needs the server's booking `confirmed`/`paid`, intent `paid` and the applied attempt to match.
/// The Idempotency-Key is persisted before the create POST and reused until the server shows the
/// new attempt, so a timeout or app restart can never create a second payment.
class BookingPaymentState extends ChangeNotifier with WidgetsBindingObserver {
  BookingPaymentState(this.repository, this.bookingGuid,
      {FlutterSecureStorage? storage,
      DateTime Function()? now,
      double Function()? jitter,
      this.minInterval = const Duration(seconds: 10),
      this.maxInterval = const Duration(seconds: 60)})
      : _storage = storage ?? const FlutterSecureStorage(),
        now = now ?? DateTime.now,
        _jitter = jitter ?? Random().nextDouble,
        _generation = repository.api.session.sessionGeneration,
        _userGuid = currentUser?.id {
    repository.api.session.sessionChanges.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  final BusinessRepository repository;
  final String bookingGuid;
  final DateTime Function() now;
  final Duration minInterval;
  final Duration maxInterval;
  final FlutterSecureStorage _storage;
  final double Function() _jitter;
  final int _generation;
  final String? _userGuid;
  static final _mutating = <String>{};

  Booking? booking;
  PaymentSnapshot? snapshot;
  BookingTickets? tickets;
  String? ticketsError;
  bool ticketsLoading = false;
  Json? operation;

  /// First read finished with a coherent booking + payment snapshot.
  bool loaded = false;
  bool loading = false;
  bool creating = false;
  bool checking = false;
  bool offline = false;
  bool retryOpen = false;
  bool receiptBusy = false;
  String? error;
  String? notice;

  Uint8List? qrSvg;
  bool qrLoading = false;
  String? qrError;

  bool _disposed = false;
  bool _sessionEnded = false;
  bool _inFlight = false;
  bool _foreground = true;
  bool _routeVisible = true;
  bool _resumePending = false;
  bool _announcedPaid = false;
  int _stable = 0;
  int _failures = 0;
  String _signature = '';
  String? _qrAttempt;
  String? _createReason;
  late DateTime _cooldownUntil = now();
  late DateTime _nextPollAt = now();
  Timer? _timer;
  Timer? _cooldownTimer;

  // ── Identity and session ───────────────────────────────────

  String get _operationKey => 'booking_payment_operation_${_userGuid}_$bookingGuid';

  bool get valid =>
      !_disposed &&
      !_sessionEnded &&
      _userGuid != null &&
      currentUser?.id == _userGuid &&
      repository.api.session.role == 0 &&
      repository.api.session.authenticated.value &&
      repository.api.session.deviceSessionReady &&
      repository.api.session.isCurrentGeneration(_generation);

  void _requireValid() {
    if (!valid) throw const ApiException('Sesi pembayaran telah berubah.', 401);
  }

  void _sessionChanged() {
    _sessionEnded = true;
    _cancelTimers();
    booking = null;
    snapshot = null;
    tickets = null;
    operation = null;
    loaded = false;
    _clearQr();
    error = 'Sesi berubah. Buka kembali pembayaran.';
    _notify();
  }

  // ── Derived state ──────────────────────────────────────────

  /// Every server signal must agree before the UI says "paid".
  bool get confirmed {
    final s = snapshot;
    final b = booking;
    return s != null &&
        b != null &&
        s.isDoku &&
        b.status == 'confirmed' &&
        b.paymentStatus == 'paid' &&
        s.paymentStatus == 'paid' &&
        s.intentStatus == 'paid' &&
        s.attemptStatus == 'paid' &&
        s.appliedAttemptGuid != null &&
        s.appliedAttemptGuid == s.attemptGuid;
  }

  bool get verificationPending => snapshot?.verificationPending == true;

  bool get instructionUsable {
    final s = snapshot;
    if (s == null || s.attemptStatus != 'pending') return false;
    return switch (s.attemptMethod) {
      'virtual_account' => s.vaNumber != null,
      'qris' => s.hasQrPayload,
      _ => false,
    };
  }

  PaymentPhase get phase {
    final s = snapshot;
    final b = booking;
    if (!loaded || s == null || b == null) {
      return error != null && !loading ? PaymentPhase.loadFailed : PaymentPhase.loading;
    }
    if (confirmed) return PaymentPhase.paid;
    final status = s.attemptStatus;
    if (const ['reversed', 'refunded', 'refund_pending', 'chargeback']
        .contains(status)) {
      return PaymentPhase.adjusted;
    }
    if (s.intentStatus == 'needs_review') return PaymentPhase.review;
    // Past its 30 minutes but unresolved: never expired/failed, never retryable, keep watching.
    if (s.verificationPending) return PaymentPhase.verifying;
    if (status == null) {
      return b.status == 'awaiting_payment' && s.isDoku
          ? PaymentPhase.choose
          : PaymentPhase.blocked;
    }
    return switch (status) {
      'pending' when s.attemptMethod != 'ewallet' && instructionUsable =>
        PaymentPhase.awaiting,
      'failed' => PaymentPhase.failed,
      'expired' => PaymentPhase.expired,
      'cancelled' => PaymentPhase.cancelled,
      _ => PaymentPhase.verifying,
    };
  }

  bool get _pollable => const [
        PaymentPhase.awaiting,
        PaymentPhase.verifying,
        PaymentPhase.review
      ].contains(phase);

  bool get busy => _inFlight || creating;

  /// The retry offer: previous attempt is terminal and the server says a new one is allowed.
  bool get canRetry =>
      valid &&
      !busy &&
      !retryOpen &&
      const [PaymentPhase.failed, PaymentPhase.expired, PaymentPhase.cancelled]
          .contains(phase) &&
      snapshot?.canCreate == true &&
      booking?.status == 'awaiting_payment';

  bool get chooserVisible =>
      phase == PaymentPhase.choose ||
      (retryOpen &&
          const [
            PaymentPhase.failed,
            PaymentPhase.expired,
            PaymentPhase.cancelled
          ].contains(phase));

  /// The channel a stored, unfinished create is bound to. Only that one may be retried.
  String? get lockedChoiceKey => operation == null
      ? null
      : '${operation!['method_code']}/${operation!['channel']}';

  bool canStartWith(PayChoice choice) =>
      valid &&
      loaded &&
      !busy &&
      chooserVisible &&
      choice.available &&
      snapshot?.canCreate == true &&
      booking?.status == 'awaiting_payment' &&
      (lockedChoiceKey == null || lockedChoiceKey == choice.key);

  Duration get cooldownRemaining {
    final left = _cooldownUntil.difference(now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Manual "Cek Status" shares the polling gate: one request at a time, never inside the cooldown.
  bool get canCheckNow =>
      valid &&
      loaded &&
      !busy &&
      _pollable &&
      cooldownRemaining == Duration.zero;

  String? get methodLabel => paymentMethodLabel(
      snapshot?.attemptMethod ?? operation?['method_code'] as String?,
      snapshot?.attemptChannel ?? operation?['channel'] as String?);

  /// Reason the server reported for the last create (for example a rejected attempt).
  String? get createReason => _createReason;

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      onResumed();
    } else {
      _foreground = false;
      _cancelPollTimer();
    }
  }

  /// The page is the current route (true) or another route covers it (false).
  set routeVisible(bool visible) {
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    if (visible) {
      onResumed();
    } else {
      _cancelPollTimer();
    }
  }

  /// First read when the page opens. Never creates anything.
  Future<void> open() async {
    _restartGate();
    await reload(initial: true);
    _restartGate();
  }

  void _restartGate() {
    final next = now().add(minInterval);
    _cooldownUntil = next;
    _nextPollAt = next;
    _schedule();
  }

  /// Read-only refresh of booking and payment (open, resume, pull-to-refresh).
  Future<void> reload({bool initial = false}) async {
    if (!valid) return;
    if (_inFlight) {
      _resumePending = true;
      return;
    }
    _inFlight = true;
    loading = true;
    if (!initial) error = null;
    _notify();
    try {
      await _read();
    } catch (e) {
      if (valid) {
        _noteFailure(e);
        if (!loaded) error = paymentError(e);
      }
    } finally {
      _inFlight = false;
      loading = false;
      _notify();
      _afterOperation();
    }
  }

  /// App or route came back: one read-only snapshot, then polling continues if still unresolved.
  Future<void> onResumed() async {
    if (!valid || !_foreground || !_routeVisible) return;
    if (_inFlight) {
      _resumePending = true;
      return;
    }
    await reload();
  }

  void _afterOperation() {
    if (_disposed) return;
    if (_resumePending && !_inFlight) {
      _resumePending = false;
      unawaited(onResumed());
      return;
    }
    _schedule();
  }

  // ── Reading ────────────────────────────────────────────────

  Future<void> _read() async {
    _requireValid();
    final results = await Future.wait<Object>(
        [repository.booking(bookingGuid), repository.paymentIntent(bookingGuid)]);
    _requireValid();
    final freshBooking = results[0] as Booking;
    final freshSnapshot = results[1] as PaymentSnapshot;
    _ensureSameBooking(freshBooking, freshSnapshot);
    _apply(freshBooking, freshSnapshot);
    await _reconcileOperation();
    offline = false;
    error = null;
  }

  void _ensureSameBooking(Booking b, PaymentSnapshot s) {
    if (b.guid != bookingGuid || s.bookingGuid != bookingGuid) {
      throw const ApiException(
          'Respons pembayaran tidak cocok.', null, 'invalid_response');
    }
  }

  /// Takes a coherent server state. Returns whether anything meaningful changed.
  bool _apply(Booking freshBooking, PaymentSnapshot fresh) {
    final previousAttempt = snapshot?.attemptGuid;
    booking = freshBooking;
    snapshot = fresh;
    loaded = true;
    final signature = [
      fresh.attemptGuid,
      fresh.attemptStatus,
      fresh.intentStatus,
      fresh.appliedAttemptGuid,
      freshBooking.status,
      freshBooking.paymentStatus,
      fresh.canCreate,
    ].join('|');
    final changed = signature != _signature;
    _signature = signature;
    if (previousAttempt != fresh.attemptGuid) {
      retryOpen = false;
      _createReason = null;
    }
    if (phase != PaymentPhase.awaiting || _qrAttempt != fresh.attemptGuid) {
      _clearQr();
    }
    final nowConfirmed = confirmed;
    if (nowConfirmed && !_announcedPaid) {
      _announcedPaid = true;
      BookingEvents.notify();
      unawaited(loadTickets());
    } else if (!nowConfirmed && _announcedPaid) {
      _announcedPaid = false;
      tickets = null;
      BookingEvents.notify();
    }
    if (phase == PaymentPhase.awaiting) unawaited(loadQr());
    return changed;
  }

  Future<void> _reconcileOperation() async {
    final saved = await _storage.read(key: _operationKey);
    _requireValid();
    operation = saved == null ? null : _decodeOperation(saved);
    // A different attempt than the one the unfinished create started from means the POST landed.
    final attempt = snapshot?.attemptGuid;
    if (operation != null &&
        attempt != null &&
        attempt != operation!['base_attempt_guid']) {
      await _storage.delete(key: _operationKey);
      _requireValid();
      operation = null;
    }
  }

  Json? _decodeOperation(String raw) {
    try {
      final data = jsonDecode(raw);
      return data is Json &&
              data['key'] is String &&
              data['method_code'] is String &&
              data['channel'] is String
          ? data
          : null;
    } on FormatException {
      return null;
    }
  }

  // ── Creating ───────────────────────────────────────────────

  void openRetry() {
    if (!canRetry) return;
    retryOpen = true;
    _notify();
  }

  Future<void> _saveOperation(PayChoice choice) async {
    final random = Random.secure();
    final key = List.generate(
            32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    operation = {
      'key': key,
      'method_code': choice.methodCode,
      'channel': choice.channel,
      'base_attempt_guid': snapshot?.attemptGuid,
    };
    await _storage.write(key: _operationKey, value: jsonEncode(operation));
    _requireValid();
  }

  /// Explicit customer action. Reads fresh state first, and never POSTs while an attempt is unresolved.
  Future<void> start(PayChoice choice) async {
    if (_inFlight || !valid || !_mutating.add(_operationKey)) return;
    _inFlight = true;
    creating = true;
    error = null;
    notice = null;
    _notify();
    try {
      await _read();
      if (confirmed) return;
      if (operation != null && lockedChoiceKey != choice.key) {
        final locked = operation!;
        throw ApiException(
            'Percobaan sebelumnya belum pasti. Lanjutkan dengan ${paymentMethodLabel(locked['method_code'] as String?, locked['channel'] as String?)}.');
      }
      final fresh = snapshot!;
      final stillAvailable = fresh.payChoices
          .any((item) => item.key == choice.key && item.available);
      if (!stillAvailable ||
          !fresh.canCreate ||
          booking?.status != 'awaiting_payment' ||
          !chooserVisible) {
        throw const ApiException(
            'Periksa status pembayaran dan kelayakan booking sebelum melanjutkan.');
      }
      if (operation == null) await _saveOperation(choice);
      _requireValid();
      final response = await repository.initiatePayment(
          bookingGuid, operation!['key'] as String,
          methodCode: choice.methodCode, channel: choice.channel);
      _requireValid();
      if (response['booking_guid'] != bookingGuid ||
          response['method_code'] != choice.methodCode ||
          response['channel'] != choice.channel ||
          response['attempt_guid'] is! String) {
        throw const ApiException('Respons pembayaran belum dapat dipastikan.',
            null, 'invalid_response');
      }
      // The POST landed. Whatever the response says, only the next read decides what is shown.
      _createReason = response['reason'] is String
          ? response['reason'] as String
          : null;
      await _storage.delete(key: _operationKey);
      _requireValid();
      operation = null;
      retryOpen = false;
      await _read();
      BookingEvents.notify();
      _restartGate();
    } catch (e) {
      if (valid) {
        final failure = paymentError(e);
        if (e is ApiException && e.status == 422 && operation != null) {
          // Validation rejected before any attempt existed: the key can never have created one.
          await _storage.delete(key: _operationKey);
          operation = null;
        }
        try {
          await _read();
        } catch (_) {
          // Keep what was known; the error below explains that state is not confirmed.
        }
        error = failure;
      }
    } finally {
      _mutating.remove(_operationKey);
      _inFlight = false;
      creating = false;
      _notify();
      _afterOperation();
    }
  }

  // ── Checking and polling ───────────────────────────────────

  /// Manual "Cek Status Pembayaran". Respects the same gate as polling.
  Future<void> checkNow() async {
    if (!canCheckNow) return;
    await _check();
  }

  /// Local timer reached zero: ask for a refresh through the gate. Never marks anything expired.
  void onCountdownElapsed() {
    if (!valid || !_pollable) return;
    _nextPollAt = now();
    _schedule();
  }

  Duration get _pollDelay {
    final base = _failures > 0
        ? minInterval.inMilliseconds * pow(2, _failures)
        : minInterval.inMilliseconds * pow(1.5, _stable);
    final spread = 1 + (_jitter() - 0.5) * 0.2;
    final bounded = (base * spread)
        .clamp(minInterval.inMilliseconds, maxInterval.inMilliseconds);
    return Duration(milliseconds: bounded.round());
  }

  bool get _canPoll =>
      valid && loaded && _foreground && _routeVisible && _pollable;

  void _cancelPollTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _cancelTimers() {
    _cancelPollTimer();
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  /// One timer: fires at the later of the 10s gate and the backoff schedule.
  void _schedule() {
    _cancelPollTimer();
    if (_disposed) return;
    _scheduleCooldownNotice();
    if (!_canPoll || _inFlight) return;
    final at =
        _cooldownUntil.isAfter(_nextPollAt) ? _cooldownUntil : _nextPollAt;
    var wait = at.difference(now());
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, _onTimer);
  }

  void _scheduleCooldownNotice() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    final left = cooldownRemaining;
    if (left > Duration.zero && valid) {
      _cooldownTimer = Timer(left, () {
        _cooldownTimer = null;
        _notify();
      });
    }
  }

  void _onTimer() {
    _timer = null;
    if (!_canPoll || _inFlight) return;
    final at =
        _cooldownUntil.isAfter(_nextPollAt) ? _cooldownUntil : _nextPollAt;
    if (now().isBefore(at)) {
      _schedule();
      return;
    }
    unawaited(_check());
  }

  /// The single gated request: provider refresh (or a read-only probe when offline / under review),
  /// then the booking, then one coherent snapshot.
  Future<void> _check() async {
    if (!valid || _inFlight) return;
    _inFlight = true;
    checking = true;
    _notify();
    final attempt = snapshot?.attemptGuid;
    final providerRefresh =
        attempt != null && !offline && phase != PaymentPhase.review;
    Duration? retryAfter;
    try {
      final fresh = providerRefresh
          ? await repository.refreshPaymentAttempt(bookingGuid, attempt)
          : await repository.paymentIntent(bookingGuid);
      _requireValid();
      final freshBooking = await repository.booking(bookingGuid);
      _requireValid();
      _ensureSameBooking(freshBooking, fresh);
      final changed = _apply(freshBooking, fresh);
      await _reconcileOperation();
      _failures = 0;
      offline = false;
      error = null;
      _stable = changed ? 0 : _stable + 1;
    } catch (e) {
      if (valid) {
        _failures++;
        _noteFailure(e);
        final Map<String, dynamic>? details =
            e is ApiException ? e.context : null;
        final Object? seconds = details == null ? null : details['retry_after'];
        if (seconds is num && seconds > 0) {
          retryAfter = Duration(seconds: seconds.toInt());
        }
      }
    } finally {
      final end = now();
      var delay = _pollDelay;
      var gate = minInterval;
      if (retryAfter != null) {
        if (retryAfter > delay) delay = retryAfter;
        if (retryAfter > gate) gate = retryAfter;
      }
      _cooldownUntil = end.add(gate);
      _nextPollAt = end.add(delay);
      _inFlight = false;
      checking = false;
      _notify();
      _afterOperation();
    }
  }

  void _noteFailure(Object e) {
    if (e is ApiException && (e.code == 'network' || e.code == 'timeout')) {
      offline = true;
      error = null;
      return;
    }
    error = paymentError(e);
  }

  // ── QR, tickets, receipt ───────────────────────────────────

  void _clearQr() {
    qrSvg = null;
    qrLoading = false;
    qrError = null;
    _qrAttempt = null;
  }

  /// The payment QR image comes from Laravel's QR endpoint (the persisted provider payload), once per attempt.
  Future<void> loadQr() async {
    final s = snapshot;
    final attempt = s?.attemptGuid;
    if (!valid ||
        attempt == null ||
        phase != PaymentPhase.awaiting ||
        s?.attemptMethod != 'qris') {
      return;
    }
    if (_qrAttempt == attempt && (qrSvg != null || qrLoading)) return;
    _qrAttempt = attempt;
    qrLoading = true;
    qrError = null;
    _notify();
    try {
      final image = await repository.paymentQr(bookingGuid, attempt);
      if (!valid || _qrAttempt != attempt) return;
      if (!image.contentType.contains('image/svg+xml') ||
          image.bytes.isEmpty) {
        throw const ApiException('QR tidak valid.', null, 'invalid_response');
      }
      qrSvg = image.bytes;
    } catch (_) {
      if (valid && _qrAttempt == attempt) {
        qrError = 'QR pembayaran belum dapat dimuat. Periksa koneksi lalu coba lagi.';
        _qrAttempt = null;
      }
    } finally {
      if (valid) {
        qrLoading = false;
        _notify();
      }
    }
  }

  Future<void> retryQr() async {
    _qrAttempt = null;
    await loadQr();
  }

  /// Ticket entitlement is separate from payment; read after verified paid and on demand.
  Future<void> loadTickets() async {
    if (!valid || ticketsLoading) return;
    ticketsLoading = true;
    ticketsError = null;
    _notify();
    try {
      final data = await repository.bookingTickets(bookingGuid);
      if (!valid) return;
      if (data.bookingGuid != bookingGuid) {
        throw const ApiException('Respons tiket tidak cocok.', null, 'invalid_response');
      }
      tickets = data;
    } catch (e) {
      if (valid) ticketsError = ticketErrorMessage(e);
    } finally {
      if (valid) {
        ticketsLoading = false;
        _notify();
      }
    }
  }

  /// Authenticated receipt download; only when the server says the receipt exists.
  Future<SavedDocument?> downloadReceipt(DocumentSaver saver) async {
    if (!valid || receiptBusy || !confirmed || snapshot?.receiptAvailable != true) {
      return null;
    }
    receiptBusy = true;
    notice = null;
    _notify();
    try {
      return await saver(repository, bookingGuid, 'receipt',
          bookingNumber: booking?.bookingNumber);
    } catch (e) {
      if (valid) {
        notice = e is ApiException && e.status == 404
            ? 'Bukti pembayaran belum siap diunduh.'
            : 'Bukti pembayaran belum dapat diunduh. Coba lagi.';
      }
      return null;
    } finally {
      if (valid) {
        receiptBusy = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    _clearQr();
    WidgetsBinding.instance.removeObserver(this);
    repository.api.session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}
