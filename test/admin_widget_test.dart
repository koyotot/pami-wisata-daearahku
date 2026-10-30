import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/daftar_pendaftar_screen.dart';
import 'package:wisata_daerahku/screens/kelola_admin_screen.dart';
import 'package:wisata_daerahku/screens/kelola_kategori_screen.dart';
import 'package:wisata_daerahku/screens/kelola_kuota_screen.dart';
import 'admin_test_support.dart';

void tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('booking list shows the status the server returned after approve',
      (tester) async {
    tallSurface(tester);
    final log = <http.Request>[];
    var current = 'pending_approval';
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        // The server decides; here it answers with a paid-flow status.
        current = 'awaiting_payment';
        return jsonResponse({'data': bookingJson('g1', current)});
      }
      return jsonResponse(pageEnvelope([bookingJson('g1', current)]));
    }, role: 1, log: log);

    await tester.pumpWidget(MaterialApp(
        home: DaftarPendaftarScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('g1'));
    expect(find.descendant(of: card, matching: find.text('Menunggu')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('approve-g1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Setujui'));
    await tester.pumpAndSettle();

    expect(log.where((r) => r.method == 'POST'), hasLength(1));
    expect(log.firstWhere((r) => r.method == 'POST').url.path,
        '/api/v1/admin/bookings/g1/approve');
    expect(find.descendant(of: card, matching: find.text('Menunggu pembayaran')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('approve-g1')), findsNothing);
    expect(find.textContaining('Status: Menunggu pembayaran'), findsOneWidget);
  });

  testWidgets('status filter chip requests the status from the server',
      (tester) async {
    tallSurface(tester);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      final status = request.url.queryParameters['status'];
      return jsonResponse(pageEnvelope(
          [bookingJson('g-${status ?? 'all'}', status ?? 'pending_approval')]));
    }, role: 1, log: log);

    await tester.pumpWidget(MaterialApp(
        home: DaftarPendaftarScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(log.last.url.queryParameters.containsKey('status'), isFalse);

    await tester.tap(find.byKey(const ValueKey('chip-Ditolak')));
    await tester.pumpAndSettle();
    expect(log.last.url.queryParameters['status'], 'rejected');
    expect(find.byKey(const ValueKey('g-rejected')), findsOneWidget);
    expect(find.byKey(const ValueKey('g-all')), findsNothing);
  });

  testWidgets('accounts screen hides role/status actions on the own row',
      (tester) async {
    tallSurface(tester);
    final session = await adminSession((request) async {
      return jsonResponse(pageEnvelope([
        {
          'guid': 'me',
          'name': 'Saya',
          'email': 'me@example.test',
          'role': 2,
          'status': 'active'
        },
        {
          'guid': 'other',
          'name': 'Rekan',
          'email': 'other@example.test',
          'role': 1,
          'status': 'active'
        },
      ]));
    }, role: 2, guid: 'me');

    await tester.pumpWidget(MaterialApp(
        home: KelolaAdminScreen(
            repository: repositoryFor(session),
            session: session,
            ownGuid: 'me')));
    await tester.pumpAndSettle();

    expect(find.text('Saya'), findsOneWidget);
    expect(find.text('Akun Anda'), findsOneWidget);
    expect(find.byKey(const ValueKey('role-other')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-other')), findsOneWidget);
    expect(find.byKey(const ValueKey('role-me')), findsNothing);
    expect(find.byKey(const ValueKey('status-me')), findsNothing);
  });

  testWidgets('deactivating a category in use shows the precise message',
      (tester) async {
    tallSurface(tester);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'DELETE') return conflict('category_in_use');
      return jsonResponse(pageEnvelope([
        {'guid': 'c1', 'name': 'Pantai', 'slug': 'pantai', 'is_active': true}
      ]));
    }, role: 2, log: log);

    await tester.pumpWidget(MaterialApp(
        home: KelolaKategoriScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(log.first.url.queryParameters['status'], 'all');

    await tester.tap(find.byKey(const ValueKey('toggle-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Nonaktifkan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('masih dipakai oleh destinasi aktif'),
        findsOneWidget);
    expect(log.where((r) => r.method == 'DELETE'), hasLength(1));
  });

  testWidgets('category screen is closed for role 1 and sends no request',
      (tester) async {
    tallSurface(tester);
    final log = <http.Request>[];
    final session = await adminSession(
        (request) async => jsonResponse(pageEnvelope([])),
        role: 1, log: log);
    await tester.pumpWidget(MaterialApp(
        home: KelolaKategoriScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Akses ditolak'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-category')), findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('quota screen shows capacity, allocated and remaining separately',
      (tester) async {
    tallSurface(tester);
    final session = await adminSession((request) async {
      return jsonResponse(pageEnvelope([
        {
          'guid': 'q1',
          'visit_date': '2026-12-01',
          'capacity': 20,
          'allocated': 7,
          'remaining': 13,
          'booking_opens_at': '2026-10-01T00:00:00+00:00',
          'booking_closes_at': '2026-11-30T00:00:00+00:00',
        }
      ]));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: KelolaKuotaScreen(
            destinationGuid: 'dest-1',
            destinationName: 'Pantai Indah',
            timezone: 'Asia/Jakarta',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();

    expect(find.text('2026-12-01'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('Kapasitas'), findsOneWidget);
    expect(find.text('Teralokasi'), findsOneWidget);
    expect(find.text('Sisa'), findsOneWidget);
  });

  testWidgets('quota form rejects a window that does not close after it opens',
      (tester) async {
    tallSurface(tester);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'PUT') {
        return jsonResponse({'message': 'x', 'errors': {'capacity': ['salah']}}, 422);
      }
      return jsonResponse(pageEnvelope([
        {
          'guid': 'q1',
          'visit_date': '2026-12-01',
          'capacity': 20,
          'allocated': 7,
          'remaining': 13,
          'booking_opens_at': '2026-11-30T10:00:00+00:00',
          'booking_closes_at': '2026-11-30T10:00:00+00:00',
        }
      ]));
    }, role: 1, log: log);
    await tester.pumpWidget(MaterialApp(
        home: KelolaKuotaScreen(
            destinationGuid: 'dest-1',
            destinationName: 'Pantai Indah',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-2026-12-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quota-save')));
    await tester.pumpAndSettle();

    expect(find.text('Waktu tutup booking harus setelah waktu buka.'),
        findsOneWidget);
    expect(log.where((r) => r.method == 'PUT'), isEmpty);
  });
}
