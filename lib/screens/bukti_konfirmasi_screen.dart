// ============================================================
// lib/screens/bukti_konfirmasi_screen.dart
// REDESIGN: biru terang + Plus Jakarta Sans — selaras home_screen
// - Hero gradasi biru + matahari & pegunungan, ikon sukses beranimasi
// - Tiket modern: foto destinasi, potongan lengkung, garis putus-putus
// - QR code kode booking + tombol salin
// Butuh package: google_fonts, qr_flutter
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/app_data.dart';
import 'main_navigation_screen.dart';

// ── Palet (sama dengan home_screen) ──────────────────────────
const _blue = Color(0xFF1976D2);
const _blueDeep = Color(0xFF1558B0);
const _navy = Color(0xFF102D59);
const _orange = Color(0xFFFF9800);
const _bg = Color(0xFFF5F8FD);
const _tint = Color(0xFFE6F0FC);
const _textMuted = Color(0xFF728099);
const _border = Color(0xFFDCE4F0);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);

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

class BuktiKonfirmasiScreen extends StatefulWidget {
  final Pendaftar pendaftaran;
  final Wisata wisata;

  const BuktiKonfirmasiScreen({
    super.key,
    required this.pendaftaran,
    required this.wisata,
  });

  @override
  State<BuktiKonfirmasiScreen> createState() => _BuktiKonfirmasiScreenState();
}

