# Phase 5: autentikasi dan routing terpadu

Login email/password, registrasi, dan pertukaran ID token Google menggunakan
`AuthSession` dan API Laravel yang sama. Sesi dipulihkan melalui secure storage
dan divalidasi lewat `GET /api/v1/auth/me` sebelum aplikasi memilih dashboard.
JWT access dan refresh tetap dikelola oleh `AuthSession`; FCM tetap memakai
mekanisme registrasi perangkat yang ada.

Kontrak `UserResource` Laravel menyediakan `guid`, `role` integer, dan `status`.
Hanya `status: active` diterima. Role `0` menuju beranda pengguna; `1` dan `2`
menuju dashboard admin. Role lain dan identitas yang tidak valid ditolak. Guard
Flutter membatasi navigasi, sedangkan otorisasi endpoint tetap dilakukan oleh
Laravel. Role 1 dan 2 tidak disamakan dalam pemeriksaan hak akses backend.

Backend Google menerima identitas provider Google dengan email terverifikasi;
akun yang sudah terhubung dapat memiliki role selain 0. Firebase UID bukan GUID
Laravel dan tidak dipakai untuk menentukan role atau akses.

## Dependensi Firebase Auth yang tersisa

- `user_login_screen.dart`: Google provider dan pertukaran Firebase ID token
  dengan Laravel, termasuk pembersihan sesi Firebase sementara.
- `main_navigation_screen.dart` dan `profil_user_screen.dart`: sign-out serta
  cabang profil, password dan penghapusan akun Firebase lama.
- `bukti_pendaftaran_screen.dart`: cabang bukti/review Firestore historis yang
  menggunakan Firebase UID. Data tersebut belum dipetakan ke identitas Laravel.
- `firebase_auth` tetap menjadi dependency; Firestore dan FCM juga tetap ada.

Fitur historis Firebase dan data bisnis di luar autentikasi tidak dimigrasikan
dalam perubahan ini. Phase 1, 3, 4, dan 5 masing-masing memiliki dokumentasi
migrasi terpisah; dokumentasi Phase 2 tidak ditemukan di checkout ini.

## Batas verifikasi

Tes lokal menggunakan HTTP mock dan tidak membuktikan autentikasi Laravel,
Google, secure storage, FCM, atau navigasi pada perangkat. Cakupan dan hasil
perintah pemeriksaan dicatat dalam laporan implementasi.

## Hasil pemeriksaan lokal

- PASS: `flutter test --no-pub`, 56 tes mock dan widget, termasuk role,
  restore, refresh, pergantian akun, respons terlambat, dan guard dashboard.
- PASS: `git diff --check` untuk file terlacak.
- FAIL: `flutter analyze --no-pub`, 263 warning/info proyek; tidak ada error
  yang dilaporkan.
- NOT VERIFIED: Laravel, Google provider, secure storage dan FCM pada perangkat
  nyata, serta alur visual dan regresi bisnis end-to-end.

Jika proses Google dibatalkan bersamaan dengan pergantian generasi sesi,
identitas Firebase sementara dapat tertinggal. Identitas tersebut tidak dipakai
untuk otorisasi Laravel; perilaku provider dan pembersihannya perlu diuji pada
perangkat.
