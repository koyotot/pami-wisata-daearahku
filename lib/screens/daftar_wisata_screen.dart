// ============================================================
// lib/screens/daftar_wisata_screen.dart
// REDESIGN: Biru terang - selaras dengan TambahWisataScreen & Dashboard
// Daftar destinasi dari Laravel (endpoint admin, termasuk nonaktif).
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/admin_state.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import '../widgets/api_image.dart';
import 'admin_common.dart';
import 'detail_wisata_screen.dart';
import 'kelola_kuota_screen.dart';
import 'tambah_wisata_screen.dart';

// -- Palet (selaras dengan TambahWisataScreen & Dashboard) ---
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const surface = Colors.white;
  static const tint = Color(0xFFE6F0FC);
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);

  // Alias supaya kode lama tetap jalan
  static const teal = blue;
  static const gold = orange;
}

// -- Warna per-kategori ---------------------------------------
const _kColor = {
  'Semua': _C.teal,
  'Pantai': Color(0xFF38BDF8),
  'Budaya': Color(0xFFA78BFA),
  'Alam': Color(0xFF4ADE80),
  'Bahari': Color(0xFF60D8E8),
  'Kuliner': Color(0xFFFBBF24),
  'Kota': Color(0xFFFB923C),
  'Lainnya': Color(0xFF94A3B8),
};

const _kIcon = {
  'Semua': Icons.explore_rounded,
  'Pantai': Icons.beach_access_rounded,
  'Budaya': Icons.account_balance_rounded,
  'Alam': Icons.forest_rounded,
  'Bahari': Icons.sailing_rounded,
  'Kuliner': Icons.restaurant_rounded,
  'Kota': Icons.location_city_rounded,
  'Lainnya': Icons.explore_rounded,
};

class DaftarWisataScreen extends StatefulWidget {
  final String mode; // 'view' | 'edit' | 'hapus' | 'kuota'
  final BusinessRepository? repository;
  final AuthSession? session;
  const DaftarWisataScreen(
      {super.key, this.mode = 'view', this.repository, this.session});

  @override
  State<DaftarWisataScreen> createState() => _DaftarWisataScreenState();
}

