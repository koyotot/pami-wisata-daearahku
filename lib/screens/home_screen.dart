// ============================================================
// lib/screens/home_screen.dart
// Butuh package: flutter pub add google_fonts
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'user_login_screen.dart';

// Font: Plus Jakarta Sans (modern, ramah, enak dibaca di HP)
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _blue = Color(0xFF1976D2);
  static const _blueDeep = Color(0xFF1558B0);
  static const _navy = Color(0xFF102D59);
  static const _orange = Color(0xFFFF9800);
  static const _background = Color(0xFFF5F8FD);
  static const _textMuted = Color(0xFF728099);

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildBrand(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildHero()),
                      const SizedBox(height: 22),
                      _ActionButton(
                        icon: Icons.explore_rounded,
                        label: 'Masuk',
                        filled: true,
                        onTap: () => _open(context, const UserLoginScreen()),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '© ${DateTime.now().year} Wisata Daerahku',
                        style: _font(
                          11,
                          FontWeight.w500,
                          _textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Brand: logo + nama ─────────────────────────────────────
  Widget _buildBrand() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF42A5F5), _blue],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Wisata Daerahku',
          style: _font(18, FontWeight.w800, _navy, letterSpacing: -0.4),
        ),
      ],
    );
  }

  // ── Hero: pemandangan + judul ──────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF90CAF9)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _ScenePainter()),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 28),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Temukan\nWisata Impianmu',
                        style: _font(
                          34,
                          FontWeight.w800,
                          Colors.white,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Jelajahi keindahan Nusantara.',
                        style: _font(
                          14.5,
                          FontWeight.w500,
                          Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Matahari & pegunungan (digambar dengan kode) ──────────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Matahari + cahaya
    final sun = Offset(w * 0.72, h * 0.27);
    final r = w * 0.12;
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
      ..moveTo(0, h * 0.62)
      ..lineTo(w * 0.20, h * 0.46)
      ..lineTo(w * 0.38, h * 0.58)
      ..lineTo(w * 0.58, h * 0.40)
      ..lineTo(w * 0.80, h * 0.60)
      ..lineTo(w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0x661558B0));

    // Gunung depan (gelap, tempat teks berada)
    final front = Path()
      ..moveTo(0, h * 0.70)
      ..lineTo(w * 0.24, h * 0.55)
      ..lineTo(w * 0.48, h * 0.68)
      ..lineTo(w * 0.72, h * 0.54)
      ..lineTo(w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC1558B0), Color(0xF2102D59)],
        ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Tombol aksi ───────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: filled
            ? [
                BoxShadow(
                  color: HomeScreen._blue.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: filled ? null : Colors.white,
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF2386E8), HomeScreen._blueDeep],
                  )
                : null,
            border: filled
                ? null
                : Border.all(color: const Color(0xFFDCE4F0), width: 1.4),
          ),
          child: InkWell(
            onTap: onTap,
            splashColor: (filled ? Colors.white : HomeScreen._blue)
                .withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: filled ? Colors.white : HomeScreen._orange,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: _font(
                    15,
                    FontWeight.w700,
                    filled ? Colors.white : HomeScreen._navy,
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
