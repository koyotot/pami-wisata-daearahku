import 'auth_presentation.dart';
// ============================================================
// lib/screens/user_login_screen.dart
// Package: google_fonts, firebase_auth
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_session.dart';

import 'session_destination.dart';
import 'user_register_screen.dart';
import 'forgot_password_screen.dart';

Future<void>? _googleInitialization;
bool _googleFlowActive = false;

@visibleForTesting
Future<String?> googleFirebaseToken(bool Function() isCurrent,
    {Future<String?> Function(String)? firebaseTokenForGoogle}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    final credential = await fb_auth.FirebaseAuth.instance
        .signInWithProvider(fb_auth.GoogleAuthProvider());
    return credential.user?.getIdToken();
  }

  final google = GoogleSignIn.instance;
  final initialization = _googleInitialization ??= google.initialize();
  try {
    await initialization;
  } catch (_) {
    if (identical(_googleInitialization, initialization)) {
      _googleInitialization = null;
    }
    rethrow;
  }
  if (!isCurrent()) {
    throw const ApiException('Permintaan masuk sudah dibatalkan.');
  }
  try {
    final account = await google.authenticate();
    if (!isCurrent()) {
      throw const ApiException('Permintaan masuk sudah dibatalkan.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('Identitas Google tidak tersedia.');
    }
    if (firebaseTokenForGoogle != null) {
      return await firebaseTokenForGoogle(idToken);
    }
    final credential = await fb_auth.FirebaseAuth.instance.signInWithCredential(
        fb_auth.GoogleAuthProvider.credential(idToken: idToken));
    return credential.user?.getIdToken();
  } finally {
    try {
      await google.signOut();
    } catch (_) {}
  }
}