class _DaftarWisataScreenState extends State<DaftarWisataScreen>
    with SingleTickerProviderStateMixin {
  String _cari = '';
  String _status = 'active';
  String? _categoryGuid;

  late final AnimationController _fabCtrl;
  late final BusinessRepository _repository =
      widget.repository ?? BusinessRepository();
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

  Future<void> _loadCatalog() => _catalog.load(filters: _filters);

  Future<void> _refreshView() async {
    await Future.wait([
      if (widget.mode == 'view') _loadCategories(),
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

  String get _judul => switch (widget.mode) {
        'edit' => 'Ubah Data Wisata',
        'hapus' => 'Hapus Data Wisata',
        'kuota' => 'Kelola Kuota',
        _ => 'Daftar Wisata',
      };

  Color get _accentColor => switch (widget.mode) {
        'edit' => const Color(0xFFA78BFA),
        'hapus' => _C.danger,
        'kuota' => const Color(0xFF26A69A),
        _ => _C.teal,
      };

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _catalog = PagedListController<Destination>(
      session: _session,
      keyOf: (destination) => destination.guid,
      fetchPage: (page, filters) => _repository.adminDestinations(
          query: {...filters, 'page': '$page', 'per_page': '50'}),
    )..addListener(_update);
    _categories = PagedListController<Category>(
      session: _session,
      keyOf: (category) => category.guid,
      fetchPage: (page, _) =>
          _repository.categories(query: {'page': '$page'}),
    )..addListener(_update);
    _guard.addListener(_update);
    _session.sessionChanges.addListener(_sessionChanged);
    _refreshView();
  }

  void _sessionChanged() {
    if (_session.authenticated.value && _session.deviceSessionReady) {
      _refreshView();
    }
  }

  Future<void> _muatData() => _refreshView();

  @override
  void dispose() {
    _debounce?.cancel();
    _session.sessionChanges.removeListener(_sessionChanged);
    _fabCtrl.dispose();
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

  // -- Dialog nonaktifkan / aktifkan kembali ----------------
  Future<bool> _konfirmasi(Wisata w) async {
    final nonaktifkan = w.isActive;
    final warna = nonaktifkan ? _C.danger : _C.teal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: warna.withValues(alpha: 0.3)),
                ),
                child: Icon(
                    nonaktifkan ? Icons.delete_rounded : Icons.restore_rounded,
                    color: warna,
                    size: 36),
              ),
              const SizedBox(height: 20),
              Text(nonaktifkan ? 'Hapus Wisata?' : 'Aktifkan Kembali?',
                  style: const TextStyle(
                    color: _C.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
              const SizedBox(height: 10),
              Text(
                nonaktifkan
                    ? '"${w.nama}" akan dinonaktifkan dari katalog.'
                    : '"${w.nama}" akan ditampilkan kembali di katalog.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.textMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: _C.border),
                      foregroundColor: _C.textMuted,
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: warna,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(nonaktifkan ? 'Hapus' : 'Aktifkan',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _toggleActive(Wisata w) async {
    if (_guard.isBusy(w.id)) return;
    final nonaktifkan = w.isActive;
    final yakin = await _konfirmasi(w);
    if (!yakin || !mounted) return;
    final generation = _session.sessionGeneration;
    await _guard.run<void>(w.id, () async {
      try {
        if (nonaktifkan) {
          await _repository.deactivateDestination(w.id);
        } else {
          await _repository.reactivateDestination(w.id);
        }
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(
            context,
            nonaktifkan
                ? 'Wisata dinonaktifkan'
                : 'Wisata diaktifkan kembali');
      } catch (e) {
        if (!mounted || !_session.isCurrentGeneration(generation)) return;
        showAdminSnack(context, adminErrorMessage(e), error: true);
      }
      if (mounted && _session.isCurrentGeneration(generation)) {
        await _loadCatalog();
      }
    });
  }

  void _bukaKuota(Wisata w) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KelolaKuotaScreen(
          destinationGuid: w.id,
          destinationName: w.nama,
          timezone: w.timezone,
          repository: widget.repository,
          session: widget.session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final filtered = _filtered;

    final total = _catalog.total ?? filtered.length;

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        onRefresh: _refreshView,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SliverAppBar ────────────────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              floating: false,
              pinned: true,
              snap: false,
              backgroundColor: const Color(0xFF1558B0),
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              actions: widget.mode == 'view'
                  ? [
                      Container(
                        margin:
                            const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.landscape_rounded,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text('$total',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ]
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A93F0),
                        Color(0xFF1976D2),
                        Color(0xFF1558B0)
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Teks header
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 46,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    widget.mode == 'edit'
                                        ? 'UBAH DESTINASI'
                                        : widget.mode == 'hapus'
                                            ? 'HAPUS DESTINASI'
                                            : 'DESTINASI NUSANTARA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _judul,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.mode == 'edit'
                                  ? 'Pilih wisata yang ingin diubah'
                                  : widget.mode == 'hapus'
                                      ? 'Nonaktifkan atau aktifkan kembali wisata'
                                      : widget.mode == 'kuota'
                                          ? 'Pilih wisata untuk mengatur kuota'
                                          : '$total destinasi ditemukan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tepi bawah melengkung menyatu dengan konten
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: _C.bg,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(26)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Search bar ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.border),
                    boxShadow: [
                      BoxShadow(
                        color: _C.blue.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: _C.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: widget.mode == 'view'
                          ? 'Cari nama wisata...'
                          : 'Cari nama, lokasi, atau kategori...',
                      hintStyle:
                          const TextStyle(color: _C.textDim, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _C.teal, size: 20),
                      suffixIcon: _cari.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: _C.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onSearch,
                  ),
                ),
              ),
            ),

            // ── Filter status: aktif / nonaktif / semua ──────────
            SliverToBoxAdapter(
              child: AdminFilterChips<String>(
                options: const [
                  ('Aktif', 'active'),
                  ('Nonaktif', 'inactive'),
                  ('Semua', 'all'),
                ],
                selected: _status,
                onSelected: (value) {
                  if (value == _status) return;
                  setState(() => _status = value);
                  _loadCatalog();
                },
              ),
            ),

            // ── Filter kategori (mode view) ─────────────────────
            if (widget.mode == 'view')
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    itemCount: 1 + _categories.items.length,
                    itemBuilder: (_, i) {
                      final category = i == 0 ? null : _categories.items[i - 1];
                      final k = category?.name ?? 'Semua';
                      final sel = _categoryGuid == category?.guid;
                      final col = _kColor[k] ?? _C.teal;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _categoryGuid = category?.guid);
                          _loadCatalog();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? col : _C.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? col : _C.border,
                              width: 1,
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: col.withValues(alpha: 0.40),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3))
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_kIcon[k] ?? Icons.place_rounded,
                                  size: 13,
                                  color: sel ? Colors.white : _C.textDim),
                              const SizedBox(width: 5),
                              Text(k,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : _C.textMuted,
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── Counter ─────────────────────────────────────────
            if (widget.mode == 'view' && _categories.loading)
              const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
            if (widget.mode == 'view' && _categories.error != null)
              SliverToBoxAdapter(
                  child: TextButton(
                onPressed: _loadCategories,
                child: const Text('Gagal memuat kategori. Coba lagi'),
              )),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filtered.length} wisata ditemukan',
                      style: const TextStyle(
                        color: _C.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Kosong ──────────────────────────────────────────
            if (!_catalog.hasLoaded && _catalog.error == null)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_catalog.error != null && filtered.isEmpty)
              SliverFillRemaining(
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                    Text(adminErrorMessage(_catalog.error!),
                        textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadCatalog,
                      child: const Text('Gagal memuat wisata. Coba lagi'),
                    ),
                  ])))
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _C.teal.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _C.teal.withValues(alpha: 0.15),
                              width: 1.5),
                        ),
                        child: Icon(Icons.search_off_rounded,
                            size: 44, color: _C.teal.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 20),
                      const Text('Tidak ada wisata ditemukan',
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 6),
                      const Text('Coba kata kunci atau filter lain.',
                          style: TextStyle(color: _C.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _WisataCard(
                      key: ValueKey(filtered[i].id),
                      wisata: filtered[i],
                      mode: widget.mode,
                      accent: accent,
                      busy: _guard.isBusy(filtered[i].id),
                      onKuota: () => _bukaKuota(filtered[i]),
                      onTap: () => widget.mode == 'kuota'
                          ? _bukaKuota(filtered[i])
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetailWisataScreen(wisata: filtered[i]),
                              ),
                            ),
                      onEdit: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TambahWisataScreen(wisataEdit: filtered[i]),
                          ),
                        );
                        if (ok == true) await _muatData();
                      },
                      onHapus: () => _toggleActive(filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────
      floatingActionButton: widget.mode == 'view'
          ? ScaleTransition(
              scale:
                  CurvedAnimation(parent: _fabCtrl, curve: Curves.elasticOut),
              child: FloatingActionButton.extended(
                backgroundColor: _C.blue,
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
                label: const Text('Tambah Wisata',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TambahWisataScreen()),
                  );
                  if (ok == true) await _muatData();
                },
              ),
            )
          : null,
    );
  }
}

