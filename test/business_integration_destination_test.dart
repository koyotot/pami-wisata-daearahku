import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/admin/tambah_wisata_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'admin_test_support.dart';
import 'gallery_test_support.dart';

const _facility = {
  'guid': 'f1',
  'name': 'Parkir',
  'slug': 'parkir',
  'icon_key': null,
  'is_active': true,
};
const _destination = {
  'guid': 'created-1',
  'name': 'Pantai Baru',
  'destination_category_guid': 'cat-1',
  'location': 'Makassar',
  'description': 'Pantai indah',
  'ticket_price': 25000,
  'opening_hours': '08.00 - 17.00',
  'timezone': 'Asia/Makassar',
  'images': [galleryImageJson],
  'gallery_version': 1,
};

Future<void> _open(WidgetTester tester, AuthSession session,
    {Wisata? edit}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TambahWisataScreen(
                          session: session,
                          repository: repositoryFor(session),
                          wisataEdit: edit))),
                  child: const Text('Buka form'))))));
  await tester.tap(find.text('Buka form'));
  await tester.pumpAndSettle();
}

Finder _input(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ordinary attribute edit preserves facilities without PUT',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path == '/api/v1/facilities') {
        return jsonResponse(pageEnvelope([_facility]));
      }
      if (request.url.path == '/api/v1/categories') {
        return jsonResponse(pageEnvelope([
          {'guid': 'cat-1', 'name': 'Pantai', 'slug': 'pantai'}
        ]));
      }
      return jsonResponse({
        'data': {
          ..._destination,
          'facilities': [_facility],
        }
      });
    }, role: 1, log: requests);
    await _open(tester, session,
        edit: Wisata.fromDestination(Destination(_destination)));
    expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('facility-f1')))
            .selected,
        isTrue);
    await tester.enterText(
        _input('Contoh: Pantai Parangtritis'), 'Pantai Diubah');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    final update = requests.lastWhere((r) => r.method == 'POST');
    expect(update.body, contains('Pantai Diubah'));
    expect(update.body, contains('gallery_manifest'));
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(find.text('Buka form'), findsOneWidget);
  });

  testWidgets('failed assignment after create retries same destination GUID',
      (tester) async {
    final requests = <http.Request>[];
    var puts = 0;
    var assigned = <Map<String, dynamic>>[];
    final session = await adminSession((request) async {
      if (request.method == 'PUT') {
        puts++;
        if (puts == 1) {
          return jsonResponse({
            'message': 'Fasilitas belum tersimpan',
            'errors': {
              'facility_guids': ['Pilihan tidak aktif.']
            }
          }, 422);
        }
        assigned = [_facility];
      }
      if (request.url.path == '/api/v1/facilities') {
        return jsonResponse(pageEnvelope([_facility]));
      }
      if (request.url.path == '/api/v1/categories') {
        return jsonResponse(pageEnvelope([
          {'guid': 'cat-1', 'name': 'Pantai', 'slug': 'pantai'}
        ]));
      }
      return jsonResponse({
        'data': {..._destination, 'facilities': assigned}
      });
    }, role: 1, log: requests);
    await _open(tester, session);
    await tester.enterText(
        _input('Contoh: Pantai Parangtritis'), 'Pantai Baru');
    await tester.enterText(_input('Contoh: Yogyakarta, DIY'), 'Makassar');
    await tester.enterText(
        _input('Ceritakan keunikan tempat wisata ini...'), 'Pantai indah');
    await tester.enterText(_input('Contoh: 25.000'), '25000');
    await pickOpeningHours(tester);
    await pickCategory(tester, 'Pantai');
    await tester.tap(find.byKey(const ValueKey('facility-f1')));
    await pickGalleryPhoto(tester);
    await pickDraftLocation(tester);
    await tester.tap(find.text('Simpan Destinasi Baru'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Destinasi sudah tersimpan.'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(puts, 1);
    expect(
        requests
            .any((r) => r.url.path == '/api/v1/admin/destinations/created-1'),
        isTrue);
    expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('facility-f1')))
            .selected,
        isTrue,
        reason: 'failed assignment must preserve unsaved input for retry');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST'), hasLength(2),
        reason: 'retry must not create a second destination');
    final update = requests.lastWhere((r) => r.method == 'POST');
    expect(update.url.path, '/api/v1/destinations/created-1');
    final assignments = requests.where((r) => r.method == 'PUT').toList();
    expect(assignments, hasLength(2));
    expect(
        assignments.every((r) =>
            r.url.path == '/api/v1/admin/destinations/created-1/facilities'),
        isTrue);
    expect(find.text('Buka form'), findsOneWidget);
  });
}
