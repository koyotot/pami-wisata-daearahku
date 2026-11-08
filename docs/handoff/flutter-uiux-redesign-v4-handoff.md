# Handoff Flutter UI/UX V4
### Finalisasi targeted 3 November 2026

- Hero Notifikasi tumbuh mengikuti teks pada 320dp; test navigasi booking pada viewport 320dp/text scale 1.5 PASS.
- Targeted final: **18 PASS, 0 FAIL** pada `v4_navigation_notifications_test.dart`, `v4_booking_detail_redesign_test.dart`, `v4_booking_success_navigation_test.dart`, dan `v4_visual_test.dart`. Detail Pendaftaran tetap **2/2 PASS**.
- Finder test navbar disesuaikan dengan CustomPainter existing; posisi badge, semantics, dan selected state tetap diperiksa.
- Full regression dan analyzer dihentikan sesuai instruksi final pengguna. Hasil sebelumnya bukan gate final. Android native, backend live, batas periode/resume scenic, dan coverage QA lain yang belum tersedia tetap NOT VERIFIED.
- `git diff --check` dijalankan setelah pembaruan catatan ini; hasil dicantumkan dalam laporan akhir.

## Addendum 3 November 2026 — Dynamic Scenic, Inbox, and Booking Detail

Implementasi Flutter untuk PRD `PRD Wisata Daerahku Flutter UIUX V4 — Dynamic Scenic Headers, Notification Experience & Booking Detail Redesign` telah ditambahkan. Ringkasan 2 November di bawah ini adalah catatan historis dan hasil tesnya bukan hasil validasi perubahan 3 November.

### Perubahan saat ini

- Riwayat, Jelajah, Profil, dan Notifikasi memakai `TimeBasedScenicBackground` yang sama dengan Beranda/auth. Periode lokal, transisi 800 ms, resume/clock reconciliation, dan reduced motion tetap dikelola komponen tersebut. Tab nonaktif menonaktifkan timer latarnya.
- Profil memakai header full-bleed dan kartu identitas/statistik yang menumpang pada batas bawah hero. Identitas, angka statistik, dan tahun bergabung tetap berasal dari data/pola existing.
- Inbox memiliki hero ringkas, badge dari unread count server, filter Semua/Belum dibaca, empty state terpisah, dan error refresh yang mempertahankan daftar terakhir. Item booking tetap memakai mark-read server dan membuka `BookingTicketScreen` full-screen dengan booking GUID yang sama. Filter dan posisi scroll tetap di widget tab yang tertahan oleh `IndexedStack`.
- Detail menampilkan judul “Detail Pendaftaran” sampai respons dokumen berisi `ticket`; status `confirmed` atau invoice saja tidak mengubah judul. Detail mempertahankan kode booking yang bisa disalin, menampilkan tanggal Indonesia dan total IDR, serta menambah konteks “Apa Selanjutnya?” tanpa CTA pembayaran.
- Dokumen tidak dicampur dengan status booking. Saat dokumen belum diperiksa, sedang dimuat, atau gagal, UI tidak menyebut dokumen belum diterbitkan. Invoice tetap dijelaskan sebagai konfirmasi pendaftaran, bukan bukti pembayaran.

### Status backend yang dipakai

Audit source Laravel di checkout `C:\laragon\www\pami-wisata-daerahku-api` menemukan `BookingRules::STATUSES` pada `app/Support/BookingRules.php:14`; `BookingController` list/detail mengembalikan `BookingResource` (`app/Http/Controllers/Api/V1/BookingController.php:20-42`). `BookingResource` memuat `status` (`app/Http/Resources/BookingResource.php:26`) dan tidak memuat alasan penolakan. Sumber dokumen tetap respons endpoint dokumen booking; invoice tidak dianggap bukti pembayaran.

| Status sumber | Label/konteks UI |
| --- | --- |
| `pending_approval` | Menunggu persetujuan; menunggu pengelola. |
| `awaiting_payment` | Menunggu pembayaran; belum menyatakan pembayaran diterima. |
| `payment_verification` | Verifikasi pembayaran; belum dipastikan diterima. |
| `payment_review` | Peninjauan pembayaran; belum dipastikan diterima. |
| `confirmed` | Disetujui; tiket hanya dinyatakan terbit bila `documents.ticket` tersedia. |
| `rejected` | Ditolak; alasan tidak ditampilkan karena resource tidak menyediakannya. |
| `expired` | Kedaluwarsa. |
| `cancelled` | Dibatalkan. |

