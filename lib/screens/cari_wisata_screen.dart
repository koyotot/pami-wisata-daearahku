// ============================================================
// lib/screens/cari_wisata_screen.dart
// REDESIGN v3: biru terang + Plus Jakarta Sans
// - Header: tombol kembali (kiri) + tombol drawer (kanan)
// - Kotak cari menempel di header
// - Filter kategori (chip)
// - Layout majalah: 1 kartu besar + grid 2 kolom
// - Tombol ganti tampilan: Grid <-> Daftar
// Butuh package: flutter pub add google_fonts
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_data.dart';
import '../data/catalog_state.dart';
import 'detail_wisata_screen.dart';

// ── Palet (sama dengan home_screen) ──────────────────────────
const _blue = Color(0xFF1976D2);
const _blueDeep = Color(0xFF1558B0);
const _navy = Color(0xFF102D59);
const _orange = Color(0xFFFF9800);
const _background = Color(0xFFF5F8FD);
const _textMuted = Color(0xFF728099);
const _border = Color(0xFFDCE4F0);

TextStyle _font(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

const _kColor = {
  'Pantai': Color(0xFF0EA5E9),
  'Budaya': Color(0xFF8B5CF6),
  'Alam': Color(0xFF16A34A),
  'Bahari': Color(0xFF0891B2),
  'Kuliner': Color(0xFFF59E0B),
  'Kota': Color(0xFFEA580C),
  'Lainnya': Color(0xFF64748B),
};

const _kIcon = {
  'Pantai': Icons.beach_access_rounded,
  'Budaya': Icons.account_balance_rounded,
  'Alam': Icons.forest_rounded,
  'Bahari': Icons.sailing_rounded,
  'Kuliner': Icons.restaurant_rounded,
  'Kota': Icons.location_city_rounded,
  'Lainnya': Icons.explore_rounded,
};

void _bukaDetail(BuildContext context, Wisata w) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailWisataScreen(wisata: w)),
  );
}

class CariWisataScreen extends StatefulWidget {
  /// true bila halaman ini dipakai sebagai tab di MainNavigationScreen.
  final bool embedded;

  /// Dipanggil saat tombol menu (☰) ditekan — membuka drawer
  /// yang ada di MainNavigationScreen.
  final VoidCallback? onBukaMenu;

  /// Dipanggil saat tombol kembali ditekan. Saat embedded, isi dengan
  /// perpindahan ke tab Beranda. Jika null dan tidak embedded,
  /// dipakai Navigator.pop.
  final VoidCallback? onKembali;

  const CariWisataScreen({
    super.key,
    this.embedded = false,
    this.onBukaMenu,
    this.onKembali,
  });

  @override
  State<CariWisataScreen> createState() => _CariWisataScreenState();
}

class _CariWisataScreenState extends State<CariWisataScreen> {
  static const _semua = 'Semua';

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String _kategori = _semua;
  bool _modeGrid = true; // true = grid majalah, false = daftar

