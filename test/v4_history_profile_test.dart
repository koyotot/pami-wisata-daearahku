import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
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
    expect(find.byTooltip('Edit Profil'), findsOneWidget);
    expect(find.text('Bergabung sejak \u2014'), findsOneWidget);
    final card = find.byKey(const ValueKey('profileIdentityCard'));
    final labels = ['Pendaftaran', 'Dikunjungi', 'Ulasan'];
    final tops = labels.map((label) => tester
        .getTopLeft(find.descendant(of: card, matching: find.text(label)))
        .dy);
    expect(tops.toSet().length, 1);
    expect(find.byType(TimeBasedScenicBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile card scrolls then stops below the fixed title',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            padding: EdgeInsets.only(top: 24), disableAnimations: true),
        child: ProfilUserScreen(active: false),
      ),
    ));
    await tester.pumpAndSettle();
    final title = find.text('Profil Saya');
    final scenery = find.byType(TimeBasedScenicBackground);
    final card = find.byKey(const ValueKey('profileIdentityCard'));
    final titleBefore = tester.getRect(title);
    final sceneryBefore = tester.getRect(scenery);
    final cardBefore = tester.getRect(card);
    final menuBefore = tester.getTopLeft(find.text('Akun')).dy;
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(60);
    await tester.pumpAndSettle();
    expect(tester.getRect(card).top, cardBefore.top - 60);
    scrollable.position.jumpTo(180);
    await tester.pumpAndSettle();
    expect(tester.getRect(title), titleBefore);
    expect(tester.getRect(scenery), sceneryBefore);
    final boundary = tester.getRect(find.byType(CustomScrollView)).top;
    expect(tester.getRect(card).top, boundary);
    scrollable.position.jumpTo(260);
    await tester.pumpAndSettle();
    expect(tester.getRect(card).top, boundary);
    final menuClip = find
        .descendant(
            of: find.byType(SliverLayoutBuilder),
            matching: find.byType(ClipRect))
        .first;
    final clipper = tester.widget<ClipRect>(menuClip).clipper!;
    final clippedTop = tester.getTopLeft(menuClip).dy +
        clipper.getClip(tester.getSize(menuClip)).top;
    expect(clippedTop, 270);
    expect(tester.getTopLeft(find.text('Akun')).dy, menuBefore - 260);
    expect(tester.getRect(find.byType(CustomScrollView)).top,
        greaterThanOrEqualTo(titleBefore.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('join year uses email verification date', (tester) async {
    currentUser = User(
        id: 'u',
        namaLengkap: 'Ayu',
        email: 'ayu@example.test',
        noTelepon: '',
        password: '',
        createdAt: DateTime(2099),
        emailVerifiedAt: DateTime.utc(2024, 8, 12));
    await tester
        .pumpWidget(const MaterialApp(home: ProfilUserScreen(active: false)));
    await tester.pumpAndSettle();
    expect(find.text('Bergabung sejak 2024'), findsOneWidget);
    expect(find.textContaining('2099'), findsNothing);
  });

  testWidgets('logout stays above floating navigation at the end of scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: const ProfilUserScreen(active: false),
        bottomNavigationBar: FloatingBottomNav(index: 4, onSelected: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Keluar')).bottom,
        lessThan(tester.getRect(find.byType(FloatingBottomNav)).top));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari Akun?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history reserves floating navigation space at scroll end',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: const BuktiPendaftaranScreen(embedded: true, active: false),
        bottomNavigationBar: FloatingBottomNav(index: 1, onSelected: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    final safeArea = tester.widget<SliverSafeArea>(find.byType(SliverSafeArea));
    expect(safeArea.bottom, isTrue);
    final padding = tester.widget<SliverPadding>(find
        .descendant(
            of: find.byType(SliverSafeArea),
            matching: find.byType(SliverPadding))
        .first);
    expect(
        (padding.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(
            tester.getSize(find.byType(FloatingBottomNav)).height));
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
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent - 160);
    await tester.pumpAndSettle();
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
