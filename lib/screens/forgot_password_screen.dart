import 'auth_presentation.dart';
import 'package:flutter/material.dart';
import '../services/auth_session.dart';
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
      await widget.session.publicEnvelope('POST', 'auth/forgot-password',
          body: {'email': email});
      if (!mounted ||
          !widget.session.isCurrentGeneration(generation) ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              VerifyResetOtpScreen(session: widget.session, email: email)));
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
  Widget build(BuildContext context) => AuthTheme(
      child: Scaffold(
          backgroundColor: const Color(0xFF1976D2),
          appBar: AppBar(title: const Text('Lupa password?')),
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.mark_email_unread_outlined,
                                            size: 48,
                                            color: Color(0xFF1976D2)),
                                        const SizedBox(height: 20),
                                        const Text('Lupa password?',
                                            style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        const Text(
                                            'Masukkan email untuk meminta kode OTP 6 digit. Jika alamat email memenuhi syarat, kode verifikasi akan dikirim.'),
                                        const SizedBox(height: 24),
                                        TextField(
                                            controller: _email,
                                            enabled: !_loading,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.email
                                            ],
                                            onSubmitted: (_) => _submit(),
                                            decoration: InputDecoration(
                                                labelText: 'Email',
                                                errorText: _error)),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                            onPressed:
                                                _loading ? null : _submit,
                                            style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(50)),
                                            child: _loading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))
                                                : const Text('Kirim kode OTP')),
                                      ])))))))));
}
