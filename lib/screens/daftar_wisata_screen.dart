// ============================================================
// lib/screens/daftar_wisata_screen.dart
// REDESIGN: Biru terang — selaras dengan TambahWisataScreen & Dashboard
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/app_data.dart';
import 'tambah_wisata_screen.dart';
import 'detail_wisata_screen.dart';

// ── Palet (selaras dengan TambahWisataScreen & Dashboard) ───
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

// ── Palette (identik dengan TambahWisataScreen) ─────────────
// ── Warna per-kategori ───────────────────────────────────────
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
  final String mode; // 'view' | 'edit' | 'hapus'
  const DaftarWisataScreen({super.key, this.mode = 'view'});

  @override
  State<DaftarWisataScreen> createState() => _DaftarWisataScreenState();
}

class _DaftarWisataScreenState extends State<DaftarWisataScreen>
    with SingleTickerProviderStateMixin {
  String _cari = '';
  String _kat = 'Semua';

  late final AnimationController _fabCtrl;
  bool _isLoadingData = true;

  static const _kategoriList = [
    'Semua',
    'Pantai',
    'Budaya',
    'Alam',
    'Bahari',
    'Kuliner',
    'Kota',
    'Lainnya',
  ];

  List<Wisata> get _filtered => daftarWisata.where((w) {
        final q = _cari.toLowerCase();
        final matchCari = _cari.isEmpty ||
            w.nama.toLowerCase().contains(q) ||
            w.lokasi.toLowerCase().contains(q) ||
            w.kategori.toLowerCase().contains(q);
        final matchKat = _kat == 'Semua' || w.kategori == _kat;
        return matchCari && matchKat;
      }).toList();

  String get _judul => switch (widget.mode) {
        'edit' => 'Ubah Data Wisata',
        'hapus' => 'Hapus Data Wisata',
        _ => 'Daftar Wisata',
      };

  Color get _accentColor => switch (widget.mode) {
        'edit' => const Color(0xFFA78BFA),
        'hapus' => _C.danger,
        _ => _C.teal,
      };

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _muatData();
  }

  Future<void> _muatData() async {
    await loadWisataFromFirestore();
    if (!mounted) return;
    setState(() => _isLoadingData = false);
  }

  @override
  void dispose() {
    _fabCtrl.dispose();
    super.dispose();
  }

  // ── Dialog hapus ─────────────────────────────────────────
  void _hapus(Wisata w) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                  color: _C.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.danger.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.delete_rounded, color: _C.danger, size: 36),
              ),
              const SizedBox(height: 20),
              Text('Hapus Wisata?',
                  style: const TextStyle(
                    color: _C.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
              const SizedBox(height: 10),
              Text(
                '"${w.nama}" akan dihapus permanen.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _C.textMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      )),
                      side: BorderSide(color: _C.border),
                      foregroundColor: _C.textMuted,
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      )),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('wisata')
                          .doc(w.id)
                          .delete();
                      setState(() => daftarWisata.remove(w));
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Row(children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Wisata berhasil dihapus'),
                        ]),
                        backgroundColor: _C.danger,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                    child: const Text('Hapus',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final filtered = _filtered;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: const Center(
          child: CircularProgressIndicator(color: _C.teal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
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
                          Text('${daftarWisata.length}',
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
                                  color: Colors.white.withValues(alpha: 0.28)),
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
                                    ? 'Pilih wisata yang ingin dihapus'
                                    : '${daftarWisata.length} destinasi tersedia',
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
                  style: const TextStyle(color: _C.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nama, lokasi, atau kategori...',
                    hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _C.teal, size: 20),
                    suffixIcon: _cari.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: _C.textMuted, size: 18),
                            onPressed: () => setState(() => _cari = ''),
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
                  onChanged: (v) => setState(() => _cari = v),
                ),
              ),
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
                  itemCount: _kategoriList.length,
                  itemBuilder: (_, i) {
                    final k = _kategoriList[i];
                    final sel = _kat == k;
                    final col = _kColor[k] ?? _C.teal;
                    return GestureDetector(
                      onTap: () => setState(() => _kat = k),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(4)),
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
          if (filtered.isEmpty)
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
                            color: _C.teal.withValues(alpha: 0.15), width: 1.5),
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
                    wisata: filtered[i],
                    mode: widget.mode,
                    accent: accent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailWisataScreen(wisata: filtered[i]),
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
                    onHapus: () => _hapus(filtered[i]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
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
  final VoidCallback onTap, onEdit, onHapus;

  const _WisataCard({
    required this.wisata,
    required this.mode,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onHapus,
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
            onTap: mode == 'view' ? onTap : null,
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
                            Text(wisata.hargaTiket,
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
                      right: mode != 'view' ? 62 : 14,
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
                        child: _overlayBtn(
                          icon: Icons.edit_rounded,
                          color: const Color(0xFFA78BFA),
                          onTap: onEdit,
                        ),
                      )
                    else if (mode == 'hapus')
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: _overlayBtn(
                          icon: Icons.delete_rounded,
                          color: _C.danger,
                          onTap: onHapus,
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
                      if (mode == 'view') ...[
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

  Widget _buildImage() {
    final path = wisata.imagePath;
    final col = _kColor[wisata.kategori] ?? _C.teal;
    if (path == null || path.isEmpty) {
      return Container(
        color: col.withValues(alpha: 0.08),
        child: Center(
          child: Icon(_kIcon[wisata.kategori] ?? Icons.landscape_rounded,
              color: col.withValues(alpha: 0.3), size: 52),
        ),
      );
    }
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.cover);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: col.withValues(alpha: 0.07),
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: col,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: col.withValues(alpha: 0.07),
          child: Icon(Icons.broken_image_rounded,
              color: col.withValues(alpha: 0.3), size: 40),
        ),
      );
    }
    return Image.file(File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
              color: col.withValues(alpha: 0.07),
              child: Icon(Icons.broken_image_rounded,
                  color: col.withValues(alpha: 0.3), size: 40),
            ));
  }
}
