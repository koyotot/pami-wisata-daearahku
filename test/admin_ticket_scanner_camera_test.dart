import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:wisata_daerahku/screens/admin_ticket_scanner_screen.dart';
import 'admin_test_support.dart';

class _CameraPlatform extends MethodChannelMobileScanner {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  bool running = false;
  final operations = <String>[];

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Stream<DeviceOrientation> get deviceOrientationChangedStream =>
      const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    operations.add('start');
    running = true;
    return const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(640, 480));
  }

  @override
  Future<void> stop({bool force = false}) async {
    operations.add(force ? 'mount-stop' : 'stop');
    running = false;
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('rescan restarts camera after scanner mounts, repeatedly',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final original = MobileScannerPlatform.instance;
    final camera = _CameraPlatform();
    MobileScannerPlatform.instance = camera;
    addTearDown(() async {
      MobileScannerPlatform.instance = original;
      await camera.captures.close();
    });
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/scope')) {
        return jsonResponse({
          'data': {
            'global': false,
            'destinations': [
              {'guid': 'd1'}
            ]
          }
        });
      }
      return jsonResponse({'message': 'QR tidak valid'}, 422);
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                AdminTicketScannerScreen(repository: repositoryFor(session)))));
    await tester.pumpAndSettle();
    expect(camera.running, isTrue);
    for (var scan = 0; scan < 2; scan++) {
      camera.captures.add(
          BarcodeCapture(barcodes: [Barcode(rawValue: 'WDR1.fixture-$scan')]));
      await tester.pumpAndSettle();
      expect(camera.running, isFalse);
      expect(find.text('Scan ulang'), findsOneWidget);
      camera.operations.clear();
      await tester.tap(find.text('Scan ulang'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(camera.operations, ['mount-stop', 'start']);
      expect(camera.running, isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
