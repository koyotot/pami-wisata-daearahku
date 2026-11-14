# DESIGN.md — Standar Desain Wisata Daerahku

Dokumen ini adalah **standar desain yang berlaku sekarang**, disusun dari kode di `lib/`. Versi sebelumnya adalah audit statis untuk aplikasi berbasis Firebase/Firestore saja; isinya sudah tidak sesuai dan diganti. Nilai pada tabel diambil dari sumber yang disebut; yang tidak punya sumber ditandai "tidak ditemukan". Perilaku di perangkat, kontras terukur, dan aksesibilitas belum diverifikasi lewat pengujian.

## 1. Ringkasan

Aplikasi wisata dengan tiga peran, memakai backend Laravel lewat `lib/services/api_client.dart` dan `lib/data/business_repository.dart`. Firebase hanya dipakai untuk inisialisasi dan FCM (`lib/main.dart`, `lib/services/fcm_device_manager.dart`).

| Peran | `session.role` | Label (`adminRoleLabel`) | Shell |
|---|---|---|---|
| Pengunjung | `0` | Pengguna | `screens/user/main_navigation_screen.dart` |
| Admin | `1` | Admin | `screens/admin/operations_navigation_shell.dart` |
| Superadmin | `2` | Superadmin | `screens/admin/operations_navigation_shell.dart` |

**Awas:** di kode, superadmin adalah `role == 2` dan admin biasa adalah `role == 1`. Banyak kondisi `_role == 1` berarti "admin", bukan "superadmin".

Dependency yang relevan untuk UI: `google_fonts` (font), `phosphor_icons` (ikon), `flutter_map`, `latlong2`, `geolocator` (peta), `mobile_scanner` (scan QR), `flutter_svg`, `country_flags`, `phone_numbers_parser` (nomor telepon), `image_picker`.

## 2. Struktur Folder

```text
lib/
  main.dart                  # init Firebase/FCM, restore sesi, MaterialApp + tema
  core/config/               # AppConfig
  data/                      # state (ChangeNotifier), repository, model
  models/                    # model lama (pendaftaran, wisata)
  services/                  # api_client, auth_session, fcm, directions
  theme/
    app_colors.dart          # AppColors, AppSpacing, visitorTheme, operationsTheme
    app_icons.dart           # AppIcons
  widgets/                   # komponen bersama lintas layar (lihat bagian 5)
  screens/
    auth/                    # login, daftar, OTP, lupa/reset password, auth_presentation.dart
    user/                    # alur pengunjung
    admin/                   # operasional (admin + superadmin): dashboard, antrean, booking, kuota, wisata
      operations_dashboard/  # beranda + laporan; satu library dengan `part` (lihat bagian 6)
    superadmin/              # kelola admin, penugasan destinasi, fasilitas, kategori
    shared/                  # session_destination, ticket_link_screen
docs/DESIGN.md
```

Halaman operasional dibagi dengan `part of 'operations_dashboard.dart'`: `operations_filters.dart`, `operations_financial.dart`, `operations_home.dart`, `operations_presentation.dart`, `operations_reports.dart`. Widget privat (`_Nama`) di salah satu part bisa dipakai part lainnya, tetapi tidak dari luar library.

## 3. Design Tokens

### Warna

Sumber utama: `AppColors` di `lib/theme/app_colors.dart`. Peran admin/superadmin memakai warna yang sama; `AdminColors` di `screens/admin/admin_common.dart` adalah duplikat historis dengan nilai hampir sama.

| Token | Nilai | Pemakaian |
|---|---|---|
| `AppColors.blue` | `#1976D2` | aksi utama, ikon aksen, link |
| `AppColors.blueDeep` | `#1558B0` | teks aksen gelap, judul tautan |
| `AppColors.navy` | `#102D59` | teks utama, judul |
| `AppColors.bg` | `#F5F8FD` | latar halaman |
| `AppColors.surface` | putih | kartu, sheet, dock, field |
| `AppColors.border` | `#DCE4F0` | border kartu dan field |
| `AppColors.textSecondary` | `#64748B` | teks pendukung, caption |
| `AppColors.textMuted` | `#728099` | teks redup |
| `AppColors.blueTint` | `#E8F3FF` | latar ikon/aksen biru |
| `AppColors.success` / `successTint` | `#16784C` / `#EDF9F2` | status berhasil |
| `AppColors.warningTint` / `warningBorder` / `warningText` | `#FFF7EA` / `#FFE0AD` / `#98621E` | peringatan |
| `AppColors.orange` | `#FF9800` | aksen oranye |

