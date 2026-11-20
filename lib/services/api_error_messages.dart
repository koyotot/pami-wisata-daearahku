const unknownMutationMessage =
    'Hasil belum diketahui. Periksa status sebelum mencoba lagi.';

String? apiDomainMessage(String? code, Map<String, dynamic>? context) {
  switch (code) {
    case 'quota_unavailable':
      return 'Kuota kunjungan untuk tanggal ini belum tersedia, atau destinasi '
          'sedang tidak menerima pendaftaran. Pilih tanggal lain.';
    case 'insufficient_capacity':
      final value = context?['remaining'];
      final remaining = value is num && value.isFinite ? value.toInt() : null;
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
    case 'booking_already_paid':
      return 'Pembayaran sudah diterima sehingga pendaftaran tidak dapat dibatalkan.';
    case 'payment_verification_pending':
      return 'Pembayaran sedang diverifikasi sehingga pendaftaran belum dapat dibatalkan. Coba lagi sebentar.';
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
  return switch (code) {
    'own_role_or_status_change' =>
      'Anda tidak dapat mengubah peran atau status akun sendiri.',
    'last_superadmin_role_change' =>
      'Superadmin aktif terakhir tidak dapat dinonaktifkan atau diturunkan perannya.',
    'reauthentication_failed' =>
      'Verifikasi gagal. Periksa kata sandi atau masuk lagi dengan akun Google yang sama.',
    'last_active_superadmin' =>
      'Akun ini adalah Superadmin aktif terakhir dan tidak dapat ditutup.',
    'invalid_reset_otp' =>
      'Kode salah, kedaluwarsa, atau sudah digunakan. Periksa kode atau minta kode baru.',
    'invalid_reset_ticket' => 'Kode reset tidak berlaku. Minta kode OTP baru.',
    _ => null,
  };
}

String? apiFieldMessage(String field) => switch (field) {
      'name' || 'visitor_name' => 'Periksa nama yang diisi.',
      'email' || 'visitor_email' => 'Periksa alamat email.',
      'phone' || 'visitor_phone' => 'Periksa nomor telepon.',
      'password' => 'Periksa kata sandi.',
      'password_confirmation' => 'Periksa konfirmasi kata sandi.',
      'otp' => 'Periksa kode OTP.',
      'reset_ticket' => 'Kode reset tidak berlaku. Minta kode OTP baru.',
      'id_token' => 'Verifikasi lagi dengan Google.',
      'visit_date' => 'Periksa tanggal kunjungan.',
      'quantity' => 'Periksa jumlah pengunjung.',
      'notes' => 'Periksa catatan yang diisi.',
      'latitude' => 'Periksa koordinat lintang.',
      'longitude' => 'Periksa koordinat bujur.',
      'address' => 'Periksa alamat.',
      _ => null,
    };

String apiStatusMessage(int status, String path, int? retryAfter) =>
    switch (status) {
      401 when path == 'auth/login' =>
        'Email atau kata sandi salah. Periksa kembali isian Anda.',
      401 when path == 'auth/google' =>
        'Identitas Google tidak dapat diverifikasi. Masuk lagi dengan Google.',
      401 => 'Sesi berakhir. Silakan masuk kembali.',
      403 => 'Anda tidak memiliki akses untuk tindakan ini.',
      404 => 'Data sudah tidak tersedia.',
      409 => 'Data sudah berubah. Muat ulang untuk melihat kondisi terbaru.',
      422 => 'Periksa kembali data yang diisi.',
      429 when retryAfter != null && retryAfter > 0 =>
        'Terlalu banyak percobaan. Coba lagi dalam $retryAfter detik.',
      429 => 'Terlalu banyak percobaan. Coba lagi nanti.',
      >= 500 => 'Layanan sedang bermasalah. Muat ulang nanti.',
      _ => 'Permintaan belum dapat diproses.',
    };
