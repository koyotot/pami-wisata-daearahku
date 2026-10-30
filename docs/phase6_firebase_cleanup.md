# Phase 6 — Firebase legacy cleanup

Implementasi lokal 30 Oktober 2026. Laravel/MySQL menjadi sumber data bisnis;
Firebase hanya dipertahankan untuk Google Login pengguna role 0 dan FCM.
Tidak ada perubahan data historis Firebase, commit, atau deployment.

## Audit sebelum implementasi

Dokumen Phase 1, 3, 4, 5, kontrak Phase 4–5, unified auth, dan handoff backend
`docs/handoff/PHASE-4-5-COMPLETION.md` telah dibaca. Dokumen Phase 2 tidak ditemukan.
Pernyataan SECURITY BLOCKER Google admin pada dokumen unified auth lama sudah
kedaluwarsa: kode Laravel saat audit sudah menolak Google role 1/2 dengan 403.

| Area sebelum cleanup | Klasifikasi dan tindakan |
| --- | --- |
| `app_data.dart`: seed/load Firestore, serializer Timestamp | Helper tanpa pemanggil aktif; dihapus. Model presentasi yang masih dipakai dipertahankan. |
| `profil_user_screen.dart`: statistik, edit, riwayat review Firestore | Cabang legacy; diganti Laravel. |
| Penghapusan akun legacy yang menghapus users/pendaftar/ulasan/kunjungan | Dihapus dari aplikasi; penutupan akun tetap melalui Laravel dengan reautentikasi existing. |
| `bukti_pendaftaran_screen.dart`: review Firestore dan QR lokal | Review diganti API; QR yang tidak terverifikasi dihapus. Dokumen memakai API existing. |
| `bukti_konfirmasi_screen.dart` | Layar mati tanpa pemanggil navigasi, menghasilkan QR legacy; dihapus. |
| `firebase_storage` | Dependency tanpa pemanggil di `lib`; dihapus setelah audit. |
| `cloud_firestore` | Dependency helper/cabang di atas; dihapus setelah semua pemanggil hilang. |
| `qr_flutter` | Tidak dibutuhkan setelah QR legacy dihapus; dihapus. |
| `firebase_core`, `firebase_auth`, `firebase_messaging` | Dipertahankan, termasuk konfigurasi Android dan registrasi perangkat FCM. |

Avatar existing berupa inisial; tidak ada upload avatar yang perlu dimigrasikan.
Tidak ada perilaku edit/hapus review existing, sehingga tidak ditambahkan.
Tidak ada check-in writer/scanner aktif sebelumnya; API kunjungan kini tersedia
melalui booking Laravel, tanpa menghidupkan QR lama.

## Kontrak tambahan

Semua path relatif `/api/v1`; Bearer dari `AuthSession` kecuali daftar review publik.
Respons sukses `data`, daftar berpaginasi `data`, `links`, `meta`.

| Endpoint | Kontrak |
| --- | --- |
| `GET profile/statistics` | Statistik pengguna token: `bookings`, `reviews`, `visits`. |
| `GET reviews` | Riwayat review pengguna token, `page`, `per_page` ≤100. |
| `GET destinations/{guid}/reviews` | Publik, destinasi/kategori aktif; tidak mengekspos GUID booking/pengguna. |
| `POST bookings/{guid}/check-in` | Pemilik atau admin; hanya `confirmed`, tepat tanggal lokal destinasi. Mengembalikan BookingResource. |
| `POST bookings/{guid}/review` | Pemilik booking yang `confirmed` dan sudah check-in; `rating` integer 1–5, `comment` wajib ≤2000. |

BookingResource menambah `checked_in_at`, `can_check_in`, `can_review`, `review`.
ReviewResource: `guid`, `booking_guid` (hanya privat), `destination_guid`,
`destination_name`, `rating`, `comment`, `created_at`. Destinasi menambah
`rating_average` (null tanpa review) dan `rating_count` dari agregasi SQL.
Tidak ada rating sintetis. Nama destinasi pada review memakai snapshot booking.

Error domain 409: `check_in_duplicate`, `check_in_not_eligible`,
`check_in_wrong_date`, `review_duplicate`, `review_not_eligible`.
Nonpemilik role 0 mendapat 404; admin tidak dapat mengulas booking pengguna lain.
Check-in dan review masing-masing unik per booking, memakai transaksi dan
`SELECT FOR UPDATE` pada booking yang sama. Status booking, pembayaran, dan kuota
tidak diubah. `awaiting_payment` selalu tidak memenuhi syarat check-in/review.

Profil tetap menggunakan `auth/me` dan `PATCH profile`; dokumen tetap metadata
dan unduhan invoice/ticket terotorisasi. Invoice adalah konfirmasi booking,
bukan bukti pembayaran. Tidak ada payment gateway atau QR baru.

