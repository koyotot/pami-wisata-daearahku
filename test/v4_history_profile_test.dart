import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/screens/auth_presentation.dart';
import 'package:wisata_daerahku/screens/profil_user_screen.dart';
import 'package:wisata_daerahku/screens/bukti_pendaftaran_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => currentUser = null);

  testWidgets('profile shows real identity and never uses hydration year',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    currentUser = User(
        id: 'u',
        namaLengkap: 'Ayu Putri',
        email: 'ayu.putri.dengan.alamat.email.yang.panjang@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2099));
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                textScaler: TextScaler.linear(1.5), disableAnimations: true),
            child: ProfilUserScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Ayu Putri'), findsOneWidget);
    expect(find.text('AP'), findsOneWidget);
    expect(find.text('2099'), findsNothing);
    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.byType(TimeBasedScenicBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history uses the shared scenic header', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: BuktiPendaftaranScreen(active: false)));
    expect(find.byType(TimeBasedScenicBackground), findsOneWidget);
    expect(find.text('Riwayat Pendaftaran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'language settings explain unavailable feature without fake apply',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilUserScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bahasa'), 250);
    await tester.tap(find.text('Bahasa'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Aplikasi menggunakan Bahasa Indonesia. Pilihan bahasa lain belum tersedia.'),
        findsOneWidget);
    expect(find.text('Terapkan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'booking deep link never exposes ticket without active user session',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: BookingTicketScreen(bookingGuid: 'booking-1')));
    await tester.pumpAndSettle();
    expect(
        find.text('Sesi berubah. Silakan buka kembali tiket.'), findsOneWidget);
    expect(find.text('Lihat detail'), findsNothing);
  });
}
