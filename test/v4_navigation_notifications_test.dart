import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/notification_state.dart';
import 'package:wisata_daerahku/screens/auth_presentation.dart';
import 'package:wisata_daerahku/screens/notifikasi_screen.dart';
import 'package:wisata_daerahku/screens/bukti_pendaftaran_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
import 'user_support.dart';

Map<String, dynamic> item(String guid,
        {bool read = false, String? bookingGuid}) =>
    {
      'guid': guid,
      'booking_guid': bookingGuid,
      'title': 'Pendaftaran $guid',
      'body': 'Status diperbarui oleh pengelola.',
      'read_at': read ? '2026-11-01T00:00:00Z' : null,
      'created_at': '2026-11-02T00:00:00Z',
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('badge belongs to bell glyph, clamps and hides at zero',
      (tester) async {
    var selected = -1;
    Future<void> render(int count) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
          bottomNavigationBar: FloatingBottomNav(
              index: 0,
              unreadCount: count,
              onSelected: (index) => selected = index),
        )));
    await render(123);
    expect(find.text('99+'), findsOneWidget);
    final badge =
        tester.getRect(find.byKey(const ValueKey('notification-badge')));
    final bell = tester.getRect(find
        .descendant(
            of: find.byTooltip('Notifikasi'),
            matching: find.byType(CustomPaint))
        .first);
    expect(badge.top, lessThan(bell.top));
    expect(badge.right, greaterThan(bell.right));
    expect(badge.left, lessThan(bell.right));
    await tester.tap(find.byTooltip('Jelajah'));
    expect(selected, 2);
    await render(1);
    expect(find.text('1'), findsOneWidget);
    await render(0);
    expect(find.byKey(const ValueKey('notification-badge')), findsNothing);
  });

  testWidgets('navigation respects gesture inset and large text at 320dp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 34),
          textScaler: TextScaler.linear(1.8)),
      child: Scaffold(
          bottomNavigationBar:
              FloatingBottomNav(index: 2, unreadCount: 99, onSelected: (_) {})),
    )));
    expect(
        tester.getRect(find.byType(FloatingBottomNav)).bottom -
            tester.getRect(find.byType(InkWell).last).bottom,
        greaterThanOrEqualTo(34));
    expect(tester.takeException(), isNull);
  });

  test('inbox uses real pagination count and authenticated mark-read contract',
      () async {
    var read = false;
    final requests = <String>[];
    final session = await signedInSession((request) async {
      requests
          .add('${request.method} ${request.url.path}?${request.url.query}');
      expect(request.headers['authorization'], 'Bearer access');
      if (request.url.path.endsWith('unread-count')) {
        return jsonResponse({
          'data': {'unread_count': read ? 0 : 1}
        });
      }
      if (request.method == 'PATCH') {
        read = true;
        return jsonResponse({'data': item('a', read: true)});
      }
      final page = request.url.queryParameters['page'];
      return jsonResponse({
        'data': [
          item(page == '1' ? 'a' : 'b', read: page == '1' ? read : true)
        ],
        'meta': {'last_page': 2}
      });
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    await state.refresh();
    expect(state.count.data, 1);
    expect(state.inbox.data!.map((e) => e.guid), ['a', 'b']);
    await state.markRead(state.inbox.data!.first);
    expect(requests, contains('PATCH /api/v1/notifications/a/read?'));
    expect(state.count.data, 0);
    expect(state.inbox.data!.first.unread, false);
  });

  test('late unread response cannot restore data after session change',
      () async {
    final pending = Completer<void>();
    final session = await signedInSession((_) async {
      await pending.future;
      return jsonResponse({
        'data': {'unread_count': 12}
      });
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    final loading = state.refreshCount();
    session.sessionChanges.notifyListeners();
    pending.complete();
    await loading;
    expect(state.count.data, isNull);
  });

  testWidgets('inbox filters unread and exposes errors without fake activity',
      (tester) async {
    var fail = false;
    final session = await signedInSession((request) async {
      if (fail) return jsonResponse({'message': 'Unavailable'}, 503);
      if (request.url.path.endsWith('unread-count')) {
        return jsonResponse({
          'data': {'unread_count': 1}
        });
      }
      return jsonResponse({
        'data': [item('a'), item('b', read: true)],
        'meta': {'last_page': 1}
      });
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    await state.refresh();
    await tester.pumpWidget(MaterialApp(home: NotifikasiScreen(state: state)));
    expect(find.byType(TimeBasedScenicBackground), findsOneWidget);
    expect(find.text('Pendaftaran a'), findsOneWidget);
    expect(find.text('Pendaftaran b'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Belum dibaca'));
    await tester.pump();
    expect(find.text('Pendaftaran b'), findsNothing);
    fail = true;
    await state.refresh();
    await tester.pump();
    expect(find.text('Aktivitas belum berhasil diperbarui.'), findsOneWidget);
    expect(find.text('Pendaftaran a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification cards use event icons and readable compact layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await signedInSession((request) async {
      if (request.url.path.endsWith('unread-count')) {
        return jsonResponse({
          'data': {'unread_count': 3}
        });
      }
      return jsonResponse({
        'data': [
          for (final event in [
            'rejected',
            'approved',
            'expired',
            'payment_review'
          ])
            {
              ...item(event, read: event == 'approved'),
              'type': 'booking.$event'
            },
        ],
        'meta': {'last_page': 1},
      });
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    await state.refresh();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: NotifikasiScreen(state: state, active: false),
      ),
    ));
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == 'Belum dibaca'),
        findsNWidgets(3));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == 'Sudah dibaca'),
        findsOneWidget);
    expect(find.textContaining('02/11/2026'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking activity opens full-screen and restores unread filter',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var read = false;
    final requests = <String>[];
    final session = await signedInSession((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('unread-count')) {
        return jsonResponse({
          'data': {'unread_count': read ? 0 : 1}
        });
      }
      if (request.url.path == '/api/v1/notifications/activity-1/read' &&
          request.method == 'PATCH') {
        read = true;
        return jsonResponse({'data': item('activity-1', read: true)});
      }
      if (request.url.path == '/api/v1/notifications') {
        return jsonResponse({
          'data': [item('activity-1', read: read, bookingGuid: 'booking-1')],
          'meta': {'last_page': 1},
        });
      }
      if (request.url.path == '/api/v1/bookings/booking-1') {
        return jsonResponse({
          'data': bookingJson(status: 'awaiting_payment'),
        });
      }
      if (request.url.path == '/api/v1/bookings/booking-1/documents') {
        return jsonResponse({
          'data': {'invoice': null, 'ticket': null}
        });
      }
      return jsonResponse({'message': 'Unexpected request'}, 404);
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    await state.refresh();
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(1.5),
                disableAnimations: true),
            child: NotifikasiScreen(state: state))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Belum dibaca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendaftaran activity-1'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingTicketScreen), findsOneWidget);
    expect(find.text('Detail Pendaftaran'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('detailStatus')),
            matching: find.text('Menunggu pembayaran')),
        findsOneWidget);
    expect(requests, contains('GET /api/v1/bookings/booking-1'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Belum dibaca'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Belum dibaca'))
            .selected,
        isTrue);
    expect(find.text('Semua aktivitas sudah dibaca.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
