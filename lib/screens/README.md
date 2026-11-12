# lib/screens — peta layar per role

Role diambil dari `AuthSession.role` dan ditentukan oleh `shared/session_destination.dart`:

| Role | Nilai | Masuk ke |
| --- | --- | --- |
| User / wisatawan | `0` | `user/main_navigation_screen.dart` |
| Admin destinasi | `1` | `admin/operations_navigation_shell.dart` |
| Superadmin | `2` | `admin/operations_navigation_shell.dart` + menu tambahan dari `superadmin/` |

Admin dan superadmin memakai **shell operasional yang sama**. Perbedaannya diatur di
dalam shell: tab ke-3 dan ke-4 berbeda menurut role, dan menu *Kelola* superadmin
membuka layar-layar di `superadmin/`. Izin per fitur ada di `lib/data/admin_state.dart`
(`canManageAdmins`, `canManageCategories`, `canManageQuota`, dst.).

```
screens/
├── auth/          sebelum login (semua role)
├── shared/        routing lintas role
├── user/          role 0 — wisatawan
├── admin/         role 1 & 2 — operasional destinasi
│   └── operations_dashboard/   dashboard + part-file-nya
└── superadmin/    role 2 saja — data master & akun
```

## auth/ — sebelum login

| File | Fungsi |
| --- | --- |
| `user_login_screen.dart` | Login email/password dan Google. Satu pintu masuk untuk semua role. |
| `user_register_screen.dart` | Daftar akun wisatawan baru. |
| `verify_email_otp_screen.dart` | Verifikasi email lewat OTP setelah register. |
| `forgot_password_screen.dart` | Minta kode reset password. |
| `verify_reset_otp_screen.dart` | Masukkan OTP reset password. |
| `reset_password_screen.dart` | Buat password baru + layar sukses. |
| `auth_presentation.dart` | Komponen visual bersama auth (`AuthTheme`, shell bergambar, tombol, input OTP). |
| `home_screen.dart` | Halaman sambutan/landing; dipakai setelah logout dari profil. |
| `admin_login.dart` | Alias kompatibilitas → `UserLoginScreen` (login admin sudah disatukan). |

## shared/ — lintas role

| File | Fungsi |
| --- | --- |
| `session_destination.dart` | `sessionDestination()` memilih layar awal berdasarkan status sesi dan role. |
| `ticket_link_screen.dart` | Penangan App Link `/tickets/{uuid}` dari email e-ticket; cek login lalu buka tiket. |

## user/ — wisatawan (role 0)

| File | Fungsi |
| --- | --- |
| `main_navigation_screen.dart` | Shell bottom-nav user: Beranda, Cari, Riwayat, Notifikasi, Profil. |
| `beranda_user_screen.dart` | Beranda: kunjungan terdekat, booking yang perlu tindakan, rekomendasi destinasi. |
| `cari_wisata_screen.dart` | Cari & filter destinasi wisata. |
| `detail_wisata_screen.dart` | Detail destinasi (galeri, fasilitas, ulasan, peta, rute). Juga dipakai admin sebagai preview. |
| `destination_map_screen.dart` | Peta lokasi destinasi layar penuh. |
| `daftar_kunjungan_screen.dart` | Form booking kunjungan: tanggal, jumlah tiket, data pengunjung. |
| `permintaan_terkirim_screen.dart` | Konfirmasi bahwa permintaan booking sudah terkirim. |
| `booking_payment_screen.dart` | Checkout Midtrans native (VA BCA/BNI, QRIS), status pembayaran, refund. |
| `demo_checkout_screen.dart` | Checkout simulasi untuk mode DEMO/TEST. |
| `bukti_pendaftaran_screen.dart` | Riwayat booking (`BuktiPendaftaranScreen`) dan detail tiket + QR (`BookingTicketScreen`). |
| `notifikasi_screen.dart` | Daftar notifikasi/aktivitas booking. |
| `profil_user_screen.dart` | Profil, edit data, favorit, riwayat ulasan, ubah password, logout. |

## admin/ — operasional (role 1 & 2)

| File | Fungsi |
| --- | --- |
| `operations_navigation_shell.dart` | Shell bottom-nav operasional: Beranda, Antrean, Scan/Analitik, Laporan/Kelola, Profil. |
| `admin_dashboard.dart` | Alias kompatibilitas → shell operasional (dengan cek role). |
| `admin_common.dart` | Komponen UI bersama admin (`AdminPage`, chips filter, notice, badge). |
| `operations_queue_screen.dart` | Antrean approval booking yang menunggu keputusan. |
| `operations_booking_screen.dart` | Detail booking + claim, setujui/tolak. |
| `daftar_pendaftar_screen.dart` | Riwayat data pendaftar (entry point lama). |
| `admin_ticket_scanner_screen.dart` | Scan QR tiket untuk check-in pengunjung. |
| `daftar_wisata_screen.dart` | Daftar destinasi yang dikelola (mode lihat / edit / hapus / kuota). |
| `tambah_wisata_screen.dart` | Form tambah/edit destinasi (galeri, fasilitas, lokasi, harga). |
| `destination_location_picker_screen.dart` | Pilih titik lokasi destinasi di peta. |
| `kelola_kuota_screen.dart` | Atur kuota kunjungan per tanggal. |

### admin/operations_dashboard/

Satu library Dart: `operations_dashboard.dart` adalah file utama, sisanya `part of`.
File-file ini harus tetap berada dalam satu folder.

| File | Fungsi |
| --- | --- |
| `operations_dashboard.dart` | `OperationsDashboard` (beranda operasional), `OperationsAnalyticsHub`, `OperationsPage`. |
| `operations_home.dart` | Kartu beranda: kinerja individu, SLA approval, lingkup penugasan. |
| `operations_reports.dart` | Laporan per seksi (destinasi, verifikasi tiket, approval). |
| `operations_financial.dart` | Ringkasan keuangan/transaksi. |
| `operations_filters.dart` | Sheet filter destinasi & periode. |
| `operations_presentation.dart` | Skeleton, metrik, tren, dan state "data belum tersedia". |

## superadmin/ — khusus role 2

Diakses dari menu *Kelola* di shell operasional ketika `session.role == 2`.

| File | Fungsi |
| --- | --- |
| `kelola_admin_screen.dart` | Kelola akun admin: tambah, ubah peran, aktif/nonaktif. |
| `destination_admin_assignments_screen.dart` | Tugaskan admin ke destinasi tertentu. |
| `kelola_kategori_screen.dart` | CRUD kategori destinasi. |
| `kelola_fasilitas_screen.dart` | CRUD master fasilitas destinasi. |