Status yang belum dikenal tetap ditampilkan sesuai string sumber, dengan konteks lanjutan generik. Tidak ada status payment/ticket baru atau perubahan backend/API pada pekerjaan ini.

### File perubahan 3 November

Produk: `lib/screens/bukti_pendaftaran_screen.dart`, `lib/screens/cari_wisata_screen.dart`, `lib/screens/main_navigation_screen.dart`, `lib/screens/notifikasi_screen.dart`, dan `lib/screens/profil_user_screen.dart`.

Regression tests: `test/v4_booking_detail_redesign_test.dart`, `test/v4_history_profile_test.dart`, `test/v4_navigation_notifications_test.dart`, dan `test/v4_visual_test.dart`.

PRD yang disediakan tetap tidak diubah. `docs/DESIGN.md` tetap tidak diubah.

### Verifikasi perubahan 3 November

| Pemeriksaan | Hasil |
| --- | --- |
| `dart format` pada file Dart tersentuh | **NOT VERIFIED**: percobaan terdahulu keluar setelah `FileSystemException` saat SDK memperbarui timestamp `C:\Users\itsba\AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json` (Access denied). Percobaan ulang `dart format` pada 3 file tetap berjalan tanpa output lebih dari 45 detik dan dihentikan; perubahan format terakhir perlu diperiksa oleh quality gate. |
| `test/v4_booking_detail_redesign_test.dart` | **PASS: 2 tests**; seluruh status, judul berbasis dokumen, kegagalan dokumen, dan layout 320/390/430dp/text scale diuji. Perbaikan mencegah overflow status/tombol dan menonaktifkan `AnimatedSize` saat reduced motion. |
| `test/v4_history_profile_test.dart` | **PASS: 4 tests**. |
| Notification booking route | **PASS: 1 focused test**; booking membuka detail full-screen, status detail terlihat, dan filter unread tersisa setelah kembali. Hero menyesuaikan tinggi saat teks membesar. |
| Scenic tab state | **PASS: 1 focused test**; Jelajah aktif saat dipilih dan state tab/back dipertahankan. |
| Seluruh `test/v4_navigation_notifications_test.dart` | **FAIL: 1 test** pada finder badge lama yang mencari `Icon` notifikasi; `FloatingBottomNav` saat ini menggambar glyph dengan `CustomPainter`. Tes route booking yang berubah lulus terpisah. |
| Suite penuh `flutter test` (run main thread sebelum perbaikan fokus di atas) | **FAIL: 347 pass, 2 skip, 8 fail**. Hasil tersebut mendahului perbaikan detail, tes route, dan urutan aktivasi scenic; rerun suite penuh dilakukan main thread. Kegagalan lain belum diklasifikasikan sebagai baseline. |
| `flutter analyze` (run main thread) | **FAIL: 118 issues found**. Belum dibandingkan ulang terhadap baseline setelah perubahan terakhir. |
| `git diff --check` | Belum dijalankan ulang setelah perbaikan terakhir. |
| Emulator/perangkat, TalkBack, system bars/keyboard native, backend live/FCM | **NOT VERIFIED**. |

Perubahan Flutter 3 November tidak menyentuh backend. Hasil lokal bila nanti dijalankan main thread harus dilaporkan terpisah dari bukti integrasi live atau rendering perangkat.

Tanggal: 2 November 2026. Scope: pengunjung role 0. Perubahan V4 yang sudah ada di working tree dilanjutkan, bukan direset. Tidak ada commit, push, deployment, atau modifikasi Laravel.

## Implementasi

