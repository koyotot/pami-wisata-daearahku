import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showLogin(WidgetTester tester, AuthSession session,
      Future<String?> Function() googleToken) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: UserLoginScreen(
        session: session,
        googleToken: googleToken,
        firebaseSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk dengan Google'));
  }

  AuthSession sessionFor(
          Future<http.Response> Function(http.Request) handler) =>
      AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: MemoryStore(),
        client: MockClient(handler),
      );

  for (final (code, message) in [
    (GoogleSignInExceptionCode.canceled, null),
    (
      GoogleSignInExceptionCode.clientConfigurationError,
      'Konfigurasi Google Sign-In belum valid.'
    ),
  ]) {
    testWidgets('Google $code does not exchange a token', (tester) async {
      var requests = 0;
      final session = sessionFor((_) async {
        requests++;
        return http.Response('{}', 500);
      });
      await showLogin(tester, session, () async {
        throw GoogleSignInException(code: code);
      });
      await tester.tap(find.text('Masuk dengan Google'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      if (message != null) expect(find.text(message), findsOneWidget);
      expect(find.text('Tidak dapat masuk dengan Google.'), findsNothing);
    });
  }

  testWidgets('missing Firebase token shows error without exchange',
      (tester) async {
    var requests = 0;
    final session = sessionFor((_) async {
      requests++;
      return http.Response('{}', 500);
    });
    await showLogin(tester, session, () async => null);
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();
    expect(find.text('Identitas Google tidak tersedia.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('double tap is guarded and logout invalidates pending provider',
      (tester) async {
    final gate = Completer<String?>();
    var calls = 0;
    var requests = 0;
    final session = sessionFor((_) async {
      requests++;
      return http.Response('{}', 500);
    });
    await showLogin(tester, session, () {
      calls++;
      return gate.future;
    });
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    await tester.tap(find.text('Masuk dengan Google'));
    await session.logout();
    gate.complete('late-token');
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(requests, 0);
    expect(session.authenticated.value, isFalse);
  });
}
