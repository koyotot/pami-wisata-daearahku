# PRD — Flutter Authentication UI/UX & Email Verification OTP

**Project:** Wisata Daerahku  
**Platform:** Flutter Android (Android Emulator; production-compatible)  
**Backend:** Laravel REST API (existing, OTP registration `role = 0`)  
**Tanggal:** 1 November 2026  
**Status:** Siap diimplementasikan oleh Codex  
**Prioritas yang diminta:** **5 → 4 → 3 → 2 → 1**  
**Batas pekerjaan:** Authentication Flutter saja; bukan modul bisnis wisata.

## 1. Tujuan

Menuntaskan integrasi dan tampilan Authentication Flutter untuk alur **Register (email/password) → email OTP → Verify Email → Login**, dengan mempertahankan login terpadu user/admin, Google Sign-In, JWT/refresh rotation, dan konfigurasi API berbasis `.env` yang sudah bekerja.

Implementasi backend OTP Laravel telah dilaporkan lulus pengujian lokal. PRD ini **tidak** meminta pengubahan backend Laravel. Pengiriman SMTP nyata dan E2E Android masih harus dibuktikan; jangan mengklaim PASS tanpa pengujian tersebut.

## 2. Interpretasi urutan 5 → 4 → 3 → 2 → 1

Urutan pekerjaan wajib mengikuti urutan prioritas berikut:

| Urutan | Tahapan asli | Deliverable |
|---|---|---|
| Pertama | **5. Uji Register → OTP → Verified → Login** | Definisikan skenario E2E, audit baseline, persiapan emulator/API/SMTP, dan cek blocker. **Uji sukses penuh baru mungkin setelah tahapan 4–1 selesai**, sehingga jalankan ulang pada akhir pekerjaan. |
| Kedua | **4. Integrasi AuthSession dengan OTP Laravel** | Service/network/state/navigation contract yang aman, dengan test. |
| Ketiga | **3. Buat VerifyEmailOtpView** | Halaman OTP 6 digit, verify/resend, aksesibilitas, state handling, dan test. |
| Keempat | **2. Redesign RegisterView** | Form registrasi yang konsisten dan transisi ke OTP setelah `verification_required`. |
| Kelima | **1. Redesign LoginView** | Hierarki desain yang dipoles, login terpadu, dan pemulihan jalur pengguna belum terverifikasi. |
| Penutupan | **Uji tahap 5 (final)** | Pengujian Android E2E dan regresi final; laporkan PASS / FAIL / NOT VERIFIED. |

**Jangan menandai tahap 5 PASS pada awal pekerjaan hanya berdasarkan mocked tests.**

## 3. Sumber kebenaran dan aturan scope

- Audit nama file, arsitektur routing, model sesi, repository, serta API client yang **benar-benar ada**; jangan mengarang path/kelas/endpoint.
- `lib/services/auth_session.dart` merupakan entry point sesi yang sudah dikenal; `ApiClient` memanggil `AuthSession.requestEnvelope` / `publicEnvelope`. Reuse existing code, termasuk generation guard, bearer auth, refresh single-flight, logout, dan storage.
- Gunakan `AppConfig.apiBaseUrl` dan `--dart-define-from-file` existing. Jangan hardcode URL Laravel di widget.
- Public register selalu user `role = 0`; jangan kirim atau izinkan pemilihan role di RegisterView.
- **Tidak ada OTP untuk admin (`role = 1`), superadmin (`role = 2`), maupun Google Sign-In yang telah memenuhi verifikasi provider/backend.** Kebijakan backend adalah sumber kebenaran.
- Admin/user **tetap satu LoginView**. Jangan menciptakan halaman login admin tersendiri.
- Forgot/Reset Password (reset link) **ditunda**; jangan implementasikan ulang atau mengubah mekanismenya dalam PRD ini. Jangan menampilkan tombol baru yang tidak berfungsi.
- Jangan ubah UI/modul katalog, detail wisata, favorit, booking, kuota, pembayaran, review, check-in, admin dashboard, atau backend Laravel.
- Jangan melakukan refactor global, menambah dependency tanpa justifikasi, commit, push, atau deployment.
- Komponen tombol **Back** pada desain existing **bukan prioritas redesign** saat ini; cukup pastikan navigasi tidak merusak alur.