- Theme pengunjung biru dan Plus Jakarta Sans mencakup Navigator overlay selama sesi role 0; auth/admin mempertahankan theme existing. Scaffold/loading Detail memakai latar netral, CTA Detail dan Booking terpisah dari navbar.
- Root tabs: Beranda, Riwayat, Jelajah, Notifikasi, Profil. Jelajah elevated dengan kompas; navbar floating blur dan SafeArea. Badge oranye berada pada Stack glyph Bell, disembunyikan saat nol dan dibatasi `99+`. Keyboard menyembunyikan navbar; Android back dari tab lain kembali ke Beranda; IndexedStack mempertahankan state tab.
- Beranda/Jelajah mempertahankan state katalog, kategori, pencarian, pagination, GUID dan error/empty/loading existing. Grid beradaptasi pada lebar sempit dan text scale. Animasi utama menghormati reduced motion.
- Detail mempertahankan fasilitas dinamis, harga/jadwal/deskripsi, favorit dan navigasi booking. Jadwal, judul bagian dan pill informasi membungkus teks panjang agar tidak overflow pada 320dp.
- Combined phone field memakai flag regional ISO, pencarian negara, selected state, dial code dan metadata parser existing. Input parsial diformat per negara; placeholder juga berdasarkan metadata. Picker menyesuaikan inset keyboard. Payload baru tetap E.164; replay tetap memakai payload/key tersimpan.
- Kalender memberi warna langsung pada tile/angka tanggal; outline biru tidak menghapus warna status. Legenda teks, bookable server, timezone, jumlah, stale-response guard dan penanganan konflik 409 dipertahankan.
- Riwayat mempertahankan kartu expandable, status server, kontak, email/catatan/total, copy kode, eligibility cancel/check-in/review dan dokumen. Invoice bukan bukti pembayaran. QR legacy tidak diaktifkan.
- Profil memakai nama/email asli dan inisial, Edit Profil, statistik server dan menu existing. Tahun bergabung `—` karena UserResource tidak menyediakan tanggal bergabung; waktu hidrasi lokal tidak digunakan. Menu Notifikasi membuka tab aktivitas. Bahasa/preferensi dan fitur API yang belum tersedia menyampaikan keterbatasan, tanpa simulasi sukses. Logout tetap melalui AuthSession.

## Integration gate notifikasi

**PASS pada kontrak source lokal; NOT VERIFIED pada server live.** Audit read-only Laravel menemukan GET `/api/v1/notifications`, GET `/api/v1/notifications/unread-count`, PATCH `/api/v1/notifications/{guid}/read` pada `routes/api.php:87–89`; resource menyediakan guid, booking_guid, title, body, read_at dan created_at. Daftar paginated, unread count dan mark-read memakai ApiClient authenticated existing. Filter unread, loading/empty/error/retry, navigasi booking GUID, reset sesi dan stale responses tercakup. Tidak ada endpoint baru atau count notifikasi palsu. FCM existing tidak diubah.

Tidak ada BACKEND DEPENDENCY untuk kontrak inbox pada checkout lokal ini. Ketersediaan versi kontrak tersebut pada deployment belum diuji.

## Verifikasi

Lingkungan: Windows, Flutter widget-test renderer. Emulator Android API 37 terdeteksi, tetapi aplikasi tidak dijalankan pada emulator dalam pekerjaan ini.

| Pemeriksaan | Hasil |
| --- | --- |
| Targeted V4: discovery, history/profile, navigation/notifications, visual | **PASS: 11 test** |
| Targeted booking/calendar/regression | **PASS: 37 test** |
| `flutter test` | **FAIL: 325 PASS, 1 SKIP, 1 FAIL**, hanya `auth_prd_redesign_test.dart` / `scrolled header stays below status bar on narrow scaled viewport` |
| `flutter analyze` | **FAIL karena lint: 152 temuan, 0 error, 3 warning, 149 info** |
| Analyzer dibanding HEAD | **0 temuan baru, 23 berkurang**; HEAD 175, dibanding berdasarkan path/rule/pesan/jumlah, bukan nomor baris |
| `dart format --output=none --set-exit-if-changed` pada Dart tersentuh | **PASS**, tidak ada perubahan format |
| `git diff --check` | **PASS**, notice LF/CRLF bukan kegagalan whitespace |
| Review system_architect dan security_auditor | Tidak menemukan blocker baru dalam scope review statis; bukan penetration test atau bukti server live |

