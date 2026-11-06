import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/app_data.dart' show currentUser;
import '../data/business_repository.dart';
import '../data/operational_models.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'admin_common.dart';
import 'operations_booking_screen.dart';
import 'operations_dashboard.dart'
    show OperationsPage, OperationsSkeleton, showOperationsFilters;

class OperationsQueueScreen extends StatefulWidget {
  const OperationsQueueScreen(
      {super.key,
      this.repository,
      this.session,
      this.filters,
      this.embedded = false,
      this.active = true});
  final BusinessRepository? repository;
  final AuthSession? session;
  final Map<String, String>? filters;
  final bool embedded;
  final bool active;
  @override
  State<OperationsQueueScreen> createState() => _OperationsQueueScreenState();
}

class _OperationsQueueScreenState extends State<OperationsQueueScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session =
      widget.session ?? widget.repository?.api.session ?? AuthSession.instance;
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final int _generation = _session.sessionGeneration;
  late final int? _role = _session.role;
  List<OperationalRow> _items = [];
  Map<String, String> _filters = {};
  Json? _meta;
  String? _error;
  bool _loading = false;
  bool _next = false;
  bool _revoked = false;
  int _page = 0;
  int _request = 0;
  String _ownership = 'all';
  bool get _valid =>
      mounted &&
      _session.isCurrentGeneration(_generation) &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.role == _role &&
      canAccessAdmin(_role);

  @override
  void initState() {
    super.initState();
    _filters = Map.of(widget.filters ?? const {});
    _session.sessionChanges.addListener(_changedSession);
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(OperationsQueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  void _changedSession() {
    if (mounted) {
      setState(() {
        _items = [];
        _meta = null;
        _request++;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!_valid || _revoked || more && (_loading || !_next)) return;
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items = [];
        _meta = null;
      }
    });
    try {
      final result = await _repository.approvalQueue(
          query: {..._filters, 'page': '$page', 'per_page': '30'});
      if (!_valid || request != _request) return;
      setState(() {
        _items = {
          ...{for (final row in _items) row.bookingGuid: row},
          ...{for (final row in result.items) row.bookingGuid: row}
        }.values.toList();
        _meta = result.meta;
        _page = page;
        _next = result.links?.containsKey('next') == true
            ? result.links!['next'] != null
            : page < ((result.meta?['last_page'] as num?)?.toInt() ?? 1);
      });
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = adminErrorMessage(e);
        if (e is ApiException && (e.status == 403 || e.status == 404)) {
          _items = [];
          _meta = null;
          _filters = {};
          _revoked = true;
          _error = 'Akses destinasi berubah. Kembali ke pilihan destinasi.';
        }
      });
      if (_revoked) {
        try {
          await _session.me();
        } catch (_) {}
      }
    }
    if (_valid && request == _request) setState(() => _loading = false);
  }

  Future<void> _dateFilter() async {
    final filters = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        utc: true);
    if (!_valid || filters == null) return;
    setState(() => _filters = filters);
    await _load();
  }

  Future<void> _open(OperationalRow row) async {
    if (!_valid || row.bookingGuid == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OperationsBookingScreen(
            bookingGuid: row.bookingGuid!,
            repository: _repository,
            session: _session)));
    if (_valid) await _load();
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_changedSession);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    final rows = _items
        .where((row) =>
            _ownership == 'all' ||
            (_ownership == 'active'
                ? row.claimState == 'active'
                : _ownership == 'mine'
                    ? row.claimState == 'active' &&
                        row.raw['owner_user_guid'] == currentUser?.id
                    : row.claimState != 'active'))
        .toList();
    return OperationsPage(
      role: _role,
      embedded: widget.embedded,
      title: 'Antrean Approval',
      subtitle: _role == 2
          ? 'Pengawasan antrean seluruh destinasi'
          : 'Permintaan kunjungan dalam penugasan Anda',
      onRefresh: _load,
      actions: [
        IconButton(
            tooltip: 'Filter destinasi dan tanggal',
            onPressed: _dateFilter,
            icon: const Icon(Icons.tune_rounded))
      ],
      children: [
        if (_meta?['generated_at'] != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Snapshot server: ${_meta!['generated_at']}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF526787)))),
        Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: AdminColors.tint,
                borderRadius: BorderRadius.circular(14)),
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final item in [
                ('all', 'Semua'),
                ('unclaimed', 'Tersedia'),
                if (_role == 1)
                  ('mine', 'Claim Saya')
                else
                  ('active', 'Claim aktif')
              ])
                ChoiceChip(
                    showCheckmark: false,
                    selectedColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ownership == item.$1
                            ? AdminColors.blue
                            : const Color(0xFF526787)),
                    label: Text(item.$2),
                    selected: _ownership == item.$1,
                    onSelected: (_) => setState(() => _ownership = item.$1)),
            ])),
        const SizedBox(height: 12),
        const Text('Berdasarkan tanggal pembuatan booking · UTC',
            style: TextStyle(fontSize: 12, color: Color(0xFF526787))),
        const SizedBox(height: 12),
        if (_filters.isNotEmpty)
          TextButton(
              onPressed: () {
                setState(() => _filters = {});
                _load();
              },
              child: const Text('Reset filter')),
        if (_loading)
          _items.isEmpty
              ? const OperationsSkeleton()
              : const LinearProgressIndicator(),
        if (_error != null)
          Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: _revoked
                      ? const Color(0xFFFFECEA)
                      : const Color(0xFFFFF0D6),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_revoked ? Icons.lock_outline : Icons.wifi_off,
                        color: const Color(0xFF795018)),
                    const SizedBox(height: 10),
                    Text(
                        _revoked
                            ? 'Akses telah berubah'
                            : 'Antrean belum dapat dimuat',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_error!,
                        style: const TextStyle(fontSize: 13, height: 1.5)),
                  ])),
        if (!_loading && _error == null && rows.isEmpty)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AdminColors.border),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Icon(
                    _filters.isNotEmpty || _ownership != 'all'
                        ? Icons.search_off_rounded
                        : Icons.task_alt_rounded,
                    size: 40,
                    color: _filters.isNotEmpty || _ownership != 'all'
                        ? AdminColors.blue
                        : const Color(0xFF16784C)),
                const SizedBox(height: 16),
                Text(
                    _filters.isNotEmpty || _ownership != 'all'
                        ? 'Tidak ada hasil'
                        : 'Antrean sudah kosong',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    _filters.isNotEmpty || _ownership != 'all'
                        ? 'Tidak ada booking untuk filter ini. Reset filter atau muat halaman berikutnya.'
                        : 'Semua tertangani. Tidak ada antrean persetujuan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, height: 1.6, color: Color(0xFF526787))),
                if (_ownership != 'all')
                  TextButton(
                      onPressed: () => setState(() => _ownership = 'all'),
                      child: const Text('Reset status claim')),
              ])),
        for (final row in rows)
          Container(
              key: ValueKey(row.bookingGuid),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AdminColors.border),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(row.bookingGuid ?? 'Booking',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF526787))),
                    const SizedBox(height: 8),
                    Text(row.name ?? 'Destinasi',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.navy)),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: AdminBadge(
                            row.claimState == 'active'
                                ? 'Claim aktif'
                                : 'Tersedia untuk diambil',
                            row.claimState == 'active'
                                ? const Color(0xFF98621E)
                                : const Color(0xFF16784C))),
                    if (row.claimState == 'active') ...[
                      const SizedBox(height: 6),
                      Text('Pemilik: ${row.raw['owner_user_guid'] ?? '—'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF526787))),
                      Text('Claim hingga: ${row.raw['expires_at'] ?? '—'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF526787))),
                    ],
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF0D6),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 18, color: Color(0xFF795018)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      '${operationalActionLabel(row.action)}\nBatas: ${row.raw['approval_expires_at'] ?? '—'}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: Color(0xFF795018)))),
                            ])),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => _open(row),
                        style: FilledButton.styleFrom(
                            backgroundColor: AdminColors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text(_role == 2
                            ? 'Tinjau & alihkan →'
                            : 'Lihat & tinjau →')),
                  ])),
        if (_next)
          OutlinedButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: const Text('Muat berikutnya')),
        if (!_loading && (_role != 1 || _revoked))
          TextButton(
              onPressed: _revoked ? () => Navigator.maybePop(context) : _load,
              child: Text(_revoked ? 'Kembali' : 'Muat ulang')),
      ],
    );
  }
}
