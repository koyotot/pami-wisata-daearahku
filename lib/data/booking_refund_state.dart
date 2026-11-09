import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'app_data.dart';
import 'business_repository.dart';
import 'payment_models.dart';

/// Refund request for one paid booking.
///
/// The CTA exists only when the server says the booking is `confirmed` and the payment is `paid`
/// and there is no active, refunded or unrecognised request. The Idempotency-Key and the reason
/// are stored before the POST and reused until the outcome is known, so a timeout or restart can
/// never file a second request. The body is the reason only; money fields belong to Laravel.
class BookingRefundState extends ChangeNotifier {
  BookingRefundState(this.repository, this.bookingGuid,
      {FlutterSecureStorage? storage,
      String Function()? keyGenerator,
      PaymentSnapshot? seed})
      : _storage = storage ?? const FlutterSecureStorage(),
        _keyGenerator = keyGenerator ?? newRefundIdempotencyKey,
        _generation = repository.api.session.sessionGeneration,
        _userGuid = currentUser?.id {
    repository.api.session.sessionChanges.addListener(_sessionChanged);
    if (seed != null) applySnapshot(seed, notify: false);
  }

  final BusinessRepository repository;
  final String bookingGuid;
  final FlutterSecureStorage _storage;
  final String Function() _keyGenerator;
  final int _generation;
  final String? _userGuid;
  static final _mutating = <String>{};

  RefundRequest? refund;

  /// A coherent server snapshot has been read (or seeded).
  bool loaded = false;
  bool loading = false;
  bool submitting = false;
  bool _paidAndConfirmed = false;

  /// Last failure of a submit or reload, already in customer wording.
  String? error;

  /// One-shot success text after a request was filed.
  String? notice;

  Json? _operation;
  bool _disposed = false;
  bool _sessionEnded = false;

  String get _storageKey => 'booking_refund_operation_${_userGuid}_$bookingGuid';

  bool get valid =>
      !_disposed &&
      !_sessionEnded &&
      _userGuid != null &&
      currentUser?.id == _userGuid &&
      repository.api.session.role == 0 &&
      repository.api.session.authenticated.value &&
      repository.api.session.deviceSessionReady &&
      repository.api.session.isCurrentGeneration(_generation);

  /// The reason of an unfinished request. It stays bound to its Idempotency-Key.
  String? get pendingReason => _operation?['reason'] as String?;

  /// The refund action may be offered: paid + confirmed, and no request that is active, refunded
  /// or unrecognised. A rejected request allows a new one.
  bool get canRequest =>
      valid &&
      loaded &&
      _paidAndConfirmed &&
      (refund == null || refund!.isRejected);

  void _sessionChanged() {
    _sessionEnded = true;
    refund = null;
    loaded = false;
    _paidAndConfirmed = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.api.session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  // ── Reading ────────────────────────────────────────────────

  /// Takes a payment-intent snapshot as the current truth for the gate and the latest request.
  /// A malformed refund object marks the state not loaded, so no action is offered.
  void applySnapshot(PaymentSnapshot snapshot, {bool notify = true}) {
    try {
      if (snapshot.bookingGuid != bookingGuid) {
        throw const ApiException(
            'Respons pengembalian dana tidak cocok.', null, 'invalid_response');
      }
      final latest = snapshot.refundRequest;
      refund = latest;
      _paidAndConfirmed = snapshot.paymentStatus == 'paid' &&
          snapshot.bookingStatus == 'confirmed';
      loaded = true;
    } on ApiException {
      refund = null;
      _paidAndConfirmed = false;
      loaded = false;
    }
    if (notify) _notify();
  }

  /// Restores a stored unfinished request without touching the network.
  Future<void> restoreOperation() async {
    final saved = await _storage.read(key: _storageKey);
    if (!valid) return;
    _operation = saved == null ? null : _decode(saved);
    await _dropOperationIfSettled();
    _notify();
  }

  Future<void> load() async {
    if (!valid || loading) return;
    loading = true;
    _notify();
    try {
      await _read();
      await restoreOperation();
    } catch (e) {
      if (valid && !loaded) error = refundErrorMessage(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _read() async {
    final snapshot = await repository.paymentIntent(bookingGuid);
    if (!valid) return;
    applySnapshot(snapshot, notify: false);
  }

  /// A landed request (active, refunded or manually refunded) means the stored key has done its job.
  Future<void> _dropOperationIfSettled() async {
    final current = refund;
    if (_operation != null &&
        current != null &&
        (current.isActive || current.isClosedRefund)) {
      await _storage.delete(key: _storageKey);
      _operation = null;
    }
  }

  Json? _decode(String raw) {
    try {
      final data = jsonDecode(raw);
      return data is Json && data['key'] is String && data['reason'] is String
          ? data
          : null;
    } on FormatException {
      return null;
    }
  }

  // ── Requesting ─────────────────────────────────────────────

  /// Returns true when the server accepted the request. While an earlier attempt is unfinished its
  /// stored reason and key are reused, whatever [reason] says.
  Future<bool> submit(String reason) async {
    if (submitting || !valid) return false;
    if (!canRequest) {
      error = 'Pengembalian dana tidak dapat diajukan untuk booking ini.';
      _notify();
      return false;
    }
    final text = pendingReason ?? reason.trim();
    final invalid = validateRefundReason(text);
    if (invalid != null) {
      error = invalid;
      _notify();
      return false;
    }
    if (!_mutating.add(_storageKey)) return false;
    submitting = true;
    error = null;
    notice = null;
    _notify();
    try {
      if (_operation == null) {
        _operation = {'key': _keyGenerator(), 'reason': text};
        await _storage.write(key: _storageKey, value: jsonEncode(_operation));
      }
      if (!valid) throw const ApiException('Sesi pengajuan telah berubah.', 401);
      final created = await repository.requestRefund(
          bookingGuid, _operation!['key'] as String, text);
      if (!valid) return false;
      await _storage.delete(key: _storageKey);
      _operation = null;
      refund = created;
      notice = 'Pengajuan terkirim. Pengelola akan meninjaunya.';
      return true;
    } catch (e) {
      if (!valid) return false;
      error = refundErrorMessage(e);
      if (e is ApiException && (e.status == 422 || e.status == 409)) {
        // Rejected before or without creating anything: this key can never create a request.
        await _storage.delete(key: _storageKey);
        _operation = null;
        if (e.status == 409) {
          try {
            await _read();
          } catch (_) {
            // Keep what was known; the error already explains the conflict.
          }
        }
      }
      return false;
    } finally {
      _mutating.remove(_storageKey);
      submitting = false;
      _notify();
    }
  }

  void clearError() {
    if (error == null || submitting) return;
    error = null;
    _notify();
  }

  /// Read-only refresh of the request status.
  Future<void> refresh() async {
    if (!valid || loading || submitting) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _read();
      await _dropOperationIfSettled();
    } catch (e) {
      if (valid) error = refundErrorMessage(e);
    } finally {
      loading = false;
      _notify();
    }
  }
}

/// Random (version 4) UUID for the Idempotency-Key header.
String newRefundIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
