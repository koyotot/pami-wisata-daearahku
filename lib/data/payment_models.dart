import '../services/api_client.dart';
import '../services/auth_session.dart';

/// GET status belongs to the intent; only last_attempt.status belongs to an attempt.
class PaymentSnapshot {
  PaymentSnapshot(this.json) {
    final attempt = json['last_attempt'];
    if (json['booking_guid'] is! String ||
        (json['booking_guid'] as String).isEmpty ||
        json['amount'] is! num ||
        json['currency'] is! String ||
        (json['status'] != null && json['status'] is! String) ||
        (attempt != null &&
            (attempt is! Json ||
                attempt['attempt_guid'] is! String ||
                attempt['status'] is! String))) {
      throw const ApiException(
          'Respons pembayaran tidak valid.', null, 'invalid_response');
    }
  }
  final Json json;
  String get bookingGuid => json['booking_guid'] as String;
  bool get isDemo =>
      json['provider'] == 'demo' &&
      json['environment'] == 'demo' &&
      json['test_only'] == true;
  String get intentStatus => json['status'] as String? ?? 'unknown';
  Json? get lastAttempt =>
      json['last_attempt'] is Json ? json['last_attempt'] as Json : null;
  String? get attemptGuid => lastAttempt?['attempt_guid'] as String?;
  String? get attemptStatus => lastAttempt?['status'] as String?;
  bool get demoAvailable =>
      json['can_pay'] == true &&
      isDemo &&
      json['methods'] is List &&
      (json['methods'] as List).any((method) =>
          method is Map &&
          method['code'] == 'demo' &&
          method['available'] == true);
  String get reason => paymentReason(json['reason'] as String?);
}

String paymentReason(String? reason) => switch (reason) {
      'doku_not_configured' =>
        'Pembayaran belum tersedia. Simulator DEMO belum diaktifkan pada server.',
      'booking_not_awaiting_payment' =>
        'Booking ini tidak sedang menunggu pembayaran.',
      'booking_not_payable' => 'Booking ini tidak memerlukan pembayaran DEMO.',
      'unsupported_currency' => 'Mata uang booking belum didukung simulator.',
      'payment_window_closed' =>
        'Batas pembayaran telah berakhir. Periksa status booking terbaru.',
      'visit_window_closed' =>
        'Waktu pembayaran untuk kunjungan ini telah berakhir.',
      'payment_provider_conflict' =>
        'Booking terhubung ke sumber pembayaran lain. Hubungi pengelola.',
      null => 'Pembayaran DEMO tersedia; tidak ada transfer uang nyata.',
      _ => 'Pembayaran belum tersedia ($reason).',
    };

String paymentError(Object error) {
  if (error is! ApiException) {
    return 'Status pembayaran belum dapat dipastikan. Periksa kembali sebelum melanjutkan.';
  }
  return switch (error.status) {
    401 => 'Sesi berakhir. Silakan masuk kembali.',
    403 ||
    404 =>
      'Pembayaran tidak dapat diakses. Hak akses atau gate simulator mungkin berubah.',
    409 =>
      'Status pembayaran berubah. Periksa hasil terbaru sebelum melanjutkan.',
    422 =>
      'Permintaan ditolak. Booking atau percobaan ini tidak lagi memenuhi syarat pembayaran.',
    429 =>
      'Terlalu banyak permintaan. Tunggu sebentar lalu periksa status kembali.',
    _ => error.outcomeUnknown
        ? 'Koneksi terputus atau respons belum pasti. Periksa status; pembayaran tidak diulang otomatis.'
        : error.message,
  };
}