// ── Warna & font: sama dengan home_screen.dart ────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const background = Color(0xFFF5F8FD);
  static const textMuted = Color(0xFF728099);
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

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen(
      {super.key, this.session, this.googleToken, this.firebaseSignOut});

  final AuthSession? session;
  final Future<String?> Function()? googleToken;
  final Future<void> Function()? firebaseSignOut;

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

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
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Login Firebase ─────────────────────────────────────────
  Future<void> _login() async {
    if (_isLoading) return;
    final session = widget.session ?? AuthSession.instance;
    final generation = session.sessionGeneration;

    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMsg = 'Email dan password tidak boleh kosong.';
      });
      return;
    }

    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    try {
      await fb_auth.FirebaseAuth.instance.signOut();
      if (!session.isCurrentGeneration(generation)) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      await session.login(email, password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _openMainNavigation();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMsg = 'Terjadi kesalahan tidak terduga.';
        _isLoading = false;
      });
    }
  }

  Future<void> _googleLogin() async {
    if (_isLoading || _googleFlowActive) return;
    _googleFlowActive = true;
    final session = widget.session ?? AuthSession.instance;
    final generation = session.sessionGeneration;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await (widget.firebaseSignOut?.call() ??
          fb_auth.FirebaseAuth.instance.signOut());
      if (!session.isCurrentGeneration(generation)) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      final token = await (widget.googleToken?.call() ??
          googleFirebaseToken(() => session.isCurrentGeneration(generation)));
      if (!session.isCurrentGeneration(generation)) {
        throw const ApiException('Permintaan masuk sudah dibatalkan.');
      }
      if (token == null || token.isEmpty) {
        throw const ApiException('Identitas Google tidak tersedia.');
      }
      await session.google(token);
      if (mounted) _openMainNavigation();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _errorMsg = switch (e.code) {
              GoogleSignInExceptionCode.clientConfigurationError ||
              GoogleSignInExceptionCode.providerConfigurationError =>
                'Konfigurasi Google Sign-In belum valid.',
              _ => 'Tidak dapat masuk dengan Google. Silakan coba lagi.',
            });
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      if (mounted &&
          !['web-context-cancelled', 'popup-closed-by-user', 'cancelled']
              .contains(e.code)) {
        setState(() =>
            _errorMsg = 'Tidak dapat masuk dengan Google. Silakan coba lagi.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'Tidak dapat masuk dengan Google.');
      }
    } finally {
      // Sesi Firebase hanya perantara; selalu dibersihkan, termasuk saat
      // Laravel menolak sesi Google (generasi sudah berganti oleh clear()).
      try {
        await (widget.firebaseSignOut?.call() ??
            fb_auth.FirebaseAuth.instance.signOut());
      } catch (_) {}
      _googleFlowActive = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMainNavigation() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => sessionDestination(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _goToRegister() async {
    if (_isLoading) return;

    final berhasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const UserRegisterScreen(),
      ),
    );

    if (!mounted) return;

    if (berhasil == true) {
      _openMainNavigation();
    }
  }

  // ── Tampilan utama ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthTheme(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // ikon putih di header biru
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeTransition(
                          opacity: _fadeAnim, child: _buildHeader(context)),
                      Expanded(
                        child: Container(
                          color: const Color(0xFF102D59),
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                                position: _slideAnim, child: _buildCard()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ));
  }

  // ── Header: gambar + tombol kembali + judul ────────────────
  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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

          // Chip brand + judul
          Padding(
            padding: EdgeInsets.fromLTRB(26, topInset + 20, 40, 24),
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
                      const Icon(Icons.travel_explore_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                          child: Text(
                        'Wisata Daerahku',
                        style: _font(11.5, FontWeight.w700, Colors.white),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selamat datang!',
                  style: _font(
                    30,
                    FontWeight.w800,
                    Colors.white,
                    height: 1.15,
                    letterSpacing: -0.8,
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
  Widget _buildCard() {
    return Container(
      width: double.infinity,
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
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle kecil
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
                  Expanded(child: Center(child: _buildForm())),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} Wisata Daerahku',
                      style: _font(
                        11,
                        FontWeight.w500,
                        _C.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form login ─────────────────────────────────────────────
  Widget _buildForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masuk untuk melanjutkan ke akun Wisata Daerahku.',
            style: _font(13.5, FontWeight.w500, _C.textMuted, height: 1.45),
          ),
          const SizedBox(height: 24),

          // Pesan error (animasi halus)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _errorMsg == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ErrorBanner(message: _errorMsg!),
                  ),
          ),

          _fieldLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.username,
              AutofillHints.email,
            ],
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: _C.blue,
            style: _font(14.5, FontWeight.w500, _C.navy),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            decoration: _inputDecoration(
              hint: 'nama@email.com',
              icon: Icons.email_rounded,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _fieldLabel('Password')),
              Flexible(
                  child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _C.blue,
                  padding: const EdgeInsets.only(left: 12),
                  textStyle: _font(13, FontWeight.w700, _C.blue),
                ),
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(
                                    session:
                                        widget.session ?? AuthSession.instance,
                                    initialEmail: _emailCtrl.text.trim(),
                                  )),
                        ),
                child: const Text('Lupa password?', textAlign: TextAlign.right),
              )),
            ],
          ),
          TextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            enabled: !_isLoading,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: _C.blue,
            style: _font(14.5, FontWeight.w500, _C.navy),
            onSubmitted: (_) => _login(),
            decoration: _inputDecoration(
              hint: 'Masukkan password',
              icon: Icons.lock_rounded,
              suffix: IconButton(
                tooltip:
                    _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _C.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _buildLoginButton(),
          const SizedBox(height: 20),

          // Pemisah
          Row(
            children: [
              const Expanded(child: Divider(color: _C.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'atau',
                  style: _font(12, FontWeight.w600, _C.textMuted),
                ),
              ),
              const Expanded(child: Divider(color: _C.border)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _googleLogin,
            icon: Image.asset('assets/images/google_g.png',
                width: 20, height: 20),
            label: const Text('Masuk dengan Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: _C.navy,
              side: const BorderSide(color: _C.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle: _font(14, FontWeight.w700, _C.navy),
            ),
          ),
          const SizedBox(height: 12),
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: _font(13, FontWeight.w700, _C.navy),
    );
  }

  // ── Tombol masuk ───────────────────────────────────────────
  Widget _buildLoginButton() {
    final radius = BorderRadius.circular(18);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _isLoading
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
              colors: _isLoading
                  ? const [_C.blueDeep, _C.blueDeep]
                  : const [Color(0xFF2386E8), _C.blueDeep],
            ),
          ),
          child: InkWell(
            onTap: _isLoading ? null : _login,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Masuk',
                          style: _font(15.5, FontWeight.w700, Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tombol daftar ──────────────────────────────────────────
  Widget _buildRegisterButton() {
    return TextButton(
      onPressed: _isLoading ? null : _goToRegister,
      child: Text.rich(
        TextSpan(
          text: 'Belum punya akun? ',
          style: _font(13.5, FontWeight.w500, _C.textMuted),
          children: [
            TextSpan(
                text: 'Daftar', style: _font(13.5, FontWeight.w800, _C.blue)),
          ],
        ),
      ),
    );
  }
}

// ── Ilustrasi matahari, awan & pegunungan ────────────────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Matahari + cahaya
    final sun = Offset(w * 0.82, h * 0.30);
    final r = w * 0.085;
    canvas.drawCircle(
      sun,
      r * 3,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x80FFC46B), Color(0x00FFC46B)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 3)),
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

    // Awan sederhana
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.22);
    void drawCloud(Offset c, double s) {
      canvas.drawCircle(c, 9 * s, cloud);
      canvas.drawCircle(c.translate(11 * s, -5 * s), 12 * s, cloud);
      canvas.drawCircle(c.translate(25 * s, 0), 9 * s, cloud);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - 9 * s, c.dy, 43 * s, 9 * s),
          Radius.circular(9 * s),
        ),
        cloud,
      );
    }

    drawCloud(Offset(w * 0.62, h * 0.20), 1.0);
    drawCloud(Offset(w * 0.42, h * 0.52), 0.75);

    // Gunung belakang
    final back = Path()
      ..moveTo(0, h * 0.74)
      ..lineTo(w * 0.18, h * 0.58)
      ..lineTo(w * 0.36, h * 0.70)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.80, h * 0.72)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0x661558B0));

    // Gunung depan
    final front = Path()
      ..moveTo(0, h * 0.84)
      ..lineTo(w * 0.24, h * 0.68)
      ..lineTo(w * 0.48, h * 0.82)
      ..lineTo(w * 0.72, h * 0.67)
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

// ── Dekorasi input ───────────────────────────────────────────
InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: _font(
      14,
      FontWeight.w400,
      _C.textMuted.withValues(alpha: 0.75),
    ),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 16, right: 10),
      child: Icon(icon, color: _C.blue, size: 20),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: _C.background,
    border: border(_C.border, 1.2),
    enabledBorder: border(_C.border, 1.2),
    disabledBorder: border(_C.border, 1.2),
    focusedBorder: border(_C.blue, 1.6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  );
}

// ── Pesan error ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _C.danger, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _font(12.5, FontWeight.w500, _C.danger, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
