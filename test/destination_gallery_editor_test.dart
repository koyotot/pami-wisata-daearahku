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

const destination = {
  'guid': 'dest-1',
  'name': 'Pantai',
  'location': 'Bali',
  'description': 'Pantai indah',
  'destination_category_guid': 'cat-1',
  'ticket_price': 0,
  'opening_hours': '08:00',
  'gallery_version': 1,
  'images': [galleryImageJson],
  'facilities': [],
};
Future<void> openEditor(WidgetTester tester, AuthSession session) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => TextButton(
              child: const Text('Edit'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TambahWisataScreen(
                          session: session,
                          repository: repositoryFor(session),
                          wisataEdit: Wisata.fromDestination(
                              Destination(destination)))))))));
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

http.Response? reads(http.Request r,
    {Map<String, dynamic> data = destination}) {
  if (r.url.path.endsWith('/facilities')) return jsonResponse(pageEnvelope([]));
  if (r.url.path.endsWith('/categories')) {
    return jsonResponse(pageEnvelope([
      {'guid': 'cat-1', 'name': 'Pantai'}
    ]));
  }
  if (r.url.path.contains('/images/')) {
    return http.Response.bytes(galleryPng, 200,
        headers: {'content-type': 'image/png'});
  }
  if (r.method == 'GET') return jsonResponse({'data': data});
  return null;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('422 preserves draft and retry uses same key until successful',
      (tester) async {
    final requests = <http.Request>[];
    var attempts = 0;
    final session = await adminSession((r) async {
      final read = reads(r);
      if (read != null) return read;
      attempts++;
      if (attempts == 1) {
        return jsonResponse({
          'message': 'Foto tidak valid',
          'errors': {
            'gallery_manifest': ['Periksa urutan.']
          }
        }, 422);
      }
      return jsonResponse({
        'data': {...destination, 'gallery_version': 2}
      });
    }, log: requests);
    await openEditor(tester, session);
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(find.text('1/10 foto'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    final saves = requests.where((r) => r.method == 'POST').toList();
    expect(saves, hasLength(2));
    expect(saves[0].headers['Idempotency-Key'],
        saves[1].headers['Idempotency-Key']);
    expect(find.text('Edit'), findsOneWidget);
  });
  testWidgets('409 keeps draft and only reloads when explicitly selected',
      (tester) async {
    final session = await adminSession((r) async =>
        reads(r) ?? jsonResponse({'message': 'Galeri berubah'}, 409));
    await openEditor(tester, session);
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(find.text('Galeri telah berubah'), findsOneWidget);
    await tester.tap(find.text('Pertahankan draft'));
    await tester.pumpAndSettle();
    expect(find.text('1/10 foto'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
  testWidgets(
      'lost response reconciles matching operation through admin detail',
      (tester) async {
    String? key;
    var posts = 0;
    final session = await adminSession((r) async {
      final read = reads(r, data: {
        ...destination,
        if (key != null) 'last_gallery_operation_key': key,
        'gallery_version': key == null ? 1 : 2
      });
      if (read != null) return read;
      posts++;
      key = r.headers['Idempotency-Key'];
      return jsonResponse({'message': 'Response lost'}, 500);
    });
    await openEditor(tester, session);
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Edit'), findsOneWidget);
  });
  testWidgets('last image cannot be deleted and unsaved form asks before exit',
      (tester) async {
    final session = await adminSession(
        (r) async => reads(r) ?? jsonResponse({'data': destination}));
    await openEditor(tester, session);
    await tester.tap(find.byTooltip('Hapus foto 1'));
    await tester.pumpAndSettle();
    expect(find.text('1/10 foto'), findsOneWidget);
    expect(find.text('Minimal satu foto harus dipertahankan.'), findsOneWidget);
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Contoh: Pantai Parangtritis'),
        'Perubahan lokal');
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await tester.tap(find.text('Lanjut edit'));
    await tester.pumpAndSettle();
    expect(find.text('Perubahan lokal'), findsOneWidget);
  });
}