Palet status (badge dan kartu pemberitahuan) didefinisikan lokal di `screens/admin/operations_booking_screen.dart` (`_toneColors`) dan dipakai sebagai acuan:

| Tone | Latar | Border | Teks | Dipakai untuk |
|---|---|---|---|---|
| orange | `#FFF4DD` | `#F3DDAA` | `#8A5A12` | menunggu / perlu tindakan |
| blue | `#E8F1FD` | `#C9DDF7` | `#1558B0` | informasi, claim aktif |
| red | `#FDECEC` | `#F3C9C9` | `#B23B3B` | ditolak, tindakan berbahaya |
| green | `#E6F6EC` | `#BFE5CC` | `#1E7A45` | disetujui |
| grey | `#EEF1F6` | `#D5DBE6` | `#526787` | dialihkan, selesai, netral |

### Tipografi

Font global **Plus Jakarta Sans** lewat `GoogleFonts.plusJakartaSansTextTheme()` pada `AppColors.visitorTheme` dan `operationsTheme` (`app_colors.dart`). Font diunduh saat runtime oleh `google_fonts`; tidak ada file font lokal di `pubspec.yaml`. Tema operasional menimpa warna teks menjadi navy.

| Peran | Ukuran / weight | Contoh |
|---|---|---|
| Judul AppBar | 18 / w800 | `app_colors.dart` `titleTextStyle` |
| Judul halaman / sheet | 20–22 / w800 | judul sheet "Tindakan Booking" |
| Judul kartu | 16 / w800 | "Informasi Kunjungan", "Data Pengunjung" |
| Sub-judul / heading kecil | 14 / w700 | `_AdminHomeHeading` |
| Label tabel / caption huruf besar | 11 / w700, letterSpacing .8 | "KINERJA INDIVIDU", "PERMINTAAN KUNJUNGAN" |
| Isi / teks pendukung | 12–13, tinggi baris 1.5–1.6 | deskripsi, catatan |
| Tombol | 13 / w800 | tombol sheet dan dock |

Acuan ukuran adalah Beranda Admin. Ukuran setengah (11.5, 12.5, 13.5) tidak dipakai; bulatkan ke 11, 12, atau 13. Angka metrik 26, angka hero 36, tinggi tombol dan kontrol minimal 48. Layar superadmin mengikuti skala ini. `admin_common.dart` (dipakai bersama admin) masih memuat beberapa ukuran setengah.

### Ruang, bentuk, efek, ikon

| Kategori | Standar |
|---|---|
| Spacing | `AppSpacing`: xs 4, sm 8, md 12, lg 16, xl 24. Gutter halaman operasional 16; padding sheet 20. |
| Radius | tombol dan field 12–14; kartu dan panel 14–20; sheet teratas 24; badge 10–12. |
| Border | 1 px `AppColors.border`; kartu tidak memakai bayangan. |
| Elevation | dock bawah `elevation: 8` dengan `shadowColor #22102D59`; AppBar 0. |
| Target sentuh | `operationsTheme` memaksa `minimumSize` 48×48 untuk Filled/Outlined/Text/IconButton. |
| Ikon | **Phosphor** (`PhosphorIconsRegular`), ukuran 15–22 sesuai konteks. Jangan memakai `Icons` Material untuk layar baru. |
| Mode | hanya light; `darkTheme` tidak ditemukan. |
| Tema | `visitorTheme` untuk pengunjung dan auth; `operationsTheme = visitorTheme.copyWith(...)` untuk admin dan superadmin (tanpa splash, tombol minimal 48). Bungkus dengan `OperationsTheme(role:)` untuk sheet yang dibuka di luar halaman. |

