// ============================================================
// lib/screens/daftar_wisata_screen.dart
// REDESIGN: Biru terang - selaras dengan TambahWisataScreen & Dashboard
// Daftar destinasi dari Laravel (endpoint admin, termasuk nonaktif).
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../data/admin_state.dart';
import '../../data/app_data.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/api_image.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/scroll_aware_status_bar.dart';
import '../../widgets/select_sheet.dart';
import '../../widgets/visit_format.dart' show visitMoney;
import 'admin_common.dart';
import '../user/detail_wisata_screen.dart';
import 'kelola_kuota_screen.dart';
import 'tambah_wisata_screen.dart';

class _C {
  static const blue = Color(0xFF1976D2);
  static const bg = Color(0xFFF5F8FD);
  static const danger = Color(0xFFE5484D);
}

enum _DestinationSort {
  newest('Terbaru'),
  nameAsc('Nama A–Z'),
  priceAsc('Harga terendah'),
  priceDesc('Harga tertinggi');

  const _DestinationSort(this.label);
  final String label;
}

/// Sticky bottom bar with the "Tambah Destinasi" action.
class DestinationAddBar extends StatelessWidget {
  const DestinationAddBar({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => AdminActionBar(
      note: 'Destinasi baru\nIsi detail, lokasi, dan galeri',
      label: 'Tambah Destinasi',
      icon: PhosphorIconsRegular.plus,
      buttonKey: const ValueKey('v3-add'),
      onPressed: onAdd);
}

class DaftarWisataScreen extends StatefulWidget {
  final String mode; // 'view' | 'manage'
  final BusinessRepository? repository;
  final AuthSession? session;
  final bool embedded;
  const DaftarWisataScreen(
      {super.key,
      this.mode = 'view',
      this.repository,
      this.session,
      this.embedded = false});

  @override
  State<DaftarWisataScreen> createState() => DaftarWisataScreenState();
}

class DaftarWisataScreenState extends State<DaftarWisataScreen> {
  String _cari = '';
  String _status = 'active';
  String? _categoryGuid;
  _DestinationSort _sort = _DestinationSort.newest;
  bool _grid = false;
  Map<String, int> _counts = {};
  int _countsRequest = 0;

  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository(ApiClient(_session));
  late final AuthSession _session = widget.session ?? AuthSession.instance;
  late final PagedListController<Destination> _catalog;
  late final PagedListController<Category> _categories;
  final _guard = InFlightGuard();
  final _searchController = TextEditingController();
  Timer? _debounce;

  void _update() {
    if (mounted) setState(() {});
  }

  Map<String, String> get _filters {
    final search = _cari.trim();
    return {
      'status': _status,
      if (_categoryGuid != null) 'category': _categoryGuid!,
      if (search.isNotEmpty) 'search': search,
    };
  }

  Future<void> _loadCategories() => _categories.load();

  Future<void> _loadCatalog({bool counts = true}) async {
    if (!canAccessAdmin(_session.role)) return;
    if (counts && (_hub || widget.mode == 'view')) unawaited(_loadCounts());
    await _catalog.load(filters: _filters);
  }

  /// Per-status totals for the stat cards and segments (same search and
  /// category as the list). Best effort: a failure keeps the previous numbers.
  Future<void> _loadCounts() async {
    final request = ++_countsRequest;
    final generation = _session.sessionGeneration;
    final search = _cari.trim();
    final base = {
      'per_page': '1',
      if (_categoryGuid != null) 'category': _categoryGuid!,
      if (search.isNotEmpty) 'search': search,
    };
    const statuses = ['all', 'active', 'inactive'];
    try {
      final pages = await Future.wait([
        for (final status in statuses)
          _repository.adminDestinations(query: {...base, 'status': status}),
      ]);
      if (!mounted ||
          request != _countsRequest ||
          !_session.isCurrentGeneration(generation)) {
        return;
      }
      final counts = <String, int>{};
      for (var i = 0; i < statuses.length; i++) {
        final total = pages[i].meta?['total'];
        if (total is num) counts[statuses[i]] = total.toInt();
      }
      setState(() => _counts = counts);
    } catch (_) {/* The list itself reports errors. */}
  }

  Future<void> refresh() => _refreshView();

  bool get _hub => widget.mode == 'manage';

  bool _current(int generation, int revision) =>
      mounted &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      canAccessAdmin(_session.role) &&
      _session.isCurrentGeneration(generation) &&
      _session.sessionChanges.value == revision;

  Future<void> _refreshView() async {
    await Future.wait([
      if (widget.mode == 'view' || _hub) _loadCategories(),
      _loadCatalog(),
    ]);
  }

  void _onSearch(String value) {
    setState(() => _cari = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadCatalog);
  }

  List<Wisata> get _filtered =>
      _catalog.items.map(Wisata.fromDestination).toList();

  @override
  void initState() {
    super.initState();
    if (_hub || widget.mode == 'view') _status = 'all';
    _catalog = PagedListController<Destination>(
      session: _session,
      keyOf: (destination) => destination.guid,
      fetchPage: (page, filters) => _repository.adminDestinations(
          query: {...filters, 'page': '$page', 'per_page': '50'}),
    )..addListener(_update);
    _categories = PagedListController<Category>(
      session: _session,
      keyOf: (category) => category.guid,
      fetchPage: (page, _) => _repository.categories(query: {'page': '$page'}),
    )..addListener(_update);
    _guard.addListener(_update);
    _session.sessionChanges.addListener(_sessionChanged);
    _refreshView();
  }

  void _sessionChanged() {
    if (_session.authenticated.value &&
        _session.deviceSessionReady &&
        canAccessAdmin(_session.role)) {
      _refreshView();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _session.sessionChanges.removeListener(_sessionChanged);
    _searchController.dispose();
    _guard
      ..removeListener(_update)
      ..dispose();
    _catalog
      ..removeListener(_update)
      ..dispose();
    _categories
      ..removeListener(_update)
      ..dispose();
    super.dispose();
  }

  // -- Sheet nonaktifkan / aktifkan kembali -----------------
  // The caller re-checks the session after this resolves, so a stale
  // confirmation never reaches the API.
  Future<bool> _konfirmasi(Wisata w) {
    final nonaktifkan = w.isActive;
    return showConfirmSheet(context,
        title: nonaktifkan ? 'Nonaktifkan Destinasi?' : 'Aktifkan Kembali?',
        message: nonaktifkan
            ? '"${w.nama}" akan dinonaktifkan dari katalog.'
            : '"${w.nama}" akan ditampilkan kembali di katalog.',
        icon: nonaktifkan
            ? PhosphorIconsRegular.trash
            : PhosphorIconsRegular.arrowCounterClockwise,
        confirmLabel: nonaktifkan ? 'Nonaktifkan' : 'Aktifkan',
        cancelLabel: 'Batal',
        confirmColor: nonaktifkan ? _C.danger : _C.blue,
        emphasizeConfirm: true);
  }

  Future<void> _toggleActive(Wisata w) async {
    if (_guard.isBusy(w.id)) return;
    final generation = _session.sessionGeneration;
    final revision = _session.sessionChanges.value;
    await _guard.run<void>(w.id, () async {
      if (!_current(generation, revision) || !await _konfirmasi(w)) return;
      if (!_current(generation, revision)) return;
      try {
        if (w.isActive) {
          await _repository.deactivateDestination(w.id);
        } else {
          await _repository.reactivateDestination(w.id);
        }
        if (!mounted || !_current(generation, revision)) return;
        showAdminSnack(context,
            w.isActive ? 'Wisata dinonaktifkan' : 'Wisata diaktifkan kembali');
      } catch (e) {
        if (!mounted || !_current(generation, revision)) return;
        showAdminSnack(context, adminErrorMessage(e), error: true);
      }
      if (_current(generation, revision)) await _loadCatalog();
    });
  }

  Future<void> _preview(Wisata w) async {
    if (!canAccessAdmin(_session.role)) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => OperationsTheme(
                role: _session.role,
                child: DetailWisataScreen(
                    wisata: w,
                    repository: _repository,
                    session: _session,
                    adminPreview: true))));
  }

  Future<void> _editor({Wisata? wisata, bool gallery = false}) async {
    final generation = _session.sessionGeneration;
    final revision = _session.sessionChanges.value;
    if (!_current(generation, revision)) return;
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => TambahWisataScreen(
                wisataEdit: wisata,
                repository: _repository,
                session: _session,
                initialGallery: gallery)));
    if (saved == true && _current(generation, revision)) await _loadCatalog();
  }

  Future<void> _manageDestination(Wisata w) async {
    final generation = _session.sessionGeneration;
    final revision = _session.sessionChanges.value;
    if (!_current(generation, revision)) return;
    final action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) => OperationsTheme(
            role: _session.role,
            child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ValueListenableBuilder<int>(
                      valueListenable: _session.sessionChanges,
                      builder: (context, value, child) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          _current(generation, revision)
                                              ? 'Kelola ${w.nama}'
                                              : 'Kelola Destinasi',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy))),
                                  IconButton(
                                      tooltip: 'Tutup',
                                      onPressed: () =>
                                          Navigator.pop(sheetContext),
                                      icon: const Icon(PhosphorIconsRegular.x))
                                ]),
                                const SizedBox(height: 8),
                                if (!_current(generation, revision))
                                  const Text(
                                      'Akses berubah. Tutup dan muat kembali destinasi.')
                                else ...[
                                  const Text(
                                      'Pilih tindakan untuk destinasi ini',
                                      style: TextStyle(
                                          color: AppColors.navy, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  for (final item in [
                                    (
                                      'preview',
                                      'Preview Pengunjung',
                                      PhosphorIconsRegular.eye
                                    ),
                                    (
                                      'edit',
                                      'Ubah Informasi',
                                      PhosphorIconsRegular.pencilSimple
                                    ),
                                    (
                                      'gallery',
                                      'Kelola Galeri',
                                      PhosphorIconsRegular.images
                                    ),
                                    (
                                      'quota',
                                      'Kelola Kuota',
                                      PhosphorIconsRegular.calendarBlank
                                    ),
                                    (
                                      'status',
                                      w.isActive
                                          ? 'Nonaktifkan'
                                          : 'Aktifkan Kembali',
                                      w.isActive
                                          ? PhosphorIconsRegular.prohibit
                                          : PhosphorIconsRegular
                                              .arrowCounterClockwise
                                    ),
                                  ]) ...[
                                    if (item.$1 == 'status')
                                      const Divider(color: AppColors.border),
                                    ListTile(
                                        key: ValueKey('v3-action-${item.$1}'),
                                        minTileHeight: 56,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(item.$3,
                                            color: item.$1 == 'status' &&
                                                    w.isActive
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : AppColors.blue),
                                        title: Text(item.$2),
                                        onTap: () => Navigator.pop(
                                            sheetContext, item.$1)),
                                  ],
                                ],
                              ])),
                ))));
    if (!mounted || !_current(generation, revision)) return;
    switch (action) {
      case 'preview':
        await _preview(w);
      case 'edit':
        await _editor(wisata: w);
      case 'gallery':
        await _editor(wisata: w, gallery: true);
      case 'quota':
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => KelolaKuotaScreen(
                    destinationGuid: w.id,
                    destinationName: w.nama,
                    timezone: w.timezone,
                    repository: _repository,
                    session: _session)));
        if (_current(generation, revision)) await _loadCatalog();
      case 'status':
        await _toggleActive(w);
    }
  }

  // ── Hub "Kelola": statistik, filter, daftar kartu ─────────────
  Future<void> addDestination() => _editor();

  int? _countFor(String status) {
    if (status == _status && _catalog.hasLoaded && _catalog.total != null) {
      return _catalog.total;
    }
    return _counts[status];
  }

  List<Wisata> get _sorted {
    final items = _filtered;
    switch (_sort) {
      case _DestinationSort.newest:
        return items;
      case _DestinationSort.nameAsc:
        return items
          ..sort(
              (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      case _DestinationSort.priceAsc:
        return items..sort((a, b) => a.ticketPrice.compareTo(b.ticketPrice));
      case _DestinationSort.priceDesc:
        return items..sort((a, b) => b.ticketPrice.compareTo(a.ticketPrice));
    }
  }

  static String _hoursLabel(String raw) {
    final times = RegExp(r'(\d{1,2})[.:](\d{2})')
        .allMatches(raw)
        .map((m) => '${m[1]!.padLeft(2, '0')}:${m[2]}')
        .toList();
    if (times.length >= 2) return '${times[0]}–${times[1]}';
    return raw.trim();
  }

  Future<void> _pickSort() async {
    final picked = await showSelectSheet<_DestinationSort>(context,
        title: 'Urutkan destinasi',
        selected: _sort,
        options: [
          for (final sort in _DestinationSort.values)
            SelectOption(sort, sort.label),
        ]);
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Widget _statCard(String value, String label, {Color? dot}) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Row(children: [
              if (dot != null) ...[
                Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 5),
              ],
              Flexible(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600))),
            ]),
          ]),
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      );

  Widget _statusSegments() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EFF8),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final option in const [
            ('all', 'Semua'),
            ('active', 'Aktif'),
            ('inactive', 'Nonaktif'),
          ])
            Expanded(
              child: Semantics(
                selected: _status == option.$1,
                button: true,
                child: GestureDetector(
                  key: ValueKey('v3-status-${option.$1}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_status == option.$1) return;
                    setState(() => _status = option.$1);
                    _loadCatalog(counts: false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                        color: _status == option.$1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _status == option.$1
                            ? const [
                                BoxShadow(
                                    color: Color(0x14102D59),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ]
                            : null),
                    child: Text.rich(
                      TextSpan(
                          text: option.$2,
                          style: TextStyle(
                              color: _status == option.$1
                                  ? AppColors.navy
                                  : AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800),
                          children: [
                            if (_countFor(option.$1) != null)
                              TextSpan(
                                  text: ' ${_countFor(option.$1)}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600)),
                          ]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _categoryChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          for (final category in <Category?>[null, ..._categories.items])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: _categoryGuid == category?.guid,
                button: true,
                child: GestureDetector(
                  key: ValueKey('v3-category-${category?.guid ?? 'all'}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_categoryGuid == category?.guid) return;
                    setState(() => _categoryGuid = category?.guid);
                    _loadCatalog();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: _categoryGuid == category?.guid
                            ? AppColors.blueTint
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _categoryGuid == category?.guid
                                ? AppColors.blue
                                : AppColors.border)),
                    child: Text(category?.name ?? 'Semua',
                        style: TextStyle(
                            color: _categoryGuid == category?.guid
                                ? AppColors.blue
                                : AppColors.navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _viewToggle(IconData icon, String tooltip, bool grid) {
    final selected = _grid == grid;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: ValueKey('v3-view-${grid ? 'grid' : 'list'}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _grid = grid),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: selected ? AppColors.blueTint : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.blue : AppColors.border)),
          child: Icon(icon,
              size: 18, color: selected ? AppColors.blue : AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _manageHub() {
    final items = _sorted;
    final total = _catalog.total ?? _catalog.items.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _statCard(_countFor('all')?.toString() ?? '–', 'Total destinasi'),
          const SizedBox(width: 10),
          _statCard(_countFor('active')?.toString() ?? '–', 'Aktif',
              dot: AppColors.success),
          const SizedBox(width: 10),
          _statCard(_countFor('inactive')?.toString() ?? '–', 'Nonaktif',
              dot: AppColors.textMuted),
        ]),
      ),
      const SizedBox(height: 16),
      DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: TextField(
            key: const ValueKey('v3-search'),
            controller: _searchController,
            onChanged: _onSearch,
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
            decoration: InputDecoration(
                hintText: 'Cari destinasi atau lokasi...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass,
                    color: AppColors.blue, size: 20),
                suffixIcon: _cari.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                        icon: const Icon(PhosphorIconsRegular.x, size: 18)))),
      ),
      const SizedBox(height: 20),
      _sectionLabel('STATUS DESTINASI'),
      _statusSegments(),
      const SizedBox(height: 20),
      _sectionLabel('KATEGORI WISATA'),
      _categoryChips(),
      if (_categories.error != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _loadCategories,
                child: const Text('Gagal memuat kategori. Coba lagi'))),
      const SizedBox(height: 20),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Destinasi Terdaftar',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  _catalog.hasLoaded
                      ? '$total destinasi ditemukan'
                      : 'Memuat destinasi...',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11.5)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const ValueKey('v3-sort'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickSort,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_sort.label,
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      const Icon(PhosphorIconsRegular.caretDown,
                          size: 14, color: AppColors.textMuted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _viewToggle(
                  PhosphorIconsRegular.listBullets, 'Tampilan daftar', false),
              const SizedBox(width: 8),
              _viewToggle(
                  PhosphorIconsRegular.squaresFour, 'Tampilan grid', true),
            ]),
          ]),
      const SizedBox(height: 14),
      if (_catalog.loading) const LinearProgressIndicator(),
      if (_catalog.error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
                '${adminErrorMessage(_catalog.error!)} Tarik turun untuk mencoba lagi.')),
      if (_catalog.hasLoaded && _catalog.error == null) ...[
        if (_catalog.items.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child:
                  Text('Tidak ada destinasi untuk pencarian atau status ini.')),
        if (_grid)
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 268 * _textScale),
              itemBuilder: (_, i) => _gridCard(items[i]))
        else
          for (final w in items) _listCard(w),
      ],
    ]);
  }

  double get _textScale =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  Widget _thumb(Wisata w) => ApiImage(
      imageUrl: w.images.isEmpty ? w.imageUrl : w.images.first.url('thumbnail'),
      adminGuid: w.id,
      repository: _repository,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_) => const ColoredBox(
          color: AppColors.blueTint,
          child: Center(
              child: Icon(PhosphorIconsRegular.mountains,
                  color: AppColors.blue, size: 36))));

  Widget _statusTag(Wisata w) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: w.isActive ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(w.isActive ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
                color: w.isActive ? AppColors.success : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]);

  Widget _manageButton(Wisata w) => Material(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('v3-manage-${w.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: _guard.isBusy(w.id) ? null : () => _manageDestination(w),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Text('Kelola',
                style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(18));

  Widget _wisataPriceHours(Wisata w) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(visitMoney(w.ticketPrice, 'IDR'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        if (w.jamBuka.trim().isNotEmpty)
          Text(_hoursLabel(w.jamBuka),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
      ]);

  Widget _locationLine(Wisata w) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(PhosphorIconsRegular.mapPin,
                size: 13, color: AppColors.textMuted)),
        const SizedBox(width: 4),
        Expanded(
            child: Text(
                w.lokasi.isEmpty ? 'Lokasi belum dicantumkan' : w.lokasi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11.5, height: 1.3))),
      ]);

  Widget _listCard(Wisata w) {
    final imageWidth =
        (MediaQuery.sizeOf(context).width * .34).clamp(104.0, 150.0);
    return Container(
      key: ValueKey('v3-card-${w.id}'),
      height: 152 * _textScale,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _guard.isBusy(w.id) ? null : () => _preview(w),
          child: Row(children: [
            SizedBox(
                width: imageWidth, height: double.infinity, child: _thumb(w)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(w.kategori,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.blue,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700))),
                        const SizedBox(width: 6),
                        _statusTag(w),
                      ]),
                      const SizedBox(height: 4),
                      Text(w.nama,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _locationLine(w),
                      const Spacer(),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _wisataPriceHours(w)),
                            const SizedBox(width: 8),
                            _manageButton(w),
                          ]),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _gridCard(Wisata w) => Container(
        key: ValueKey('v3-card-${w.id}'),
        decoration: _cardDecoration,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _guard.isBusy(w.id) ? null : () => _preview(w),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 104, child: _thumb(w)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(w.kategori,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.blue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700))),
                              const SizedBox(width: 4),
                              Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: w.isActive
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      shape: BoxShape.circle)),
                            ]),
                            const SizedBox(height: 3),
                            Text(w.nama,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 13.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            _locationLine(w),
                            const Spacer(),
                            _wisataPriceHours(w),
                            const SizedBox(height: 6),
                            SizedBox(
                                width: double.infinity,
                                child: _manageButton(w)),
                          ]),
                    ),
                  ),
                ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_hub) {
      final hub = _manageHub();
      return widget.embedded
          ? hub
          : OperationsTheme(
              role: _session.role,
              child: Scaffold(
                  backgroundColor: AppColors.bg,
                  bottomNavigationBar: DestinationAddBar(onAdd: addDestination),
                  body: RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const OperationsScenicHeader(
                                title: 'Kelola Destinasi',
                                subtitle: 'Destinasi dalam penugasan Anda'),
                            Padding(
                                padding: const EdgeInsets.all(16), child: hub)
                          ]))));
    }
    final total = _catalog.total ?? _catalog.items.length;

    return OperationsTheme(
        role: _session.role,
        child: ScrollAwareStatusBar(
            builder: (context, headerKey) => _viewScaffold(headerKey, total)));
  }

  /// Super admin "Daftar Wisata": same layout as the admin "Kelola" hub.
  Widget _viewScaffold(GlobalKey headerKey, int total) => Scaffold(
        backgroundColor: _C.bg,
        bottomNavigationBar: DestinationAddBar(onAdd: addDestination),
        body: RefreshIndicator(
          onRefresh: _refreshView,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  key: headerKey,
                  child: _session.role == 1
                      ? OperationsScenicHeader(
                          title: 'Daftar Wisata',
                          subtitle: '$total destinasi dalam penugasan',
                          onBack: () => Navigator.maybePop(context))
                      : OperationsDayHeader(
                          label: 'Wisata Daerahku · Operasional',
                          title: 'Daftar Wisata',
                          subtitle: 'Seluruh destinasi terdaftar',
                          onBack: () => Navigator.maybePop(context))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverToBoxAdapter(child: _manageHub())),
            ],
          ),
        ),
      );
}
