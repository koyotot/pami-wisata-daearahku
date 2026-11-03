import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/widgets/profile_avatar.dart';

void main() {
  testWidgets(
      'saved square preserves visible framing before and after zoom/drag',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1200, 400), Paint()..color = Colors.blue);
    canvas.drawRect(
        const Rect.fromLTWH(0, 400, 1200, 400), Paint()..color = Colors.red);
    final picture = recorder.endRecording();
    final source = (await tester.runAsync(() => picture.toImage(1200, 800)))!;
    picture.dispose();
    final input = (await tester
            .runAsync(() => source.toByteData(format: ui.ImageByteFormat.png)))!
        .buffer
        .asUint8List();
    source.dispose();
    for (final zoom in [false, true]) {
      Uint8List? result;
      const boundaryKey = ValueKey('capture');
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
              home: Builder(
                  builder: (context) => TextButton(
                        onPressed: () async {
                          result = await Navigator.of(context).push<Uint8List>(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      AvatarCropScreen(bytes: input)));
                        },
                        child: const Text('Open'),
                      )))));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final area = tester.getRect(find.byType(InteractiveViewer));
      if (zoom) {
        final left = await tester
            .startGesture(area.center - const Offset(40, 0), pointer: 1);
        final right = await tester
            .startGesture(area.center + const Offset(40, 0), pointer: 2);
        await tester.pump();
        await left.moveTo(area.center - const Offset(70, 0));
        await right.moveTo(area.center + const Offset(70, 0));
        await tester.pump();
        await left.up();
        await right.up();
        expect(viewer.transformationController!.value.entry(0, 0),
            greaterThan(viewer.minScale));
        await tester.drag(find.byType(InteractiveViewer), const Offset(25, 30));
        await tester.pumpAndSettle(const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      }
      final controller = viewer.transformationController!;
      final topLeft = controller.toScene(Offset.zero);
      final bottomRight = controller.toScene(Offset(area.width, area.height));
      expect(topLeft.dx, greaterThanOrEqualTo(-.01));
      expect(topLeft.dy, greaterThanOrEqualTo(-.01));
      expect(bottomRight.dx, lessThanOrEqualTo(1200.01));
      expect(bottomRight.dy, lessThanOrEqualTo(800.01));
      // Compare pixels inside the final circle, away from its edge/antialiasing.
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      final preview =
          (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final previewBytes = (await tester.runAsync(() => preview.toByteData()))!;
      await tester.tap(find.text('Gunakan Foto'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(result, isNotNull);
      final codec =
          (await tester.runAsync(() => ui.instantiateImageCodec(result!)))!;
      final output = (await tester.runAsync(() => codec.getNextFrame()))!.image;
      final outputBytes = (await tester.runAsync(() => output.toByteData()))!;
      expect(output.width, 512);
      expect(output.height, 512);
      for (final fraction in [.25, .75]) {
        final px = area.center.dx.floor();
        final py = (area.top + area.height * fraction).floor();
        final expected = previewBytes.getUint32((py * preview.width + px) * 4);
        final actual =
            outputBytes.getUint32(((512 * fraction).floor() * 512 + 256) * 4);
        expect(actual, expected,
            reason: 'visible pixel at y=$fraction, zoom=$zoom');
      }
      output.dispose();
      codec.dispose();
      preview.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