`operationsTheme` berlaku untuk admin (`role == 1`) dan superadmin (`role == 2`), baik lewat `builder` di `main.dart` maupun `OperationsTheme(role:)`. Skala teks sistem dibatasi 1.0–1.15 untuk semua peran (`MediaQuery.withClampedTextScaling` di `main.dart`).

## 4. Pola Layout Operasional (Admin & Superadmin)

Urutan standar halaman laporan/beranda, dari atas ke bawah:

1. **Header** (`OperationsPage` / `OperationsScenicHeader`): panah kembali, judul halaman, subjudul.
2. **Filter bar** (`OperationsFilterBar`, `widgets/operations_chrome.dart`).
3. **Tab** bila ada (`OperationsHomeTabs`, `widgets/operations_tabs.dart`; tab segmented pada Kinerja Destinasi).
4. **Kartu ringkasan** besar (contoh `_AdminPersonalSummary`: label huruf besar, angka 36 w800, keterangan).
5. **Metrik** (`OperationsMetrics`): empat kartu berikon, `labelStyle` 11 / w500 navy.
6. **Heading bagian** (`_AdminHomeHeading`) lalu kartu isi (grafik, daftar, pintasan).
7. **Catatan kaki** 11–12, `textSecondary`.

### Filter bar standar

Satu baris, dua kontrol, tinggi minimal 48, radius 12 (`OperationsFilterBar`):

- kiri (flex 2): tombol destinasi, ikon pin biru, label "Semua destinasi" atau nama destinasi, panah turun;
- kanan: tombol periode, ikon kalender biru, label rentang (misal "1–30 Nov"; "Semua tanggal" bila kosong).

Pemakaian saat ini:

| Peran | Halaman dengan filter bar | Periode awal |
|---|---|---|
| Admin (1) | Beranda, Kinerja Destinasi, Kunjungan, Pusat Tindakan | bulan berjalan |
| Superadmin (2) | Beranda, Kinerja Admin, Pusat Tindakan | bulan berjalan |

Sheet pilihan filter memakai varian `home: true` bila `_usesHomeFilters` (`operations_reports.dart`) bernilai benar. Kartu `_ScopeCard` ("Semua destinasi yang dapat diakses · Filter aktif") adalah **desain lama**: jangan dipakai untuk halaman baru.

### Antrean Approval (superadmin)

`screens/admin/operations_queue_screen.dart`, cabang `_superadminBody`. Urutan: tiga kartu statistik (Total antrean, Tersedia, Claim aktif), dua kotak filter bercaption (DESTINASI, TGL BOOKING), kolom cari, tab Semua / Tersedia / Claim aktif, judul "Permintaan Masuk" dengan jumlah hasil dan tombol urut, lalu kartu permintaan.

- Pilihan urut (Tenggat terdekat, Terbaru, Nama A–Z) memakai **bottom sheet**, bukan dropdown/popup menu.
- Kartu: kode (guid dipendekkan `8 karakter…7 karakter`), badge (Claim Anda biru, Tersedia hijau, Claim admin lain abu), nama destinasi, tanggal kunjungan, kotak waktu bertone (biru = claim sendiri, oranye = tersedia, abu = claim admin lain), tombol (Kelola Claim / Tinjau Booking / Lihat Detail).
- Pencarian dan pengurutan berjalan di sisi klien pada baris yang sudah dimuat.
- Data baris dari server hanya berisi guid booking, nama destinasi, tanggal kunjungan, batas persetujuan, dan status claim. Nomor booking, jumlah orang, dan nama pengunjung belum dikirim, jadi tidak ditampilkan. Nama pemilik claim diambil dari daftar akun admin.
- Filter tanggal bekerja pada tanggal pembuatan booking (UTC), bukan tanggal kunjungan, maka captionnya "TGL BOOKING".

### Perbandingan Destinasi (superadmin)