Baseline analyzer diperiksa dari arsip HEAD di direktori sementara, dengan package config/dependency existing dan assets yang sama; source working tree tidak diganti. Kegagalan auth direproduksi pada arsip HEAD: 4 PASS, 1 FAIL pada test yang sama; layar auth tidak diubah oleh V4. Kegagalan V4 awal berupa overflow Detail telah diperbaiki dan test terkait lulus. Percobaan test visual awal tanpa font menghasilkan artefak Ahem; test final memakai font SDK dan lulus.

Test booking meliputi 422 inline, 409 reconciliation, original payload/key replay, respons bulan/jumlah lama, logout saat request, nullable quota dan bookable server. Test V4 meliputi badge glyph, batas count, SafeArea, layar kecil/text scale, unread API/pagination/mark-read, late response sesi, state tab/back, identitas dan fitur unsupported.

## Bukti visual dan batas penerimaan

Lihat [catatan render](visual/README.md) dan PNG [320dp](visual/v4-components-320.png), [390dp](visual/v4-components-390.png), [430dp](visual/v4-components-430.png). Ini render Flutter nyata dengan fixture test yang diberi label, bukan screenshot Android atau bukti API live. Font capture Arial, bukan Plus Jakarta Sans. Font Windows tidak merender flag regional; bendera native Android belum diverifikasi. Label weekday membungkus dan label tab terpotong pada 320dp/text scale 1.8, dengan label semantics tetap lengkap.

**DoD visual/perangkat belum terpenuhi seluruhnya.** Belum ada perbandingan semua layar dengan artefak interactive wireframe V4, rekaman transisi Android tanpa flash hijau, pemeriksaan TalkBack/system bars/native keyboard/flag, real API/FCM, atau alur booking live. Tidak ada klaim selesai 7/7 secara visual maupun production-ready. Pengujian perangkat memerlukan sesi pengunjung dan backend yang sesuai; jangan memakai hasil fixture sebagai bukti integrasi.

## File tersentuh dalam working tree V4

Produk:

- `lib/main.dart`
- `lib/theme/app_colors.dart`
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/beranda_user_screen.dart`
- `lib/screens/cari_wisata_screen.dart`
- `lib/screens/detail_wisata_screen.dart`
- `lib/screens/daftar_kunjungan_screen.dart`
- `lib/screens/bukti_pendaftaran_screen.dart`
- `lib/screens/profil_user_screen.dart`
- `lib/widgets/international_phone_field.dart`
- `lib/widgets/availability_calendar.dart`
- `lib/widgets/floating_bottom_nav.dart` (baru)
- `lib/screens/notifikasi_screen.dart` (baru)
- `lib/data/notification_state.dart` (baru)

Test/dokumentasi:

- `test/business_booking_widgets_test.dart`
- `test/v4_discovery_test.dart`
- `test/v4_history_profile_test.dart`
- `test/v4_navigation_notifications_test.dart`
- `test/v4_visual_test.dart`
- `docs/visual/README.md` dan tiga PNG
- `docs/flutter-uiux-redesign-v4-handoff.md`
- PRD V4 untracked sudah ada sebelum pekerjaan dilanjutkan dan tidak diubah.

`bukti_konfirmasi_screen.dart` tidak ada pada source terbaru; konfirmasi/alur tiket memakai implementasi booking/riwayat existing. BookingIntent, AuthSession, business repository, FCM, kontrak API dan kuota tidak diubah.

## Agent dan skill yang diverifikasi

Konfigurasi global `C:/Users/itsba/.codex/agents/flutter_engineer.toml` dibaca; `.codex` lokal tidak tersedia. Delegasi nyata: flutter_engineer (phone/booking/calendar), system_architect (kontrak read-only), qa_engineer (test/render), security_auditor (review read-only). QA sempat mengalami error kapasitas model; retry menghasilkan file/test/render yang diverifikasi oleh main thread. Skill ponytail dan design-taste-frontend beserta app-screens dibaca; tidak ditemukan mobile taste skill terpisah dalam katalog. Panduan web inspector tidak dipakai sebagai bukti Flutter; approval V4 mengungguli aturan generik skill yang bertentangan seperti blur/navbar floating.
