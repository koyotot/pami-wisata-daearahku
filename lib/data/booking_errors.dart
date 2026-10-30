import '../services/auth_session.dart';

/// Codes for which the server provably did NOT create a booking for a create request.
/// A fresh local intent is discarded on these (the attempt can never succeed as-is).
const definitiveCreateRejections = {
  'quota_unavailable',
  'insufficient_capacity',
  'booking_window_closed',
  'visit_date_too_close',
  'idempotency_conflict',
};

/// Indonesian message for a booking-related [error].
///
/// Maps the stable Laravel `code` (never only the HTTP status, so 409s are not all alike).
/// [mutation] marks a create/cancel call: an unknown outcome (timeout, network, 5xx or an
/// unreadable response) is then reported as "result unknown" and never as success or failure.
String bookingErrorMessage(Object error, {bool mutation = false}) {
  if (error is! ApiException) {
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  switch (error.code) {
    case 'quota_unavailable':
      return 'Kuota kunjungan untuk tanggal ini belum tersedia, atau destinasi '
          'sedang tidak menerima pendaftaran. Pilih tanggal lain.';
    case 'insufficient_capacity':
      final remaining = _remaining(error);
      if (remaining == null) {
        return 'Sisa kuota tidak mencukupi untuk jumlah pengunjung ini. '
            'Kurangi jumlah pengunjung atau pilih tanggal lain.';
      }
      if (remaining <= 0) {
        return 'Kuota untuk tanggal ini sudah penuh. Pilih tanggal lain.';
      }
      return 'Sisa kuota hanya $remaining orang untuk tanggal ini. '
          'Kurangi jumlah pengunjung atau pilih tanggal lain.';
    case 'booking_window_closed':
      return 'Pendaftaran untuk tanggal ini belum dibuka atau sudah ditutup.';
    case 'visit_date_too_close':
      return 'Tanggal kunjungan terlalu dekat sehingga pendaftaran sudah tidak '
          'diterima. Pilih tanggal yang lebih jauh.';
    case 'idempotency_conflict':
      return 'Percobaan pendaftaran sebelumnya memakai data yang berbeda. '
          'Periksa atau batalkan percobaan tersebut terlebih dahulu.';
    case 'idempotency_key_expired':
      return 'Percobaan pendaftaran sebelumnya sudah kedaluwarsa dan tidak dapat '
          'dikirim ulang. Periksa riwayat pendaftaran atau batalkan percobaan tersebut.';
    case 'idempotency_key_abandoned':
      return 'Percobaan pendaftaran sebelumnya sudah dibatalkan dan tidak dapat '
          'dikirim ulang.';
    case 'intent_already_completed':
      return 'Pendaftaran dari percobaan sebelumnya ternyata sudah terbentuk.';
    case 'booking_not_cancellable':
      return 'Pendaftaran ini sudah diproses sehingga tidak dapat dibatalkan.';
    case 'booking_already_cancelled':
      return 'Pendaftaran ini sudah dibatalkan sebelumnya.';
    case 'check_in_duplicate':
      return 'Pendaftaran ini sudah check-in sebelumnya.';
    case 'check_in_not_eligible':
      return 'Check-in hanya tersedia untuk pendaftaran yang sudah dikonfirmasi.';
    case 'check_in_wrong_date':
      return 'Check-in hanya tersedia pada tanggal kunjungan sesuai zona waktu destinasi.';
    case 'review_duplicate':
      return 'Ulasan untuk pendaftaran ini sudah dikirim.';
    case 'review_not_eligible':
      return 'Ulasan hanya tersedia setelah pendaftaran dikonfirmasi dan sudah check-in.';
  }
  if (error.outcomeUnknown) {
    return mutation
        ? 'Hasil belum diketahui karena koneksi terputus atau layanan tidak '
            'merespons. Periksa hasilnya sebelum mencoba lagi.'
        : error.message;
  }
  return error.message;
}

int? _remaining(ApiException error) {
  final value = error.context?['remaining'];
  return value is num ? value.toInt() : null;
}
