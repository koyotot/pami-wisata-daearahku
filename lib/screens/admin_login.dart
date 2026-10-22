// ============================================================
// lib/screens/admin_login.dart
// Auth berbasis Firestore collection 'admins'
// Tema: biru terang — sama dengan home & login pengunjung
// Package: google_fonts, cloud_firestore
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_dashboard.dart';

// ── Palet & font (sama dengan home_screen.dart) ──────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const background = Color(0xFFF5F8FD);
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);
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

// Model admin yang dipakai di seluruh app
class AdminUser {
  final String id;
  final String username;
  final String namaLengkap;
  final bool isSuperAdmin;

  const AdminUser({
    required this.id,
    required this.username,
    required this.namaLengkap,
    required this.isSuperAdmin,
  });

  factory AdminUser.fromMap(Map<String, dynamic> m, String id) => AdminUser(
        id: id,
        username: m['username'] ?? '',
        namaLengkap: m['namaLengkap'] ?? '',
        isSuperAdmin: m['isSuperAdmin'] == true,
      );
}

// State global — null jika belum login
AdminUser? currentAdmin;

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMsg;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _seedSuperAdmin(); // pastikan superadmin selalu ada
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Seed superadmin jika collection 'admins' masih kosong ──
  Future<void> _seedSuperAdmin() async {
    final col = FirebaseFirestore.instance.collection('admins');
    final snap = await col.limit(1).get();
    if (snap.docs.isEmpty) {
      await col.doc('superadmin').set({
        'username': 'superadmin',
        'password': 'super123', // ganti setelah deploy
        'namaLengkap': 'Super Administrator',
        'isSuperAdmin': true,
        'createdAt': Timestamp.now(),
      });
    }
  }

  // ── Login: cek Firestore collection 'admins' ───────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final snap = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _errorMsg = 'Username atau password salah. Silakan coba lagi.';
          _isLoading = false;
        });
        return;
      }

      final doc = snap.docs.first;
      currentAdmin = AdminUser.fromMap(doc.data(), doc.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const AdminDashboard(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMsg = 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.top;
    final heroH = inset + 300;
    final cardTop = heroH - 36;
    final screenH = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              SizedBox(
                height: heroH,
                width: double.infinity,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildHeader(inset),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: cardTop),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildFormCard(minHeight: screenH - cardTop),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: tombol kembali + judul ─────────────────────────
  Widget _buildHeader(double inset) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF90CAF9)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _ScenePainter())),

          // Tombol kembali
          Positioned(
            top: inset + 10,
            left: 20,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Material(
                color: Colors.white.withValues(alpha: 0.22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _isLoading ? null : () => Navigator.pop(context),
                  child: const Center(
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
              ),
            ),
          ),

          // Chip brand + judul
          Positioned(
            left: 26,
            right: 110,
            top: inset + 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Wisata Daerahku · Admin',
                          style: _font(11.5, FontWeight.w700, Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Portal\nAdmin',
                  style: _font(34, FontWeight.w800, Colors.white,
                      height: 1.12, letterSpacing: -1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masuk untuk mengelola konten wisata',
                  style: _font(
                    12.5,
                    FontWeight.w500,
                    Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Kartu putih berisi form ────────────────────────────────
  Widget _buildFormCard({required double minHeight}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: _C.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Masuk Admin',
                        style: _font(22, FontWeight.w800, _C.navy,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Akses terbatas untuk administrator',
                        style: _font(12.5, FontWeight.w500, _C.textMuted)),
                    const SizedBox(height: 22),
                    if (_errorMsg != null) ...[
                      _ErrorBanner(message: _errorMsg!),
                      const SizedBox(height: 18),
                    ],
                    const _FieldLabel(label: 'Username'),
                    const SizedBox(height: 8),
                    _LoginTextField(
                      controller: _usernameController,
                      hint: 'Masukkan username',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Username wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(label: 'Password'),
                    const SizedBox(height: 8),
                    _PasswordTextField(
                      controller: _passwordController,
                      obscure: _obscure,
                      onToggle: () => setState(() => _obscure = !_obscure),
                      onSubmit: (_) => _login(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 26),
                    _LoginButton(isLoading: _isLoading, onPressed: _login),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        '© ${DateTime.now().year} Wisata Daerahku',
                        style: _font(11, FontWeight.w500,
                            _C.textMuted.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-Widgets ─────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) =>
      Text(label, style: _font(13, FontWeight.w700, _C.navy));
}

InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: _font(14, FontWeight.w500, _C.textDim),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Icon(icon, color: _C.blue, size: 20),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: _C.background,
    enabledBorder: border(_C.border, 1.3),
    focusedBorder: border(_C.blue, 1.6),
    errorBorder: border(_C.danger, 1.3),
    focusedErrorBorder: border(_C.danger, 1.6),
    errorStyle: _font(11.5, FontWeight.w600, _C.danger),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
  );
}

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  const _LoginTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.textInputAction = TextInputAction.done,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        textInputAction: textInputAction,
        validator: validator,
        style: _font(14, FontWeight.w600, _C.navy),
        decoration: _fieldDecoration(hint: hint, icon: prefixIcon),
      );
}

class _PasswordTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String>? onSubmit;
  final String? Function(String?)? validator;

  const _PasswordTextField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.onSubmit,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscure,
        onFieldSubmitted: onSubmit,
        validator: validator,
        textInputAction: TextInputAction.done,
        style: _font(14, FontWeight.w600, _C.navy),
        decoration: _fieldDecoration(
          hint: 'Masukkan password',
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _C.textDim,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _C.danger, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: _font(12.5, FontWeight.w600, _C.danger, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: _C.blue.withValues(alpha: 0.35),
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
            gradient: LinearGradient(
              colors: isLoading
                  ? [const Color(0xFF6FA8DC), const Color(0xFF6FA8DC)]
                  : const [Color(0xFF2386E8), _C.blueDeep],
            ),
          ),
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Masuk',
                            style: _font(15, FontWeight.w700, Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Matahari & pegunungan (sama dengan home_screen) ──────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sun = Offset(w * 0.80, h * 0.26);
    final r = w * 0.09;
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

    final back = Path()
      ..moveTo(0, h * 0.74)
      ..lineTo(w * 0.20, h * 0.60)
      ..lineTo(w * 0.38, h * 0.70)
      ..lineTo(w * 0.58, h * 0.54)
      ..lineTo(w * 0.80, h * 0.72)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0x661558B0));

    final front = Path()
      ..moveTo(0, h * 0.84)
      ..lineTo(w * 0.24, h * 0.70)
      ..lineTo(w * 0.48, h * 0.82)
      ..lineTo(w * 0.72, h * 0.69)
      ..lineTo(w, h * 0.82)
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
        ).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
