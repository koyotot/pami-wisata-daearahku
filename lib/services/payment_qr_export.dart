import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PaymentQrExportResult {
  /// The file was written where the customer chose.
  saved,

  /// The system share sheet opened. The app cannot know whether the customer finished sharing.
  shared,
  cancelled,
  denied,

  /// This platform (or build) has no save/share bridge.
  unavailable,
  failed,
}

/// Saves or shares the payment QR as a PNG. It only ever receives pixels rendered from the server's
/// QR image; it never sees credentials or entry tickets.
abstract class PaymentQrExporter {
  bool get supported;
  Future<PaymentQrExportResult> save(Uint8List png, {required String fileName});
  Future<PaymentQrExportResult> share(Uint8List png,
      {required String fileName});
}

/// Android bridge: a Storage Access Framework "create document" intent for saving and a
/// FileProvider-backed chooser for sharing, so no storage permission is requested.
/// Other targets report `unavailable` instead of pretending to export.
class PlatformPaymentQrExporter implements PaymentQrExporter {
  PlatformPaymentQrExporter({MethodChannel? channel, bool? forceAndroid})
      : _channel = channel ?? const MethodChannel(channelName),
        _android = forceAndroid;

  static const channelName = 'id.wisatadaerahku.app/payment_qr';
  final MethodChannel _channel;
  final bool? _android;

  @override
  bool get supported =>
      _android ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<PaymentQrExportResult> save(Uint8List png,
          {required String fileName}) =>
      _invoke('saveImage', png, fileName);

  @override
  Future<PaymentQrExportResult> share(Uint8List png,
          {required String fileName}) =>
      _invoke('shareImage', png, fileName);

  Future<PaymentQrExportResult> _invoke(
      String method, Uint8List png, String fileName) async {
    if (!supported) return PaymentQrExportResult.unavailable;
    try {
      final result = await _channel.invokeMethod<String>(method, {
        'bytes': png,
        'fileName': fileName,
        'mimeType': 'image/png',
      });
      return switch (result) {
        'saved' => PaymentQrExportResult.saved,
        'shared' => PaymentQrExportResult.shared,
        'cancelled' => PaymentQrExportResult.cancelled,
        _ => PaymentQrExportResult.failed,
      };
    } on MissingPluginException {
      return PaymentQrExportResult.unavailable;
    } on PlatformException catch (error) {
      return switch (error.code) {
        'PERMISSION_DENIED' => PaymentQrExportResult.denied,
        'CANCELLED' => PaymentQrExportResult.cancelled,
        'UNAVAILABLE' => PaymentQrExportResult.unavailable,
        _ => PaymentQrExportResult.failed,
      };
    }
  }
}

/// A file name that is safe on every platform and carries no payment data.
String paymentQrFileName(String bookingNumber) {
  final label = bookingNumber.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  return 'qris-${label.isEmpty ? 'pembayaran' : label}.png';
}

/// Rasterises the server-provided SVG onto an opaque white square with a quiet zone, so the exported
/// PNG still scans. Plain SVG bytes in, PNG bytes out.
Future<Uint8List> rasterizePaymentQr(Uint8List svg, {int size = 1024}) async {
  final info = await vg.loadPicture(SvgBytesLoader(svg), null);
  try {
    final quiet = size / 16;
    final inner = size - quiet * 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.translate(quiet, quiet);
    canvas.scale(
        inner / (info.size.width <= 0 ? 1 : info.size.width),
        inner / (info.size.height <= 0 ? 1 : info.size.height));
    canvas.drawPicture(info.picture);
    final image = await recorder.endRecording().toImage(size, size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    info.picture.dispose();
  }
}

/// Customer wording for an export result. `shared` only says the share sheet opened.
String paymentQrExportMessage(PaymentQrExportResult result,
        {required bool saving}) =>
    switch (result) {
      PaymentQrExportResult.saved => 'QR tersimpan.',
      PaymentQrExportResult.shared =>
        'Menu bagikan dibuka. Pilih aplikasi tujuan untuk mengirim QR.',
      PaymentQrExportResult.cancelled => saving
          ? 'Penyimpanan dibatalkan. QR belum disimpan.'
          : 'Pembagian dibatalkan.',
      PaymentQrExportResult.denied =>
        'Tidak ada izin untuk ${saving ? 'menyimpan' : 'membagikan'} QR. Izinkan akses lalu coba lagi.',
      PaymentQrExportResult.unavailable =>
        'Simpan dan bagikan QR belum tersedia di perangkat ini. Tunjukkan QR dari layar ini.',
      PaymentQrExportResult.failed =>
        'QR gagal ${saving ? 'disimpan' : 'dibagikan'}. Coba lagi.',
    };
