import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PaymentQrExportResult {
  /// The file was written where the customer chose.
  saved,

  /// The system share sheet opened. The app cannot know whether the customer finished sharing.
  shared,
  cancelled,
  denied,
  expired,

  /// This platform (or build) has no save/share bridge.
  unavailable,
  failed,
}

/// Saves or shares the payment QR as a PNG. It only ever receives authentic PNG bytes from Laravel's
/// QR endpoint; it never sees credentials or entry tickets.
abstract class PaymentQrExporter {
  bool get supported;
  Future<PaymentQrExportResult> save(Uint8List png,
      {required String fileName, required Duration validFor});
  Future<PaymentQrExportResult> share(Uint8List png,
      {required String fileName, required Duration validFor});
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
          {required String fileName, required Duration validFor}) =>
      _invoke('saveImage', png, fileName, validFor);

  @override
  Future<PaymentQrExportResult> share(Uint8List png,
          {required String fileName, required Duration validFor}) =>
      _invoke('shareImage', png, fileName, validFor);

  Future<PaymentQrExportResult> _invoke(
      String method, Uint8List png, String fileName, Duration validFor) async {
    if (!supported) return PaymentQrExportResult.unavailable;
    if (validFor.inMilliseconds <= 0) return PaymentQrExportResult.expired;
    try {
      final result = await _channel.invokeMethod<String>(method, {
        'bytes': png,
        'fileName': fileName,
        'mimeType': 'image/png',
        'validForMillis': validFor.inMilliseconds,
      });
      return switch (result) {
        'saved' => PaymentQrExportResult.saved,
        'shared' => PaymentQrExportResult.shared,
        'cancelled' => PaymentQrExportResult.cancelled,
        'expired' => PaymentQrExportResult.expired,
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
  final label =
      bookingNumber.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  return 'qris-${label.isEmpty ? 'pembayaran' : label}.png';
}

/// Customer wording for an export result. `shared` only says the share sheet opened.
String paymentQrExportMessage(PaymentQrExportResult result,
        {required bool saving}) =>
    switch (result) {
      PaymentQrExportResult.saved => 'QR tersimpan.',
      PaymentQrExportResult.expired =>
        'Batas pembayaran telah berakhir. QR tidak diekspor.',
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