## 4. Kontrak API Laravel yang wajib dipakai

Semua respons mengikuti **envelope `data` existing**; pastikan lokasi field dari kode/response sebenarnya sebelum parsing.

### 4.1 Registrasi

`POST /api/v1/auth/register`

- Field registrasi **tetap mengikuti kontrak existing** (audit request Laravel/current Flutter; jangan mengasumsikan field baru).
- Respons sukses tetap menyediakan token dan user sesuai existing, dan menambahkan:
  - `verification_required: true`
  - `expires_in_seconds: 600`
  - `resend_after_seconds: 60`
  - pesan anjuran memeriksa email.
- User email/password yang baru dibuat wajib dibawa ke VerifyEmailOtpView, **bukan dashboard**.
- Backend menerbitkan JWT sebelum verifikasi. Pertahankan integrasi token existing tetapi **jangan menggunakan token tersebut untuk membuka fitur terlindungi** sampai status verified terkonfirmasi.

### 4.2 Verifikasi OTP

`POST /api/v1/auth/email-verification/verify-otp`

```json
{"email":"user@example.com","otp":"123456"}
```

- `otp` adalah **string enam digit**, bukan integer; pertahankan leading zero.
- Sukses `200` dengan bentuk `{"data":{"message":"Email verified."}}`.
- OTP invalid, expired, habis percobaan, atau sudah dipakai mengembalikan `422` generik. UI **tidak boleh mengklaim mengetahui penyebab spesifik** hanya dari `422`.
- Periksa route middleware aktual untuk kebutuhan autentikasi; jangan mengasumsikan endpoint publik/ber-Bearer tanpa audit.

### 4.3 Kirim ulang OTP

`POST /api/v1/auth/email-verification/resend-otp`

```json
{"email":"user@example.com"}
```

- `200` bersifat **generik**, termasuk kemungkinan email tidak terdaftar atau masih cooldown. UI tidak boleh menjanjikan email pasti terkirim.
- Cooldown backend: **60 detik**; rate limit `429` mungkin terjadi. Tampilkan pesan netral, patuhi header retry jika tersedia.
- Resend sukses yang valid membatalkan kode lama; pastikan Flutter tidak menyimpan/menampilkan kode sebelumnya.

### 4.4 Session status dan akses

- Gunakan `auth/me` existing dan field verifikasi user aktual untuk mendeteksi akun belum verified saat app launch, login, dan resume.
- User belum verified dapat memakai `auth/me` dan logout, tetapi backend memberikan `403` pada fitur terlindungi.
- **Jangan klasifikasikan seluruh respons `403` sebagai email belum verified.** Gunakan indikator spesifik yang benar-benar tersedia pada respons/model. Jika tidak tersedia, dokumentasikan kontrak yang perlu dikonfirmasi, bukan mengarang error code.
- Pertahankan behavior token/session yang sudah ada pada admin, superadmin, dan Google login.

## 5. Tahap 5 — Test-first E2E plan dan baseline (dikerjakan PERTAMA)

**Tujuan:** menentukan hasil yang dapat diverifikasi sebelum mulai mengubah kode.

1. Audit current Flutter auth routing, RegisterView, LoginView, AuthSession, secure storage, model user, dan automated tests existing.
2. Catat baseline (`flutter test`, targeted analyze) serta warning/info yang sudah ada; jangan menyebut lint existing sebagai regresi baru. Laporan terakhir menyebut **209 PASS, 1 skip**, analyzer **180 warning/info, 0 error**, tetapi ukur ulang baseline checkout saat ini.
3. Periksa env development, emulator, koneksi Laravel localhost, Gmail SMTP, dan queue worker; laporkan dependency yang tidak aktif.
4. Definisikan automated tests dan checklist manual dari tabel berikut. Lakukan baseline tanpa mengklaim flow OTP sukses saat view belum ada.

**Matriks E2E wajib:**

