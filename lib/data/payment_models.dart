import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'refund_models.dart';

export 'refund_models.dart';

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

  /// The attempt is still unresolved after its absolute payment instruction expired. The customer must not
  /// be told it failed or expired, and must not be offered a new payment.
  bool get verificationPending => lastAttempt?['verification_pending'] == true;

  /// The unresolved attempt was handed to the manager.
  bool get escalated => lastAttempt?['escalated'] == true;
  bool get demoAvailable =>
      json['can_pay'] == true &&
      isDemo &&
      json['methods'] is List &&
      (json['methods'] as List).any((method) =>
          method is Map &&
          method['code'] == 'demo' &&
          method['available'] == true);
  String get reason => paymentReason(json['reason'] as String?);

  bool get isMidtrans => json['provider'] == 'midtrans';

  /// Midtrans, or a historical DOKU ledger that stays readable (never payable from the app).
  bool get isRealPayment =>
      (isMidtrans || json['provider'] == 'doku') &&
      ((json['environment'] == 'sandbox' && json['test_only'] == true) ||
          (json['environment'] == 'production' && json['test_only'] == false));
  DateTime? get serverTime => _time(json['server_time']);

  /// Latest refund request (`refund_request`), or null when none was made. A malformed object is
  /// an invalid response, never an empty refund.
  RefundRequest? get refundRequest {
    final value = json['refund_request'];
    if (value == null) return null;
    if (value is! Json) {
      throw const ApiException(
          'Respons pengembalian dana tidak valid.', null, 'invalid_response');
    }
    return RefundRequest(value);
  }

  String get bookingStatus => json['booking_status'] as String? ?? '';
  String get paymentStatus => json['payment_status'] as String? ?? 'unverified';
  String? get attemptMethod => lastAttempt?['method'] as String?;
  String? get attemptChannel => lastAttempt?['channel'] as String?;
  Json? get instruction =>
      json['instruction'] is Json ? json['instruction'] as Json : null;

  // v3 additive contract. Every value is nullable: a missing amount or time is never zero.
  String? get invoiceNumber => _text('invoice_number');
  String? get bookingNumber => _text('booking_number');
  int? get quantity => _int('quantity');
  int? get unitPrice => _int('unit_price');
  int? get subtotal => _int('subtotal');
  int? get serviceFee => _int('service_fee');

  /// `total_amount`, else the legacy `amount`; both come from Laravel.
  int? get totalAmount => _int('total_amount') ?? _int('amount');
  DateTime? get paidAt => _time(json['paid_at']);
  String? get appliedAttemptGuid => _text('applied_attempt_guid');
  bool get receiptAvailable => json['receipt_available'] == true;
  bool get canCreate => json['can_create'] == true;
  bool get canSwitch => json['can_switch'] == true;
  String? get switchReason => _text('switch_reason');

  /// Booking deadline (top level `expires_at` on GET). Every attempt shares this deadline.
  DateTime? get bookingExpiresAt => _time(json['expires_at']);

  /// Absolute server time the unfinished attempt stops being payable.
  DateTime? get attemptExpiresAt => _time(lastAttempt?['expires_at']);
  String? get instructionType => instruction?['presentation_type'] as String?;
  String? get vaNumber {
    if (instructionType != 'virtual_account') return null;
    final value = instruction?['va_number'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String? get bankCode => instruction?['bank_code'] as String?;

  /// True when the server holds a provider QR payload; the image itself is fetched from the QR endpoint.
  bool get hasQrPayload =>
      instructionType == 'qr_payload' &&
      instruction?['qr_content'] is String &&
      (instruction!['qr_content'] as String).isNotEmpty;

  bool get hasQrImage =>
      isMidtrans &&
      instructionType == 'qr_image' &&
      instruction?['image_available'] == true &&
      instruction?['image_content_type'] == 'image/png';

  /// BCA/BNI virtual accounts and QRIS are the only choices a new payment can use; the server decides
  /// availability. Wallets are deliberately absent from this list.
  List<PayChoice> get payChoices {
    final list = json['methods'];
    final methods = list is List ? list : const [];
    return [
      for (final spec in PayChoice.supported)
        PayChoice(spec.$1, spec.$2, _choiceAvailable(methods, spec.$1, spec.$2),
            _choiceReason(methods, spec.$1, spec.$2))
    ];
  }

  Map? _family(List methods, String code) {
    for (final method in methods) {
      if (method is Map && method['code'] == code) return method;
    }
    return null;
  }

  Map? _channel(List methods, String code, String channel) {
    final channels = _family(methods, code)?['channels'];
    if (channels is List) {
      for (final item in channels) {
        if (item is Map && item['channel'] == channel) return item;
      }
    }
    return null;
  }

  bool _choiceAvailable(List methods, String code, String channel) =>
      isRealPayment &&
      json['can_pay'] == true &&
      _family(methods, code)?['available'] == true &&
      _channel(methods, code, channel)?['available'] == true;

  String? _choiceReason(List methods, String code, String channel) {
    if (_choiceAvailable(methods, code, channel)) return null;
    for (final candidate in [
      _channel(methods, code, channel)?['reason'],
      _family(methods, code)?['reason'],
      json['reason'],
    ]) {
      if (candidate is String && candidate.isNotEmpty) return candidate;
    }
    return 'channel_unavailable';
  }

  String? _text(String key) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _int(String key) {
    final value = json[key];
    return value is num ? value.toInt() : null;
  }

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// One payable BCA/BNI VA / QRIS option as the server reports it.
class PayChoice {
  const PayChoice(this.methodCode, this.channel, this.available, this.reason);
  final String methodCode;
  final String channel;
  final bool available;
  final String? reason;

  /// Order shown to the customer: virtual account first, then QRIS.
  static const supported = [
    ('virtual_account', 'bca'),
    ('virtual_account', 'bni'),
    ('qris', 'qris'),
  ];
  String get key => '$methodCode/$channel';
  String get label => methodCode == 'qris'
      ? 'QRIS'
      : 'Virtual Account ${channel.toUpperCase()}';
  String get subtitle => methodCode == 'qris'
      ? 'Pindai kode QR dengan aplikasi bank atau dompet digital yang mendukung QRIS.'
      : 'Bayar ke nomor virtual account ${channel.toUpperCase()} lewat m-banking, internet banking, atau ATM.';
}

/// Customer label for a method/channel pair, including legacy wallet attempts.
String paymentMethodLabel(String? method, String? channel) =>
    switch ((method, channel)) {
      ('virtual_account', 'bni') => 'BNI Virtual Account',
      ('virtual_account', 'bca') => 'BCA Virtual Account',
      ('virtual_account', final bank?) =>
        'Virtual Account ${bank.toUpperCase()}',
      ('qris', _) => 'QRIS',
      ('ewallet', 'dana') => 'DANA',
      ('ewallet', 'shopeepay') => 'ShopeePay',
      _ => 'Pembayaran online',
    };

String formatMoney(int amount, [String currency = 'IDR']) {
  final digits = amount
      .abs()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final sign = amount < 0 ? '-' : '';
  return currency == 'IDR' ? '${sign}Rp$digits' : '$currency $sign$digits';
}

/// Customer wording for a v3 channel or booking reason. Unknown codes are shown, not guessed.
String payChoiceReason(String? reason) => switch (reason) {
      'provider_expiry_window_unverified' =>
        'Metode ini belum dapat dipakai karena batas waktu pembayaran dari penyedia belum terverifikasi.',
      'channel_contract_unverified' ||
      'channel_not_verified' ||
      'channel_not_implemented' ||
      'channel_unavailable' ||
      null =>
        'Metode ini belum tersedia saat ini.',
      _ => paymentReason(reason),
    };

String switchReasonText(String? reason) => switch (reason) {
      'payment_attempt_unresolved' =>
        'Metode pembayaran tidak dapat diganti selama pembayaran sebelumnya masih berjalan. Selesaikan pembayaran atau tunggu hingga kedaluwarsa.',
      _ =>
        'Metode pembayaran tidak dapat diganti untuk pembayaran ini. Selesaikan pembayaran atau tunggu hingga kedaluwarsa.',
    };

String paymentReason(String? reason) => switch (reason) {
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
      'payment_needs_review' =>
        'Pembayaran sedang diperiksa pengelola. Tidak perlu membayar ulang.',
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
