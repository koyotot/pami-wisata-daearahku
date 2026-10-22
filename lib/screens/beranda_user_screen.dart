// ============================================================
// lib/screens/beranda_user_screen.dart
// Package: google_fonts
// Tema: biru terang — sama dengan home, login, dan register
// ============================================================
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_data.dart';
import 'detail_wisata_screen.dart';

// ── Palet & font (sama dengan home_screen.dart) ──────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const background = Color(0xFFF5F8FD);
  static const textMuted = Color(0xFF728099);
  static const border = Color(0xFFDCE4F0);
}

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

class BerandaUserScreen extends StatefulWidget {
  /// Dipanggil saat tombol menu (☰) ditekan — membuka drawer
  /// yang ada di MainNavigationScreen.
  final VoidCallback? onBukaMenu;

  const BerandaUserScreen({super.key, this.onBukaMenu});

  @override
  State<BerandaUserScreen> createState() => _BerandaUserScreenState();
}

class _BerandaUserScreenState extends State<BerandaUserScreen>
    with TickerProviderStateMixin {
  String _kategoriTerpilih = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  bool _isLoadingData = true;

  final List<Map<String, dynamic>> _kategoriList = [
    {'label': 'Semua', 'icon': '🗺️'},
    {'label': 'Alam', 'icon': '🏔️'},
    {'label': 'Budaya', 'icon': '🏛️'},
    {'label': 'Pantai', 'icon': '🏖️'},
    {'label': 'Bahari', 'icon': '🐚'},
    {'label': 'Kuliner', 'icon': '🍜'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _muatData();
  }

  // ── Logika data (tidak diubah) ─────────────────────────────
  Future<void> _muatData() async {
    await loadWisataFromFirestore();
    await loadPendaftarFromFirestore(userId: currentUser?.id);
    if (!mounted) return;
    setState(() => _isLoadingData = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<Wisata> get _filtered => daftarWisata.where((w) {
        final cocokKat = _kategoriTerpilih == 'Semua' ||
            w.kategori.toLowerCase() == _kategoriTerpilih.toLowerCase();
        final q = _searchCtrl.text.toLowerCase();
        final cocokQ = w.nama.toLowerCase().contains(q) ||
            w.lokasi.toLowerCase().contains(q);
        return cocokKat && cocokQ;
      }).toList();

  // ── Tampilan ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCEBFF), _C.background, Colors.white],
              stops: [0.0, 0.3, 0.7],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _fadeCtrl,
                curve: Curves.easeOut,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),
                        _buildHero(),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildKategori(),
                        _buildSectionTitle(),
                        _buildWisataSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bar atas: logo + nama aplikasi ─────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF42A5F5), _C.blue],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _C.blue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Wisata Daerahku',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _font(18, FontWeight.w800, _C.navy, letterSpacing: -0.4),
            ),
          ),
          // Tombol pembuka drawer
          if (widget.onBukaMenu != null)
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _C.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onBukaMenu,
                  child: const Center(
                    child: Icon(Icons.menu_rounded, color: _C.navy, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hero: sapaan + statistik ───────────────────────────────
  Widget _buildHero() {
    final nama = currentUser?.namaLengkap.trim() ?? '';
    final namaDepan = nama.isEmpty ? 'Pengunjung' : nama.split(' ').first;
    final inisial = nama.isEmpty ? '' : nama[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), _C.blue, _C.blueDeep],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekorasi lingkaran lembut
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Matahari kecil (sama dengan motif beranda awal)
          Positioned(
            top: 20,
            right: 22,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE9B0), _C.orange],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC46B).withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: inisial.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 26)
                          : Text(
                              inisial,
                              style: _font(22, FontWeight.w800, Colors.white),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, $namaDepan 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(
                                20,
                                FontWeight.w800,
                                Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Mau jelajah mana hari ini?',
                              style: _font(
                                13,
                                FontWeight.w500,
                                Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statPill(Icons.place_rounded, '${daftarWisata.length}',
                        'Destinasi'),
                    const SizedBox(width: 10),
                    _statPill(Icons.category_rounded,
                        '${_kategoriList.length - 1}', 'Kategori'),
                    const SizedBox(width: 10),
                    _statPill(Icons.people_rounded, '${daftarPendaftar.length}',
                        'Terdaftar'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: _font(16, FontWeight.w800, Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _font(
                10.5,
                FontWeight.w600,
                Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kolom pencarian ────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _C.navy.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: _font(14.5, FontWeight.w500, _C.navy),
          cursorColor: _C.blue,
          decoration: InputDecoration(
            hintText: 'Cari nama atau lokasi wisata...',
            hintStyle: _font(
              14,
              FontWeight.w400,
              _C.textMuted.withValues(alpha: 0.75),
            ),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _C.blue, size: 22),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _C.textMuted, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ── Filter kategori (chip bisa digeser) ────────────────────
  Widget _buildKategori() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: _kategoriList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = _kategoriList[i];
          final label = item['label'] as String;
          final icon = item['icon'] as String;
          final selected = label == _kategoriTerpilih;

          return GestureDetector(
            onTap: () => setState(() => _kategoriTerpilih = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF2386E8), _C.blueDeep],
                      )
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Colors.transparent : _C.border,
                  width: 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _C.blue.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: _font(
                      13,
                      selected ? FontWeight.w700 : FontWeight.w600,
                      selected ? Colors.white : _C.navy,
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

  // ── Judul bagian ───────────────────────────────────────────
  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _C.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Destinasi Populer',
                style: _font(
                  17,
                  FontWeight.w800,
                  _C.navy,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _C.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.orange.withValues(alpha: 0.35)),
            ),
            child: Text(
              '${_filtered.length} tempat',
              style: _font(11.5, FontWeight.w800, const Color(0xFFE08600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Daftar wisata ──────────────────────────────────────────
  Widget _buildWisataSection() {
    if (_isLoadingData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: CircularProgressIndicator(color: _C.blue, strokeWidth: 3),
        ),
      );
    }

    final hasil = _filtered;

    if (hasil.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.blue.withValues(alpha: 0.08),
                ),
                child: const Icon(Icons.search_off_rounded,
                    color: _C.blue, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada destinasi ditemukan',
                style: _font(14.5, FontWeight.w800, _C.navy),
              ),
              const SizedBox(height: 6),
              Text(
                'Coba kata kunci lain atau ganti kategori',
                textAlign: TextAlign.center,
                style: _font(12.5, FontWeight.w500, _C.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // Grid 2 kolom — semua kartu langsung terlihat.
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.68,
        ),
        itemCount: hasil.length,
        itemBuilder: (_, i) => _WisataCard(
          wisata: hasil[i],
          index: i,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailWisataScreen(wisata: hasil[i]),
              ),
            );
            if (!mounted) return;
            setState(() {});
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  KARTU WISATA
// ══════════════════════════════════════════════════════════
class _WisataCard extends StatefulWidget {
  final Wisata wisata;
  final int index;
  final VoidCallback onTap;

  const _WisataCard({
    required this.wisata,
    required this.index,
    required this.onTap,
  });

  @override
  State<_WisataCard> createState() => _WisataCardState();
}

class _WisataCardState extends State<_WisataCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.wisata;

    // Muncul bergantian (stagger) saat kartu pertama kali tampil.
    final delay = (widget.index.clamp(0, 6)) * 70;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: _C.navy.withValues(alpha: 0.09),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Gambar ──
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                        child: _wisataImage(w),
                      ),
                      // Gradasi gelap tipis di bawah gambar
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _C.navy.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5],
                            ),
                          ),
                        ),
                      ),
                      // Badge kategori
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2386E8), _C.blueDeep],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            w.kategori,
                            style: _font(10, FontWeight.w800, Colors.white),
                          ),
                        ),
                      ),
                      // Badge rating
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: _C.orange, size: 13),
                              const SizedBox(width: 3),
                              Text(
                                w.rating.toStringAsFixed(1),
                                style: _font(10.5, FontWeight.w800, _C.navy),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info ──
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _font(
                            14,
                            FontWeight.w800,
                            _C.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: _C.blue),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                w.lokasi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    _font(11.5, FontWeight.w500, _C.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Tiket',
                                    style: _font(
                                      9.5,
                                      FontWeight.w600,
                                      _C.textMuted.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  Text(
                                    w.hargaTiket,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _font(
                                      12.5,
                                      FontWeight.w800,
                                      const Color(0xFFE08600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2386E8), _C.blueDeep],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.blue.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
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

  // ── Gambar wisata (logika sama seperti sebelumnya) ─────────
  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE6F0FC),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 46,
          color: _C.blue.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _wisataImage(Wisata w) {
    final path = w.imagePath;

    if (path == null || path.isEmpty) return _placeholder();

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFE6F0FC),
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: _C.blue,
                strokeWidth: 2.2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}
