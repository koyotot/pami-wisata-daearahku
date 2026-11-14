import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/app_data.dart' show currentUser;
import '../../data/business_repository.dart';
import '../../data/operational_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/operations_chrome.dart'
    show OperationsFilterBar, operationsPeriodLabel;
import '../../widgets/operations_option_sheet.dart';
import '../../widgets/operations_status.dart';
import 'admin_common.dart';
import 'operations_booking_screen.dart';
import 'operations_dashboard/operations_dashboard.dart'
    show
        OperationsPage,
        OperationsSkeleton,
        showOperationsFilters,
        showOperationsDestinationPicker,
        showOperationsDateRangeCalendar;

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
  String? _destinationLabel;
  String? _error;
  bool _loading = false;
  bool _next = false;
  bool _revoked = false;
  int _page = 0;
  int _request = 0;
  String _ownership = 'all';
  String _query = '';
  String _sort = 'deadline';
  final Map<String, String> _names = {};
  final _search = TextEditingController();
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
    if (_role == 1) {
      final now = DateTime.now().toUtc();
      _filters = {
        'from': isoDay(DateTime(now.year, now.month)),
        'to': isoDay(DateTime(now.year, now.month + 1, 0)),
        ..._filters,
      };
    }
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
        _names.clear();
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
        _page = page;
        _next = result.links?.containsKey('next') == true
            ? result.links!['next'] != null
            : page < ((result.meta?['last_page'] as num?)?.toInt() ?? 1);
      });
      if (_role == 2 && _names.isEmpty) _loadOwnerNames(request);
    } catch (e) {
      if (!_valid || request != _request) return;
      setState(() {
        _error = adminErrorMessage(e);
        if (e is ApiException && (e.status == 403 || e.status == 404)) {
          _items = [];
          _filters = {};
          _destinationLabel = null;
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

  /// Resolves claim owners to names for the superadmin view. Failures only
  /// leave the generic "Admin lain" label; they never block the queue.
  Future<void> _loadOwnerNames(int request) async {
    try {
      for (var page = 1; page <= 5; page++) {
        final result = await _repository.adminAccounts(
            query: {'page': '$page', 'per_page': '100'});
        if (!_valid || request != _request) return;
        setState(() {
          for (final account in result.items) {
            _names[account.guid] = account.name;
          }
        });
        if (page >= ((result.meta?['last_page'] as num?)?.toInt() ?? 1)) break;
      }
    } catch (_) {}
  }

  Future<void> _filter() async {
    if (!_valid || _revoked) return;
    final request = _request;
    final revision = _session.sessionChanges.value;
    var destinationLabel = _destinationLabel;
    final filters = await showOperationsFilters(context,
        repository: _repository,
        session: _session,
        initial: _filters,
        home: true,
        utc: true,
        destinationLabel: _destinationLabel,
        onDestinationLabelSelected: (label) => destinationLabel = label);
    if (filters == null ||
        !_valid ||
        _revoked ||
        request != _request ||
        revision != _session.sessionChanges.value) return;
    setState(() {
      _filters = filters;
      _destinationLabel =
          filters['destination_guid'] == null ? null : destinationLabel;
    });
    await _load();
  }

  Future<void> _destinationFilter() async {
    if (!_valid || _revoked) return;
    String? label;
    final destination = await showOperationsDestinationPicker(context,
        repository: _repository,
        session: _session,
        initial: _filters['destination_guid'],
        home: _role == 2,
        onLabelSelected: (value) => label = value);
    if (!_valid || _revoked || destination == null) return;
    setState(() {
      _destinationLabel = destination.isEmpty ? null : label;
      if (destination.isEmpty) {
        _filters.remove('destination_guid');
      } else {
        _filters['destination_guid'] = destination;
      }
    });
    await _load();
  }

  Future<void> _dateFilter() async {
    if (!_valid || _revoked) return;
    final range = await showOperationsDateRangeCalendar(context,
        from: DateTime.tryParse(_filters['from'] ?? ''),
        to: DateTime.tryParse(_filters['to'] ?? ''),
        home: _role == 2,
        utc: true);
    if (!_valid || _revoked || range == null) return;
    setState(() {
      _filters['from'] = isoDay(range.start);
      _filters['to'] = isoDay(range.end);
    });
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
    _search.dispose();
    _session.sessionChanges.removeListener(_changedSession);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isMine(OperationalRow row) =>
      row.claimState == 'active' &&
      row.raw['owner_user_guid'] == currentUser?.id;

  bool _matchesOwnership(OperationalRow row) =>
      _ownership == 'all' ||
      (_ownership == 'active'
          ? row.claimState == 'active'
          : _ownership == 'mine'
              ? _isMine(row)
              : row.claimState != 'active');

  // ── Shared blocks ────────────────────────────────────────

  Widget _ownershipTabs() => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AdminColors.tint, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (final item in [
          ('all', 'Semua'),
          ('unclaimed', 'Tersedia'),
          if (_role == 1) ('mine', 'Claim saya') else ('active', 'Claim aktif')
        ])
          Expanded(
              child: Semantics(
                  selected: _ownership == item.$1,
                  child: TextButton(
                      key: ValueKey('queue-ownership-${item.$1}'),
                      style: TextButton.styleFrom(
                          foregroundColor: _ownership == item.$1
                              ? AdminColors.blue
                              : AdminColors.textMuted,
                          backgroundColor: _ownership == item.$1
                              ? AdminColors.card
                              : Colors.transparent,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => setState(() => _ownership = item.$1),
                      child: Text(item.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))))),
      ]));

  Widget _errorBox() => Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _revoked ? const Color(0xFFFFECEA) : const Color(0xFFFFF0D6),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            _revoked ? PhosphorIconsRegular.lock : PhosphorIconsRegular.wifiSlash,
            color: const Color(0xFF795018)),
        const SizedBox(height: 10),
        Text(_revoked ? 'Akses telah berubah' : 'Antrean belum dapat dimuat',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_error!, style: const TextStyle(fontSize: 13, height: 1.5)),
      ]));

  Widget _emptyBox() {
    final filtering =
        _filters.isNotEmpty || _ownership != 'all' || _query.trim().isNotEmpty;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AdminColors.border),
            borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Icon(
              filtering
                  ? PhosphorIconsRegular.magnifyingGlassMinus
                  : PhosphorIconsRegular.checkCircle,
              size: 40,
              color: filtering ? AdminColors.blue : const Color(0xFF16784C)),
          const SizedBox(height: 16),
          Text(filtering ? 'Tidak ada hasil' : 'Antrean sudah kosong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              filtering
                  ? 'Tidak ada booking untuk filter ini. Reset filter atau muat halaman berikutnya.'
                  : 'Semua tertangani. Tidak ada antrean persetujuan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.6, color: Color(0xFF526787))),
          if (_role != 1 && (_ownership != 'all' || _query.isNotEmpty))
            TextButton(
                onPressed: () => setState(() {
                      _ownership = 'all';
                      _query = '';
                      _search.clear();
                    }),
                child: const Text('Reset status claim')),
        ]));
  }

  // ── Superadmin ───────────────────────────────────────────

  static const _sortLabels = {
    'deadline': 'Tenggat terdekat',
    'newest': 'Terbaru',
    'name': 'Nama A–Z',
  };

  List<OperationalRow> _superadminRows() {
    final query = _query.trim().toLowerCase();
    final rows = _items.where(_matchesOwnership).where((row) {
      if (query.isEmpty) return true;
      final owner = _names[row.raw['owner_user_guid']] ?? '';
      return [row.name ?? '', row.bookingGuid ?? '', owner]
          .any((text) => text.toLowerCase().contains(query));
    }).toList();
    DateTime? time(OperationalRow row, String key) =>
        DateTime.tryParse('${row.raw[key] ?? ''}');
    int byTime(OperationalRow a, OperationalRow b, String key, int sign) {
      final x = time(a, key);
      final y = time(b, key);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return sign * x.compareTo(y);
    }

    rows.sort(switch (_sort) {
      'newest' => (a, b) => byTime(a, b, 'updated_at', -1),
      'name' => (a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()),
      _ => (a, b) => byTime(a, b, 'approval_expires_at', 1),
    });
    return rows;
  }

  Future<void> _pickSort() async {
    final value = await showOperationsOptionSheet(context,
        title: 'Urutkan',
        options: _sortLabels,
        selected: _sort,
        keyPrefix: 'queue-sort');
    if (value != null && mounted) setState(() => _sort = value);
  }

  Widget _statCard(String value, String label, {Color? dot}) => Expanded(
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy)),
            const SizedBox(height: 6),
            Row(children: [
              if (dot != null) ...[
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary))),
            ]),
          ])));

  Widget _filterTile(
          {required String caption,
          required String label,
          required IconData icon,
          required VoidCallback? onTap,
          Key? key}) =>
      Expanded(
          child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  key: key,
                  onTap: onTap,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(icon, size: 18, color: AppColors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(caption,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      letterSpacing: .6,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                            ])),
                        const Icon(PhosphorIconsRegular.caretDown,
                            size: 16, color: AppColors.blue),
                      ])))));

  Widget _searchField() => DecoratedBox(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: TextField(
          key: const ValueKey('queue-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(fontSize: 13, color: AppColors.navy),
          decoration: InputDecoration(
              hintText: 'Cari destinasi, kode booking...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                  size: 20, color: AppColors.blue),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () => setState(() {
                            _query = '';
                            _search.clear();
                          }),
                      icon: const Icon(PhosphorIconsRegular.x, size: 18)))));

  String _shortId(String guid) => guid.length <= 16
      ? guid
      : '${guid.substring(0, 8)}…${guid.substring(guid.length - 7)}';

  Widget _queueCard(OperationalRow row) {
    final active = row.claimState == 'active';
    final mine = _isMine(row);
    final ownerGuid = row.raw['owner_user_guid'] as String?;
    final ownerName = _names[ownerGuid] ?? 'Admin lain';
    final approval = formatDeadline(row.raw['approval_expires_at']);
    final visit = '${row.raw['visit_date'] ?? ''}';
    final (badge, badgeTone) = mine
        ? ('Claim Anda', OperationsTone.blue)
        : active
            ? ('Claim admin lain', OperationsTone.grey)
            : ('Tersedia', OperationsTone.green);
    final boxTone = mine
        ? OperationsTone.blue
        : active
            ? OperationsTone.grey
            : OperationsTone.orange;
    final (boxTitle, boxBody) = mine
        ? (
            'Claim aktif · ${formatDeadline(row.raw['expires_at'])}',
            'Perlu keputusan sebelum claim berakhir'
          )
        : active
            ? ('Ditangani $ownerName', 'Batas persetujuan · $approval')
            : ('Batas persetujuan · $approval', 'Menunggu tindakan admin');
    final colors = operationsToneColors(boxTone);
    final buttonLabel = mine
        ? 'Kelola Claim'
        : active
            ? 'Lihat Detail'
            : 'Tinjau Booking';
    return Container(
        key: ValueKey(row.bookingGuid),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(_shortId(row.bookingGuid ?? 'Booking'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            OperationsStatusBadge(badge, badgeTone),
          ]),
          const SizedBox(height: 14),
          Text(row.name ?? 'Destinasi',
              style: const TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          if (visit.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(PhosphorIconsRegular.calendarBlank,
                  size: 15, color: AppColors.blue),
              const SizedBox(width: 6),
              Text(visitDayLabel(visit),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: colors.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(PhosphorIconsRegular.clock, size: 20, color: colors.fg),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(boxTitle,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(boxBody,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: boxTone == OperationsTone.grey
                                  ? AppColors.textSecondary
                                  : colors.fg)),
                    ])),
              ])),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Text(operationalActionLabel(row.action),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary))),
            const SizedBox(width: 12),
            FilledButton.icon(
                key: ValueKey('queue-open-${row.bookingGuid}'),
                onPressed: () => _open(row),
                iconAlignment: IconAlignment.end,
                icon: const Icon(PhosphorIconsRegular.arrowRight, size: 16),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                label: Text(buttonLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
        ]));
  }

  List<Widget> _superadminBody() {
    final rows = _superadminRows();
    final available = _items.where((r) => r.claimState != 'active').length;
    final claimed = _items.length - available;
    return [
      Row(children: [
        _statCard('${_items.length}', 'Total antrean'),
        const SizedBox(width: 10),
        _statCard('$available', 'Tersedia', dot: const Color(0xFF1E7A45)),
        const SizedBox(width: 10),
        _statCard('$claimed', 'Claim aktif', dot: AppColors.textSecondary),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _filterTile(
            key: const ValueKey('queue-destination-filter'),
            caption: 'DESTINASI',
            label: _filters['destination_guid'] == null
                ? 'Semua destinasi'
                : _destinationLabel ?? 'Destinasi terpilih',
            icon: PhosphorIconsRegular.mapPin,
            onTap: _revoked ? null : _destinationFilter),
        const SizedBox(width: 10),
        _filterTile(
            key: const ValueKey('queue-date-filter'),
            caption: 'TGL BOOKING',
            label: operationsPeriodLabel(_filters),
            icon: PhosphorIconsRegular.calendarBlank,
            onTap: _revoked ? null : _dateFilter),
      ]),
      if (_filters.isNotEmpty)
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () {
                  setState(() {
                    _filters = {};
                    _destinationLabel = null;
                  });
                  _load();
                },
                child: const Text('Reset filter'))),
      const SizedBox(height: 10),
      _searchField(),
      const SizedBox(height: 12),
      _ownershipTabs(),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Permintaan Masuk',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          Text('${rows.length} permintaan ditemukan',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ])),
        OutlinedButton.icon(
            key: const ValueKey('queue-sort'),
            onPressed: _pickSort,
            iconAlignment: IconAlignment.end,
            icon: const Icon(PhosphorIconsRegular.caretDown, size: 16),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                backgroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            label: Text(_sortLabels[_sort]!,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      if (_loading)
        _items.isEmpty ? const OperationsSkeleton() : const LinearProgressIndicator(),
      if (_error != null) _errorBox(),
      if (!_loading && _error == null && rows.isEmpty) _emptyBox(),
      for (final row in rows) _queueCard(row),
      if (_next)
        OutlinedButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Muat berikutnya')),
      if (_revoked)
        TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Kembali')),
    ];
  }

  // ── Admin ────────────────────────────────────────────────

  List<Widget> _adminBody() {
    final rows = _items.where(_matchesOwnership).toList();
    return [
      OperationsFilterBar(
          filters: _filters,
          keyPrefix: 'queue',
          destinationLabel: _destinationLabel,
          dateTooltip: 'Filter tanggal pembuatan booking · UTC',
          onDestinationPressed: _revoked ? null : _filter,
          onDatePressed: _revoked ? null : _filter),
      const SizedBox(height: 12),
      _ownershipTabs(),
      const SizedBox(height: 12),
      if (_loading)
        _items.isEmpty ? const OperationsSkeleton() : const LinearProgressIndicator(),
      if (_error != null) _errorBox(),
      if (!_loading && _error == null && rows.isEmpty) _emptyBox(),
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
                            const Icon(PhosphorIconsRegular.clock,
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
                      child: const Text('Lihat & tinjau →')),
                ])),
      if (_next)
        OutlinedButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Muat berikutnya')),
      if (_revoked)
        TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Kembali')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) return const SizedBox.shrink();
    return OperationsPage(
      role: _role,
      embedded: widget.embedded,
      title: 'Antrean Approval',
      subtitle: _role == 2
          ? 'Pengawasan antrean seluruh destinasi'
          : 'Permintaan kunjungan dalam penugasan Anda',
      onRefresh: _load,
      children: _role == 2 ? _superadminBody() : _adminBody(),
    );
  }
}
