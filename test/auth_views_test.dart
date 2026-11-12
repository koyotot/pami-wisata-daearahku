import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/screens/auth/user_register_screen.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/screens/auth/verify_email_otp_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore, ok, tokens, user;

AuthSession sessionFor(Future<http.Response> Function(http.Request) handler) =>
    AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: MemoryStore(),
        client: MockClient(handler));

Finder field(String hint) => find
    .byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'OTP accepts six numeric digits, rejects invalid code and guards submission',
      (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    final session = sessionFor((request) async {
      calls++;
      expect(jsonDecode(request.body),
          {'email': 'user@example.test', 'otp': '012345'});
      await gate.future;
      return http.Response(jsonEncode({'message': 'invalid'}), 422);
    });
    await tester.pumpWidget(MaterialApp(
        home: VerifyEmailOtpScreen(
            email: 'user@example.test', session: session)));
    final input = find.byType(TextField);
    final textField = tester.widget<TextField>(input);
    expect(textField.keyboardType, TextInputType.number);
    expect(textField.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(input, '012345');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Kode tidak valid'), findsOneWidget);
  });

  testWidgets('resend starts cooldown and clears entered code', (tester) async {
    var calls = 0;
    final session = sessionFor((request) async {
      calls++;
      expect(request.url.path, endsWith('/resend-otp'));
      return ok({'message': 'ok'});
    });
    await tester.pumpWidget(MaterialApp(
        home: VerifyEmailOtpScreen(
            email: 'user@example.test', session: session)));
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.textContaining('Kirim ulang kode (60 dtk)'), findsOneWidget);
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });

  testWidgets('old OTP screen cannot submit into a newer registration',
      (tester) async {
    var otpCalls = 0;
    final session = sessionFor((request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) otpCalls++;
      return ok({...user('u'), 'email_verified_at': null});
    });
    await session.register(
        'User', 'user@example.test', 'password123', 'password123');
    await tester.pumpWidget(MaterialApp(
        home: VerifyEmailOtpScreen(
            email: 'user@example.test', session: session)));
    await session.clear();
    await session.register(
        'User', 'user@example.test', 'password123', 'password123');
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();
    expect(otpCalls, 0);
    expect(find.byType(VerifyEmailOtpScreen), findsOneWidget);
    expect(session.authenticated.value, isFalse);
  });

  testWidgets('revoked pending tokens after valid OTP fall back to login',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var verified = false;
    final session = sessionFor((request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) {
        verified = true;
        return ok({'message': 'verified'});
      }
      if (verified) return http.Response('{}', 401);
      return ok({...user('u'), 'email_verified_at': null});
    });
    await session.register(
        'User', 'user@example.test', 'password123', 'password123');
    await tester.pumpWidget(MaterialApp(
        home: VerifyEmailOtpScreen(
            email: 'user@example.test', session: session)));
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.tap(find.text('Verifikasi'));
    await tester.pumpAndSettle();
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(VerifyEmailOtpScreen), findsNothing);
    expect(session.authenticated.value, isFalse);
  });

  testWidgets('OTP slots fit a narrow screen and countdown enables resend',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = sessionFor((request) async => ok({'message': 'ok'}));
    await tester.pumpWidget(MaterialApp(
        home: VerifyEmailOtpScreen(
            email: 'user@example.test',
            resendAfterSeconds: 1,
            session: session)));
    expect(
        find.byWidgetPredicate(
            (widget) => widget is ExcludeSemantics && widget.child is Text),
        findsNWidgets(6));
    expect(tester.takeException(), isNull);
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull);
  });

  testWidgets('register displays field errors returned by server',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = sessionFor((request) async => http.Response(
        jsonEncode({
          'message': 'Validasi gagal',
          'errors': {
            'email': ['Email sudah digunakan.'],
            'name': ['Nama ditolak.']
          }
        }),
        422));
    await tester
        .pumpWidget(MaterialApp(home: UserRegisterScreen(session: session)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Masukkan nama lengkap'), 'Nama');
    await tester.enterText(field('nama@email.com'), 'user@example.test');
    await tester.enterText(field('Minimal 8 karakter'), 'password123');
    await tester.enterText(field('Ulangi password'), 'password123');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Email sudah digunakan.'), findsOneWidget);
    expect(find.text('Nama ditolak.'), findsOneWidget);
    expect(find.text('Nomor Telepon'), findsNothing);
  });

  testWidgets('successful registration opens OTP screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = sessionFor((request) async {
      if (request.url.path.endsWith('/register')) {
        expect(jsonDecode(request.body), {
          'name': 'Nama',
          'email': 'user@example.test',
          'password': 'password123',
          'password_confirmation': 'password123'
        });
        return ok({
          ...tokens('u'),
          'verification_required': true,
          'resend_after_seconds': 60
        });
      }
      return ok({...user('u'), 'email_verified_at': null});
    });
    await tester
        .pumpWidget(MaterialApp(home: UserRegisterScreen(session: session)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Masukkan nama lengkap'), 'Nama');
    await tester.enterText(field('nama@email.com'), 'user@example.test');
    await tester.enterText(field('Minimal 8 karakter'), 'password123');
    await tester.enterText(field('Ulangi password'), 'password123');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailOtpScreen), findsOneWidget);
  });
}
