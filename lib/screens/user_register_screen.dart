// ============================================================
// lib/screens/user_register_screen.dart
// Package: google_fonts, firebase_auth, cloud_firestore
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_session.dart';

// ── Palet: sama dengan home dan login ─────────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
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

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _teleponCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureKonfirmasi = true;
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
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _teleponCtrl.dispose();
    _passwordCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  // ── Pendaftaran Firebase ───────────────────────────────────
  Future<void> _register() async {
    if (_isLoading) return;

    setState(() => _errorMsg = null);

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final nama = _namaCtrl.text.trim();
      await AuthSession.instance.register(nama, _emailCtrl.text.trim(),
          _passwordCtrl.text, _konfirmasiCtrl.text);
      if (!mounted) return;

      // Tetap loading sampai dialog ditutup.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(namaUser: nama),
      );

      if (!mounted) return;

      // Dikembalikan ke halaman login untuk melanjutkan navigasi.
      Navigator.pop(context, true);
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

  // ── Tampilan utama ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCEBFF), Color(0xFFF5F8FD), Colors.white],
              stops: [0.0, 0.35, 0.8],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                              position: _slideAnim,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildTopBar(),
                                  const SizedBox(height: 28),
                                  _buildTitle(),
                                  const SizedBox(height: 26),
                                  _buildForm(),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Bar atas: kembali + brand ──────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _C.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isLoading ? null : () => Navigator.pop(context),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _C.navy,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
            style: _font(18, FontWeight.w800, _C.navy, letterSpacing: -0.4),
          ),
        ),
      ],
    );
  }

  // ── Judul halaman ──────────────────────────────────────────
  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mulai Petualangan\nBarumu!',
          style: _font(
            32,
            FontWeight.w800,
            _C.navy,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Buat akun pengunjung dan temukan keindahan Nusantara.',
          style: _font(14, FontWeight.w500, _C.textMuted, height: 1.5),
        ),
      ],
    );
  }

  // ── Form pendaftaran ───────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            // ── Bagian 1 ──
            _sectionLabel(
              1,
              'Informasi Pribadi',
              'Data dirimu untuk profil pengunjung',
              Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
            _RegField(
              controller: _namaCtrl,
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap',
              icon: Icons.person_rounded,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama lengkap wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _RegField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'nama@email.com',
              icon: Icons.email_rounded,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Email wajib diisi';
                }

                if (!email.contains('@') || !email.contains('.')) {
                  return 'Format email tidak valid';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            _RegField(
              controller: _teleponCtrl,
              label: 'Nomor Telepon',
              hint: 'Contoh: 08123456789',
              icon: Icons.phone_rounded,
              enabled: !_isLoading,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.trim().length < 8) {
                  return 'Nomor telepon tidak valid';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // ── Bagian 2 ──
            _sectionLabel(
              2,
              'Keamanan Akun',
              'Lindungi akunmu dengan password kuat',
              Icons.shield_outlined,
            ),
            const SizedBox(height: 16),
            _RegField(
              controller: _passwordCtrl,
              label: 'Password',
              hint: 'Minimal 8 karakter',
              icon: Icons.lock_rounded,
              enabled: !_isLoading,
              obscure: _obscurePass,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              onToggleObscure: () {
                setState(() => _obscurePass = !_obscurePass);
              },
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password minimal 8 karakter';
                }
                return null;
              },
            ),
            _PasswordStrength(password: _passwordCtrl.text),
            const SizedBox(height: 16),
            _RegField(
              controller: _konfirmasiCtrl,
              label: 'Konfirmasi Password',
              hint: 'Ulangi password',
              icon: Icons.lock_outline_rounded,
              enabled: !_isLoading,
              obscure: _obscureKonfirmasi,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              onToggleObscure: () {
                setState(
                  () => _obscureKonfirmasi = !_obscureKonfirmasi,
                );
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Konfirmasi password wajib diisi';
                }

                if (value != _passwordCtrl.text) {
                  return 'Password tidak cocok';
                }

                return null;
              },
            ),
            const SizedBox(height: 28),
            _buildRegisterButton(),
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
            _buildLoginLinkButton(),
          ],
        ),
      ),
    );
  }

  // Label bagian bernomor
  Widget _sectionLabel(
    int number,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF42A5F5), _C.blue],
              ),
            ),
            child: Text(
              '$number',
              style: _font(15, FontWeight.w800, Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _font(14, FontWeight.w800, _C.navy)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: _font(11.5, FontWeight.w500, _C.textMuted),
                ),
              ],
            ),
          ),
          Icon(icon, color: _C.blue.withValues(alpha: 0.7), size: 22),
        ],
      ),
    );
  }

  // ── Tombol daftar ──────────────────────────────────────────
  Widget _buildRegisterButton() {
    return _GradientButton(
      label: 'Buat Akun',
      icon: Icons.how_to_reg_rounded,
      isLoading: _isLoading,
      onTap: _isLoading ? null : _register,
    );
  }

  // ── Tombol ke halaman masuk ────────────────────────────────
  Widget _buildLoginLinkButton() {
    final radius = BorderRadius.circular(18);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: _C.orange.withValues(alpha: 0.08),
          border: Border.all(
            color: _C.orange.withValues(alpha: 0.45),
            width: 1.3,
          ),
        ),
        child: InkWell(
          onTap: _isLoading ? null : () => Navigator.pop(context),
          splashColor: _C.orange.withValues(alpha: 0.15),
          highlightColor: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded, color: _C.orange, size: 20),
              const SizedBox(width: 10),
              Text(
                'Sudah punya akun? ',
                style: _font(13.5, FontWeight.w500, _C.textMuted),
              ),
              Text(
                'Masuk',
                style: _font(13.5, FontWeight.w800, const Color(0xFFE08600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field pendaftaran ────────────────────────────────────────
class _RegField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  final bool enabled;
  final bool obscure;

  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onToggleObscure;

  const _RegField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.onToggleObscure,
  });

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _font(13, FontWeight.w700, _C.navy)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          validator: validator,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: _C.blue,
          style: _font(14.5, FontWeight.w500, _C.navy),
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          decoration: InputDecoration(
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
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    tooltip:
                        obscure ? 'Tampilkan password' : 'Sembunyikan password',
                    onPressed: enabled ? onToggleObscure : null,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _C.textMuted,
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: _border(_C.border, 1.2),
            enabledBorder: _border(_C.border, 1.2),
            disabledBorder: _border(_C.border, 1.2),
            focusedBorder: _border(_C.blue, 1.6),
            errorBorder: _border(_C.danger, 1.2),
            focusedErrorBorder: _border(_C.danger, 1.6),
            errorStyle: _font(11, FontWeight.w500, _C.danger),
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Indikator kekuatan password ──────────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;

  const _PasswordStrength({required this.password});

  // 0 = kosong, 1 = lemah, 2 = cukup, 3 = kuat
  int get _level {
    if (password.isEmpty) return 0;
    if (password.length < 8) return 1;

    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    return score >= 3 ? 3 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;

    final color = switch (level) {
      1 => _C.danger,
      2 => _C.orange,
      3 => const Color(0xFF2EAD6B),
      _ => _C.border,
    };

    final text = switch (level) {
      1 => 'Lemah',
      2 => 'Cukup',
      3 => 'Kuat',
      _ => '',
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: level == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Row(
                children: [
                  for (var i = 1; i <= 3; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= level ? color : _C.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 6),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: _font(11.5, FontWeight.w700, color),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Tombol gradasi ───────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return Container(
      width: double.infinity,
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
                  ? const [_C.blueDeep, _C.blueDeep]
                  : const [Color(0xFF2386E8), _C.blueDeep],
            ),
          ),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Center(
              child: isLoading
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
                        if (icon != null) ...[
                          Icon(
                            icon,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: _font(
                            15,
                            FontWeight.w700,
                            Colors.white,
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
}

// ── Pesan error ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: _C.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _C.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _C.danger,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _font(
                12.5,
                FontWeight.w500,
                _C.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog sukses: tema terang & biru ─────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String namaUser;

  const _SuccessDialog({
    required this.namaUser,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF42A5F5),
                      _C.blueDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.blue.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Akun Berhasil Dibuat!',
                textAlign: TextAlign.center,
                style: _font(
                  20,
                  FontWeight.w800,
                  _C.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Selamat datang, $namaUser!\n'
                'Akun kamu sudah siap digunakan untuk '
                'menjelajahi keindahan Nusantara.',
                textAlign: TextAlign.center,
                style: _font(
                  13,
                  FontWeight.w500,
                  _C.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              _GradientButton(
                label: 'Mulai Menjelajah',
                icon: Icons.explore_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
