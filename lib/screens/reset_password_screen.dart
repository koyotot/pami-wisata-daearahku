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
    if (_busy || _remaining == 0) return;
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
              builder: (_) =>
                  ResetPasswordSuccessScreen(session: widget.session)),
          (_) => false);
    } on ApiException catch (e) {
      if (!mounted || !_current(generation)) return;
      if (e.status == 422 && e.fieldErrors.containsKey('reset_ticket')) {
        _password.clear();
        _confirmation.clear();
        _requestNewCode();
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

  void _requestNewCode() {
    _password.clear();
    _confirmation.clear();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(
              session: widget.session, initialEmail: widget.email)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return AuthScenicShell(
        title: 'Pulihkan akun',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AuthBackLink(
              label: 'Minta kode baru',
              onPressed: _busy ? null : _requestNewCode),
          const SizedBox(height: 12),
          const AuthHeading(
              title: 'Buat password baru',
              description:
                  'Kode OTP berhasil diverifikasi. Gunakan minimal 8 karakter untuk password baru.'),
          Text(
              _remaining > 0
                  ? 'Sisa waktu kode reset: $minutes:$seconds'
                  : 'Kode reset kedaluwarsa. Minta kode OTP baru.',
              style: TextStyle(
                  color: _remaining > 0
                      ? const Color(0xFF536780)
                      : const Color(0xFFE5484D))),
          const SizedBox(height: 24),
          TextField(
              controller: _password,
              enabled: !_busy && _remaining > 0,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _passwordError = null),
              decoration: InputDecoration(
                  labelText: 'Password baru',
                  hintText: 'Minimal 8 karakter',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                      tooltip: _showPassword
                          ? 'Sembunyikan password'
                          : 'Tampilkan password',
                      onPressed: _busy
                          ? null
                          : () =>
                              setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined)))),
          const SizedBox(height: 20),
          TextField(
              controller: _confirmation,
              enabled: !_busy && _remaining > 0,
              obscureText: !_showConfirmation,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() => _confirmationError = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                  labelText: 'Konfirmasi password',
                  hintText: 'Ulangi password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  errorText: _confirmationError,
                  suffixIcon: IconButton(
                      tooltip: _showConfirmation
                          ? 'Sembunyikan konfirmasi password'
                          : 'Tampilkan konfirmasi password',
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _showConfirmation = !_showConfirmation),
                      icon: Icon(_showConfirmation
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined)))),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!,
                    style: const TextStyle(color: Color(0xFFE5484D)))),
          const SizedBox(height: 24),
          AuthPrimaryButton(
              label: 'Simpan password',
              loading: _busy,
              onPressed: _remaining > 0 ? _submit : null),
        ]));
  }
}

class ResetPasswordSuccessScreen extends StatelessWidget {
  const ResetPasswordSuccessScreen({super.key, required this.session});
  final AuthSession session;
  @override
  Widget build(BuildContext context) => AuthScenicShell(
      title: 'Pulihkan akun',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 20),
        const Center(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xFFE8F3FF), shape: BoxShape.circle),
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Icon(Icons.check_rounded,
                        size: 48, color: AuthTheme.blue)))),
        const SizedBox(height: 28),
        const AuthHeading(
            title: 'Password berhasil diubah!',
            description:
                'Password akunmu telah diperbarui. Silakan masuk kembali menggunakan password baru.'),
        AuthPrimaryButton(
            label: 'Kembali ke Login',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => UserLoginScreen(session: session)),
                (_) => false)),
      ]));
}
