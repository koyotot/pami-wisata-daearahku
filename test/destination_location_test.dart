import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/admin/destination_location_picker_screen.dart';
import 'package:wisata_daerahku/screens/user/detail_wisata_screen.dart';
import 'package:wisata_daerahku/widgets/destination_location_map_preview.dart';
import 'admin_test_support.dart';

class _GeocodingRepository extends BusinessRepository {
  final responses = <Completer<String?>>[];
  @override
  Future<String?> reverseGeocode(double latitude, double longitude) {
    final response = Completer<String?>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('reverse geocoding uses authenticated admin endpoint and numeric pair',
      () async {
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      expect(request.url.path, '/api/v1/admin/geocoding/reverse');
      expect(request.url.queryParameters,
          {'latitude': '-7.0000000', 'longitude': '110.0000000'});
      expect(request.headers['Authorization'], 'Bearer access');
      return jsonResponse({
        'data': {'formatted_address': 'Alamat server'}
      });
    }, log: log);
    expect(
        await repositoryFor(session).reverseGeocode(-7, 110), 'Alamat server');
    expect(log, hasLength(1));
  });

  test('coordinates parse numbers and strings without inventing a legacy pin',
      () {
    final destination = Destination({
      'guid': 'one',
      'name': 'Pantai',
      'latitude': '-7.8012345',
      'longitude': 110.3645678
    });
    expect(destination.hasCoordinates, isTrue);
    expect(Wisata.fromDestination(destination).latitude, -7.8012345);
    expect(
        destinationDirectionsUri(destination)!.queryParameters['destination'],
        '-7.8012345,110.3645678');
    for (final coordinates in [
      <String, dynamic>{},
      {'latitude': 10},
      {'latitude': 'NaN', 'longitude': 110},
      {'latitude': -91, 'longitude': 110},
      {'latitude': 10, 'longitude': double.infinity},
    ]) {
      final legacy =
          Destination({'guid': 'old', 'name': 'Lama', ...coordinates});
      expect(legacy.hasCoordinates, isFalse);
      expect(destinationDirectionsUri(legacy), isNull);
    }
  });

  testWidgets('picker rejects stale geocoding and preserves typed address',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _GeocodingRepository();
    final responses = repository.responses;
    final session =
        await adminSession((_) async => jsonResponse({'data': {}}), role: 1);
    DestinationLocationDraft? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<DestinationLocationDraft>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DestinationLocationPickerScreen(
                              initialAddress: '',
                              repository: repository,
                              session: session)));
                },
                child: const Text('Pilih')))));
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DestinationLocationMap>(find.byType(DestinationLocationMap))
            .point,
        isNull);
    void pin(LatLng point) => tester
        .widget<DestinationLocationMap>(find.byType(DestinationLocationMap))
        .onTap!(point);
    pin(const LatLng(-7, 110));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    pin(const LatLng(-8, 111));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(responses, hasLength(2));
    await tester.enterText(
        find.byKey(const ValueKey('picker-address')), 'Alamat manual terbaru');
    responses[1].complete('Alamat otomatis terbaru');
    await tester.pump();
    responses[0].complete('Alamat lama');
    await tester.pumpAndSettle();
    expect(find.text('Alamat manual terbaru'), findsOneWidget);
    await tester.ensureVisible(find.text('Gunakan Lokasi Ini'));
    await tester.tap(find.text('Gunakan Lokasi Ini'));
    await tester.pumpAndSettle();
    expect(result!.point, const LatLng(-8, 111));
    expect(result!.address, 'Alamat manual terbaru');
  });

  testWidgets('picker cancellation returns no draft and does not save',
      (tester) async {
    final log = <http.Request>[];
    final session =
        await adminSession((_) async => jsonResponse({'data': {}}), log: log);
    DestinationLocationDraft? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<DestinationLocationDraft>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DestinationLocationPickerScreen(
                              initialPoint: const LatLng(-7, 110),
                              initialAddress: 'Alamat tersimpan',
                              repository: repositoryFor(session),
                              session: session)));
                },
                child: const Text('Pilih')))));
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('picker-address')), 'Draft dibuang');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(log, isEmpty);
  });
}