// ── Card ─────────────────────────────────────────────────────

class _WisataCard extends StatelessWidget {
  final Wisata wisata;
  final String mode;
  final Color accent;
  final bool busy;
  final VoidCallback onTap, onEdit, onHapus, onKuota;

  const _WisataCard({
    super.key,
    required this.wisata,
    required this.mode,
    required this.accent,
    required this.busy,
    required this.onTap,
    required this.onEdit,
    required this.onHapus,
    required this.onKuota,
  });

  Color get _badgeColor => (_kColor[wisata.kategori] ?? _C.teal);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: mode == 'view' || mode == 'kuota' ? onTap : null,
            splashColor: _C.teal.withValues(alpha: 0.08),
            highlightColor: _C.teal.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero image ─────────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: _buildImage(),
                    ),
                    // gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xFF0B2347).withValues(alpha: 0.78),
                            ],
                            stops: const [0.35, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // badge kategori
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _badgeColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _badgeColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _kIcon[wisata.kategori] ?? Icons.place_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(wisata.kategori,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3)),
                          ],
                        ),
                      ),
                    ),
                    if (!wisata.isActive)
                      Positioned(
                        top: 44,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _C.danger.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Nonaktif',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    // badge harga
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                color: _C.gold, size: 11),
                            const SizedBox(width: 4),
                            Text(
                                wisata.isLaravel
                                    ? formatMoney(wisata.ticketPrice, 'IDR')
                                    : wisata.hargaTiket,
                                style: const TextStyle(
                                    color: _C.navy,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    // nama wisata overlay
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: mode == 'edit' ? 108 : (mode != 'view' ? 62 : 14),
                      child: Text(
                        wisata.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 1)),
                          ],
                        ),
                      ),
                    ),
                    // tombol edit / hapus
                    if (mode == 'edit')
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Row(
                          children: [
                            _overlayBtn(
                              icon: Icons.event_available_rounded,
                              color: const Color(0xFF26A69A),
                              onTap: onKuota,
                            ),
                            const SizedBox(width: 8),
                            _overlayBtn(
                              icon: Icons.edit_rounded,
                              color: const Color(0xFFA78BFA),
                              onTap: onEdit,
                            ),
                          ],
                        ),
                      )
                    else if (mode == 'hapus')
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: busy
                            ? const SizedBox(
                                width: 38,
                                height: 38,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                ),
                              )
                            : _overlayBtn(
                                icon: wisata.isActive
                                    ? Icons.delete_rounded
                                    : Icons.restore_rounded,
                                color: wisata.isActive ? _C.danger : _C.teal,
                                onTap: onHapus,
                              ),
                      )
                    else if (mode == 'kuota')
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: _overlayBtn(
                          icon: Icons.event_available_rounded,
                          color: const Color(0xFF26A69A),
                          onTap: onKuota,
                        ),
                      ),
                  ],
                ),

                // ── Info bawah ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  child: Row(
                    children: [
                      // Lokasi
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _C.tint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded,
                                  color: _C.teal, size: 13),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                wisata.lokasi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _C.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Jam buka
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: _C.textDim),
                          const SizedBox(width: 4),
                          Text(wisata.jamBuka,
                              style: const TextStyle(
                                  color: _C.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      if (mode == 'view' || mode == 'kuota') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A93F0), Color(0xFF1558B0)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _C.blue.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // Gambar dimuat lewat ApiClient; endpoint admin dipakai agar destinasi
  // nonaktif tetap tampil.
  Widget _buildImage() {
    final col = _kColor[wisata.kategori] ?? _C.teal;
    Widget placeholder(BuildContext context) => Container(
          color: col.withValues(alpha: 0.08),
          child: Center(
            child: Icon(_kIcon[wisata.kategori] ?? Icons.landscape_rounded,
                color: col.withValues(alpha: 0.3), size: 52),
          ),
        );
    return ApiImage(
      imageUrl: wisata.imageUrl,
      adminGuid: wisata.id,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 190,
      placeholder: placeholder,
    );
  }
}