`operations_dashboard/operations_comparison.dart` (`_DestinationComparison`), dipakai `OperationsReportScreen` bila `_isComparison` (role 2, section `destinations`). Urutan: hero gradien "Total Kapasitas Destinasi" (jumlah kapasitas, progress alokasi), tiga kartu total (Dialokasikan, Terkonfirmasi, Sisa kapasitas), kartu CAKUPAN LAPORAN (baris destinasi dan periode, keduanya membuka sheet), judul "Performa per Destinasi" dengan tombol urut (bottom sheet), chip filter berhitung, kartu destinasi, lalu tautan "Kelola destinasi dan kuota".

- Semua halaman destinasi dimuat sekaligus (per_page 100) agar total kapasitas benar; chip, urut, dan hitungan berjalan di sisi klien.
- Klasifikasi: kapasitas ≤ 0 = "Tanpa kuota" (oranye); alokasi > 0 = "Ada alokasi" (biru); selain itu "Belum teralokasi" (abu). Chip dengan hitungan 0 disembunyikan kecuali "Semua".
- Angka ribuan memakai titik, persen memakai koma (maks. 2 desimal). Persen dari server dipakai bila ada.
- Bottom bar putih: jumlah destinasi dan tombol "Reset Filter" (kembali ke bulan berjalan, semua destinasi, chip dan urut default).
- "Lihat Rincian" membuka sheet "Rincian Kapasitas"; "Tiket layak hadir" ditulis "Belum tersedia", jangan diasumsikan 0.

### Kelola Kuota (superadmin)

`screens/superadmin/kelola_kuota_view.dart` (`SuperadminQuotaView`), dipanggil `KelolaKuotaScreen` bila role 2; admin (role 1) tetap memakai tampilan lama. Urutan: kartu DESTINASI YANG DIKELOLA, tiga kartu statistik (Jadwal kunjungan, Total kapasitas, Kuota tersisa; dihitung dari bulan terpilih), judul "Jadwal & Kuota" dengan tombol filter bulan (bottom sheet "Pilih Bulan", default bulan berjalan), kartu jadwal per tanggal, kotak info zona waktu, dan dock putih "Tambah Tanggal".

- Kartu jadwal: tile tanggal, tombol ubah, kuota teralokasi dengan persen dan progress bar, tile Kapasitas total / Sisa kuota, timeline Periode Pemesanan, dan "Lihat Rincian →" (sheet "Rincian Jadwal" dengan tombol Tutup / Ubah Kuota).
- Tambah dan Ubah memakai bottom sheet, bukan dialog. Tanggal lewat date picker, jam diketik `HH:mm` (24 jam, tanpa analog clock picker). Tanggal kunjungan terkunci saat Ubah.
- Jendela booking diinput dan ditampilkan dalam zona waktu destinasi (WIB/WITA/WIT, default Asia/Jakarta) dan dikirim sebagai UTC. Validasi klien: tutup setelah buka, tutup sebelum hari kunjungan dimulai, kapasitas tidak lebih kecil dari teralokasi.
- Default form Tambah: tanggal setelah jadwal terakhir, kapasitas jadwal terakhir, buka sekarang, tutup sehari sebelum kunjungan pada jam yang sama.

### Profil (superadmin)

`operations_navigation_shell.dart`, `_OperationsProfileState._superadminProfile`. Urutan: kartu identitas (avatar inisial gradien, label AKUN OPERASIONAL, nama, badge Superadmin, email dengan tombol salin), "Hak Akses" (kartu Akses Global, badge "Akses berdasarkan peran", "Lihat rincian →" membuka sheet Rincian Akses), "Informasi Akun" (Tipe akun, Peran, Cakupan), lalu tombol merah "Keluar dari Akun" tepat di bawahnya, ikut menggulir (tidak sticky). Konfirmasinya bottom sheet "Keluar dari Akun" (judul + tombol tutup, ikon dan "Akhiri sesi operasional?", nama akun tebal, tombol Batal dan "Ya, Keluar" berdampingan), bukan dialog; berlaku untuk admin dan superadmin. Profil admin (role 1) tidak berubah.

### Bottom sheet tindakan

