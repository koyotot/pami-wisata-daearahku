import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'booking_state.dart';
import 'business_repository.dart';
import 'ticket_models.dart';

class TicketScannerState extends ChangeNotifier {
  final BusinessRepository repository;
  late final int _generation;
  String? _payload;
  String? _key;
  Json? preview;
  Json? result;
  Json? scope;
  String? error;
  bool loading = false;
  bool confirmUncertain = false;
  bool _disposed = false;
  bool get valid =>
      !_disposed &&
      repository.api.session.isCurrentGeneration(_generation) &&
      repository.api.session.authenticated.value &&
      (repository.api.session.role == 1 || repository.api.session.role == 2);
  bool get canScan =>
      valid &&
      !loading &&
      (scope?['global'] == true ||
          (scope?['destinations'] as List? ?? []).isNotEmpty);
  bool get hasCapture => _payload != null;
  bool get canConfirm =>
      valid && !loading && preview?['can_confirm'] == true && result == null;

  TicketScannerState(this.repository) {
    _generation = repository.api.session.sessionGeneration;
    repository.api.session.sessionChanges.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!valid) {
      _payload = null;
      _key = null;
      preview = null;
      result = null;
      scope = null;
      error = 'Sesi berubah. Silakan masuk kembali.';
      notifyListeners();
    }
  }

  Future<void> loadScope() async {
    if (!valid || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.ticketScanScope();
      if (valid) scope = value;
    } catch (e) {
      if (valid) error = ticketErrorMessage(e);
    } finally {
      if (valid) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> capture(String payload) async {
    if (!canScan || hasCapture) return;
    _payload = payload;
    await retryPreview();
  }

  Future<void> retryPreview() async {
    if (!valid || loading || _payload == null || confirmUncertain) return;
    loading = true;
    error = null;
    preview = null;
    notifyListeners();
    try {
      final value = await repository.previewTicket(_payload!);
      if (valid) preview = value;
    } catch (e) {
      if (valid) error = ticketErrorMessage(e);
    } finally {
      if (valid) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> confirm() async {
    if (!canConfirm || _payload == null) return;
    _key ??= _newKey();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await repository.confirmTicket(_payload!, _key!);
      if (!valid) return;
      result = value;
      confirmUncertain = false;
      _payload = null;
      _key = null;
      BookingEvents.notify();
    } catch (e) {
      if (!valid) return;
      confirmUncertain = e is ApiException && e.outcomeUnknown;
      error = confirmUncertain
          ? 'Hasil konfirmasi belum diketahui. Coba konfirmasi lagi dengan permintaan yang sama.'
          : ticketErrorMessage(e);
      if (!confirmUncertain) preview = null;
    } finally {
      if (valid) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    if (!valid || loading || confirmUncertain) return;
    _payload = null;
    _key = null;
    preview = null;
    result = null;
    error = null;
    notifyListeners();
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _payload = null;
    _key = null;
    preview = null;
    result = null;
    repository.api.session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}
