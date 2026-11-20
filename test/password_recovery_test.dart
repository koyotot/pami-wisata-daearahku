import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/screens/auth/verify_reset_otp_screen.dart';
import 'package:wisata_daerahku/screens/shared/profile_account_actions.dart';
import 'package:wisata_daerahku/screens/auth/reset_password_screen.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore, ok, tokens, user;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  AuthSession session(Future<http.Response> Function(http.Request) handler,
          [MemoryStore? store]) =>
      AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store ?? MemoryStore(),
        client: MockClient(handler),
      );

  testWidgets('profile password confirms a locked email before sending OTP',
      (tester) async {
    var otpCalls = 0;
    final identity = {
      ...user('1'),
      'email': 'visitor@example.test',
      'has_local_password': true
    };
    final auth = session((request) async {
      if (request.url.path.endsWith('/login'))
        return ok({...tokens('1'), 'user': identity});
      if (request.url.path.endsWith('/me')) return ok(identity);
      otpCalls++;
      expectSync(jsonDecode(request.body), {'email': 'visitor@example.test'});
      return ok({'message': 'Accepted.'});
    });
    await auth.login('visitor@example.test', 'password');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => changeProfilePassword(context, auth),
                    child: const Text('Ubah Kata Sandi'))))));
    await tester.tap(find.text('Ubah Kata Sandi'));
    await tester.pumpAndSettle();
    final email = tester.widget<TextField>(find.byType(TextField));
    expect(email.controller!.text, 'visitor@example.test');
    expect(email.readOnly, isTrue);
    expect(otpCalls, 0);
    await tester.tap(find.text('Kembali ke Profil'));
    await tester.pumpAndSettle();
    expect(otpCalls, 0);
    expect(auth.authenticated.value, isTrue);
    await tester.tap(find.text('Ubah Kata Sandi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kirim kode OTP'));
    await tester.tap(find.text('Kirim kode OTP'));
    await tester.pumpAndSettle();
    expect(otpCalls, 1);
    expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
    expect(find.text('Ubah email'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'close keeps session on bad proof and checks status after an unknown result',
      (tester) async {
    var closeCalls = 0;
    final wrongProof = Completer<http.Response>();
    var statusReads = 0;
    var refreshes = 0;
    final identity = {...user('1'), 'has_local_password': true};
    final store = MemoryStore();
    final auth = session((request) async {
      if (request.url.path.endsWith('/login'))
        return ok({...tokens('1'), 'user': identity});
      if (request.url.path.endsWith('/me')) {
        statusReads++;
        return ok(identity);
      }
      if (request.url.path.endsWith('/refresh')) refreshes++;
      expect(request.url.path, '/api/v1/profile/close');
      expect(request.headers['authorization'], 'Bearer access-1');
      closeCalls++;
      expect(jsonDecode(request.body),
          {'password': closeCalls == 1 ? 'wrong' : 'correct'});
      if (closeCalls == 1) return wrongProof.future;
      if (closeCalls == 2) return http.Response('unreadable', 200);
      return ok({'message': 'Account closed.'});
    }, store);
    await auth.login('visitor@example.test', 'password');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => closeProfileAccount(context, auth),
                    child: const Text('Hapus Akun'))))));
    await tester.tap(find.text('Hapus Akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(closeCalls, 0);
    await tester.tap(find.text('Hapus Akun'));
    await tester.pumpAndSettle();
    final close = find.widgetWithText(FilledButton, 'Tutup akun');
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(close);
    await tester.pump();
    final pending = find.widgetWithText(FilledButton, 'Memproses…');
    expect(tester.widget<FilledButton>(pending).onPressed, isNull);
    await tester.tap(pending, warnIfMissed: false);
    expect(closeCalls, 1);
    wrongProof
        .complete(http.Response('{"code":"reauthentication_failed"}', 401));
    await tester.pumpAndSettle();
    expect(
        find.text('Kata sandi salah. Periksa dan coba lagi.'), findsOneWidget);
    expect(auth.authenticated.value, isTrue);
    expect(refreshes, 0);
    final initialReads = statusReads;
    await tester.enterText(find.byType(TextField), 'correct');
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(closeCalls, 2);
    expect(statusReads, initialReads + 1);
    expect(find.text('Akun berhasil ditutup.'), findsNothing);
    expect(
        find.text('Sesi masih aktif. Penutupan akun belum dapat dipastikan.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'correct');
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(closeCalls, 3);
    expect(auth.authenticated.value, isFalse);
    expect(store.value, isNull);
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.text('Hapus Akun'), findsNothing);
  });

  testWidgets(
      'verification sends leading-zero OTP once and fails closed on malformed ticket',
      (tester) async {
    final gate = Completer<http.Response>();
    var calls = 0;
    final auth = session((request) {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/password-reset/verify-otp');
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(jsonDecode(request.body),
          {'email': 'user@example.test', 'otp': '012345'});
      return gate.future;
    });
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(email: 'user@example.test', session: auth)));
    final input = find.byType(TextField);
    expect(tester.widget<TextField>(input).keyboardType, TextInputType.number);
    expect(tester.widget<TextField>(input).autofillHints,
        contains(AutofillHints.oneTimeCode));
    await tester.enterText(input, '012345');
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    gate.complete(http.Response(
        jsonEncode({
          'data': {'reset_ticket': '', 'expires_in_seconds': 300}
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'valid OTP opens reset; matching passwords submit exact body without persistence',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final calls = <String>[];
    final auth = session((request) async {
      calls.add(request.url.path);
      expect(request.headers.containsKey('authorization'), isFalse);
      if (request.url.path.endsWith('/verify-otp')) {
        expect(jsonDecode(request.body),
            {'email': 'user@example.test', 'otp': '012345'});
        return http.Response(
            jsonEncode({
              'data': {
                'reset_ticket': 'ticket-value',
                'expires_in_seconds': 300
              }
            }),
            200);
      }
      expect(request.url.path, '/api/v1/auth/reset-password');
      expect(jsonDecode(request.body), {
        'email': 'user@example.test',
        'reset_ticket': 'ticket-value',
        'password': 'Password123',
        'password_confirmation': 'Password123'
      });
      return http.Response(
          jsonEncode({
            'data': {'message': 'Password reset.'}
          }),
          200);
    }, store);
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(email: 'user@example.test', session: auth)));
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(store.value, isNull);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Password123');
    await tester.enterText(fields.at(1), 'different');
    await tester.ensureVisible(find.text('Simpan password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan password'));
    await tester.pump();
    expect(calls, hasLength(1));
    await tester.enterText(fields.at(1), 'Password123');
    await tester.tap(find.text('Simpan password'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(store.value, isNull);
    expect(auth.authenticated.value, isFalse);
    expect(find.byType(ResetPasswordSuccessScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.byType(VerifyResetOtpScreen), findsNothing);
    await tester.ensureVisible(find.text('Kembali ke Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembali ke Login'));
    await tester.pumpAndSettle();
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(ResetPasswordSuccessScreen), findsNothing);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resend clears stale input and starts cooldown', (tester) async {
    var calls = 0;
    final auth = session((request) async {
      calls++;
      expect(request.url.path, '/api/v1/auth/password-reset/resend-otp');
      expect(jsonDecode(request.body), {'email': 'user@example.test'});
      return http.Response(jsonEncode({'data': null}), 200);
    });
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(
            email: 'user@example.test', session: auth, resendAfterSeconds: 0)));
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    await tester.ensureVisible(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.textContaining('Kirim ulang kode ('), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late verify response after disposal cannot navigate',
      (tester) async {
    final gate = Completer<http.Response>();
    final auth = session((_) => gate.future);
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(email: 'user@example.test', session: auth)));
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('abandoned')));
    gate.complete(http.Response(
        jsonEncode({
          'data': {'reset_ticket': 'ticket-value', 'expires_in_seconds': 300}
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.text('abandoned'), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid OTP and resend throttle present retry feedback',
      (tester) async {
    final auth = session((request) async {
      if (request.url.path.endsWith('/verify-otp')) {
        return http.Response(
            jsonEncode({
              'code': 'invalid_reset_otp',
              'errors': {
                'otp': ['Invalid code']
              }
            }),
            422);
      }
      return http.Response(jsonEncode({'message': 'Too many requests'}), 429);
    });
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(
            email: 'user@example.test', session: auth, resendAfterSeconds: 0)));
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kode salah'), findsOneWidget);
    await tester.ensureVisible(find.text('Kirim ulang kode'));
    await tester.ensureVisible(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Terlalu banyak'), findsOneWidget);
    expect(find.textContaining('Kirim ulang kode ('), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'password validation preserves ticket; invalid ticket returns to request',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    final auth = session((request) async {
      calls++;
      expect(jsonDecode(request.body)['reset_ticket'], 'ticket-value');
      return http.Response(
          jsonEncode({
            'errors': calls == 1
                ? {
                    'password': ['Password ditolak server.']
                  }
                : {
                    'reset_ticket': ['Ticket expired']
                  }
          }),
          422);
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ResetPasswordScreen(
                                session: auth,
                                email: 'user@example.test',
                                ticket: 'ticket-value',
                                expiresInSeconds: 300))),
                    child: const Text('Request OTP'))))));
    await tester.tap(find.text('Request OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Password123');
    await tester.enterText(find.byType(TextField).at(1), 'Password123');
    await tester.ensureVisible(find.text('Simpan password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan password'));
    await tester.pumpAndSettle();
    expect(find.text('Periksa kata sandi.'), findsOneWidget);
    expect(find.text('Password ditolak server.'), findsNothing);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    await tester.tap(find.text('Simpan password'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Kode reset kedaluwarsa. Minta kode OTP baru.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Minta kode baru'));
    await tester.tap(find.text('Minta kode baru'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.text('Request OTP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('session generation change discards verify response',
      (tester) async {
    final gate = Completer<http.Response>();
    final auth = session((_) => gate.future);
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(email: 'user@example.test', session: auth)));
    await tester.enterText(find.byType(TextField), '012345');
    await tester.pump();
    await tester.ensureVisible(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pump();
    await auth.clear();
    gate.complete(http.Response(
        jsonEncode({
          'data': {'reset_ticket': 'ticket-value', 'expires_in_seconds': 300}
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.byType(VerifyResetOtpScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
