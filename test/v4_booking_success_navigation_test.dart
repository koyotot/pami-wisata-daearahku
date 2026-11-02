import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/main_navigation_screen.dart';
import 'package:wisata_daerahku/screens/permintaan_terkirim_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
import 'user_support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final staleBeforeBuild in [true, false]) {
    testWidgets(
        'success hides booking on ${staleBeforeBuild ? 'stale route generation' : 'logout'}',
        (tester) async {
      final session = await signedInSession((_) async => jsonResponse({}));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('safe root'))));
      navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => PermintaanTerkirimScreen(
              booking: Booking(bookingJson()),
              session: session,
              sessionGeneration:
                  session.sessionGeneration - (staleBeforeBuild ? 1 : 0))));
      await tester.pump();
      if (!staleBeforeBuild) {
        await tester.pumpAndSettle();
        expect(find.text('Pendaftaran tercatat!'), findsOneWidget);
        session.authenticated.value = false;
        session.sessionChanges.notifyListeners();
        await tester.pump();
      }
      expect(find.text('Pendaftaran tercatat!'), findsNothing);
      expect(find.byKey(const ValueKey('bookingNumber')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('safe root'), findsOneWidget);
      expect(find.byType(PermintaanTerkirimScreen, skipOffstage: false),
          findsNothing);
      expect(
          find.byType(MainNavigationScreen, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'success summary uses actual resource and scales without overflow',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    final session = await signedInSession((_) async => jsonResponse({}));
    final booking = Booking(bookingJson(status: 'confirmed')
      ..['destination_name'] = 'Pantai dengan nama destinasi sangat panjang'
      ..['visit_date'] = '2027-04-23'
      ..['quantity'] = 5
      ..['booking_number'] = 'SERVER-BOOKING-123456789012345678901234567890');
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 740);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
              padding: EdgeInsets.only(top: 24, bottom: 34),
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true),
          child: PermintaanTerkirimScreen(booking: booking, session: session),
        ),
      ));
      expect(find.text('Permintaan Terkirim'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(FloatingBottomNav), findsNothing);
      expect(find.text('Pendaftaran diterima server'), findsNothing);
      await tester.scrollUntilVisible(find.text(booking.destinationName), 150);
      expect(find.text('2027-04-23'), findsOneWidget);
      expect(find.text('5 orang'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('bookingStatus')), 150);
      expect(find.text('Status: Disetujui'), findsOneWidget);
      expect(find.text('Nomor: ${booking.bookingNumber}'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('successHome')), 150);
      expect(tester.takeException(), isNull, reason: '$width dp');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  for (final action in ['history', 'home', 'system back']) {
    testWidgets('success $action reuses shell and removes intermediate routes',
        (tester) async {
      final session = AuthSession.instance;
      final oldRole = session.role;
      final oldReady = session.deviceSessionReady;
      final oldAuthenticated = session.authenticated.value;
      session.role = 0;
      session.deviceSessionReady = true;
      session.authenticated.value = true;
      addTearDown(() {
        session.role = oldRole;
        session.deviceSessionReady = oldReady;
        session.authenticated.value = oldAuthenticated;
      });
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator, home: const MainNavigationScreen()));
      await tester.pump(const Duration(seconds: 1));
      final shell = tester.element(find.byType(MainNavigationScreen));
      navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail route'))));
      await tester.pumpAndSettle();
      navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('completed form'))));
      await tester.pumpAndSettle();
      navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
          builder: (_) =>
              PermintaanTerkirimScreen(booking: Booking(bookingJson()))));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingBottomNav), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      if (action == 'system back') {
        await tester.binding.handlePopRoute();
      } else {
        final button = find.byKey(
            ValueKey(action == 'history' ? 'successHistory' : 'successHome'));
        await tester.scrollUntilVisible(button, 150);
        await tester.tap(button);
      }
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(MainNavigationScreen)), same(shell));
      expect(find.byType(MainNavigationScreen, skipOffstage: false),
          findsOneWidget);
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          action == 'history' ? 1 : 0);
      expect(find.text('completed form', skipOffstage: false), findsNothing);
      expect(find.text('detail route', skipOffstage: false), findsNothing);
      expect(find.byType(PermintaanTerkirimScreen, skipOffstage: false),
          findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('five icon-only tabs retain accessible names and selected state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    const labels = ['Beranda', 'Riwayat', 'Jelajah', 'Notifikasi', 'Profil'];
    var selected = -1;
    for (var index = 0; index < 5; index++) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingBottomNav(
              index: index, onSelected: (value) => selected = value),
        ),
      ));
      expect(find.descendant(of: find.byType(FloatingBottomNav), matching: find.byType(CustomPaint)), findsNWidgets(5));
      expect(find.byType(Text), findsNothing);
      for (var tab = 0; tab < labels.length; tab++) {
        final node = tester.getSemantics(find.bySemanticsLabel(labels[tab]));
        final flags = node.getSemanticsData().flagsCollection;
        expect(flags.isButton, isTrue);
        expect(flags.isSelected.toBoolOrNull(), tab == index);
        final rect = tester.getRect(find.bySemanticsLabel(labels[tab]));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.bySemanticsLabel(labels[index]));
      expect(selected, index);
    }
    semantics.dispose();
  });

  testWidgets('bell badge stays on glyph at 0, 1, 99 and 100 across widths',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 740);
      for (final count in [0, 1, 99, 100]) {
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
                padding: EdgeInsets.only(bottom: 34),
                textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              bottomNavigationBar: FloatingBottomNav(
                  index: 3, unreadCount: count, onSelected: (_) {}),
            ),
          ),
        ));
        for (final label in [
          'Beranda',
          'Riwayat',
          'Jelajah',
          'Notifikasi',
          'Profil'
        ]) {
          expect(find.text(label), findsNothing);
        }
        final badge = find.byKey(const ValueKey('notification-badge'));
        if (count == 0) {
          expect(badge, findsNothing);
        } else {
          expect(find.text(count > 99 ? '99+' : '$count'), findsOneWidget);
          final rect = tester.getRect(badge);
          final bell =
              tester.getRect(find.descendant(of: find.byTooltip('Notifikasi'), matching: find.byType(CustomPaint)).first);
          expect(rect.top, lessThan(bell.top));
          expect(rect.right, greaterThan(bell.right));
          expect(rect.left, lessThan(bell.right));
          final decoration =
              tester.widget<Container>(badge).decoration as BoxDecoration;
          expect(decoration.color, const Color(0xFFFF9800));
          final text = tester.widget<Text>(
              find.descendant(of: badge, matching: find.byType(Text)));
          expect(text.style?.color, Colors.white);
        }
        final bellStack = tester.widget<Stack>(find
            .ancestor(
                of: find.descendant(of: find.byTooltip('Notifikasi'), matching: find.byType(CustomPaint)).first,
                matching: find.byType(Stack))
            .first);
        expect(bellStack.clipBehavior, Clip.none);
        expect(tester.takeException(), isNull,
            reason: '$width dp, unread $count');
      }
    }
  });
}
