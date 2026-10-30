import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart' show Wisata;
import 'package:wisata_daerahku/data/business_repository.dart' show Destination;
import 'package:wisata_daerahku/screens/tambah_wisata_screen.dart';
import 'admin_test_support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('create form submits category, integer price and timezone',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'GET') {
        return jsonResponse(pageEnvelope([
          {
            'guid': 'cat-1',
            'name': 'Pantai',
            'slug': 'pantai',
            'is_active': true
          }
        ]));
      }
      return jsonResponse({
        'data': {'guid': 'new', 'name': 'Pantai Baru'}
      });
    }, role: 1, log: log);

    await tester.pumpWidget(MaterialApp(
        home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => TambahWisataScreen(
              repository: repositoryFor(session), session: session)),
    )));
    await tester.pumpAndSettle();

    expect(find.text('4.5'), findsNothing);
    expect(find.text('-'), findsOneWidget);

    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Contoh: Pantai Parangtritis'),
        'Pantai Baru');
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Contoh: Yogyakarta, DIY'),
        'Makassar');
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText ==
                'Ceritakan keunikan tempat wisata ini...'),
        'Pantai indah');
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Rupiah, 0 = gratis'),
        '25000');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == '08.00 – 17.00'),
        '08.00 - 17.00');
    await tester.tap(find.text('Pantai'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('timezone-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asia/Makassar (WITA)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambahkan Wisata'));
    await tester.pumpAndSettle();

    final post = log.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/v1/destinations');
    expect(jsonDecode(post.body), {
      'destination_category_guid': 'cat-1',
      'name': 'Pantai Baru',
      'location': 'Makassar',
      'description': 'Pantai indah',
      'ticket_price': 25000,
      'opening_hours': '08.00 - 17.00',
      'timezone': 'Asia/Makassar',
    });

    await tester.pumpWidget(MaterialApp(
      home: TambahWisataScreen(
        repository: repositoryFor(session),
        session: session,
        wisataEdit: Wisata.fromDestination(Destination({
          'guid': 'dest-1',
          'name': 'Pantai Server',
          'rating_average': 4.3,
          'rating_count': 7,
        })),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('4.5'), findsNothing);
  });
}
