import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/screens/user_login_screen.dart';
import 'package:wisata_daerahku/screens/user_register_screen.dart';
import 'package:wisata_daerahku/screens/verify_email_otp_screen.dart';
import 'package:wisata_daerahku/screens/forgot_password_screen.dart';
import 'package:wisata_daerahku/screens/verify_reset_otp_screen.dart';
import 'package:wisata_daerahku/screens/reset_password_screen.dart';
import 'auth_views_test.dart' show sessionFor;
import 'auth_session_test.dart' show ok;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'all six auth screens support small viewport keyboard and enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    final session = sessionFor((_) async => ok({}));
    final screens = <Widget>[
      UserLoginScreen(session: session),
      UserRegisterScreen(session: session),
      VerifyEmailOtpScreen(email: 'visual@example.test', session: session),
      ForgotPasswordScreen(session: session),
      VerifyResetOtpScreen(email: 'visual@example.test', session: session),
      ResetPasswordScreen(
          session: session,
          email: 'visual@example.test',
          ticket: 'test',
          expiresInSeconds: 300),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: screen.runtimeType.toString());
      final fields = find.byType(EditableText);
      expect(fields, findsWidgets);
      await tester.ensureVisible(fields.last);
      await tester.pumpAndSettle();
      expect(tester.getRect(fields.last).bottom, lessThanOrEqualTo(380),
          reason: screen.runtimeType.toString());
      await tester.pumpWidget(const SizedBox());
    }
  });
}