  final _catalog = CatalogState();
  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Future.wait([_catalog.loadCategories(), _loadCatalog()]);
  }

  Future<void> _loadCatalog() => _catalog.loadDestinations(
      category: _kategori == _semua ? null : _kategori, search: _query);

  @override
  void initState() {
    super.initState();
    _catalog.categories.addListener(_changed);
    _catalog.destinations.addListener(_changed);
    _refresh();
  }

  @override
  void dispose() {
    _catalog.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Wisata> get _hasil =>
      (_catalog.destinations.data ?? []).map(Wisata.fromDestination).toList();

  void _reset() {
    setState(() {
      _query = '';
      _kategori = _semua;
      _ctrl.clear();
    });
    _loadCatalog();
  }

  String _animKey(Wisata w) => '${w.nama}-$_kategori-$_query-$_modeGrid';

  @override
  Widget build(BuildContext context) {
    final hasil = _hasil;
    final sedangMencari = _query.trim().isNotEmpty || _kategori != _semua;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(),
                SliverToBoxAdapter(child: _buildCategoryChips()),
                SliverToBoxAdapter(
                    child: _buildSectionTitle(hasil.length, sedangMencari)),
                if (_catalog.categories.loading ||
                    _catalog.destinations.loading)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()))
                else if (_catalog.categories.error != null ||
                    _catalog.destinations.error != null)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Gagal memuat data wisata.'),
                        TextButton(
                            onPressed: _refresh,
                            child: const Text('Coba lagi')),
                      ])))
                else if (hasil.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false, child: _notFoundState())
                else if (_modeGrid) ...[
                  // Kartu besar (hasil pertama)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: _FadeSlide(
                        key: ValueKey(_animKey(hasil.first)),
                        index: 0,
                        child: _HeroCard(wisata: hasil.first),
                      ),
                    ),
                  ),
                  // Sisanya: grid 2 kolom
                  if (hasil.length > 1)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 228,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final w = hasil[i + 1];
                            return _FadeSlide(
                              key: ValueKey(_animKey(w)),
                              index: i + 1,
                              child: _GridCard(wisata: w),
                            );
                          },
                          childCount: hasil.length - 1,
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ] else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _FadeSlide(
                          key: ValueKey(_animKey(hasil[i])),
                          index: i,
                          child: _ListCard(wisata: hasil[i]),
                        ),
                        childCount: hasil.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header gradien + kotak cari yang menempel ──────────────
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _blue,
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      centerTitle: true,
      // Pill jumlah destinasi, di antara tombol kembali & menu
      title: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              '${_hasil.length} destinasi tersedia',
              style: _font(11.5, FontWeight.w700, Colors.white),
            ),
          ],
        ),
      ),
      // Tombol kembali
      leading: (widget.embedded && widget.onKembali == null)
          ? null
          : _headerButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 17,
              margin: const EdgeInsets.fromLTRB(20, 8, 0, 8),
              onTap: () {
                FocusScope.of(context).unfocus();
                if (widget.onKembali != null) {
                  widget.onKembali!();
                } else {
                  Navigator.maybePop(context);
                }
              },
            ),
      // Tombol pembuka drawer
      actions: [
        if (widget.onBukaMenu != null)
          _headerButton(
            icon: Icons.menu_rounded,
            iconSize: 22,
            margin: const EdgeInsets.fromLTRB(0, 8, 20, 8),
            onTap: () {
              FocusScope.of(context).unfocus();
              widget.onBukaMenu!();
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A93F0), _blue, _blueDeep],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 22,
                right: 22,
                bottom: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cari Wisata',
                      style: _font(
                        32,
                        FontWeight.w800,
                        Colors.white,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ke mana kamu mau pergi hari ini?',
                      style: _font(
                        13,
                        FontWeight.w500,
                        Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: _font(14, FontWeight.w600, _navy),
              cursorColor: _blue,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama wisata...',
                hintStyle: _font(13, FontWeight.w500, _textMuted),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _blue, size: 22),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _textMuted, size: 18),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _ctrl.clear();
                          });
                          _loadCatalog();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (v) {
                setState(() => _query = v);
                _loadCatalog();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Tombol bulat di header (kembali / menu) ────────────────
  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
    required EdgeInsets margin,
    double iconSize = 20,
  }) {
    return Padding(
      padding: margin,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.white.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            child: Center(
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  // ── Chip kategori ──────────────────────────────────────────
  Widget _buildCategoryChips() {
    final kategori = _catalog.categories.data ?? [];
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: kategori.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final k = i == 0 ? _semua : kategori[i - 1].name;
          final guid = i == 0 ? _semua : kategori[i - 1].guid;
          final aktif = guid == _kategori;
          final warna = _kColor[k] ?? _blue;
          final ikon = _kIcon[k] ?? Icons.apps_rounded;

          return GestureDetector(
            onTap: () {
              setState(() => _kategori = guid);
              _loadCatalog();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: aktif
                    ? const LinearGradient(
                        colors: [Color(0xFF2386E8), _blueDeep])
                    : null,
                color: aktif ? null : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: aktif ? null : Border.all(color: _border, width: 1.2),
                boxShadow: aktif
                    ? [
                        BoxShadow(
                          color: _blue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(ikon, size: 17, color: aktif ? Colors.white : warna),
                  const SizedBox(width: 6),
                  Text(
                    k,
                    style: _font(
                      12.5,
                      FontWeight.w700,
                      aktif ? Colors.white : _navy,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Judul bagian + tombol ganti tampilan ───────────────────
  Widget _buildSectionTitle(int jumlah, bool sedangMencari) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 14),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            sedangMencari ? '$jumlah wisata ditemukan' : 'Jelajahi Destinasi',
            style: _font(15, FontWeight.w800, _navy, letterSpacing: -0.2),
          ),
        ),
        if (sedangMencari)
          GestureDetector(
            onTap: _reset,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('Reset', style: _font(12.5, FontWeight.w700, _blue)),
            ),
          ),
        _buildToggleTampilan(),
      ]),
    );
  }

  Widget _buildToggleTampilan() {
    Widget tombol(IconData ikon, bool grid) {
      final aktif = _modeGrid == grid;
      return GestureDetector(
        onTap: () => setState(() => _modeGrid = grid),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            color: aktif ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikon, size: 18, color: aktif ? Colors.white : _textMuted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tombol(Icons.dashboard_rounded, true),
          tombol(Icons.view_agenda_rounded, false),
        ],
      ),
    );
  }

  Widget _notFoundState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _border, width: 1.4),
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 42, color: _textMuted),
          ),
          const SizedBox(height: 20),
          Text('Wisata tidak ditemukan',
              style: _font(17, FontWeight.w800, _navy, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text('Coba kata kunci atau kategori lain',
              style: _font(13, FontWeight.w500, _textMuted)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2386E8), _blueDeep]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Tampilkan semua',
                  style: _font(13, FontWeight.w700, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animasi masuk kartu (fade + geser, berurutan) ─────────────
class _FadeSlide extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlide({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 6)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ── Gambar wisata (http / asset / file / placeholder) ─────────
class _Thumb extends StatelessWidget {
  final Wisata wisata;
  const _Thumb({required this.wisata});

  @override
  Widget build(BuildContext context) {
    final katColor = _kColor[wisata.kategori] ?? _blue;
    final katIcon = _kIcon[wisata.kategori] ?? Icons.explore_rounded;
    final path = wisata.imagePath;

    Widget placeholder() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                katColor.withValues(alpha: 0.25),
                katColor.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Center(
            child: Icon(katIcon,
                color: katColor.withValues(alpha: 0.55), size: 48),
          ),
        );

    Widget broken() => Container(
          color: katColor.withValues(alpha: 0.10),
          child: const Center(
            child:
                Icon(Icons.broken_image_rounded, color: _textMuted, size: 30),
          ),
        );

    if (path == null || path.isEmpty) return placeholder();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(),
        errorBuilder: (_, __, ___) => broken(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => broken(),
    );
  }
}

// ── Badge kategori ────────────────────────────────────────────
class _KategoriBadge extends StatelessWidget {
  final String kategori;
  final bool kecil;
  const _KategoriBadge({required this.kategori, this.kecil = false});

  @override
  Widget build(BuildContext context) {
    final warna = _kColor[kategori] ?? _blue;
    final ikon = _kIcon[kategori] ?? Icons.explore_rounded;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: kecil ? 8 : 10, vertical: kecil ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: kecil ? 11 : 13, color: warna),
          const SizedBox(width: 4),
          Text(kategori, style: _font(kecil ? 10 : 11, FontWeight.w700, warna)),
        ],
      ),
    );
  }
}