Respons profil saat logout dan riwayat review lintas halaman setelah pergantian
akun ditolak melalui generasi sesi. Check-in/review dengan hasil tidak pasti
direkonsiliasi melalui detail booking; tidak dikirim ulang otomatis.

## Inventaris historis yang tidak dimigrasikan

`users`/profil, `wisata`, `wisataTersimpan`, `pendaftar`, `ulasan`, `kunjungan`,
dan aset Firebase Storage lama tetap berada pada sumber historisnya.
Inventaris ini berdasarkan referensi kode/dokumentasi, bukan pembacaan Console.
Tidak tersedia pemetaan Firebase UID → GUID Laravel atau ID destinasi yang
terverifikasi; tidak ada impor berdasarkan email/nama, seed, penghapusan, atau
penulisan Firestore/Firebase Storage historis dalam pekerjaan ini. Isi/jumlah record dan aset historis
belum diperiksa pada provider.

## Migrasi dan pengujian

Backend menambah migration `2026_10_30_020000_create_visit_review_tables.php`
untuk tabel `check_ins` dan `reviews` beserta FK dan unique booking.
Jalankan migrasi melalui prosedur deployment normal sebelum aplikasi baru
digunakan. Migrasi hanya dijalankan pada database pengujian dalam pekerjaan ini.
Rollback migration menghapus tabel baru beserta isinya; jangan rollback setelah
ada data kunjungan/review nyata tanpa rencana preservasi data.

| Pemeriksaan aktual | Hasil |
| --- | --- |
| `php artisan test --compact` | PASS — 70 tes, 504 assertion, termasuk 20 tes Phase 6/136 assertion dan regresi Phase 1–5. |
| `php artisan test -c phpunit.mysql.xml` | PASS — 9 tes, 150 assertion, MySQL 8.4.3 nyata. Masing-masing 8 proses check-in/review serentak menghasilkan tepat 1 record; booking/quota race lama tetap lulus. |
| `php artisan test -c phpunit.e2e.xml` | PASS — 5 skenario HTTP nyata, 176 assertion; mencakup Phase 1–5 dan profil/check-in/review/statistik/dokumen Phase 6. |
| `flutter test --no-pub` | PASS — 208 tes, 1 tes live opt-in dilewati dalam suite default. |
| `flutter test --no-pub test/phase6_live_api_test.dart` dengan fixture | PASS — repository Flutter menggunakan HTTP nyata ke Laravel/MySQL: profil, check-in, review, agregat, PDF, registrasi/unregister perangkat, logout, pergantian akun, isolasi data. |
| Tes widget QA | PASS — 3 tes modal pada lebar 320px, empty/error/retry, logout dan respons terlambat. Termasuk dalam 208 tes. |
| `flutter analyze --no-pub` | FAIL (exit 1) karena lint existing: 0 error, 4 warning dan 176 info = 180 issue; baseline Phase 4–5 237. Tidak ada error kompilasi. |
| `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8099/api/v1` | PASS — APK final setelah perubahan terakhir; warning deprecation Kotlin existing. Artifact `build/app/outputs/flutter-apk/app-debug.apk` adalah debug untuk API pengujian lokal. |
| Tes setelah perubahan terakhir loader review | PASS — 20 tes Phase 6; batas 200 halaman yang tidak diperlukan dihapus, semua halaman server dimuat. |
| Regresi rating form admin | PASS — tes form existing memverifikasi create tanpa ulasan menampilkan `-`, edit menampilkan rating server 4.3; default estimasi 4.5 dan cabang pengaturan manual mati dihapus. Tidak menambah jumlah tes. APK final dibangun ulang sesudah perubahan ini. |
| Android emulator Android 17/API 37 `emulator-5554` + Laravel/MySQL nyata | PASS — login akun fixture terisolasi, riwayat `confirmed`, check-in, review 5 bintang, unduh tiket (header file `%PDF`), statistik profil 1/1/1, edit profil, dan riwayat ulasan. Ini smoke emulator, bukan pengujian perangkat fisik atau seluruh variasi perangkat. |
| APK final emulator | PASS — artifact 30 Oktober 2026 20:59:24 WIB, 188077462 byte, dipasang ulang tanpa menghapus data; restore akun Laravel dan logout ke login berhasil. Tidak ditemukan error fatal/overflow pada sampel log QA. |
| Laravel Pint, `git diff --check` kedua checkout | PASS. |
| Dependency audit setelah `flutter pub get` | PASS — nol kecocokan di `lib`, `pubspec.yaml`, `pubspec.lock` untuk cloud_firestore/firebase_storage/FirebaseFirestore/FirebaseStorage, helper Firestore, dan `.uid`; Firebase core/auth/messaging tetap ada. Registrant desktop diperbarui. |

