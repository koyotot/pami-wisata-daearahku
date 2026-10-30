import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/widgets/reviews_sheet.dart';

import 'user_support.dart';

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
      'data': items,
      'meta': {'last_page': 1, 'total': items.length},
    };

Map<String, dynamic> _review() => {
      'guid': 'review-1',
      'booking_guid': 'booking-1',
      'destination_guid': 'destination-1',
      'destination_name':
          'Destinasi dengan nama yang panjang untuk layar kecil',
      'rating': 4,
      'comment': 'Ulasan privat akun pertama.',
      'created_at': '2026-10-30T10:00:00Z',
    };

Future<void> _open(WidgetTester tester, BusinessRepository repository) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ReviewsSheet(repository: repository),
          ),
          child: const Text('Buka'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('review sheet renders empty state on a narrow viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = await signedInSession((_) async => jsonResponse(_page([])));
    addTearDown(session.client.close);
    await _open(tester, repositoryFor(session));
    expect(find.text('Riwayat Ulasan'), findsOneWidget);
    expect(find.text('Belum ada ulasan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'review sheet retries a failed request and clears private rows on logout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    final session = await signedInSession((_) async {
      requests++;
      return requests == 1
          ? jsonResponse({'message': 'Layanan ulasan tidak tersedia.'}, 503)
          : jsonResponse(_page([_review()]));
    });
    addTearDown(session.client.close);
    await _open(tester, repositoryFor(session));
    expect(find.text('Coba lagi'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Ulasan privat akun pertama.'), findsOneWidget);
    expect(requests, 2);
    expect(tester.takeException(), isNull);
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.text('Ulasan privat akun pertama.'), findsNothing);
    expect(find.text('Belum ada ulasan.'), findsOneWidget);
  });

  testWidgets('late review response cannot repopulate sheet after logout',
      (tester) async {
    final response = Completer<http.Response>();
    final session = await signedInSession((_) => response.future);
    addTearDown(session.client.close);
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: ReviewsSheet(repository: repositoryFor(session)))));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await session.clear();
    response.complete(jsonResponse(_page([_review()])));
    await tester.pumpAndSettle();
    expect(find.text('Ulasan privat akun pertama.'), findsNothing);
    expect(find.text('Belum ada ulasan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
