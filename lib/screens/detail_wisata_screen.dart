// ============================================================
// lib/screens/detail_wisata_screen.dart
// Tema: biru terang — sama dengan home, login, beranda, dan profil
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../data/favorite_state.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'daftar_kunjungan_screen.dart';

// ── Palet (sama dengan home_screen.dart) ─────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const orangeDeep = Color(0xFFE08600);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const surface = Colors.white;
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const goldLight = Color(0xFFFFE9B0);

  // Alias supaya kode lama tetap jalan dengan warna baru
  static const teal = blue;
  static const tealDark = blueDeep;
  static const gold = orange;
}

// ── Liked masih in-memory (opsional: bisa dipersist juga nanti) ──
final Set<String> _likedWisataIds = {};

class DetailWisataScreen extends StatefulWidget {
  final Wisata wisata;
  const DetailWisataScreen({super.key, required this.wisata});

  @override
  State<DetailWisataScreen> createState() => _DetailWisataScreenState();
}

class _DetailWisataScreenState extends State<DetailWisataScreen>
    with SingleTickerProviderStateMixin {
  final _repository = BusinessRepository();
  final _detail = RequestState<Destination>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool get _isLiked => _likedWisataIds.contains(widget.wisata.id);

  final _favorites = FavoriteState.instance;
  bool get _isSaved => _favorites.isFavorite(widget.wisata.id);
  bool _loadingSave = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _detail.addListener(_detailChanged);
    _loadDetail();
    _favorites.favorites.addListener(_detailChanged);
  }

  void _detailChanged() {
    if (mounted) setState(() {});
  }

  void _loadDetail() {
    final id = widget.wisata.id;
    _detail.load(() async {
      final destination = await _repository.destination(id);
      if (destination.guid != id) {
        throw const ApiException('Identitas wisata tidak sesuai.');
      }
      return destination;
    });
  }

  @override
  void didUpdateWidget(covariant DetailWisataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wisata.id != widget.wisata.id) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _favorites.favorites.removeListener(_detailChanged);
    _detail.removeListener(_detailChanged);
    _detail.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _likedWisataIds.remove(widget.wisata.id);
      } else {
        _likedWisataIds.add(widget.wisata.id);
      }
    });
    _showSnack(
      _isLiked
          ? '❤️  ${widget.wisata.nama} disukai!'
          : '🤍  Dihapus dari disukai',
    );
  }

  Future<void> _toggleSave() async {
    if (_loadingSave) return;
    if (!_favorites.session.authenticated.value ||
        !_favorites.session.deviceSessionReady) {
      _showSnack('Login dulu untuk menyimpan wisata.');
      return;
    }
    final id = widget.wisata.id;
    final generation = _favorites.session.sessionGeneration;
    if (_favorites.favorites.error != null ||
        _favorites.favorites.data == null) {
      await _favorites.load();
      if (!mounted ||
          generation != _favorites.session.sessionGeneration ||
          id != widget.wisata.id ||
          !_favorites.session.deviceSessionReady) {
        return;
      }
      if (_favorites.favorites.error != null ||
          _favorites.favorites.data == null) {
        _showSnack(_favorites.favorites.error?.toString() ??
            'Gagal memuat wisata tersimpan.');
        return;
      }
    }
    final wasSaved = _isSaved;
    setState(() => _loadingSave = true);
    try {
      await _favorites.toggle(id);
      if (!mounted ||
          generation != _favorites.session.sessionGeneration ||
          id != widget.wisata.id) {
        return;
      }
      if (_favorites.favorites.error != null) {
        _showSnack(_favorites.favorites.error.toString());
      } else if (_isSaved != wasSaved) {
        _showSnack(_isSaved ? 'Wisata disimpan!' : 'Dihapus dari tersimpan');
      }
    } catch (e) {
      if (mounted && generation == _favorites.session.sessionGeneration) {
        _showSnack(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingSave = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: const TextStyle(color: _C.text, fontSize: 13)),
        backgroundColor: _C.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = _detail.data;
    if (_detail.loading ||
        _detail.error != null ||
        destination == null ||
        destination.guid != widget.wisata.id) {
      final error = _detail.error;
      final message = error is ApiException && error.status == 404
          ? 'Wisata tidak ditemukan.'
          : error?.toString() ?? 'Memuat wisata...';
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(message),
                  TextButton(
                      onPressed: _detail.retry, child: const Text('Coba lagi')),
                ]),
        ),
      );
    }
    final w = Wisata.fromDestination(destination);

    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.navy, size: 18),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _toggleLike,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isLiked
                    ? const Color(0xFFFFF1D6)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isLiked ? _C.gold.withValues(alpha: 0.6) : _C.border,
                ),
              ),
              child: Icon(
                _isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isLiked ? _C.gold : _C.gold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Hero Image + Konten ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Gambar utama
                  Stack(
                    children: [
                      SizedBox(
                        height: 320,
                        width: double.infinity,
                        child: _buildImage(w),
                      ),
                      // Gradient overlay bawah
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _C.bg,
                                _C.bg.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Badge kategori
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _C.teal,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _C.teal.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            w.kategori.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      // Badge rating
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _C.gold.withValues(alpha: 0.3),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: _C.gold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                w.isLaravel ? '-' : w.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: _C.goldLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Konten ─────────────────────────────────
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nama wisata
                            Text(
                              w.nama,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _C.text,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Lokasi
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 15, color: _C.teal),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    w.lokasi,
                                    style: TextStyle(
                                      color: _C.textMuted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 15, color: _C.teal),
                                const SizedBox(width: 5),
                                Text(
                                  w.jamBuka,
                                  style: TextStyle(
                                      color: _C.textMuted, fontSize: 13),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ── Harga Tiket Card ─────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _C.card,
                                    const Color(0xFFE6F0FC),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _C.teal.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.teal.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _C.gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              _C.gold.withValues(alpha: 0.3)),
                                    ),
                                    child: Icon(
                                      Icons.confirmation_number_rounded,
                                      color: _C.gold,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Harga Tiket Masuk',
                                          style: TextStyle(
                                            color: _C.textDim,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          w.hargaTiket,
                                          style: TextStyle(
                                            color: _C.orangeDeep,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _C.teal.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              _C.teal.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Per Orang',
                                      style: TextStyle(
                                        color: _C.teal,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Info Pills ───────────────────
                            Row(
                              children: [
                                _infoPill(
                                    Icons.place_rounded, w.kategori, _C.teal),
                                const SizedBox(width: 10),
                                _infoPill(
                                  Icons.schedule_rounded,
                                  w.jamBuka == '24 Jam'
                                      ? 'Buka 24 Jam'
                                      : w.jamBuka,
                                  _C.orangeDeep,
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // ── Deskripsi ────────────────────
                            _sectionTitle('Tentang Tempat Ini'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _C.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _C.border,
                                ),
                              ),
                              child: Text(
                                w.deskripsi.isNotEmpty
                                    ? w.deskripsi
                                    : 'Deskripsi belum tersedia.',
                                style: TextStyle(
                                  color: _C.textMuted,
                                  fontSize: 14,
                                  height: 1.7,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Fasilitas ────────────────────
                            _sectionTitle('Fasilitas'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _FasilitasBadge(
                                    icon: Icons.local_parking_rounded,
                                    label: 'Parkir'),
                                _FasilitasBadge(
                                    icon: Icons.wc_rounded, label: 'Toilet'),
                                _FasilitasBadge(
                                    icon: Icons.restaurant_rounded,
                                    label: 'Kuliner'),
                                _FasilitasBadge(
                                    icon: Icons.photo_camera_rounded,
                                    label: 'Spot Foto'),
                                _FasilitasBadge(
                                    icon: Icons.security_rounded,
                                    label: 'Keamanan'),
                              ],
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tombol CTA Bawah ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: _C.surface,
              border: Border(
                top: BorderSide(
                    color: _C.teal.withValues(alpha: 0.12), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x14102D59),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Tombol Simpan (Bookmark)
                GestureDetector(
                  onTap: _toggleSave,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color:
                          _isSaved ? _C.gold.withValues(alpha: 0.2) : _C.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isSaved
                            ? _C.gold.withValues(alpha: 0.6)
                            : _C.gold.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: _loadingSave
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _C.gold),
                          )
                        : Icon(
                            _isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: _C.gold,
                            size: 22,
                          ),
                  ),
                ),
                // Tombol Daftar Kunjungan
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DaftarKunjunganScreen(wisata: w),
                      ),
                    ),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_C.teal, _C.tealDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _C.teal.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_reg_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'DAFTAR KUNJUNGAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.teal, _C.gold],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: _C.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ],
      );

  Widget _infoPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Wisata w) {
    final path = w.imagePath;
    if (path == null || path.isEmpty) return _placeholder();
    if (path.startsWith('http')) {
      return Image.network(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    return Image.file(File(path),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFDCEBFF), _C.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Icon(Icons.landscape_rounded,
              size: 80, color: _C.teal.withValues(alpha: 0.35)),
        ),
      );
}

// ── Fasilitas Badge ───────────────────────────────────────
class _FasilitasBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FasilitasBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _C.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.blue, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _C.navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
