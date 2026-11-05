import '../services/api_client.dart';
import '../services/auth_session.dart';

class BookingTicket {
  final Json json;
  BookingTicket(this.json);
  String get guid => json['guid'] as String;
  int get sequence => (json['sequence'] as num).toInt();
  bool get checkedIn => json['status'] == 'checked_in';
  bool get qrAvailable => json['qr_available'] == true;
  String? get checkedInAt => json['checked_in_at'] as String?;
}

class BookingTickets {
  final Json json;
  BookingTickets(this.json);
  String get bookingGuid => json['booking_guid'] as String;
  String get state => json['ticket_state'] as String;
  String get availableFrom => json['qr_available_from'] as String? ?? '';
  String get timezone => json['timezone'] as String? ?? '';
  bool get paymentTestOnly => json['payment_test_only'] == true;
  String? get paymentLabel => json['payment_label'] as String?;
  int get quantity => (json['quantity'] as num).toInt();
  int get checkedInCount => (json['checked_in_count'] as num).toInt();
  List<BookingTicket> get tickets =>
      (json['tickets'] as List).cast<Json>().map(BookingTicket.new).toList();
  String get message => switch (state) {
        'awaiting_payment' => 'Menunggu pembayaran terverifikasi',
        'awaiting_approval' => 'Menunggu persetujuan pengelola',
        'scheduled' => 'QR tersedia pada $availableFrom ($timezone)',
        'expired' => 'Masa kunjungan telah berakhir',
        'revoked' => 'Tiket tidak dapat digunakan',
        'fully_checked_in' => 'Seluruh tiket sudah check-in',
        _ =>
          'Tunjukkan QR tiket yang dipilih kepada petugas pada hari kunjungan',
      };
}

String ticketErrorMessage(Object error) {
  if (error is! ApiException) return 'Tiket belum dapat diproses. Coba lagi.';
  return switch (error.code) {
    'payment_not_paid' => 'Pembayaran belum terverifikasi lunas.',
    'booking_not_approved' => 'Booking belum disetujui.',
    'ticket_already_checked_in' => 'Tiket ini sudah check-in.',
    'wrong_visit_date' ||
    'ticket_expired' =>
      'Check-in hanya pada tanggal kunjungan menurut waktu destinasi.',
    'ticket_not_issued' => 'QR tiket belum tersedia.',
    'ticket_revoked' => 'Tiket sudah tidak berlaku.',
    'invalid_qr' => 'QR tidak valid. Pindai QR tiket Wisata Daerahku.',
    'ticket_out_of_scope' => 'Anda tidak ditugaskan ke destinasi tiket ini.',
    'idempotency_conflict' =>
      'Permintaan berbeda dengan konfirmasi sebelumnya. Pindai ulang.',
    'network' ||
    'timeout' =>
      'Koneksi terputus. Internet diperlukan untuk memverifikasi tiket.',
    _ => switch (error.status) {
        401 => 'Sesi berakhir. Silakan masuk kembali.',
        403 => 'Anda tidak memiliki akses untuk tiket ini.',
        429 => 'Terlalu banyak permintaan. Tunggu sebentar dan coba lagi.',
        _ => 'Tiket belum dapat diproses. Coba lagi.',
      },
  };
}