Pola dari `_BookingActionSheet` (`operations_booking_screen.dart`):

- `showModalBottomSheet` dengan `isScrollControlled`, `useSafeArea`, `showDragHandle`, latar putih, sudut atas 24, dibungkus `OperationsTheme`.
- Kepala: judul 20 / w800 dan tombol tutup persegi bulat (radius 12, latar `#EEF3FA`), lalu `Divider`.
- Isi: kalimat pengantar 12, kotak informasi bertone, lalu kartu pilihan atau formulir.
- Kartu pilihan: ikon 44×44 dalam kotak tint, judul 14 / w800, subjudul 12, panah kanan; nonaktif = opacity 50%.
- Tombol konfirmasi dua kolom, tinggi 52, radius 14: kiri `Batal` atau `Kembali` (outline), kanan aksi utama (biru) atau aksi bahaya (tone merah).
- Sheet hanya mengumpulkan niat dan mengembalikan hasil; mutasi dijalankan layar setelah sheet tertutup.

### Dock aksi bawah

Latar putih penuh sampai tepi layar: `Material` di luar, `SafeArea(top: false)` di dalam (kebalikannya membuat area navigasi sistem tampak abu-abu). Kiri: judul 13 / w800 dan subjudul 12. Kanan: satu tombol biru minimal 140×50, radius 14. Tombol yang tidak tersedia memakai `Opacity(.5)` dan `onPressed: null`, tetap berwarna biru.

## 5. Komponen Bersama

| Komponen | File | Fungsi |
|---|---|---|
| `OperationsFilterBar`, `operationsPeriodLabel` | `widgets/operations_chrome.dart` | filter destinasi + periode, label periode ringkas |
| `OperationsTheme`, `OperationsScenicHeader`, `OperationsDayHeader` | `widgets/operations_chrome.dart` | tema peran, header berlatar pemandangan |
| `OperationsHomeTabs` | `widgets/operations_tabs.dart` | tab Beranda "Destinasi" / "Pribadi" |
| `showOperationsOptionSheet` | `widgets/operations_option_sheet.dart` | bottom sheet pilih satu opsi (urutkan); pengganti dropdown/popup menu |
| `OperationsTone`, `operationsToneColors`, `OperationsStatusBadge` | `widgets/operations_status.dart` | palet status dan badge status bertitik (dipakai layar booking dan antrean) |
| `OperationsPage`, `OperationsSkeleton` | `screens/admin/operations_dashboard/operations_dashboard.dart` | kerangka halaman operasional dan skeleton loading |
| `OperationsMetrics`, `OperationsTrend` | `.../operations_presentation.dart` | kartu metrik dan grafik tren |
| `AdminPage`, `AdminActionBar`, `AdminFilterChips`, `AdminStatCard` | `screens/admin/admin_common.dart` | halaman kelola superadmin/admin |
| `AdminNotice`, `AdminBadge`, `AdminRowMenu`, `showAdminSnack` | `screens/admin/admin_common.dart` | pemberitahuan, badge, menu baris, snackbar |
| `adminInputDecoration`, `adminLoadingSliver`, `adminErrorSliver`, `adminEmptySliver` | `screens/admin/admin_common.dart` | dekorasi input, state loading/error/kosong |
| `SelectFormField`, `SelectOption` | `widgets/select_sheet.dart` | pilihan lewat bottom sheet |
| `FloatingBottomNav` | `widgets/floating_bottom_nav.dart` | navigasi bawah |
| `ScrollAwareStatusBar` | `widgets/scroll_aware_status_bar.dart` | warna status bar mengikuti scroll |
| `ApiImage`, `DestinationHeroGallery`, `AvailabilityCalendar`, `InternationalPhoneField`, `ProfileAvatar`, `ReviewsSheet` | `widgets/` | gambar, galeri, kalender, telepon, avatar, ulasan |
| `BookingPaymentSection`, `BookingRefundSection`, `BookingTicketQrSection` | `widgets/` | bagian pembayaran, refund, tiket QR pada detail booking pengunjung |
| `Auth*` (`AuthScenicShell`, `AuthPrimaryButton`, `AuthHeading`, `AuthOtpInput`, ...) | `screens/auth/auth_presentation.dart` | komponen halaman autentikasi |

