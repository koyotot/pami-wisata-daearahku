import 'auth_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../services/auth_session.dart';
import 'user_login_screen.dart';
import '../shared/session_destination.dart';

class VerifyEmailOtpScreen extends StatefulWidget {
  const VerifyEmailOtpScreen(
      {super.key,
      required this.email,
      this.resendAfterSeconds = 0,
      this.session});
  final String email;
  final int resendAfterSeconds;
  final AuthSession? session;
  @override
  State<VerifyEmailOtpScreen> createState() => _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends State<VerifyEmailOtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  DateTime? _until;
  bool _busy = false;
  String? _message;
  bool _error = false;
  late final int _generation;
  int get _remaining => _until == null
      ? 0
      : (_until!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 86400);
  @override
  void initState() {
    super.initState();
    _generation = (widget.session ?? AuthSession.instance).sessionGeneration;
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

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await (widget.session ?? AuthSession.instance).verifyEmailOtp(
          widget.email, _code.text,
          expectedGeneration: _generation);
      if (!mounted ||
          !(widget.session ?? AuthSession.instance)
              .isCurrentGeneration(_generation)) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => sessionDestination(session: widget.session)),
          (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Email terverifikasi. Selamat datang!',
              style: AuthTheme.snackBarTextStyle)));
    } on ApiException catch (e) {
      if (mounted) {
        final session = widget.session ?? AuthSession.instance;
        if ((e.code == 'verification_login_required' || e.status == 401) &&
            !session.authenticated.value &&
            !session.authenticating &&
            session.role == null) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const UserLoginScreen()),
              (_) => false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  e.code == 'verification_login_required'
                      ? e.message
                      : 'Sesi tidak tersedia. Silakan masuk kembali.',
                  style: AuthTheme.snackBarTextStyle)));
          return;
        }
        setState(() {
          _error = true;
          _message = e.status == 422
              ? 'Kode tidak valid atau tidak dapat digunakan. Silakan coba lagi.'
              : e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _remaining > 0) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await (widget.session ?? AuthSession.instance)
          .resendEmailOtp(widget.email);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _countdown(60);
        _error = false;
        _message =
            'Jika akun memenuhi syarat, kode akan dikirim. Periksa email Anda.';
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (e.status == 429) {
            _countdown((e.context?['retry_after'] as int?) ?? 60);
          }
          _error = true;
          _message = e.message;
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
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                        PhosphorIconsRegular.envelopeSimpleOpen,
                                        size: 48,
                                        color: Color(0xFF1976D2)),
                                    const SizedBox(height: 20),
                                    const Text('Verifikasi email',
                                        style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Masukkan 6 digit kode yang dikirim ke $masked.'),
                                    const SizedBox(height: 24),
                                    AuthOtpInput(
                                      controller: _code,
                                      enabled: !_busy,
                                      hasError: _error && _message != null,
                                      onChanged: (_) => setState(() {
                                        _message = null;
                                        _error = false;
                                      }),
                                    ),
                                    if (_message != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(_message!,
                                              style: TextStyle(
                                                  color: _error
                                                      ? Colors.red.shade800
                                                      : Colors.blue.shade800))),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                        onPressed:
                                            !_busy && _code.text.length == 6
                                                ? _verify
                                                : null,
                                        style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF1976D2),
                                            minimumSize:
                                                const Size.fromHeight(50)),
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
                                        onPressed: !_busy && _remaining == 0
                                            ? _resend
                                            : null,
                                        child: Text(_remaining > 0
                                            ? 'Kirim ulang kode ($_remaining dtk)'
                                            : 'Kirim ulang kode')),
                                  ]))))))),
    ));
  }
}
