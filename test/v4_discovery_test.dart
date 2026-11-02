import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/detail_wisata_screen.dart';

class _Repository extends BusinessRepository {
  final response = Completer<Destination>();
  @override
  Future<Destination> destination(String guid) => response.future;
}

void main() {
  testWidgets(
      'detail loading has an explicit neutral surface and safe scaled CTA',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    final destination = Destination({
      'guid': 'destination-1',
      'name': 'Destinasi dengan nama panjang dari API',
      'location': 'Lokasi wisata dari API',
      'opening_hours': '08.00 sampai 17.00 waktu setempat',
      'facilities': <dynamic>[],
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(bottom: 24),
          textScaler: const TextScaler.linear(1.4),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: DetailWisataScreen(
          wisata: Wisata.fromDestination(destination), repository: repository),
    ));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFFF5F8FD));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFF5F8FD));
    repository.response.complete(destination);
    await tester.pumpAndSettle();
    expect(find.text('Daftar Kunjungan'), findsOneWidget);
    expect(
        tester.getBottomRight(find.text('Daftar Kunjungan')).dy, lessThan(776));
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
