import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_state.dart';
import 'app_data.dart';
import 'business_repository.dart';
import 'gallery_draft.dart' show galleryUuid;
import 'operational_models.dart';

final operationsDataChanges = ValueNotifier<int>(0);

/// A detail is actionable only after both booking and claim were reread.
class ApprovalDetailState extends ChangeNotifier {
  ApprovalDetailState(this.repository, this.bookingGuid, {AuthSession? session})
      : session = session ?? repository.api.session {
    _generation = this.session.sessionGeneration;
    _role = this.session.role;
    _actor = currentUser?.id;
    _decider = AdminBookingDecider(repository, session: this.session);
    this.session.sessionChanges.addListener(_sessionChanged);
  }
  final BusinessRepository repository;
  final AuthSession session;
  final String bookingGuid;
  late final int _generation;
  late final int? _role;
  late final String? _actor;
  late final AdminBookingDecider _decider;
  Booking? booking;
  ApprovalClaim? claim;
  String? message;
  bool busy = false;
  bool fresh = false;
  bool accessRevoked = false;
  bool uncertain = false;
  bool _disposed = false;
  String? _operation;
  String? _key;
  Json _payload = const {};
  String? get pendingKey => _key;
  bool get valid =>
      !_disposed &&
      session.isCurrentGeneration(_generation) &&
      session.authenticated.value &&
      session.deviceSessionReady &&
      canAccessAdmin(_role) &&
      session.role == _role &&
      currentUser?.id == _actor;
  bool get pending =>
      booking?.status == 'pending_approval' &&
      DateTime.tryParse(booking?.json['approval_expires_at'] as String? ?? '')
              ?.isAfter(DateTime.now().toUtc()) ==
          true;
  bool get mine =>
      claim?.activeAt(DateTime.now().toUtc()) == true &&
      claim?.ownerGuid == _actor;
  bool get canDecide =>
      valid &&
      fresh &&
      !busy &&
      !uncertain &&
      !accessRevoked &&
      pending &&
      mine;
  bool get canClaim =>
      valid &&
      fresh &&
      !busy &&
      !uncertain &&
      !accessRevoked &&
      pending &&
      claim != null &&
      !claim!.activeAt(DateTime.now().toUtc());
  bool get canReassign =>
      valid &&
      _role == 2 &&
      fresh &&
      !busy &&
      !uncertain &&
      !accessRevoked &&
      pending;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (!valid) {
      booking = null;
      claim = null;
      _key = null;
      _payload = const {};
      fresh = false;
      _emit();
    }
  }

  Future<void> _read() async {
    final detail = await repository.adminBooking(bookingGuid);
    if (!valid) return;
    ApprovalClaim? latest;
    if (detail.status == 'pending_approval') {
      // Laravel has no GET claim endpoint or booking_guid queue filter.
      for (var page = 1;; page++) {
        final rows = await repository.approvalQueue(query: {
          'destination_guid': detail.destinationGuid,
          'page': '$page',
          'per_page': '100',
        });
        if (!valid) return;
        for (final row in rows.items) {
          if (row.bookingGuid == bookingGuid) latest = row.claim;
        }
        final hasNext = rows.links?.containsKey('next') == true
            ? rows.links!['next'] != null
            : page < ((rows.meta?['last_page'] as num?)?.toInt() ?? 1);
        if (latest != null || !hasNext || rows.items.isEmpty) break;
      }
    }
    if (!valid) return;
    booking = detail;
    claim = latest;
    fresh = true;
  }

  Future<void> _failure(Object error) async {
    fresh = false;
    message = adminErrorMessage(error);
    if (error is ApiException && (error.status == 403 || error.status == 404)) {
      booking = null;
      claim = null;
      accessRevoked = true;
      uncertain = false;
      _key = null;
      _payload = const {};
      message =
          'Akses destinasi berubah. Kembali ke pilihan destinasi dan muat ulang.';
      try {
        await session.me();
      } catch (_) {/* Session handles invalid credentials. */}
    }
  }

  Future<void> handleAccessError(Object error) async {
    if (!valid) return;
    await _failure(error);
    _emit();
  }

  Future<void> refresh() async {
    if (!valid || busy || accessRevoked) return;
    busy = true;
    fresh = false;
    message = null;
    _emit();
    try {
      await _read();
      if (valid && uncertain) {
        // Reading never proves a timed-out write completed; keep its key for recovery.
        message =
            'Status terbaru dimuat. Hasil tindakan belum terkonfirmasi; periksa ulang dengan kunci yang sama.';
      }
    } catch (e) {
      if (valid) await _failure(e);
    }
    if (valid) {
      busy = false;
      _emit();
    }
  }

  Future<void> mutate(String action,
      {String? adminGuid, String? reason}) async {
    if (!valid || busy || uncertain || accessRevoked) return;
    if (action == 'claim' && !canClaim ||
        action == 'release' && !canDecide ||
        action == 'reassign' && !canReassign) {
      return;
    }
    if (!const ['claim', 'release', 'reassign'].contains(action)) return;
    if (action == 'reassign' &&
        (adminGuid == null || reason == null || reason.trim().isEmpty)) {
      return;
    }
    _operation = action;
    _key = galleryUuid();
    _payload = {
      if (adminGuid != null) 'admin_guid': adminGuid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()
    };
    await _sendMutation();
  }

  /// Explicit recovery reuses the original action, payload and idempotency key.
  Future<void> recoverMutation() async {
    if (!valid || busy || !uncertain || _key == null || accessRevoked) return;
    busy = true;
    _emit();
    try {
      await _read();
    } catch (e) {
      if (valid) await _failure(e);
    }
    if (!valid) return;
    busy = false;
    if (!fresh || accessRevoked) {
      _emit();
      return;
    }
    await _sendMutation();
  }

  Future<void> _sendMutation() async {
    busy = true;
    fresh = false;
    message = null;
    _emit();
    try {
      final result = await repository
          .mutateApprovalClaim(bookingGuid, _operation!, _key!, body: _payload);
      if (!valid) return;
      claim = result;
      uncertain = false;
      _key = null;
      message = 'Status claim dikonfirmasi server.';
      operationsDataChanges.value++;
    } catch (e) {
      if (!valid) return;
      final apiError = e is ApiException
          ? e
          : const ApiException(
              'Respons layanan tidak valid.', null, 'invalid_response');
      uncertain = apiError.outcomeUnknown;
      if (!uncertain) _key = null;
      await _failure(apiError);
      if (!valid) return;
      if (!accessRevoked) {
        try {
          await _read();
        } catch (readError) {
          if (valid) await _failure(readError);
        }
      }
      if (valid && uncertain) {
        message =
            'Hasil tindakan belum terkonfirmasi. Muat status dan periksa ulang dengan kunci yang sama.';
      }
    }
    if (valid && !uncertain && !accessRevoked && _key == null && !fresh) {
      try {
        await _read();
      } catch (e) {
        if (valid) await _failure(e);
      }
    }
    if (valid) {
      busy = false;
      _emit();
    }
  }

  Future<void> decide({required bool approve, String? reason}) async {
    if (!canDecide) return;
    busy = true;
    fresh = false;
    message = null;
    _emit();
    try {
      await _read();
      if (!valid) return;
      if (!fresh || !pending || !mine) {
        message =
            'Claim atau status berubah. Periksa status terbaru sebelum memutuskan.';
      } else {
        final result = await _decider.decide(bookingGuid,
            approve: approve, reason: reason);
        if (!valid) return;
        message = result.message;
        operationsDataChanges.value++;
        if (result.booking != null) booking = result.booking;
        if (result.error?.status == 403 || result.error?.status == 404) {
          await _failure(result.error!);
        } else {
          await _read();
        }
      }
    } catch (e) {
      if (valid) await _failure(e);
    }
    if (valid) {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.sessionChanges.removeListener(_sessionChanged);
    _decider.dispose();
    super.dispose();
  }
}