class _BuktiKonfirmasiScreenState extends State<BuktiKonfirmasiScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _badgeScale;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();

    _badgeScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
          parent: _animCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _salinKode() {
    Clipboard.setData(ClipboardData(text: widget.pendaftaran.nomorBukti));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Kode booking disalin!',
          style: _font(13, FontWeight.w600, Colors.white)),
      backgroundColor: _blueDeep,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _selesai() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => route.isFirst,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = widget.pendaftaran;
    final inset = MediaQuery.of(context).padding.top;
    final heroH = inset + 290;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Hero + tiket yang menumpuk di atasnya
              SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: heroH,
                      child: _buildHero(inset),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, heroH - 50, 20, 0),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _buildTicket(p),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tombol selesai
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  26,
                  20,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildDoneButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HERO
  // ══════════════════════════════════════════════════════════
  Widget _buildHero(double inset) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A93F0), _blue, _blueDeep],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ScenePainter())),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: inset + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.travel_explore_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Wisata Daerahku',
                        style: _font(15, FontWeight.w800, Colors.white,
                            letterSpacing: -0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ikon sukses
                  ScaleTransition(
                    scale: _badgeScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: _navy.withValues(alpha: 0.25),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF34D399), _green],
                              ),
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 36),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        Text(
                          'Pendaftaran Berhasil!',
                          style: _font(24, FontWeight.w800, Colors.white,
                              letterSpacing: -0.6),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Tunjukkan bukti ini kepada petugas loket',
                                style:
                                    _font(11.5, FontWeight.w600, Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TIKET
  // ══════════════════════════════════════════════════════════
  Widget _buildTicket(Pendaftar p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Destinasi ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(width: 68, height: 68, child: _foto()),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESTINASI',
                        style: _font(10, FontWeight.w800, _orange,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.wisata,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _font(17, FontWeight.w800, _navy,
                            letterSpacing: -0.4, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: _blue),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.wisata.lokasi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(12, FontWeight.w500, _textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tanggal & jumlah ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _miniTile(
                    Icons.calendar_today_rounded,
                    'Tanggal',
                    p.tanggal,
                    _blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    Icons.group_rounded,
                    'Pengunjung',
                    '${p.jumlahOrang} Orang',
                    _orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _tear(),

          // ── Data pengunjung ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _subHeader('Data Pengunjung'),
                const SizedBox(height: 8),
                _detailRow(
                    Icons.person_rounded, 'Nama Pengunjung', p.namaPengunjung),
                _detailRow(
                    Icons.phone_android_rounded, 'No. Telepon', p.noTelepon),
                _detailRow(Icons.email_rounded, 'Email', p.email),
                if (p.catatan.isNotEmpty)
                  _detailRow(Icons.notes_rounded, 'Catatan', p.catatan),
              ],
            ),
          ),

          _tear(),

          // ── QR & kode booking ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: p.nomorBukti,
                    version: QrVersions.auto,
                    size: 148,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _navy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _navy,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'KODE BOOKING',
                  style: _font(10.5, FontWeight.w800, _textMuted,
                      letterSpacing: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  p.nomorBukti,
                  textAlign: TextAlign.center,
                  style:
                      _font(22, FontWeight.w800, _blueDeep, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                Material(
                  color: _tint,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _salinKode,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded,
                              color: _blue, size: 15),
                          const SizedBox(width: 7),
                          Text('Salin Kode',
                              style: _font(12.5, FontWeight.w800, _blueDeep)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status Pendaftaran',
                        style: _font(12.5, FontWeight.w600, _textMuted)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _amber,
                              boxShadow: [
                                BoxShadow(
                                  color: _amber.withValues(alpha: 0.6),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Menunggu Konfirmasi',
                            style: _font(
                                11.5, FontWeight.w800, const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded, color: _blue, size: 15),
                const SizedBox(width: 6),
                Text(
                  'Wisata Daerahku  ·  Tiket Resmi',
                  style:
                      _font(11, FontWeight.w700, _blueDeep, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tombol selesai ─────────────────────────────────────────
  Widget _buildDoneButton() {
    final radius = BorderRadius.circular(18);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [Color(0xFF2386E8), _blueDeep],
            ),
          ),
          child: InkWell(
            onTap: _selesai,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Selesai & Kembali ke Beranda',
                  style: _font(15, FontWeight.w700, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HELPER
  // ══════════════════════════════════════════════════════════
  Widget _foto() {
    Widget placeholder() => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF90CAF9), _blue],
            ),
          ),
          child: Center(
            child: Icon(Icons.landscape_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 30),
          ),
        );

    final path = widget.wisata.imagePath;
    if (path == null || path.isEmpty) return placeholder();

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; FlutterApp/1.0)',
        },
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(),
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder());
    }
    return Image.file(File(path),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder());
  }

  Widget _miniTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _font(10.5, FontWeight.w600, _textMuted)),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _font(12.5, FontWeight.w800, _navy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: _font(13.5, FontWeight.w800, _navy, letterSpacing: -0.2)),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _font(11, FontWeight.w600, _textMuted)),
                const SizedBox(height: 1),
                Text(value, style: _font(13.5, FontWeight.w700, _navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Potongan tiket: garis putus-putus + lekukan kiri/kanan
  Widget _tear() {
    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: CustomPaint(painter: _DashPainter()),
            ),
          ),
          Positioned(left: -12, top: 0, child: _notch()),
          Positioned(right: -12, top: 0, child: _notch()),
        ],
      ),
    );
  }

  Widget _notch() => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
      );
}

// ── Garis putus-putus ─────────────────────────────────────────
class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3D3EA)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 6, size.height / 2),
        paint,
      );
      x += 11;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Matahari & pegunungan (sama dengan home_screen) ───────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Matahari + cahaya
    final sun = Offset(w * 0.82, h * 0.2);
    final r = w * 0.07;
    canvas.drawCircle(
      sun,
      r * 2.8,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x80FFC46B), Color(0x00FFC46B)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 2.8)),
    );
    canvas.drawCircle(
      sun,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9B0), Color(0xFFFF9800)],
        ).createShader(Rect.fromCircle(center: sun, radius: r)),
    );

    // Gunung belakang
    final back = Path()
      ..moveTo(0, h * 0.78)
      ..lineTo(w * 0.20, h * 0.64)
      ..lineTo(w * 0.38, h * 0.74)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.80, h * 0.76)
      ..lineTo(w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0x4D1558B0));

    // Gunung depan
    final front = Path()
      ..moveTo(0, h * 0.86)
      ..lineTo(w * 0.24, h * 0.73)
      ..lineTo(w * 0.48, h * 0.84)
      ..lineTo(w * 0.72, h * 0.72)
      ..lineTo(w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x801558B0), Color(0xB3102D59)],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
