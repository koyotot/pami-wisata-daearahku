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

Firebase UID bukan GUID Laravel dan tidak dipakai untuk menentukan role/akses.

## Hardening: Google Login hanya untuk role 0

| Metode | Role 0 | Role 1 | Role 2 |
|---|---|---|---|
| Email/password Laravel | Diizinkan | Diizinkan | Diizinkan |
| Google (Firebase Auth) | Diizinkan | Ditolak | Ditolak |

Implementasi Flutter (satu halaman login dan `AuthSession` tetap dipakai):

- `AuthSession.google()` memanggil `_authenticate(allowedRoles: {0})`. Setelah
  `auth/me` memvalidasi role dan status `active`, role di luar `{0}` ditolak
  (`ApiException` 403) **sebelum** `authenticated`/`deviceSessionReady` diset,
  sehingga tidak ada navigasi ke dashboard admin maupun beranda pengguna.
- Penolakan memanggil `clear()` (generasi sesi naik, token & secure storage
  dihapus) lalu mencabut token Laravel yang sempat terbit lewat
  `POST auth/logout` (best effort). Respons async lama dari generasi sebelumnya
  tidak dapat mengaktifkan kembali sesi karena semua pemeriksaan membandingkan
  generasi.
- `user_login_screen.dart` selalu `FirebaseAuth.signOut()` di `finally`, juga
  saat Laravel menolak sesi (sebelumnya dilewati karena generasi sudah berganti).
- Logout tetap membersihkan sesi Laravel; tiap login/pergantian akun mereset
  state akun sebelumnya.

### SECURITY BLOCKER — penegakan di Laravel belum ada

`AuthService::google()` memverifikasi ID token Firebase, lalu mengembalikan sesi
untuk user yang terhubung via `external_identities` **tanpa memeriksa role**.
Akun role 1/2 yang identitas Google-nya terhubung tetap menerima token valid
dari `POST /auth/google`. Pembatasan di Flutter hanya perlindungan sisi klien;
klien lain atau yang dimodifikasi dapat memakai endpoint itu. Pembatasan
**belum dapat dianggap aman** sampai Laravel menolak (mis. 403) exchange Google
untuk role 1/2. Backend tidak diubah (di luar scope); butuh persetujuan terpisah.

### Keterbatasan restore sesi

Kontrak `auth/me`/`UserResource` tidak memuat metode login (password vs Google)
dan JWT tidak diperiksa untuk itu. Karena itu restore hanya dapat memvalidasi
role dan status, bukan metode autentikasi; role saja tidak membuktikan metode.
Sesi Google role 0 dan sesi password role 0 tidak dapat dibedakan setelah
restore. Penegakan sesungguhnya bergantung pada penolakan di backend saat exchange.

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

- PASS: `flutter test --no-pub`, 59 tes mock dan widget (email/password role
  0/1/2, Google role 0, Google role 1/2 ditolak + token dicabut + storage
  kosong, exchange gagal, restore, refresh, pergantian akun, respons terlambat,
  akun nonaktif, guard dashboard).
- PASS: `git diff --check`.
- FAIL: `flutter analyze --no-pub`, 263 issue info/warning lama (tanpa
  penambahan dari perubahan ini); tidak ada error.
- NOT VERIFIED: Google dibatalkan pengguna (kode `cancelled` ditangani, tanpa
  tes otomatis), logout setelah Google Login di perangkat, Firebase signOut
  nyata, secure storage dan FCM pada perangkat, alur visual.
- BLOCKER: penolakan Google role 1/2 di Laravel tidak ada (lihat di atas).
- Catatan: `.codex/agents/` tidak ada di checkout ini, sehingga subagent
  tidak dipakai; audit keamanan dan pengujian dilakukan langsung.

Jika proses Google dibatalkan bersamaan dengan pergantian generasi sesi,
identitas Firebase sementara dapat tertinggal. Identitas tersebut tidak dipakai
untuk otorisasi Laravel; perilaku provider dan pembersihannya perlu diuji pada
perangkat.
