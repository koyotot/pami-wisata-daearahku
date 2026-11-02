import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class _MemorySessionStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
  @override
  Future<void> clear() async => value = null;
}

void main() {
  const enabled = bool.fromEnvironment('GALLERY_LIVE_TEST');
  const base = String.fromEnvironment('GALLERY_LIVE_URL',
      defaultValue: 'http://127.0.0.1:8099/api/v1');

  test('real Laravel multipart save, ordered media, retry and conflict',
      () async {
    final session = AuthSession(baseUrl: base, store: _MemorySessionStore());
    addTearDown(session.client.close);
    await session.login('gallery-http@example.test', 'password');
    final repository = BusinessRepository(ApiClient(session));
    final page = await repository.adminDestinations();
    final current = page.items.first;
    expect(current.images.length, greaterThanOrEqualTo(2));
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
    final key = '00000000-0000-4000-8000-'
            '${DateTime.now().microsecondsSinceEpoch % 1000000000000}'
        .padLeft(12, '0');
    final manifest = <Json>[
      {'image_guid': current.images.last.guid},
      {'upload_key': 'flutter-photo'},
      {'image_guid': current.images.first.guid},
    ];
    Future<Destination> save() => repository.saveDestinationGallery(
        guid: current.guid,
        fields: {'name': 'Flutter real HTTP gallery'},
        galleryVersion: current.galleryVersion,
        manifest: manifest,
        files: [UploadFile('new_images[flutter-photo]', png, 'flutter.png')],
        idempotencyKey: key);

    final saved = await save();
    expect(saved.images.map((image) => image.sequence), [1, 2, 3]);
    expect(saved.images.first.guid, current.images.last.guid);
    final replay = await save();
    expect(replay.images.map((image) => image.guid),
        saved.images.map((image) => image.guid));
    expect(replay.galleryVersion, saved.galleryVersion);
    final latest = await repository.adminDestination(current.guid);
    expect(latest.galleryVersion, current.galleryVersion + 1);
    for (final image in latest.images) {
      final bytes = await repository.adminImageBytes(
          latest.guid, image.json['urls']['thumbnail'] as String);
      expect(bytes.contentType, startsWith('image/'));
      expect(bytes.bytes, isNotEmpty);
    }
    await expectLater(
        repository.saveDestinationGallery(
            guid: current.guid,
            fields: {},
            galleryVersion: current.galleryVersion,
            manifest: [
              {'image_guid': saved.images.first.guid}
            ],
            files: [],
            idempotencyKey: '00000000-0000-4000-8000-000000000001'),
        throwsA(isA<ApiException>()
            .having((error) => error.status, 'status', 409)));
  },
      skip: !enabled
          ? 'Requires isolated gallery HTTP fixture and server.'
          : false);
}
