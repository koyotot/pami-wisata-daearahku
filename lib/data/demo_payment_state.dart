import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'app_data.dart';
import 'booking_state.dart';
import 'business_repository.dart';
import 'payment_models.dart';

/// Keeps uncertain operations account/booking-bound, like the existing BookingIntent.
class DemoPaymentState extends ChangeNotifier {
  DemoPaymentState(this.repository, this.bookingGuid)
      : _generation = repository.api.session.sessionGeneration,
        _userGuid = currentUser?.id {
    repository.api.session.sessionChanges.addListener(_sessionChanged);
  }
  final BusinessRepository repository;
  final String bookingGuid;
  final int _generation;
  final String? _userGuid;
  static final _mutating = <String>{};
  final _storage = const FlutterSecureStorage();
  Booking? booking;
  PaymentSnapshot? intent;
  PaymentSnapshot? methods;
  Json? operation;
  bool busy = false;
  bool reconciled = false;
  String? error;
  bool _disposed = false;
  String get _storageKey => 'demo_payment_${_userGuid}_$bookingGuid';
  bool get valid =>
      !_disposed &&
      _userGuid != null &&
      currentUser?.id == _userGuid &&
      repository.api.session.role == 0 &&
      repository.api.session.authenticated.value &&
      repository.api.session.deviceSessionReady &&
      repository.api.session.isCurrentGeneration(_generation);
  bool get paid =>
      booking?.status == 'confirmed' &&
      booking?.paymentStatus == 'paid' &&
      intent?.intentStatus == 'paid' &&
      intent?.attemptStatus == 'paid' &&
      intent?.isDemo == true &&
      booking?.paymentProvider == 'demo' &&
      booking?.paymentEnvironment == 'demo' &&
      booking?.paymentTestOnly == true;
  bool get canPay =>
      valid &&
      reconciled &&
      methods?.demoAvailable == true &&
      intent?.demoAvailable == true &&
      booking?.status == 'awaiting_payment';
  bool get pending =>
      intent?.isDemo == true &&
      intent?.intentStatus == 'processing' &&
      intent?.attemptStatus == 'pending' &&
      intent?.attemptGuid != null;
  bool get canStart =>
      canPay &&
      ((intent?.intentStatus == 'not_created' && intent?.lastAttempt == null) ||
          (intent?.intentStatus == 'requires_payment' &&
              const ['failed', 'expired'].contains(intent?.attemptStatus)));
  bool get needsRecovery =>
      reconciled &&
      !paid &&
      !pending &&
      !((intent?.intentStatus == 'not_created' &&
              intent?.lastAttempt == null) ||
          (intent?.intentStatus == 'requires_payment' &&
              const ['failed', 'expired'].contains(intent?.attemptStatus)));
  String? get lockedOutcome {
    if (operation?['kind'] != 'simulate') return null;
    return operation!['outcome'] as String?;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _requireValid() {
    if (!valid) throw const ApiException('Sesi pembayaran telah berubah.', 401);
  }

  void _sessionChanged() {
    booking = null;
    intent = null;
    methods = null;
    operation = null;
    reconciled = false;
    error = 'Sesi berubah. Buka kembali pembayaran.';
    _notify();
  }

  /// Always reads both authoritative resources, even if one read fails.
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
    for (final snapshot in [freshIntent!, freshMethods!]) {
      if (snapshot.json['amount'] != freshBooking!.totalAmount ||
          snapshot.json['currency'] != freshBooking!.currency ||
          snapshot.json['booking_status'] != freshBooking!.status ||
          snapshot.json['payment_status'] != freshBooking!.paymentStatus) {
        throw const ApiException('Status pembayaran berubah. Periksa kembali.',
            null, 'invalid_response');
      }
    }
    booking = freshBooking;
    intent = freshIntent;
    methods = freshMethods;
    final saved = await _storage.read(key: _storageKey);
    _requireValid();
    operation = saved == null ? null : jsonDecode(saved) as Json;
    // A known current attempt resolves initiation; a terminal attempt resolves simulation.
    final kind = operation?['kind'];
    final resolved = kind == 'initiate'
        ? intent?.attemptGuid != null &&
            intent?.attemptGuid != operation!['base_attempt_guid']
        : kind == 'simulate' &&
            (intent?.attemptGuid != operation!['attempt_guid'] ||
                const ['paid', 'failed', 'expired']
                    .contains(intent?.attemptStatus));
    if (operation != null && resolved) await _clearOperation();
    _requireValid();
    reconciled = true;
  }