| ID | Skenario | Hasil yang diharapkan |
|---|---|---|
| E01 | Register user baru lewat email/password | Akun `role = 0`, `verification_required = true`, masuk OTP View, bukan dashboard |
| E02 | Email dari Gmail SMTP diterima | Pengguna menerima OTP; pemeriksaan inbox nyata, bukan `Mail::fake` |
| E03 | OTP valid 6 digit | Verify `200`, status email terverifikasi, lanjut ke Login |
| E04 | Login ulang setelah verified | Berhasil, masuk area yang sesuai role |
| E05 | OTP salah / expired / terpakai | Tampilkan error generik dari `422`, tidak membuka fitur |
| E06 | Resend selama cooldown | Patuh cooldown; respons `200` generik tidak dianggap bukti terkirim |
| E07 | Resend setelah waktunya | Permintaan diterima, kode lama tak berlaku (cek ketika email nyata tersedia) |
| E08 | Double tap verify/resend, request lambat, offline | Tidak membuat request berulang yang tak perlu, state tetap konsisten |
| E09 | Force close & buka ulang saat belum verified | Tetap menuju OTP gate; tidak masuk dashboard |
| E10 | Login admin dan superadmin existing | Tanpa OTP, routing/role tetap seperti sebelumnya |
| E11 | Google Sign-In existing | Tidak memunculkan OTP registrasi email/password |
| E12 | Logout/refresh/restore sesudah verified | Tidak terjadi regresi session handling |
| E13 | Response `403` selain unverified | Tidak salah diarahkan ke OTP View |
| E14 | Keyboard, screen kecil, screen reader, paste OTP | Form dapat dipakai, tidak overflow |

## 6. Tahap 4 — Integrasi AuthSession ↔ OTP Laravel

**Implementasi sebelum membuat UI baru.**

- Tambahkan method/abstraksi seperlunya pada networking/auth layer existing untuk `verify-otp` dan `resend-otp` (gunakan request public/authenticated sesuai hasil audit route).
- Implementasikan parsing respons `verification_required`, `expires_in_seconds`, `resend_after_seconds`, dan status email verified yang aman terhadap field nullable/missing.
- Tetap gunakan `AppConfig.apiBaseUrl`, HTTP client existing, error mapping existing, dan envelope `data`. Jangan menggandakan client HTTP.
- Definisikan state typed untuk `unverified`, `verifying`, `verified`, `resending`, `rateLimited`, `networkFailure`; jangan menyimpan OTP ke persistent storage atau log.
- Tangani register berhasil dengan JWT: simpan/kelola sesi menggunakan mekanisme existing, tetapi pasang gate agar belum verified hanya boleh mengakses alur terbatas.
- Saat app launch/restore, periksa `/auth/me` untuk menetapkan status yang benar; cegah flicker dashboard saat status masih diperiksa.
- Saat login menggunakan akun user belum verified, arahkan ke OTP View dan tawarkan resend sesuai kontrak, bukan membuat OTP secara otomatis tanpa kebijakan.
- Setelah verify sukses, ambil ulang status `/auth/me` atau cara aman existing untuk memastikan verified. **Target UX PRD ini: pengguna diarahkan ke Login dan login dengan password yang baru didaftarkan.** Jika ada JWT pra-verifikasi, akhiri/bersihkan sesi tersebut melalui mekanisme logout existing secara benar sebelum menampilkan Login (jangan tinggal menyimpan sesi aktif diam-diam).
- Perubahan sesi harus tetap aman terhadap request in-flight, logout/login races, refresh rotation, dan duplicate navigation. Pertahankan generation guard.
- `422`: error generik. `429`: tangani rate limit. Timeout/offline: retry secara aman, tidak mengklaim OTP terkirim/terverifikasi.
- Tulis unit tests / integration tests untuk auth state dan API parsing.

## 7. Tahap 3 — VerifyEmailOtpView (halaman BARU)

**Target UI:** konsisten dengan identitas visual Wisata Daerahku (biru, ilustrasi gunung, permukaan putih, tipografi existing), rapi pada Android.

### Komponen

