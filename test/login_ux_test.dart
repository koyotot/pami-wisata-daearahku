import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/screens/auth/forgot_password_screen.dart';
import 'package:wisata_daerahku/screens/auth/verify_reset_otp_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  AuthSession session() => AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: MemoryStore(),
        client: MockClient((_) async => http.Response('{}', 500)),
      );

  testWidgets('login actions, Google logo, and required fields',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: UserLoginScreen(session: session())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text('Selamat datang!'), findsOneWidget);
    expect(find.text('Lupa password?'), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsNothing);
    expect(
        find.descendant(
            of: find.byType(OutlinedButton), matching: find.byType(Image)),
        findsOneWidget);
    await tester.ensureVisible(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Email dan password tidak boleh kosong.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small viewport with keyboard and large text remains scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: UserLoginScreen(session: session()),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Masuk dengan Google')).bottom,
        lessThanOrEqualTo(380));
    expect(tester.takeException(), isNull);
  });
  testWidgets('forgot password navigates, validates, and requests reset',
      (tester) async {
    var requests = 0;
    final auth = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/forgot-password');
        expect(jsonDecode(request.body), {'email': 'user@example.test'});
        return http.Response(jsonEncode({'message': 'ok', 'data': null}), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: UserLoginScreen(session: auth)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'user@example.test');
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'user@example.test');
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.ensureVisible(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(requests, 0);
    await tester.enterText(find.byType(TextField), 'user@example.test');
    await tester.ensureVisible(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
  });

  testWidgets('forgot password allows retry after a network error',
      (tester) async {
    var requests = 0;
    final auth = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((_) async {
        requests++;
        if (requests == 1) throw http.ClientException('offline');
        return http.Response(jsonEncode({'data': null}), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: ForgotPasswordScreen(
          session: auth, initialEmail: 'user@example.test'),
    ));
    await tester.ensureVisible(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak dapat terhubung. Periksa koneksi internet Anda.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
  });
}