Tes live memakai akun dan booking fixture dalam database terisolasi `*_e2e`.
Tanggal kuota fixture dipindah ke hari ini sesudah approval agar server memakai
jam nyata; ini bukan kemampuan mengubah eligibility pada aplikasi produksi.
Registrasi perangkat yang diuji memakai token uji, bukan bukti push FCM nyata.
Screenshot QA: `C:/Users/itsba/AppData/Local/Temp/phase6-checkin.png` dan
`C:/Users/itsba/AppData/Local/Temp/phase6-history.png`. Port reverse 8099 untuk
pengujian dihapus setelah smoke; mapping emulator yang sudah ada dipertahankan.

## Laporan agent

Konfigurasi ditemukan dan dibaca dari `C:/Users/itsba/.codex/agents/`;
`.codex/agents` tidak tersedia di root workspace/checkout. Main mengikuti
`master_orchestrator.toml`; specialist dijalankan memakai role yang sesuai
konfigurasi TOML tersedia. Batas runtime empat agent bersamaan termasuk main,
sehingga arsitek → implementasi paralel + keamanan → QA dijalankan bergiliran.

| Agent | Hasil |
| --- | --- |
| `system_architect` | Audit read-only, kontrak final, pemetaan legacy/historis; memastikan profil/dokumen tidak diduplikasi dan avatar/edit-delete review tidak diperlukan. |
| `backend_engineer` | Service/request/resource/controller/migration, resource agregat, 20 feature tests dan dua race tambahan MySQL; seluruh tes backend/Pint lulus. |
| `flutter_engineer` | Migrasi profil/review/check-in/rating, cleanup dependency/helper/QR, pengamanan respons saat logout; 20 tes bisnis baru dan pemeriksaan Flutter. |
| `security_auditor` | Audit read-only; menemukan dan memastikan perbaikan kebocoran GUID booking pada review publik, race profil saat logout, riwayat review lintas akun, dan guard detail saat logout. Tidak ada blocker terbukti tersisa pada sumber yang diaudit. |
| `qa_engineer` | Audit independen, tiga tes widget review, pemeriksaan dependency/Android config, dan smoke alur emulator terhadap Laravel/MySQL nyata. |
| Main orchestrator | Menetapkan kontrak, integrasi, menambah skenario HTTP Phase 6 dan fixture/pengujian Flutter API nyata, menjalankan quality gate dan dokumentasi ini. |

## Batas operasional

Tidak ada deployment atau migrasi database aplikasi utama. Firebase Google ID
token nyata, push FCM nyata, SMTP, perangkat fisik/iOS, serta staging/produksi
belum diverifikasi. Penolakan Google admin diuji dengan verifier yang di-mock.
Tidak ada impor historis tanpa mapping terverifikasi. Unduhan PDF masih memakai
direktori sementara dan menampilkan path sesuai implementasi Phase 4; belum
menambah penampil/share. Tidak ada klaim release-ready.

## Daftar file

### Laravel (path relatif checkout API)

```text
M	app/Http/Controllers/Api/V1/DestinationController.php
M	app/Http/Resources/BookingResource.php
M	app/Http/Resources/DestinationResource.php
M	app/Models/Destination.php
M	app/Services/BookingService.php
M	app/Services/CatalogService.php
M	app/Services/FavoriteService.php
M	routes/api.php
M	tests/E2E/EndToEndTest.php
M	tests/Mysql/ConcurrencyTest.php
M	tests/Mysql/worker.php
A	app/Http/Controllers/Api/V1/VisitController.php
A	app/Http/Requests/ReviewRequest.php
A	app/Http/Resources/ProfileStatisticsResource.php
A	app/Http/Resources/ReviewResource.php
A	app/Models/Review.php
A	app/Services/VisitService.php
A	database/migrations/2026_10_30_020000_create_visit_review_tables.php
A	docs/phase6_firebase_cleanup.md
A	tests/E2E/phase6_flutter_fixture.php
A	tests/Feature/VisitReviewApiTest.php
```

### Flutter (path relatif checkout mobile)

```text
M	lib/data/app_data.dart
M	lib/data/booking_errors.dart
M	lib/data/booking_state.dart
M	lib/data/business_repository.dart
M	lib/screens/beranda_user_screen.dart
D	lib/screens/bukti_konfirmasi_screen.dart
M	lib/screens/bukti_pendaftaran_screen.dart
M	lib/screens/detail_wisata_screen.dart
M	lib/screens/profil_user_screen.dart
M	lib/screens/tambah_wisata_screen.dart
M	lib/screens/user_login_screen.dart
M	lib/screens/user_register_screen.dart
M	lib/services/api_client.dart
M	lib/services/auth_session.dart
M	macos/Flutter/GeneratedPluginRegistrant.swift
M	pubspec.lock
M	pubspec.yaml
M	windows/flutter/generated_plugin_registrant.cc
M	windows/flutter/generated_plugins.cmake
A	docs/phase6_firebase_cleanup.md
A	lib/data/review_state.dart
A	lib/widgets/reviews_sheet.dart
A	test/phase6_business_test.dart
A	test/phase6_live_api_test.dart
A	test/phase6_reviews_widget_test.dart
M	test/admin_destination_form_test.dart
```
