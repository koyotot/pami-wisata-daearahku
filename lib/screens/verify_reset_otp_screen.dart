import 'auth_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_session.dart';
import 'forgot_password_screen.dart';
import 'reset_password_screen.dart';

class VerifyResetOtpScreen extends StatefulWidget {
  const VerifyResetOtpScreen(
      {super.key,
      required this.session,
      required this.email,
      this.resendAfterSeconds = 60});
  final AuthSession session;
  final String email;
  final int resendAfterSeconds;
  @override
  State<VerifyResetOtpScreen> createState() => _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState extends State<VerifyResetOtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  DateTime? _until;
  bool _busy = false;
  String? _message;
  bool _error = false;
  int get _remaining => _until == null
      ? 0
      : (_until!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 86400);
  @override
  void initState() {
    super.initState();
    _countdown(widget.resendAfterSeconds);
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    _until = DateTime.now().add(Duration(seconds: seconds));
    if (seconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {});
        if (_remaining == 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  bool _current(int generation) =>
      mounted &&
      widget.session.isCurrentGeneration(generation) &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    final generation = widget.session.sessionGeneration;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await widget.session.publicEnvelope(
          'POST', 'auth/password-reset/verify-otp',
          body: {'email': widget.email, 'otp': _code.text});
      if (!mounted || !_current(generation)) return;
      final data = response['data'];
      final ticket = data is Map ? data['reset_ticket'] : null;
      final expiry = data is Map ? data['expires_in_seconds'] : null;
      if (ticket is! String ||
          ticket.trim().isEmpty ||
          expiry is! int ||
          expiry <= 0) {
        throw const ApiException('Respons layanan tidak valid.');
      }
      _code.clear();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
              session: widget.session,
              email: widget.email,
              ticket: ticket,
              expiresInSeconds: expiry)));
    } on ApiException catch (e) {
      if (_current(generation)) {
        setState(() {
          _error = true;
          _message = e.status == 422
              ? 'Kode tidak valid, kedaluwarsa, atau sudah digunakan. Silakan coba lagi.'
              : recoveryError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _remaining > 0) return;
    final generation = widget.session.sessionGeneration;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.session.publicEnvelope(
          'POST', 'auth/password-reset/resend-otp',
          body: {'email': widget.email});
      if (!mounted || !_current(generation)) return;
      _code.clear();
      setState(() {
        _countdown(60);
        _error = false;
        _message =
            'Jika alamat email memenuhi syarat, kode verifikasi akan dikirim.';
      });
    } on ApiException catch (e) {
      if (_current(generation)) {
        setState(() {
          if (e.status == 429) _countdown(60);
          _error = true;
          _message = recoveryError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.email.split('@');
    final masked = parts.length == 2 && parts[0].isNotEmpty
        ? '${parts[0][0]}***@${parts[1]}'
        : 'email Anda';
    return AuthTheme(
        child: Scaffold(
            backgroundColor: const Color(0xFF1976D2),
            appBar: AppBar(title: const Text('Verifikasi reset password')),
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
                                          const Text('Kode reset password',
                                              style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Jika alamat email memenuhi syarat, kode verifikasi akan dikirim ke $masked. Masukkan 6 digit kode.'),
                                          const SizedBox(height: 24),
                                          AuthOtpInput(
                                            controller: _code,
                                            enabled: !_busy,
                                            hasError:
                                                _error && _message != null,
                                            onChanged: (_) => setState(() {
                                              _message = null;
                                              _error = false;
                                            }),
                                          ),
                                          if (_message != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Text(_message!,
                                                    style: TextStyle(
                                                        color: _error
                                                            ? Colors
                                                                .red.shade800
                                                            : Colors.blue
                                                                .shade800))),
                                          const SizedBox(height: 20),
                                          FilledButton(
                                              onPressed: !_busy &&
                                                      _code.text.length == 6
                                                  ? _verify
                                                  : null,
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
                                                  : const Text('Verifikasi')),
                                          const SizedBox(height: 12),
                                          TextButton(
                                              onPressed:
                                                  !_busy && _remaining == 0
                                                      ? _resend
                                                      : null,
                                              child: Text(_remaining > 0
                                                  ? 'Kirim ulang kode ($_remaining dtk)'
                                                  : 'Kirim ulang kode')),
                                          TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => Navigator.of(context)
                                                      .pop(),
                                              child: const Text('Ubah email')),
                                        ])))))))));
  }
}
