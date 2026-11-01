import 'auth_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_session.dart';
import 'forgot_password_screen.dart';
import 'user_login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen(
      {super.key,
      required this.session,
      required this.email,
      required this.ticket,
      required this.expiresInSeconds});
  final AuthSession session;
  final String email;
  final String ticket;
  final int expiresInSeconds;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final DateTime _until;
  Timer? _timer;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String? _passwordError;
  String? _confirmationError;
  String? _message;
  int get _remaining =>
      (_until.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 86400);
  @override
  void initState() {
    super.initState();
    _until = DateTime.now().add(Duration(seconds: widget.expiresInSeconds));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool _current(int generation) =>
      mounted &&
      widget.session.isCurrentGeneration(generation) &&
      ModalRoute.of(context)?.isCurrent == true;
  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _passwordError =
          _password.text.length < 8 ? 'Password minimal 8 karakter.' : null;
      _confirmationError = _confirmation.text != _password.text
          ? 'Konfirmasi password tidak sama.'
          : null;
      _message = null;
    });
    if (_passwordError != null || _confirmationError != null) return;
    final generation = widget.session.sessionGeneration;
    setState(() => _busy = true);
    try {
      await widget.session.publicEnvelope('POST', 'auth/reset-password', body: {
        'email': widget.email,
        'reset_ticket': widget.ticket,
        'password': _password.text,
        'password_confirmation': _confirmation.text
      });
      if (!mounted || !_current(generation)) return;
      _password.clear();
      _confirmation.clear();
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => UserLoginScreen(session: widget.session)),
          (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password berhasil diubah. Silakan masuk.',
              style: AuthTheme.snackBarTextStyle)));
    } on ApiException catch (e) {
      if (!mounted || !_current(generation)) return;
      if (e.status == 422 && e.fieldErrors.containsKey('reset_ticket')) {
        _password.clear();
        _confirmation.clear();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Kode reset tidak berlaku atau kedaluwarsa. Minta kode OTP baru.',
                style: AuthTheme.snackBarTextStyle)));
      } else {
        setState(() {
          _passwordError = e.fieldErrors['password'];
          _confirmationError = e.fieldErrors['password_confirmation'];
          if (_passwordError == null && _confirmationError == null) {
            _message = e.outcomeUnknown
                ? 'Hasil perubahan belum diketahui. Coba masuk dengan password baru atau minta kode baru.'
                : recoveryError(e);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return AuthTheme(
        child: Scaffold(
            backgroundColor: const Color(0xFF1976D2),
            appBar: AppBar(title: const Text('Password baru')),
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
                                          const Icon(Icons.lock_reset,
                                              size: 48,
                                              color: Color(0xFF1976D2)),
                                          const SizedBox(height: 20),
                                          const Text('Buat password baru',
                                              style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'Gunakan minimal 8 karakter.'),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Sisa waktu kode reset: $minutes:$seconds'),
                                          const SizedBox(height: 24),
                                          TextField(
                                              controller: _password,
                                              enabled: !_busy,
                                              obscureText: !_showPassword,
                                              autofillHints: const [
                                                AutofillHints.newPassword
                                              ],
                                              decoration: InputDecoration(
                                                  labelText: 'Password baru',
                                                  errorText: _passwordError,
                                                  suffixIcon: IconButton(
                                                      tooltip: _showPassword
                                                          ? 'Sembunyikan password'
                                                          : 'Tampilkan password',
                                                      onPressed: () => setState(
                                                          () => _showPassword =
                                                              !_showPassword),
                                                      icon: Icon(_showPassword
                                                          ? Icons.visibility_off
                                                          : Icons
                                                              .visibility)))),
                                          const SizedBox(height: 16),
                                          TextField(
                                              controller: _confirmation,
                                              enabled: !_busy,
                                              obscureText: !_showConfirmation,
                                              autofillHints: const [
                                                AutofillHints.newPassword
                                              ],
                                              onSubmitted: (_) => _submit(),
                                              decoration: InputDecoration(
                                                  labelText:
                                                      'Konfirmasi password',
                                                  errorText: _confirmationError,
                                                  suffixIcon: IconButton(
                                                      tooltip: _showConfirmation
                                                          ? 'Sembunyikan konfirmasi password'
                                                          : 'Tampilkan konfirmasi password',
                                                      onPressed: () => setState(
                                                          () => _showConfirmation =
                                                              !_showConfirmation),
                                                      icon: Icon(_showConfirmation
                                                          ? Icons.visibility_off
                                                          : Icons
                                                              .visibility)))),
                                          if (_message != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Text(_message!,
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error))),
                                          const SizedBox(height: 20),
                                          FilledButton(
                                              onPressed: _busy ? null : _submit,
                                              style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size.fromHeight(
                                                          50)),
                                              child: _busy
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))
                                                  : const Text(
                                                      'Simpan password')),
                                        ])))))))));
  }
}
