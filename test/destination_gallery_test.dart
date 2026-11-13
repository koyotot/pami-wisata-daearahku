import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/gallery_draft.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/widgets/api_image.dart';
import 'package:wisata_daerahku/widgets/admin_destination_gallery_editor.dart';
import 'package:wisata_daerahku/widgets/destination_hero_gallery.dart';
import 'admin_test_support.dart';
import 'gallery_test_support.dart';

List<DestinationImage> pictures() => List.generate(
    3,
    (i) => DestinationImage({
          'guid': 'photo-$i',
          'sequence': i + 1,
          'urls': {
            'thumbnail': 'destinations/d/images/photo-$i/thumbnail',
            'display': 'destinations/d/images/photo-$i/display',
            'fullscreen': 'destinations/d/images/photo-$i/fullscreen'
          }
        }));

void main() {
  setUp(ApiImage.clearCache);
  test(
      'gallery parser orders photos and respects explicit empty legacy gallery',
      () {
    final old = Destination({'guid': 'd', 'name': 'D', 'image_url': 'old?v=1'});
    expect(old.images.single.url('display'), 'old?v=1');
    expect(
        Destination({...old.json, 'gallery_version': 1, 'images': []}).images,
        isEmpty);
    final d = Destination({
      ...old.json,
      'gallery_version': 7,
      'images': pictures().reversed.map((e) => e.json).toList()
    });
    expect(d.images.map((e) => e.sequence), [1, 2, 3]);
    expect(d.galleryVersion, 7);
  });
  test('draft operation IDs are UUIDs and image manifest keeps ownership IDs',
      () {
    final item =
        GalleryDraftItem.upload(Uint8List.fromList(galleryPng), 'photo.png');
    expect(
        item.key,
        matches(RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$')));
    expect(item.manifest, {'upload_key': item.key});
    expect(GalleryDraftItem.existing(pictures().first).manifest,
        {'image_guid': 'photo-0'});
  });
  test(
      'gallery transport retains idempotency key, manifest and authenticated media suffix',
      () async {
    final requests = <http.Request>[];
    final session = await adminSession((r) async {
      if (r.method == 'GET') {
        return http.Response.bytes(galleryPng, 200,
            headers: {'content-type': 'image/png'});
      }
      return jsonResponse({
        'data': {'guid': 'd', 'name': 'D', 'gallery_version': 2, 'images': []}
      });
    }, log: requests);
    final repository = repositoryFor(session);
    for (var i = 0; i < 2; i++) {
      await repository.saveDestinationGallery(
          guid: 'd',
          fields: {'name': 'D'},
          galleryVersion: 1,
          manifest: [
            {'image_guid': 'photo-1'},
            {'upload_key': 'new'}
          ],
          files: [UploadFile('new_images[new]', galleryPng, 'photo.png')],
          idempotencyKey: 'same-key');
    }
    expect(requests[0].headers['Idempotency-Key'], 'same-key');
    expect(requests[1].headers['Idempotency-Key'], 'same-key');
    expect(requests[0].headers['Authorization'], 'Bearer access');
    expect(latin1.decode(requests[0].bodyBytes), contains('gallery_version'));
    expect(latin1.decode(requests[0].bodyBytes), contains('new_images[new]'));
    await repository.adminImageBytes('d', pictures().first.url('fullscreen'));
    expect(requests.last.url.path,
        '/api/v1/admin/destinations/d/images/photo-0/fullscreen');
  });
  testWidgets('cover plus four-column thumbnails reorder on long press',
      (tester) async {
    final session = await adminSession((_) async => http.Response.bytes(
        galleryPng, 200,
        headers: {'content-type': 'image/png'}));
    final items = pictures().map(GalleryDraftItem.existing).toList();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => SizedBox(
                    width: 390,
                    child: AdminDestinationGalleryEditor(
                        items: items,
                        enabled: true,
                        onAdd: () {},
                        onRemove: (i) => setState(() => items.removeAt(i)),
                        onReorder: (a, b) => setState(() {
                              items.insert(b, items.removeAt(a));
                            }),
                        destinationGuid: 'd',
                        repository: repositoryFor(session)))))));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        4);
    expect(find.text('3 dari 10 foto'), findsOneWidget);
    final from = tester.getCenter(find.byType(LongPressDraggable<int>).first);
    final to = tester.getCenter(find.byType(LongPressDraggable<int>).last);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(items.map((e) => e.key), ['photo-1', 'photo-2', 'photo-0']);
    expect(find.text('Foto Sampul'), findsOneWidget);
  });
  testWidgets(
      'carousel index fullscreen thumbnail zoom and return stay synchronized',
      (tester) async {
    final session = await adminSession((_) async => http.Response.bytes(
        galleryPng, 200,
        headers: {'content-type': 'image/png'}));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 320,
                child: DestinationHeroGallery(
                    images: pictures(), repository: repositoryFor(session))))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenDestinationGallery), findsOneWidget);
    expect(find.text('2 dari 3 foto').last, findsOneWidget);
    await tester.tap(find.byType(InkWell).last);
    await tester.pumpAndSettle();
    expect(find.text('3 dari 3 foto').last, findsOneWidget);
    final viewer = find.byType(InteractiveViewer).last;
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView).last).physics,
        isA<NeverScrollableScrollPhysics>());
    await tester.tap(find.byTooltip('Tutup galeri'));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenDestinationGallery), findsNothing);
    expect(find.text('3 / 3'), findsOneWidget);
  });
  testWidgets('fullscreen swipes unzoomed and zoomed pan stays on same photo',
      (tester) async {
    final session = await adminSession((_) async => http.Response.bytes(
        galleryPng, 200,
        headers: {'content-type': 'image/png'}));
    await tester.pumpWidget(MaterialApp(
        home: FullscreenDestinationGallery(
            images: pictures(),
            initialIndex: 0,
            repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 dari 3 foto'), findsOneWidget);
    final viewer = find.byType(InteractiveViewer).last;
    final center = tester.getCenter(viewer);
    final finger1 =
        await tester.startGesture(center - const Offset(40, 0), pointer: 1);
    final finger2 =
        await tester.startGesture(center + const Offset(40, 0), pointer: 2);
    await tester.pump();
    await finger1.moveTo(center - const Offset(140, 0));
    await finger2.moveTo(center + const Offset(140, 0));
    await tester.pump();
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>());
    await tester.drag(viewer, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 dari 3 foto'), findsOneWidget);
  });
  testWidgets(
      'fullscreen gradual Android-like swipe advances exactly one photo',
      (tester) async {
    final session = await adminSession((_) async => http.Response.bytes(
        galleryPng, 200,
        headers: {'content-type': 'image/png'}));
    await tester.pumpWidget(MaterialApp(
        home: FullscreenDestinationGallery(
            images: pictures(),
            initialIndex: 0,
            repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    Future<void> swipe(Offset start, Offset end) async {
      final gesture = await tester.startGesture(start);
      for (var step = 1; step <= 30; step++) {
        await gesture.moveTo(Offset.lerp(start, end, step / 30)!);
        await tester.pump(const Duration(milliseconds: 15));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await swipe(const Offset(700, 300), const Offset(100, 300));
    expect(find.text('2 dari 3 foto'), findsOneWidget);
    await swipe(const Offset(100, 300), const Offset(700, 300));
    expect(find.text('1 dari 3 foto'), findsOneWidget);
    await swipe(const Offset(100, 300), const Offset(700, 300));
    expect(find.text('1 dari 3 foto'), findsOneWidget,
        reason: 'swipe is bounded at first image');
  });
  testWidgets('legacy empty gallery and single image affordances are safe',
      (tester) async {
    final session =
        await adminSession((_) async => http.Response('broken', 500));
    final repository = repositoryFor(session);
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            height: 320,
            child: DestinationHeroGallery(
                images: const [], repository: repository))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            height: 320,
            child: DestinationHeroGallery(
                key: const ValueKey('one'),
                images: [pictures().first],
                repository: repository))));
    await tester.pumpAndSettle();
    expect(find.text('1 dari 1 foto'), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
