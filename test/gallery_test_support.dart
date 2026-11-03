import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/widgets/destination_location_map_preview.dart';

const galleryImageJson = {
  'guid': 'image-1',
  'sequence': 1,
  'urls': {
    'thumbnail': 'destinations/created-1/images/image-1/thumbnail',
    'display': 'destinations/created-1/images/image-1/display',
    'fullscreen': 'destinations/created-1/images/image-1/fullscreen'
  },
};
final galleryPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

Future<void> pickDraftLocation(WidgetTester tester,
    {String address = 'Makassar'}) async {
  await tester.tap(find.text('Pilih Titik Lokasi'));
  await tester.pumpAndSettle();
  tester
      .widget<DestinationLocationMap>(find.byType(DestinationLocationMap))
      .onTap!(const LatLng(-5.14, 119.41));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump();
  await tester.enterText(find.byKey(const ValueKey('picker-address')), address);
  await tester.tap(find.text('Gunakan Lokasi Ini'));
  await tester.pumpAndSettle();
}

Future<void> pickGalleryPhoto(WidgetTester tester) async {
  late Directory directory;
  late File file;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('gallery-test-');
    file = File('${directory.path}/photo.png');
    await file.writeAsBytes(galleryPng);
  });
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel,
          (call) async => call.method == 'pickMultiImage' ? [file.path] : null);
  addTearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  await tester.tap(find.text('Tambah Foto'));
  await tester.pump();
  for (var i = 0; i < 20 && find.text('1/10 foto').evaluate().isEmpty; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.text('1/10 foto'), findsOneWidget);
}