  Future<void> _clearOperation() async {
    _requireValid();
    await _storage.delete(key: _storageKey);
    operation = null;
  }

  Future<void> recover() async {
    if (busy || !valid || _mutating.contains(_storageKey)) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _read();
      if (paid) BookingEvents.notify();
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

  Future<void> _saveOperation(String kind, {String? outcome}) async {
    final random = Random.secure();
    final key = List.generate(
            32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    operation = {
      'kind': kind,
      'key': key,
      if (kind == 'initiate') 'base_attempt_guid': intent?.attemptGuid,
      if (kind == 'simulate') 'attempt_guid': intent!.attemptGuid,
      if (outcome != null) 'outcome': outcome
    };
    await _storage.write(key: _storageKey, value: jsonEncode(operation));
    _requireValid();
  }

  /// Only explicit user actions mutate. Resume/rebuild/recovery never POST.
  Future<void> submit({String? outcome}) async {
    if (busy || !valid || !_mutating.add(_storageKey)) return;
    busy = true;
    error = null;
    _notify();
    try {
      await _read();
      if (paid) return;
      final kind = outcome == null ? 'initiate' : 'simulate';
      if (!canPay ||
          (kind == 'initiate' && !canStart && !pending) ||
          (kind == 'simulate' &&
              (!pending ||
                  !const ['success', 'failed', 'expired'].contains(outcome)))) {
        throw const ApiException(
            'Periksa status pembayaran dan kelayakan booking sebelum melanjutkan.');
      }
      if (kind == 'initiate' && pending) return;
      if (operation != null &&
          (operation!['kind'] != kind ||
              (kind == 'simulate' &&
                  (operation!['outcome'] != outcome ||
                      operation!['attempt_guid'] != intent!.attemptGuid)))) {
        throw const ApiException(
            'Operasi sebelumnya belum pasti. Lanjutkan dengan skenario yang tersimpan.');
      }
      if (operation == null) await _saveOperation(kind, outcome: outcome);
      _requireValid();
      final response = kind == 'initiate'
          ? await repository.initiateDemoPayment(
              bookingGuid, operation!['key'] as String)
          : await repository.simulateDemoPayment(
              bookingGuid,
              operation!['key'] as String,
              operation!['attempt_guid'] as String,
              operation!['outcome'] as String);
      _requireValid();
      if (response['booking_guid'] != bookingGuid ||
          response['provider'] != 'demo' ||
          response['environment'] != 'demo' ||
          response['test_only'] != true ||
          response['attempt_guid'] is! String ||
          response['status'] !=
              (kind == 'initiate'
                  ? 'pending'
                  : outcome == 'success'
                      ? 'paid'
                      : outcome) ||
          (kind == 'simulate' &&
              response['attempt_guid'] != operation!['attempt_guid'])) {
        throw const ApiException('Respons pembayaran belum dapat dipastikan.',
            null, 'invalid_response');
      }
      await _read();
      BookingEvents.notify();
    } catch (e) {
      if (valid) {
        error = paymentError(e);
        // No second mutation, even on 409/network/5xx; preserve the exact key and payload.
        try {
          await _read();
          BookingEvents.notify();
        } catch (_) {
          reconciled = false;
        }
      }
    } finally {
      _mutating.remove(_storageKey);
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    repository.api.session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}
