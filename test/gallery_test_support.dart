import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
