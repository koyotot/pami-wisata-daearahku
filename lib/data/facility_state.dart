import 'package:flutter/foundation.dart';
import '../services/auth_session.dart';
import 'admin_state.dart';
import 'business_repository.dart';

bool canManageFacilities(int? role) => role == 2;

/// Hydrates all active choices before allowing replacement of assignments.
class DestinationFacilitiesState extends ChangeNotifier {
  DestinationFacilitiesState(this.repository, {AuthSession? session})
      : session = session ?? repository.api.session {
    this.session.sessionChanges.addListener(_sessionChanged);
  }

  final BusinessRepository repository;
  final AuthSession session;
  List<Facility> items = const [];
  Set<String> selected = {};
  Set<String> _original = {};
  bool loading = false;
  bool ready = false;
  bool saving = false;
  Object? error;
  int _request = 0;
  bool _disposed = false;

  bool get allowed =>
      session.authenticated.value &&
      session.deviceSessionReady &&
      canAccessAdmin(session.role);
  bool get changed => !setEquals(selected, _original);
  bool _current(int request, int generation) =>
      !_disposed &&
      request == _request &&
      session.isCurrentGeneration(generation) &&
      allowed;

  Future<void> load([String? destinationGuid]) async {
    if (!allowed || _disposed) return;
    final request = ++_request;
    final generation = session.sessionGeneration;
    loading = true;
    ready = false;
    error = null;
    items = const [];
    selected = {};
    _original = {};
    notifyListeners();
    try {
      final choices = <String, Facility>{};
      for (var number = 1; number <= 200; number++) {
        final page =
            await repository.activeFacilities(page: number, perPage: 100);
        if (!_current(request, generation)) return;
        for (final item in page.items) {
          if (item.isActive) choices[item.guid] = item;
        }
        final last = page.meta?['last_page'];
        final hasNext = page.links?.containsKey('next') == true
            ? page.links!['next'] != null
            : last is num && number < last;
        if (!hasNext) break;
        if (page.items.isEmpty || number == 200) {
          throw const ApiException(
              'Daftar fasilitas belum lengkap. Muat ulang sebelum memilih.');
        }
      }
      final detail = destinationGuid == null
          ? null
          : await repository.adminDestination(destinationGuid);
      if (!_current(request, generation)) return;
      if (detail != null && detail.guid != destinationGuid) {
        throw const ApiException('Identitas destinasi tidak sesuai.');
      }
      items = choices.values.toList();
      selected = detail?.facilities
              .map((f) => f.guid)
              .where(choices.containsKey)
              .toSet() ??
          {};
      _original = Set.of(selected);
      ready = true;
    } catch (e) {
      if (!_current(request, generation)) return;
      error = e;
    }
    if (!_current(request, generation)) return;
    loading = false;
    notifyListeners();
  }

  String? toggle(String guid, bool value) {
    if (!allowed ||
        !ready ||
        loading ||
        saving ||
        !items.any((f) => f.guid == guid)) {
      return null;
    }
    if (value && selected.length >= 100 && !selected.contains(guid)) {
      return 'Maksimal 100 fasilitas dapat dipilih.';
    }
    selected = {...selected};
    value ? selected.add(guid) : selected.remove(guid);
    notifyListeners();
    return null;
  }

  /// A failed PUT is always reconciled through detail, never assumed committed.
  Future<String?> save(String destinationGuid) async {
    if (!allowed || !ready || loading || saving) {
      return 'Fasilitas belum siap disimpan.';
    }
    if (!changed) return null;
    final generation = session.sessionGeneration;
    final request = _request;
    final desired = Set.of(selected);
    saving = true;
    notifyListeners();
    Object? failure;
    try {
      await repository.assignDestinationFacilities(
          destinationGuid, desired.toList());
    } catch (e) {
      failure = e;
    }
    if (!_current(request, generation)) return 'Sesi telah berakhir.';
    try {
      final detail = await repository.adminDestination(destinationGuid);
      if (!_current(request, generation)) return 'Sesi telah berakhir.';
      if (detail.guid != destinationGuid) {
        throw const ApiException('Identitas destinasi tidak sesuai.');
      }
      final active = items.map((f) => f.guid).toSet();
      final actual =
          detail.facilities.map((f) => f.guid).where(active.contains).toSet();
      _original = Set.of(actual);
      if (!setEquals(desired, actual)) {
        selected = desired;
        failure ??= const ApiException(
            'Pilihan fasilitas belum tersimpan sesuai data server. Periksa pilihan lalu simpan kembali.');
      } else {
        selected = actual;
        failure = null;
      }
    } catch (e) {
      if (!_current(request, generation)) return 'Sesi telah berakhir.';
      ready = false;
      error = e;
      failure = const ApiException(
          'Hasil fasilitas belum dapat dipastikan. Muat ulang fasilitas sebelum mencoba lagi.');
    }
    saving = false;
    notifyListeners();
    return failure == null ? null : adminErrorMessage(failure);
  }

  void _sessionChanged() {
    _request++;
    items = const [];
    selected = {};
    _original = {};
    ready = false;
    loading = false;
    saving = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}
