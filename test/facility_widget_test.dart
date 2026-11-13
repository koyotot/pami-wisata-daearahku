import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/superadmin/kelola_fasilitas_screen.dart';
import 'admin_test_support.dart';
import 'user_support.dart' as users;

void main() {
  for (final role in [0, 1]) {
    testWidgets('master direct entry rejects role $role without requests',
        (tester) async {
      final log = <http.Request>[];
      final session = role == 0
          ? await users.signedInSession((request) async {
              log.add(request);
              return jsonResponse(pageEnvelope([]));
            })
          : await adminSession((r) async => jsonResponse(pageEnvelope([])),
              role: role, log: log);
      await tester.pumpWidget(MaterialApp(
          home: KelolaFasilitasScreen(
              repository: repositoryFor(session), session: session)));
      await tester.pumpAndSettle();
      expect(find.text('Akses ditolak'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-facility')), findsNothing);
      expect(log, isEmpty);
    });
  }

  testWidgets('action sheet deactivates a facility after confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'DELETE') return jsonResponse({'data': null});
      return jsonResponse(pageEnvelope([
        {
          'guid': 'f1',
          'name': 'Parkir',
          'slug': 'parkir',
          'icon_key': null,
          'is_active': true
        }
      ]));
    }, log: log);
    await tester.pumpWidget(MaterialApp(
        home: KelolaFasilitasScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Slug: parkir'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('actions-f1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Fasilitas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-f1')));
    await tester.pumpAndSettle();
    expect(find.text('Nonaktifkan Fasilitas?'), findsOneWidget);
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(log.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty master, create, immutable slug edit, status filter',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <http.Request>[];
    var rows = <Map<String, dynamic>>[];
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        expect(jsonDecode(request.body),
            {'name': 'Parkir', 'icon_key': null, 'is_active': true});
        rows = [
          {
            'guid': 'f1',
            'name': 'Parkir',
            'slug': 'parkir',
            'icon_key': null,
            'is_active': true
          }
        ];
        return jsonResponse({'data': rows.single}, 201);
      }
      if (request.method == 'PATCH') {
        expect(jsonDecode(request.body).containsKey('slug'), isFalse);
        return jsonResponse({'data': rows.single});
      }
      return jsonResponse(pageEnvelope(rows));
    }, log: log);
    await tester.pumpWidget(MaterialApp(
        home: KelolaFasilitasScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada fasilitas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-facility')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('facility-name')), 'Parkir');
    await tester.tap(find.byKey(const ValueKey('facility-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actions-f1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-f1')));
    await tester.pumpAndSettle();
    final slug = tester
        .widget<TextFormField>(find.byKey(const ValueKey('facility-slug')));
    expect(slug.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('facility-save')));
    await tester.pumpAndSettle();
    // Status filter and search run on the device over the full list.
    await tester.tap(find.byKey(const ValueKey('status-filter-inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada fasilitas yang cocok'), findsOneWidget);
    expect(find.text('0 ditemukan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-filter')));
    await tester.pumpAndSettle();
    expect(find.text('1 ditemukan'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('facility-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada fasilitas yang cocok'), findsOneWidget);
    expect(log.where((r) => r.method == 'POST'), hasLength(1));
    expect(log.where((r) => r.method == 'PATCH'), hasLength(1));
    expect(log.where((r) => r.method == 'GET').every(
        (r) => r.url.queryParameters['status'] == 'all'), isTrue);
  });
}
