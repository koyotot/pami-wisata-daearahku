import 'auth_presentation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../services/auth_session.dart';
import 'verify_reset_otp_screen.dart';

String recoveryError(ApiException e) {
  if (e.code == 'timeout') return 'Koneksi habis waktu. Silakan coba lagi.';
  if (e.code == 'network') {
    return 'Tidak dapat terhubung. Periksa koneksi internet Anda.';
  }
  if (e.status == 429) {
    return 'Terlalu banyak permintaan. Tunggu sebentar dan coba lagi.';
  }
  return 'Permintaan belum dapat diproses. Silakan coba lagi.';
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen(
      {super.key, required this.session, this.initialEmail = ''});
  final AuthSession session;
  final String initialEmail;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Masukkan email yang valid.');
      return;
    }
    final generation = widget.session.sessionGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.session.publicEnvelope(
          'POST', 'auth/forgot-password',
          body: {'email': email});
      if (!mounted ||
          !widget.session.isCurrentGeneration(generation) ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyResetOtpScreen(
              session: widget.session,
              email: email,
              resendAfterSeconds: response['data'] is Map &&
                      response['data']['resend_after_seconds'] is int
                  ? response['data']['resend_after_seconds'] as int
                  : 60)));
    } on ApiException catch (e) {
      if (mounted && widget.session.isCurrentGeneration(generation)) {
        setState(() => _error =
            e.status == 422 ? 'Masukkan email yang valid.' : recoveryError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScenicShell(
      title: 'Pulihkan akun',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AuthBackLink(
            label: 'Kembali ke Login',
            onPressed: _loading ? null : () => Navigator.of(context).pop()),
        const SizedBox(height: 12),
        const AuthHeading(
            title: 'Lupa password?',
            description:
                'Masukkan email yang terdaftar untuk melanjutkan proses pemulihan akun.'),
        TextField(
            controller: _email,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'nama@email.com',
                prefixIcon: const Icon(PhosphorIconsRegular.envelope),
                errorText: _error)),
        const SizedBox(height: 24),
        AuthPrimaryButton(
            label: 'Kirim kode OTP', loading: _loading, onPressed: _submit),
      ]));
}
