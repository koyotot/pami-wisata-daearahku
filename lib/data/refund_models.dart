import '../services/api_client.dart';
import '../services/auth_session.dart';

const refundReasonMinLength = 5;
const refundReasonMaxLength = 500;

/// One customer refund request as Laravel reports it. Money was returned only for `refunded`
/// (verified with the payment provider) and `manual_refunded` (transferred by the manager and recorded
/// with proof, NOT an automatic DOKU refund); [isClosedRefund] covers both.
class RefundRequest {
  RefundRequest(this.json) {
    if (json['guid'] is! String ||
        (json['guid'] as String).isEmpty ||
        json['status'] is! String ||
        (json['status'] as String).isEmpty) {
      throw const ApiException(
          'Respons pengembalian dana tidak valid.', null, 'invalid_response');
    }
  }
  final Json json;

  /// Requests that are still being handled; a new one cannot be filed meanwhile.
  static const activeStatuses = {
    'requested',
    'approved',
    'manual_action_required',
    'refund_pending',
    'needs_review',
  };

  String get guid => json['guid'] as String;
  String get status => json['status'] as String;
  String? get reason => _text('reason');
  String? get decisionNote => _text('decision_note');
  String? get currency => _text('currency');
  int? get amount {
    final value = json['amount'];
    return value is num ? value.toInt() : null;
  }

  DateTime? get requestedAt => _time('requested_at');
  DateTime? get decidedAt => _time('decided_at');
  DateTime? get refundedAt => _time('refunded_at');

  /// `provider` or `manual`; anything else (or null, on an older server) is unknown.
  String? get channel {
    final value = _text('refund_channel');
    return value == 'provider' || value == 'manual' ? value : null;
  }

  bool get isActive => activeStatuses.contains(status);

  /// Provider-verified refund.
  bool get isRefunded => status == 'refunded';

  /// Refund transferred manually by the manager and recorded with proof.
  bool get isManualRefunded => status == 'manual_refunded';

  /// Terminal: money came back, by either route. No request can be filed afterwards.
  bool get isClosedRefund => isRefunded || isManualRefunded;
  bool get isRejected => status == 'rejected';

  /// Short badge text. "Dana dikembalikan" is reserved for `refunded`.
  String get statusLabel => switch (status) {
        'requested' || 'needs_review' => 'Sedang ditinjau',
        'approved' || 'manual_action_required' => 'Disetujui, diproses manual',
        'refund_pending' => 'Sedang diproses',
        'rejected' => 'Ditolak',
        'refunded' => 'Dana dikembalikan',
        'manual_refunded' => 'Dana dikembalikan manual',
        _ => 'Status diperiksa',
      };

  String get title => switch (status) {
        'requested' || 'needs_review' => 'Pengajuan Sedang Ditinjau',
        'approved' || 'manual_action_required' => 'Disetujui, Diproses Manual',
        'refund_pending' => 'Pengembalian Sedang Diproses',
        'rejected' => 'Pengajuan Ditolak',
        'refunded' => 'Dana Dikembalikan',
        'manual_refunded' => 'Dana Dikembalikan Manual',
        _ => 'Status Pengajuan Diperiksa',
      };

  /// Server wording is the primary copy, except when it claims a return for any status other than
  /// `refunded`: the customer must never be told money came back before it did.
  String get message {
    // Fixed wording: the server text is never allowed to describe a manual refund as a DOKU one.
    if (isManualRefunded) {
      return 'Dana dikembalikan manual oleh pengelola. Ini bukan pengembalian otomatis melalui DOKU.';
    }
    final server = _text('message');
    if (server != null && (isRefunded || !_claimsReturn(server))) return server;
    return switch (status) {
      'requested' || 'needs_review' =>
        'Pengajuan Anda sedang ditinjau pengelola. Dana belum Anda terima.',
      'approved' || 'manual_action_required' =>
        'Pengajuan disetujui dan sedang diproses manual oleh pengelola. Proses belum selesai; dana belum Anda terima.',
      'refund_pending' =>
        'Pengembalian dana sedang diproses. Dana belum Anda terima sampai statusnya selesai.',
      'rejected' => 'Pengajuan pengembalian dana ditolak.',
      'refunded' => 'Dana telah dikembalikan.',
      _ => 'Status pengajuan sedang diperiksa.',
    };
  }

  static final _returnClaim = RegExp(
      r'dikembalikan|dikirim ke rekening|sudah kembali|telah kembali|dana kembali|refunded',
      caseSensitive: false);
  static final _negation =
      RegExp(r'\b(belum|tidak|bukan|akan)\b', caseSensitive: false);
  static bool _claimsReturn(String text) =>
      _returnClaim.hasMatch(text) && !_negation.hasMatch(text);

  String? _text(String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  DateTime? _time(String key) {
    final value = json[key];
    return value is String ? DateTime.tryParse(value) : null;
  }
}

/// Null when [reason] (trimmed) is 5 to 500 characters.
String? validateRefundReason(String reason) {
  final length = reason.trim().length;
  if (length < refundReasonMinLength) {
    return 'Alasan minimal $refundReasonMinLength karakter.';
  }
  if (length > refundReasonMaxLength) {
    return 'Alasan maksimal $refundReasonMaxLength karakter.';
  }
  return null;
}

/// Indonesian message for a failed refund read or request, keyed on the stable Laravel `code`.
String refundErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'Pengajuan belum dapat dipastikan. Periksa kembali statusnya.';
  }
  switch (error.code) {
    case 'refund_already_requested':
      return 'Pengembalian dana untuk booking ini sudah pernah diajukan. Periksa statusnya di bawah.';
    case 'refund_not_available':
      return 'Pengembalian dana tidak tersedia untuk booking ini.';
    case 'ticket_already_used':
      return 'Tiket sudah dipakai sehingga tidak dapat diajukan pengembalian dana.';
    case 'idempotency_conflict':
      return 'Pengajuan sebelumnya memakai alasan yang berbeda. Tutup formulir lalu ajukan ulang.';
  }
  if (error.outcomeUnknown) {
    return 'Koneksi terputus atau respons belum pasti. Kirim ulang dengan alasan yang sama; pengajuan tidak terkirim ganda.';
  }
  return switch (error.status) {
    401 => 'Sesi berakhir. Silakan masuk kembali.',
    404 => 'Booking tidak ditemukan atau tidak dapat diakses.',
    422 => 'Alasan belum valid. Isi $refundReasonMinLength sampai $refundReasonMaxLength karakter.',
    429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
    _ => error.message,
  };
}
