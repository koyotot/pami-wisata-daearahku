import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/widgets/availability_calendar.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
import 'package:wisata_daerahku/widgets/international_phone_field.dart';
import 'package:wisata_daerahku/screens/user/main_navigation_screen.dart';
import 'package:wisata_daerahku/screens/auth/auth_presentation.dart';
import 'package:wisata_daerahku/screens/user/cari_wisata_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('root tabs retain explore state and Android back returns home',
      (tester) async {
    final session = AuthSession.instance;
    final previousRole = session.role;
    final previousReady = session.deviceSessionReady;
    final previousAuthenticated = session.authenticated.value;
    session.role = 0;
    session.deviceSessionReady = true;
    session.authenticated.value = true;
    addTearDown(() {
      session.role = previousRole;
      session.deviceSessionReady = previousReady;
      session.authenticated.value = previousAuthenticated;
    });
    await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    await tester.pump(const Duration(seconds: 1));
    final explore =
        tester.element(find.byType(CariWisataScreen, skipOffstage: false));
    await tester.tap(find.byTooltip('Jelajah'));
    await tester.pump();
    final exploreScenic = find.descendant(
        of: find.byType(CariWisataScreen, skipOffstage: false),
        matching: find.byType(TimeBasedScenicBackground));
    expect(exploreScenic, findsOneWidget);
    expect(
        tester.widget<TimeBasedScenicBackground>(exploreScenic).active, isTrue);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
    await tester.tap(find.byTooltip('Riwayat'));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(tester.element(find.byType(CariWisataScreen, skipOffstage: false)),
        same(explore));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
      'V4 components preserve calendar status and navigation on compact layouts',
      (tester) async {
    const capture = bool.fromEnvironment('V4_CAPTURE');
    await tester.runAsync(() async {
      final fontFile = capture && Platform.isWindows
          ? File('C:/Windows/Fonts/arial.ttf')
          : File.fromUri(File(Platform.resolvedExecutable)
              .uri
              .resolve('../../material_fonts/roboto-regular.ttf'));
      final font = FontLoader('QAVisual')
        ..addFont(fontFile
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: '896-5586-2781');
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    final availability = MonthlyAvailability({
      'destination_guid': 'fixture-destination',
      'month': '2027-03',
      'timezone': 'Asia/Jakarta',
      'requested_quantity': 1,
      'dates': [
        for (var day = 1; day <= 31; day++)
          {
            'date': '2027-03-${day.toString().padLeft(2, '0')}',
            'capacity': 100,
            'remaining': day % 4 == 0 ? 0 : 30,
            'level': ['none', 'high', 'medium', 'low'][day % 4],
            'status': day % 4 == 0 ? 'sold_out' : 'available',
            'bookable': day % 4 != 0,
          },
      ],
    });
    var selectedTab = 0;
    AvailabilityDay? selectedDay;
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          fontFamily: 'QAVisual',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(width == 320 ? 1.8 : 1),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFFF5F8FD),
              body: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fixture visual V4',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Data uji komponen; bukan data produksi.'),
                      const SizedBox(height: 24),
                      InternationalPhoneField(
                        controller: controller,
                        country: IsoCode.ID,
                        onCountryChanged: (_) {},
                        onChanged: () {},
                      ),
                      const SizedBox(height: 24),
                      AvailabilityCalendar(
                        month: DateTime(2027, 3),
                        availability: availability,
                        selectedDate: '2027-03-03',
                        onMonthChanged: (_) {},
                        onSelected: (day) => selectedDay = day,
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: FloatingBottomNav(
                index: 2,
                unreadCount: 123,
                onSelected: (tab) => selectedTab = tab,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width=$width');
      await tester.tap(find.byKey(const ValueKey('availability-2027-03-03')));
      expect(selectedDay?.date, '2027-03-03');
      selectedDay = null;
      await tester.tap(find.byKey(const ValueKey('availability-2027-03-04')));
      expect(selectedDay, isNull);
      await tester.tap(find
          .descendant(
              of: find.byType(FloatingBottomNav),
              matching: find.byType(InkWell))
          .at(3));
      expect(selectedTab, 3);
      final badge =
          tester.getRect(find.byKey(const ValueKey('notification-badge')));
      final bell =
          tester.getRect(find.descendant(of: find.byTooltip('Notifikasi'), matching: find.byType(CustomPaint)).first);
      expect(badge.top, lessThan(bell.top));
      expect(badge.left, lessThan(bell.right));
      expect(badge.right, greaterThan(bell.right));
      if (capture) {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/visual/v4-components-${width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
