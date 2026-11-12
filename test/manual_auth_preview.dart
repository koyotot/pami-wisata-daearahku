// Manual Android rendering harness: no Firebase initialization or live API calls.
// Long press the top-right corner to advance through the six production screens.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/screens/auth/user_register_screen.dart';
import 'package:wisata_daerahku/screens/auth/forgot_password_screen.dart';
import 'package:wisata_daerahku/screens/auth/verify_reset_otp_screen.dart';
import 'package:wisata_daerahku/screens/auth/reset_password_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

void main() => runApp(const Preview());

class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  int index = 0;
  final session = AuthSession(
      baseUrl: 'https://example.invalid/api/v1',
      client: MockClient((_) async => http.Response('{}', 503)));
  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      UserLoginScreen(session: session),
      UserRegisterScreen(session: session),
      ForgotPasswordScreen(session: session),
      VerifyResetOtpScreen(email: 'visual@example.test', session: session),
      ResetPasswordScreen(
          session: session,
          email: 'visual@example.test',
          ticket: 'rendering-only',
          expiresInSeconds: 3600),
      ResetPasswordSuccessScreen(session: session),
    ];
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Stack(children: [
          Positioned.fill(
              child: KeyedSubtree(key: ValueKey(index), child: screens[index])),
          Positioned(
              top: 25,
              right: 0,
              width: 50,
              height: 45,
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => index = (index + 1) % 6);
                  },
                  child: const SizedBox.expand())),
        ]));
  }
}
