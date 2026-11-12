import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/admin/operations_booking_screen.dart';
import 'admin_test_support.dart';
import 'operations_test_support.dart';

void main() {
  testWidgets(
      'reassign only offers active assigned Admin and requires a reason',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <http.Request>[];
    var owner = 'other';
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/admins')) {
        return jsonResponse({
          'data': {
            'user_guids': ['target', 'inactive', 'super']
          }
        });
      }
      if (request.url.path.endsWith('/accounts')) {
        return jsonResponse(pageEnvelope([
          {'guid': 'target', 'name': 'Sari', 'role': 1, 'status': 'active'},
          {
            'guid': 'inactive',
            'name': 'Nonaktif',
            'role': 1,
            'status': 'inactive'
          },
          {'guid': 'super', 'name': 'Super', 'role': 2, 'status': 'active'},
          {
            'guid': 'unassigned',
            'name': 'Luar scope',
            'role': 1,
            'status': 'active'
          },
        ]));
      }
      if (request.method == 'POST') {
        owner = 'target';
        return jsonResponse({'data': operationalClaim(owner)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, log: log);
    await tester.pumpWidget(MaterialApp(
        home: OperationsBookingScreen(
            bookingGuid: 'b1',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alihkan ke Admin'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Alihkan'))
            .onPressed,
        isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Sari'), findsWidgets);
    expect(find.text('Nonaktif'), findsNothing);
    expect(find.text('Luar scope'), findsNothing);
    expect(find.text('Super'), findsNothing);
    await tester.tap(find.text('Sari').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Alihkan'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Pergantian shift');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Alihkan'));
    await tester.pumpAndSettle();
    final post = log.singleWhere((request) => request.method == 'POST');
    expect(post.url.path, '/api/v1/superadmin/bookings/b1/reassign');
    expect(jsonDecode(post.body),
        {'admin_guid': 'target', 'reason': 'Pergantian shift'});
    expect(find.textContaining('Claim Admin lain · target'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unknown claim blocks back until explicit same-key recovery',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var writes = 0;
    String? owner;
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        writes++;
        owner = 'admin-1';
        if (writes == 1) throw TimeoutException('unknown');
        return jsonResponse({'data': operationalClaim(owner)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: log);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => OperationsBookingScreen(
                                bookingGuid: 'b1',
                                repository: repositoryFor(session),
                                session: session))),
                    child: const Text('Buka booking'))))));
    await tester.tap(find.text('Buka booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-primary-action')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Detail Booking'), findsOneWidget);
    expect(writes, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Periksa ulang tindakan yang sama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periksa ulang tindakan yang sama'));
    await tester.pumpAndSettle();
    final posts = log.where((request) => request.method == 'POST').toList();
    expect(posts, hasLength(2));
    expect(posts.first.headers, posts.last.headers);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Buka booking'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
