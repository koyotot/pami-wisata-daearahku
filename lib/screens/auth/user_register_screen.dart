import 'auth_presentation.dart';
// ============================================================
// lib/screens/user_register_screen.dart
// Package: google_fonts, firebase_auth
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_session.dart';
import '../shared/session_destination.dart';

// ── Palet: sama dengan home dan login ─────────────────────────
class _C {
  static const blue = Color(0xFF1976D2);
  static const navy = Color(0xFF102D59);
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
  const UserRegisterScreen({super.key, this.session});
  final AuthSession? session;

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _konfirmasiCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureKonfirmasi = true;
  bool _isLoading = false;
  String? _errorMsg;
  Map<String, String> _fieldErrors = {};

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
    _passwordCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  // ── Pendaftaran Firebase ───────────────────────────────────
  Future<void> _register() async {
    if (_isLoading) return;

    setState(() {
      _errorMsg = null;
      _fieldErrors = {};
    });

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final nama = _namaCtrl.text.trim();
      await (widget.session ?? AuthSession.instance).register(nama,
          _emailCtrl.text.trim(), _passwordCtrl.text, _konfirmasiCtrl.text);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => sessionDestination(session: widget.session)),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = Map.of(e.fieldErrors);
        _errorMsg = _fieldErrors.keys.any((key) => !{
                  'name',
                  'email',
                  'password',
                  'password_confirmation'
                }.contains(key))
            ? e.message
            : (_fieldErrors.isEmpty ? e.message : null);
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
  Widget build(BuildContext context) => AuthScenicShell(
      title: 'Mulai petualangan!',
      child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
              position: _slideAnim,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthHeading(
                        title: 'Buat akun baru',
                        description:
                            'Mulai petualanganmu dan jelajahi Nusantara.'),
                    _buildForm(),
                  ]))));

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pesan error (animasi halus)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              child: _errorMsg == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _ErrorBanner(message: _errorMsg!),
                    ),
            ),

            // ── Bagian 1 ──
            _sectionLabel('Informasi pribadi'),
            const SizedBox(height: 16),
            _RegField(
              controller: _namaCtrl,
              label: 'Nama lengkap',
              hint: 'Masukkan nama lengkap',
              icon: PhosphorIconsRegular.userCircle,
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              errorText: _fieldErrors['name'],
              onChanged: (_) => setState(() => _fieldErrors.remove('name')),
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
              icon: PhosphorIconsRegular.envelope,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              errorText: _fieldErrors['email'],
              onChanged: (_) => setState(() => _fieldErrors.remove('email')),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Email wajib diisi';
                }

                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return 'Format email tidak valid';
                }

                return null;
              },
            ),
            const SizedBox(height: 28),

            // ── Bagian 2 ──
            _sectionLabel('Keamanan akun'),
            const SizedBox(height: 16),
            _RegField(
              controller: _passwordCtrl,
              label: 'Password',
              hint: 'Minimal 8 karakter',
              icon: PhosphorIconsRegular.lockKey,
              enabled: !_isLoading,
              obscure: _obscurePass,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _fieldErrors['password'],
              onChanged: (_) => setState(() => _fieldErrors.remove('password')),
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
            const SizedBox(height: 16),
            _RegField(
              controller: _konfirmasiCtrl,
              label: 'Konfirmasi password',
              hint: 'Ulangi password',
              icon: PhosphorIconsRegular.lockKey,
              enabled: !_isLoading,
              obscure: _obscureKonfirmasi,
              textInputAction: TextInputAction.done,
              errorText: _fieldErrors['password_confirmation'],
              onChanged: (_) =>
                  setState(() => _fieldErrors.remove('password_confirmation')),
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

            _buildLoginLinkButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: _C.border, height: 24),
        Text(title, style: _font(14, FontWeight.w800, _C.navy)),
      ]);

  Widget _buildRegisterButton() => AuthPrimaryButton(
      label: 'Daftar', loading: _isLoading, onPressed: _register);

  Widget _buildLoginLinkButton() => TextButton(
      onPressed: _isLoading ? null : () => Navigator.pop(context),
      child: Text.rich(TextSpan(
          text: 'Sudah punya akun? ',
          style: _font(13.5, FontWeight.w500, _C.textMuted),
          children: [
            TextSpan(
                text: 'Masuk', style: _font(13.5, FontWeight.w800, _C.blue))
          ])));
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
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onToggleObscure;
  final String? errorText;

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
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.onToggleObscure,
    this.errorText,
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
            errorText: errorText,
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
                          ? PhosphorIconsRegular.eye
                          : PhosphorIconsRegular.eyeSlash,
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
            PhosphorIconsRegular.warningCircle,
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