- Judul jelas: **Verifikasi email**; deskripsi singkat: masukkan kode 6 digit yang dikirim ke alamat email yang ditampilkan dalam format aman.
- Enam slot visual OTP, boleh implementasi satu `TextField` tersembunyi/terpusat untuk menjaga keyboard input, paste, cursor, dan aksesibilitas. `keyboardType: number`, `maxLength: 6`, `autofillHints: [AutofillHints.oneTimeCode]` bila cocok. OTP tetap `String`.
- Tombol utama **Verifikasi**, disabled sampai enam digit valid; loading/double-submit guard saat request.
- Indikator countdown berdasarkan `resend_after_seconds` dari backend (60 detik default hanya bila kontrak terbukti). Jangan menganggap countdown klien sebagai sumber kebenaran throttling.
- Tombol **Kirim ulang kode** aktif setelah waktu lokal yang diketahui; gunakan pesan generik untuk respons 200. Tangani `429` tanpa loop otomatis.
- UI state untuk invalid (`422` generik), connection failure, loading, verified, dan resend feedback. Jangan menampilkan OTP mentah di error/crash logs.
- Hindari overflow ketika keyboard terbuka; scrollable/safe area, touch target minimal ~48dp, label semantik dan fokus yang masuk akal.
- Lifecycle: jika halaman dibuka lagi setelah app restart, dapatkan email dan status verifikasi dari session/user yang sah; jangan menyimpan OTP pengguna untuk prefill.

### Navigasi

- Register berhasil → OTP View.
- Login user unverified → OTP View.
- Verified → konfirmasi sukses singkat → Login; bersihkan sesi pra-verifikasi secara aman.
- Jika user meninggalkan flow, sesi dan route tetap konsisten; tombol Back cukup berfungsi sesuai pola existing, **jangan redesign tombol Back**.

## 8. Tahap 2 — Redesign RegisterView

- Pertahankan identitas visual gunung/matahari dan warna biru, namun rapikan hierarchy, whitespace, konsistensi radius, label input dan state focus/error.
- Pertahankan field registrasi existing dan validasi yang sesuai kontrak backend. Jangan menambahkan pilihan role.
- CTA utama **Daftar** jelas; loading dan pencegahan submit berulang.
- Setelah backend sukses `verification_required=true`, selalu navigasi ke OTP View dengan email terverifikasi sumbernya dari response/request yang sah; jangan redirect dashboard.
- Jika register gagal, tampilkan validation error per field (jika ada) dan pesan umum tanpa membocorkan informasi sensitif.
- Link kembali ke Login tetap tersedia dan berfungsi; keyboard tidak menutupi tombol.
- Jaga konsistensi penggunaan font, ikon, spacing, serta dark/light behavior bila project existing mendukung.

## 9. Tahap 1 — Redesign LoginView

Referensi: screenshot login existing pengguna. **Perbaiki**, bukan ganti identitas desain.

- Pertahankan ilustrasi pegunungan, matahari, palette biru, dan white card/sheet; compact-kan header agar form mendapat ruang lebih baik.
- Hindari headline duplikat antara hero dan form; satu headline dominan dan satu kalimat pendukung netral untuk user/admin.
- Tingkatkan kontras input email/password, border dan focus/error state, ikon visibility, serta jarak antar komponen.
- Pertahankan tombol **Masuk** sebagai CTA utama warna biru; state loading/disabled terdefinisi.
- Jadikan **Masuk dengan Google** tombol secondary full-width yang jelas, bukan link kecil. Pertahankan behavior provider existing.
- Ubah ajakan **Daftar** menjadi hierarki teks/link pendukung sehingga tidak bersaing dengan CTA utama.
- Login admin/superadmin tetap di halaman yang sama. Jangan menampilkan pilihan role.
- Login role 0 belum verified → OTP View. Login user sudah verified → destinasi existing. Admin/Google → flow existing.
- Forgot Password **di luar scope**. Jika saat ini tombol/link sudah ada, jangan merusaknya; jangan membuat link mati baru.
- Tidak mengubah desain tombol Back pada fase ini.

## 10. Testing & quality gates setelah implementasi

