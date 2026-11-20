import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth_session.dart';
import '../../theme/app_colors.dart';
import '../auth/forgot_password_screen.dart';
import '../auth/user_login_screen.dart';

Future<void> changeProfilePassword(
    BuildContext context, AuthSession session) async {
  final route = ModalRoute.of(context);
  final user = await _account(context, session);
  if (!context.mounted || route?.isCurrent != true || user == null) return;
  if (!user.hasLocalPassword) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kata sandi akun Google dikelola melalui Google.')));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(
          session: session, initialEmail: user.email, fromProfile: true)));
}

Future<({String email, bool hasLocalPassword})?> _account(
    BuildContext context, AuthSession session) async {
  final generation = session.sessionGeneration;
  try {
    if (session.profile?.hasLocalPassword == null) await session.me();
    final user = session.profile;
    if (!session.isCurrentGeneration(generation) ||
        user == null ||
        user.hasLocalPassword == null) {
      throw const ApiException(
          'Metode verifikasi akun belum tersedia. Muat ulang Profil.');
    }
    return (email: user.email, hasLocalPassword: user.hasLocalPassword!);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}

Future<void> closeProfileAccount(
    BuildContext context, AuthSession session) async {
  final route = ModalRoute.of(context);
  final user = await _account(context, session);
  if (!context.mounted || route?.isCurrent != true || user == null) return;
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CloseAccountSheet(
          session: session, hasLocalPassword: user.hasLocalPassword));
}

class _CloseAccountSheet extends StatefulWidget {
  const _CloseAccountSheet(
      {required this.session, required this.hasLocalPassword});

  final AuthSession session;
  final bool hasLocalPassword;

  @override
  State<_CloseAccountSheet> createState() => _CloseAccountSheetState();
}

class _CloseAccountSheetState extends State<_CloseAccountSheet> {
  final _password = TextEditingController();
  late final int _generation;
  bool _busy = false;
  bool _needsStatus = false;
  bool _lastSuperadmin = false;
  String? _message;
  String? _passwordError;

  bool get _current =>
      mounted && widget.session.isCurrentGeneration(_generation);

  @override
  void initState() {
    super.initState();
    _generation = widget.session.sessionGeneration;
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<String?> _googleToken() async {
    final auth = firebase.FirebaseAuth.instance;
    await auth.signOut();
    try {
      if (!_current) return null;
      return await googleFirebaseToken(() => _current);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    } on firebase.FirebaseAuthException catch (e) {
      if (const ['web-context-cancelled', 'popup-closed-by-user', 'cancelled']
          .contains(e.code)) return null;
      rethrow;
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    if (_busy || !_current || _lastSuperadmin) return;
    if (!_needsStatus && widget.hasLocalPassword && _password.text.isEmpty) {
      setState(() => _passwordError = 'Masukkan kata sandi akun Anda.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _passwordError = null;
    });
    try {
      if (_needsStatus) {
        await _checkStatus();
        return;
      }
      final proof = widget.hasLocalPassword
          ? {'password': _password.text}
          : {'id_token': await _googleToken()};
      if (!_current || proof.values.single == null) return;
      try {
        final data =
            await widget.session.request('POST', 'profile/close', body: proof);
        if (!_current) return;
        if (data['message'] is! String) {
          throw const ApiException(
              'Respons layanan tidak valid.', null, 'invalid_response');
        }
        await _finish('Akun berhasil ditutup.');
      } on ApiException catch (e) {
        if (!_current) return;
        if (e.outcomeUnknown) {
          _password.clear();
          _needsStatus = true;
          await _checkStatus();
        } else if (widget.hasLocalPassword &&
            e.code == 'reauthentication_failed') {
          setState(() =>
              _passwordError = 'Kata sandi salah. Periksa dan coba lagi.');
        } else {
          setState(() {
            _lastSuperadmin = e.code == 'last_active_superadmin';
            _message = e.message;
          });
        }
      }
    } catch (_) {
      if (_current) {
        setState(
            () => _message = 'Verifikasi belum dapat diselesaikan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.session.me();
      if (_current) {
        setState(() {
          _needsStatus = false;
          _message = 'Sesi masih aktif. Penutupan akun belum dapat dipastikan.';
        });
      }
    } on ApiException catch (e) {
      if (e.status == 401) {
        const message =
            'Sesi berakhir. Status penutupan akun belum dapat dipastikan. Silakan masuk kembali.';
        if (_current) {
          await _finish(message);
        } else if (navigator.mounted &&
            !widget.session.authenticated.value &&
            messenger.mounted) {
          messenger.showSnackBar(const SnackBar(content: Text(message)));
        }
      } else if (_current) {
        setState(
            () => _message = 'Status penutupan akun belum dapat diperiksa.');
      }
    }
  }

  Future<void> _finish(String message) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = widget.session;
    final clearing = session.clear();
    final clearedGeneration = session.sessionGeneration;
    await clearing;
    if (!navigator.mounted || !session.isCurrentGeneration(clearedGeneration))
      return;
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => UserLoginScreen(session: session)),
        (_) => false);
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.sheetPadding,
              AppSpacing.sheetPadding,
              AppSpacing.sheetPadding,
              AppSpacing.sheetPadding +
                  MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tutup akun',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),
              const Text(
                  'Akun akan ditutup dan Anda akan keluar. Anda tidak dapat masuk kembali dengan akun ini.'),
              const SizedBox(height: AppSpacing.md),
              if (widget.hasLocalPassword && !_needsStatus && !_lastSuperadmin)
                TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) {
                      if (_passwordError != null)
                        setState(() => _passwordError = null);
                    },
                    decoration: InputDecoration(
                        labelText: 'Kata sandi', errorText: _passwordError)),
              if (!widget.hasLocalPassword && !_needsStatus)
                const Text('Verifikasi dengan akun Google yang terhubung.'),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                    liveRegion: true,
                    child: Text(_message!,
                        style: const TextStyle(color: AppColors.danger))),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    minimumSize: const Size(48, 52)),
                onPressed: _busy || _lastSuperadmin ? null : _submit,
                child: Text(_busy
                    ? 'Memproses…'
                    : _needsStatus
                        ? 'Periksa status'
                        : 'Tutup akun'),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ));
}
