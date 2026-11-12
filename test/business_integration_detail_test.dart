import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/user/detail_wisata_screen.dart';

class _DetailRepository extends BusinessRepository {
  _DetailRepository(this.facilities);
  final List<Map<String, dynamic>> facilities;
  @override
  Future<Destination> destination(String guid) async => Destination({
        'guid': guid,
        'name': 'Destinasi API',
        'location': 'Bali',
        'facilities': facilities,
      });
}

void main() {
  Future<void> open(
      WidgetTester tester, List<Map<String, dynamic>> facilities) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final destination = Destination({
      'guid': 'dest-1',
      'name': 'Destinasi Lama',
      'facilities': [],
    });
    await tester.pumpWidget(MaterialApp(
        home: DetailWisataScreen(
            wisata: Wisata.fromDestination(destination),
            repository: _DetailRepository(facilities))));
    await tester.pumpAndSettle();
  }

  testWidgets('detail renders dynamic facility names and null icon fallback',
      (tester) async {
    await open(tester, [
      {
        'guid': 'f1',
        'name': 'Ruang Laktasi API',
        'slug': 'ruang-laktasi',
        'icon_key': null,
      },
      {
        'guid': 'f2',
        'name': 'Area Kursi Roda',
        'slug': 'area-kursi-roda',
        'icon_key': null,
      },
    ]);
    expect(find.text('Ruang Laktasi API'), findsOneWidget);
    expect(find.text('Area Kursi Roda'), findsOneWidget);
    expect(find.byIcon(Icons.room_service_outlined), findsNWidgets(2));
    expect(find.text('Parkir'), findsNothing);
    expect(find.text('Toilet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty detail facilities never get hardcoded replacements',
      (tester) async {
    await open(tester, []);
    expect(find.text('Fasilitas belum dicantumkan'), findsOneWidget);
    expect(find.byIcon(Icons.room_service_outlined), findsNothing);
    for (final label in ['Parkir', 'Toilet', 'Wi-Fi', 'Mushola']) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