Gunakan komponen di atas sebelum membuat yang baru. Widget privat di dalam satu layar (mis. `_BookingPanel`, `_StatusBadge`, `_NoticeCard`, `_InfoTile` di `operations_booking_screen.dart`) tidak bisa diimpor; bila dibutuhkan di layar lain, pindahkan ke `widgets/` terlebih dahulu.

## 6. Standar Halaman Detail Booking (Admin & Superadmin)

File: `screens/admin/operations_booking_screen.dart`. Satu layout untuk kedua peran; perbedaannya hanya pada tindakan.

**Isi halaman**

1. Kartu "PERMINTAAN KUNJUNGAN": badge status di kanan, nama destinasi, kotak nomor booking dengan tombol salin.
2. Kartu "Informasi Kunjungan": dua tile (tanggal, jumlah tiket), tile total booking berukuran besar berwarna biru, pemisah, baris "Batas persetujuan".
3. Kartu "Data Pengunjung": avatar inisial, nama, "Nama sesuai data booking", baris email dan telepon.
4. Kartu "Claim Persetujuan" bila ada claim aktif, dengan badge "Milik Anda", "Admin lain", atau "Dialihkan".
5. Kartu pemberitahuan sesuai kondisi, lalu catatan kaki tentang validasi server.
6. Tombol refresh tidak ada; muat ulang lewat tarik ke bawah dan saat aplikasi dibuka kembali.

**Kondisi (`_BookingView`)**

| Kondisi | Badge | Dock |
|---|---|---|
| Menunggu, belum diklaim | Menunggu Persetujuan (orange) | "Perlu penanganan / Claim belum diambil" + **Kelola Booking** |
| Menunggu, claim milik pengguna | Menunggu Persetujuan (blue) | "Claim aktif / Tindakan persetujuan tersedia" + **Kelola Booking** |
| Menunggu, claim admin lain | Menunggu Persetujuan (blue) | "Claim aktif / Sedang ditinjau Admin lain"; superadmin: **Kelola Booking**, admin: **Lihat Tindakan** nonaktif |
| Dialihkan (superadmin, sesi ini) | Dialihkan (grey) | "Sudah dialihkan / Menunggu admin tujuan" + **Lihat Tindakan** nonaktif 50% |
| Ditolak | Ditolak (red) | "Permintaan ditolak / Tidak ada tindakan aktif" + **Lihat Tindakan** nonaktif 50% |
| Selesai / kedaluwarsa | sesuai status | dock tidak tampil |

Status "Dialihkan" bukan status dari server; ia muncul hanya setelah superadmin mengalihkan dari layar ini dan server mengonfirmasi pemilik claim berubah.

**Sheet "Tindakan Booking"**

| Kondisi | Pilihan |
|---|---|
| Belum diklaim | Ambil Claim |
| Claim milik pengguna | Ambil Claim (redup), Setujui Booking, Tolak Booking, Lepas Claim, dan **Alihkan ke Admin** (hanya superadmin) |
| Claim milik admin lain | Ambil Claim (redup), dan Alihkan ke Admin (hanya superadmin) |

Langkah konfirmasi: Ambil Claim, Setujui (`Ya, Setujui`), Tolak (alasan wajib, tombol `Lanjutkan` tone merah), Lepas Claim, dan Alihkan (dropdown admin tujuan + alasan wajib, karena backend mewajibkan alasan pengalihan).

### Pembayaran booking (pengunjung)

