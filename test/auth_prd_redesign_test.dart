import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/auth_presentation.dart';
import 'package:wisata_daerahku/screens/user_login_screen.dart';
import 'package:wisata_daerahku/screens/user_register_screen.dart';
import 'package:wisata_daerahku/screens/verify_reset_otp_screen.dart';
import 'package:wisata_daerahku/screens/reset_password_screen.dart';

import 'auth_views_test.dart' show sessionFor;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('register has grouped fields, independent eyes and nearby login',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = sessionFor((_) async => http.Response('{}', 500));
    await tester
        .pumpWidget(MaterialApp(home: UserLoginScreen(session: session)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.textContaining('Belum punya akun?', findRichText: true));
    await tester
        .tap(find.textContaining('Belum punya akun?', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(UserRegisterScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Kembali'), findsNothing);
    expect(find.text('Informasi pribadi'), findsOneWidget);
    expect(find.text('Keamanan akun'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Tampilkan password').first);
    await tester.tap(find.byTooltip('Tampilkan password').first);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isFalse);
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isTrue);
    await tester.ensureVisible(
        find.textContaining('Sudah punya akun?', findRichText: true));
    final cta = tester.getRect(find.text('Daftar'));
    final link = tester
        .getRect(find.textContaining('Sudah punya akun?', findRichText: true));
    expect(link.top - cta.bottom, inInclusiveRange(0, 90));
    await tester
        .tap(find.textContaining('Sudah punya akun?', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(UserRegisterScreen), findsNothing);
  });

  testWidgets(
      'OTP stays white, masks email, filters paste and honors Retry-After',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session =
        sessionFor((request) async => request.url.path.endsWith('/verify-otp')
            ? http.Response(
                jsonEncode({
                  'errors': {
                    'otp': ['Invalid']
                  }
                }),
                422)
            : http.Response('{}', 429, headers: {'retry-after': '120'}));
    await tester.pumpWidget(MaterialApp(
        home: VerifyResetOtpScreen(
            session: session,
            email: 'private@example.test',
            resendAfterSeconds: 0)));
    await tester.pumpAndSettle();
    expect(find.textContaining('private@example.test'), findsNothing);
    expect(find.textContaining('p***@example.test'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    final input = find.byType(TextField);
    await tester.enterText(input, '01a234567');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '012345');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.tap(find.text('Verifikasi kode'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsNothing);
    final slots = find.descendant(
        of: find.byType(AuthOtpInput),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null));
    expect(slots, findsNWidgets(6));
    for (final slot in tester.widgetList<Container>(slots)) {
      expect((slot.decoration as BoxDecoration).color, Colors.white);
    }
    await tester.ensureVisible(find.text('Kirim ulang kode'));
    await tester.tap(find.text('Kirim ulang kode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kirim ulang kode (120 dtk)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unknown reset outcome never shows success or loses ticket',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    final session = sessionFor((request) async {
      calls++;
      expect(jsonDecode(request.body)['reset_ticket'], 'test-ticket');
      throw http.ClientException('offline');
    });
    await tester.pumpWidget(MaterialApp(
        home: ResetPasswordScreen(
            session: session,
            email: 'user@example.test',
            ticket: 'test-ticket',
            expiresInSeconds: 300)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Password123');
    await tester.enterText(find.byType(TextField).at(1), 'Password123');
    await tester.ensureVisible(find.text('Simpan password'));
    await tester.tap(find.text('Simpan password'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(ResetPasswordSuccessScreen), findsNothing);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(
        find.textContaining('Hasil perubahan belum diketahui'), findsOneWidget);
    expect(session.authenticated.value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired ticket disables fields and recovers to editable email',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var requests = 0;
    final session = sessionFor((_) async {
      requests++;
      return http.Response('{}', 500);
    });
    await tester.pumpWidget(MaterialApp(
        home: ResetPasswordScreen(
            session: session,
            email: 'user@example.test',
            ticket: 'expired',
            expiresInSeconds: 0)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kode reset kedaluwarsa'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.text('Minta kode baru'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'user@example.test');
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'full-bleed header keeps foreground safe and scaled keyboard CTA reachable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    final session = sessionFor((_) async => http.Response('{}', 500));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: UserRegisterScreen(session: session)));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CustomScrollView)).top, 0);
    expect(tester.getRect(find.text('Wisata Daerahku')).top,
        greaterThanOrEqualTo(44));
    final sheet = tester
        .widget<Container>(find.byKey(const ValueKey('auth-white-sheet')));
    expect((sheet.decoration as BoxDecoration).color, Colors.white);
    expect(find.byType(Card), findsNothing);
    await tester.ensureVisible(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Daftar')).bottom, lessThanOrEqualTo(480));
    expect(tester.getRect(find.byType(CustomScrollView)).top, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