1. Unit/widget tests untuk input OTP 6 digit (termasuk `0` pertama, paste, hapus, validasi, loading, error), countdown dan resend.
2. Tests AuthSession untuk register response, verify/resend payload, `422`, `429`, offline, refresh/restore, dan unverified guard.
3. Tests Login/Register: navigasi benar untuk user unverified, verified, admin, Google; tidak ada double submit atau repeated navigation.
4. Jalankan Flutter tests existing dan catat total/skips/regresi. Jangan menerima penurunan baseline tanpa penjelasan.
5. `flutter analyze` boleh memiliki lint lama, tetapi **tidak boleh menambah error analyzer atau warning baru pada file yang disentuh**.
6. Jalankan Android emulator nyata dengan Laravel & MySQL lokal, Gmail SMTP dan queue worker. Buktikan E01–E14 sejauh environment memungkinkan.
7. Bila Gmail, worker, domain/deep link, atau perangkat tidak tersedia, laporkan **NOT VERIFIED** secara jujur; jangan mengganti bukti E2E dengan mocks.
8. Cek `git diff --check` dan format Dart. Jangan commit/push.

### Commands development (PowerShell Windows)

Backend Laravel aktif pada `127.0.0.1:8000` di terminalnya sendiri, dan worker tersedia:

```powershell
php artisan serve --host=127.0.0.1 --port=8000
php artisan queue:work --tries=3 --backoff=60 -v
```

Flutter (terminal terpisah):

```powershell
cd C:\laragon\www\pami-mobile\pami-wisata-daearahku
flutter devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
flutter run -d emulator-5554 --dart-define-from-file=.env.development
```

ID `emulator-5554` contoh; cocokkan dengan `flutter devices`. Jangan menambah `--dart-define=API_BASE_URL=...` jika `.env.development` sudah valid.

## 11. Codex execution, agents, & design skills

- Kerjakan langsung pada repository Flutter existing; audit struktur aktual sebelum menentukan file yang diubah.
- Bila tersedia, gunakan **`.codex/agents/frontend_engineer.toml`** untuk Flutter/UI dan skill **`taste-skill-frontend`** untuk konsistensi visual. Bila agent/skill tidak tersedia, laporkan dan gunakan kemampuan setara yang benar-benar tersedia, tanpa mengklaim telah memanggilnya.
- Minta review implementasi auth/security (gunakan agent security/QA yang tersedia bila memungkinkan), khusus JWT unverified gate, penyimpanan OTP, retry, role routing, dan efek logout.
- Backend contract dari PRD adalah referensi, tetapi bila mismatch dengan source/API aktual, catat mismatch dan lakukan penyesuaian aman pada Flutter; jangan mengubah Laravel di luar scope.
- Lakukan pekerjaan berurutan sesuai **5 (planning/baseline) → 4 → 3 → 2 → 1 → 5 (final E2E)**. Tidak boleh melewati tahap verifikasi akhir.

## 12. Definition of Done & laporan akhir

**DONE untuk implementasi Flutter** hanya jika:

- AuthSession menangani verifikasi OTP, resend, status unverified, login, logout dan restore tanpa regresi.
- VerifyEmailOtpView tersedia dan dapat dipakai, termasuk state error/loading/cooldown.
- RegisterView dan LoginView selesai dipoles dengan komponen dan hierarki konsisten.
- User role 0 email/password tidak bisa melewati gate sebelum email verified; admin/superadmin/Google tidak terkena OTP registrasi.
- Tests Flutter + analyzer terkait + diff check dilaporkan lengkap.
- E2E emulator ditandai **PASS** hanya jika benar-benar terbukti. SMTP/inbox/device yang belum diuji tetap **NOT VERIFIED**, bukan COMPLETE E2E.

Laporan akhir wajib mencantumkan:

1. File yang dibuat dan diubah; alasan.
2. Ringkasan setiap tahap dalam urutan 5 → 4 → 3 → 2 → 1.
3. Perubahan state AuthSession dan aturan navigasi role/unverified.
4. Hasil unit/widget tests dan baseline versus setelah perubahan.
5. Hasil E2E E01–E14 (PASS/FAIL/NOT VERIFIED) dan bukti yang tersedia.
6. Masalah eksternal, endpoint mismatch, dan tindak lanjut yang diperlukan.
7. Konfirmasi tidak ada perubahan backend, main business logic, commit, push, atau deployment.