`screens/user/booking_payment_screen.dart`. Fase pilih metode: banner waktu (`PaymentDeadline(banner: true)`, kuning, merah saat habis), kartu RINGKASAN PESANAN (tombol Detail membuka nomor booking, invoice, biaya layanan), daftar metode dengan logo resmi dari `assets/images/payment/` (bca.png, bni.png, qris.png pada tile putih; radio, badge "Terpilih"; tanpa tombol "Kembali ke Detail Booking", cukup tombol back di header), kotak info, dan dock putih "Total pembayaran" dengan tombol "Lanjut Bayar →" yang membuka bottom sheet "Konfirmasi Metode" (Ubah Metode / Lihat Instruksi) sebelum instruksi dibuat. Fase menunggu pembayaran: banner, kartu METODE YANG DIPILIH, kartu INSTRUKSI PEMBAYARAN (nomor VA atau QR asli dari server; bila nomor belum ada tampil placeholder "Nomor VA belum diterbitkan"), cara pembayaran, tombol teks "← Pilih Metode Lain" (membuka sheet penjelasan, karena metode tidak bisa diganti selama pembayaran berjalan), dan dock putih "Total tagihan" dengan tombol "Cek Status Pembayaran". Semua angka dan batas waktu dari server; teks tidak boleh menyebut "simulasi" karena alurnya nyata. Satu-satunya pengecualian adalah `payment_instruction_preview_screen.dart`: bila instruksi asli gagal dibuat (`kPaymentPreviewOnFailure`), halaman pratinjau dibuka dengan placeholder "Nomor VA/Kode QR belum diterbitkan", countdown lokal berlabel "Countdown simulasi", alasan kegagalan dari server, dan catatan "Mode prototype" yang menyatakan tidak ada transaksi. Matikan flag itu untuk produksi.

## 7. Aturan Wajib untuk Perubahan UI

- Periksa peran: superadmin = `role == 2`, admin = `role == 1`. Jangan menukar keduanya.
- Pakai token dari `AppColors` dan `AppSpacing`; jangan menambah warna heksa baru bila token atau tone yang sesuai sudah ada.
- Filter destinasi + periode di halaman operasional selalu memakai `OperationsFilterBar`, bukan kartu.
- Tindakan yang mengubah data (claim, setujui, tolak, lepas, alihkan) dilakukan lewat bottom sheet dengan langkah konfirmasi, bukan `AlertDialog` atau tombol di badan halaman.
- Aksi utama halaman detail ditempatkan di dock bawah putih penuh.
- Tombol yang tidak tersedia ditampilkan opacity 50% dan disabled, bukan disembunyikan, kecuali dock memang tidak relevan (status selesai).
- Ikon memakai `PhosphorIconsRegular`. Periksa nama ikon ada di `phosphor_icons-3.0.1` sebelum memakainya.
- Status dan kepemilikan claim selalu mengikuti data server; UI tidak boleh menyimpulkan kewenangan sendiri.
- Jangan mengubah navigasi atau logika bisnis hanya untuk penyesuaian tampilan.
- Jangan menambah dependency tanpa kebutuhan teknis yang jelas.

## 8. Utang Desain yang Diketahui

| Temuan | Lokasi | Dampak |
|---|---|---|
| Kartu filter lama `_ScopeCard` masih dipakai | `operations_presentation.dart` (`_filterButton`), dipanggil dari `operations_reports.dart` untuk superadmin pada Kinerja Destinasi dan Kunjungan, dan admin biasa pada halaman non-beranda | tampilan filter tidak seragam antar halaman |
| Warna duplikat | `AdminColors` vs `AppColors`; konstanta lokal di `select_sheet.dart` | perubahan warna harus dilakukan di beberapa tempat |
| Komponen privat berulang | `_BookingPanel`, `_NoticeCard`, `_InfoTile` hanya ada di layar booking (badge sudah dipindah ke `widgets/operations_status.dart`) | perlu dipindah ke `widgets/` bila dipakai ulang |
| Model lama tidak terpakai | `lib/models/` | kemungkinan sisa versi Firebase; verifikasi sebelum menghapus |
| Aset terdaftar tanpa referensi terverifikasi | `assets/images/Candi_Borobudur.jpg`, `Pantai_Kuta.jpg` | menambah ukuran bundle bila tidak dipakai |
| Font bergantung unduhan runtime | `google_fonts` | pada perangkat offline yang belum pernah memuat font, dipakai font sistem |
