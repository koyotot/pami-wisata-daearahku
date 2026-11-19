import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/superadmin/timezone_drift_screen.dart';
import 'admin_test_support.dart';

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(2000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('superadmin sees bookings that keep the old timezone',
      (tester) async {
    tall(tester);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      return jsonResponse({
        'data': {
          'bookings': [
            {
              'guid': 'b1',
              'booking_number': 'PAMI-001',
              'status': 'awaiting_payment',
              'visit_date': '2026-12-01',
              'destination_name': 'Pantai Indah',
              'booking_timezone': 'Asia/Jakarta',
              'destination_timezone': 'Asia/Makassar',
            }
          ]
        }
      });
    }, role: 2, log: log);
    await tester.pumpWidget(MaterialApp(
        home: TimezoneDriftScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(log.first.url.path, endsWith('superadmin/bookings/timezone-drift'));
    expect(find.text('Pantai Indah'), findsOneWidget);
    expect(find.textContaining('Asia/Jakarta (WIB)'), findsOneWidget);
    expect(find.textContaining('Asia/Makassar (WITA)'), findsOneWidget);
  });

  testWidgets('an admin gets no list and sends no request', (tester) async {
    tall(tester);
    final log = <http.Request>[];
    final session = await adminSession(
        (request) async => jsonResponse({'data': {'bookings': []}}),
        role: 1,
        log: log);
    await tester.pumpWidget(MaterialApp(
        home: TimezoneDriftScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Akses ditolak'), findsOneWidget);
    expect(log, isEmpty);
  });

  testWidgets('an empty list says nothing differs', (tester) async {
    tall(tester);
    final session = await adminSession(
        (request) async => jsonResponse({'data': {'bookings': []}}),
        role: 2);
    await tester.pumpWidget(MaterialApp(
        home: TimezoneDriftScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada selisih'), findsOneWidget);
  });
}
