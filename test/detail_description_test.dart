import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/user/detail_wisata_screen.dart';

class _Repository extends BusinessRepository {
  _Repository(this.detail);
  final Destination detail;

  @override
  Future<Destination> destination(String guid) async => detail;
}

void main() {
  testWidgets('description toggle follows actual four-line overflow',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> open(String description,
        {double scale = 1, TextDirection direction = TextDirection.ltr}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final detail = Destination({
        'guid': 'destination-1',
        'name': 'Destinasi',
        'description': description,
      });
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: DetailWisataScreen(
          wisata: Wisata.fromDestination(detail),
          repository: _Repository(detail),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final description in ['dadada', 'satu\ndua\ntiga\nempat', '']) {
      await open(description);
      expect(find.text('Baca selengkapnya'), findsNothing);
      if (description.isNotEmpty) {
        expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
      }
    }

    const long = 'satu\ndua\ntiga\nempat\nlima';
    await open(long);
    expect(tester.widget<Text>(find.text(long)).maxLines, 4);
    await tester.tap(find.text('Baca selengkapnya'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    await tester.tap(find.text('Tampilkan Lebih Sedikit'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(long)).maxLines, 4);

    const wrapping = 'Destinasi wisata alam yang indah dan nyaman. '
        'Nikmati suasana tenang bersama keluarga dan teman.';
    await open(wrapping);
    expect(find.text('Baca selengkapnya'), findsNothing);
    await open(wrapping, scale: 2, direction: TextDirection.rtl);
    expect(find.text('Baca selengkapnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