// ── Kartu besar (hasil pertama) ───────────────────────────────
class _HeroCard extends StatelessWidget {
  final Wisata wisata;
  const _HeroCard({required this.wisata});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: 230,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumb(wisata: wisata),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6102D59)],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: _KategoriBadge(kategori: wisata.kategori),
              ),
              Positioned(
                left: 18,
                right: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wisata.nama,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _font(22, FontWeight.w800, Colors.white,
                                height: 1.15, letterSpacing: -0.6),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.location_on_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.9)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                wisata.lokasi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _font(
                                  12.5,
                                  FontWeight.w500,
                                  Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer_rounded,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  wisata.hargaTiket,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _font(
                                      11.5, FontWeight.w800, Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 22, color: _blue),
                    ),
                  ],
                ),
              ),
              // Lapisan ripple + tap
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _bukaDetail(context, wisata),
                    splashColor: Colors.white.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Kartu grid (2 kolom) ──────────────────────────────────────
class _GridCard extends StatelessWidget {
  final Wisata wisata;
  const _GridCard({required this.wisata});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaDetail(context, wisata),
          splashColor: _blue.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: _border, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Thumb(wisata: wisata),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _KategoriBadge(
                            kategori: wisata.kategori, kecil: true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wisata.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _font(14, FontWeight.w800, _navy,
                              letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: _blue),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              wisata.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(11.5, FontWeight.w500, _textMuted),
                            ),
                          ),
                        ]),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                wisata.hargaTiket,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _font(12, FontWeight.w800, _orange),
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2386E8), _blueDeep],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Kartu daftar (tampilan list) ──────────────────────────────
class _ListCard extends StatelessWidget {
  final Wisata wisata;
  const _ListCard({required this.wisata});

  @override
  Widget build(BuildContext context) {
    final katColor = _kColor[wisata.kategori] ?? _blue;
    final katIcon = _kIcon[wisata.kategori] ?? Icons.explore_rounded;
    final radius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaDetail(context, wisata),
          splashColor: _blue.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: _border, width: 1.2),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 108,
                  child: _Thumb(wisata: wisata),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: katColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(katIcon, size: 11, color: katColor),
                              const SizedBox(width: 4),
                              Text(wisata.kategori,
                                  style: _font(10, FontWeight.w700, katColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          wisata.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _font(14.5, FontWeight.w800, _navy,
                              letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: _blue),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              wisata.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(11.5, FontWeight.w500, _textMuted),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                size: 12, color: _orange),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                wisata.hargaTiket,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _font(11.5, FontWeight.w700, _orange),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2386E8), _blueDeep],
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
