# PRD — Wisata Daerahku
## Phase 1: Flutter × Laravel API Integration — Authentication & API Foundation

**Status:** Siap diberikan kepada Codex  
**Model Codex yang dipilih:** Luna — Extra High  
**Target:** Proyek Flutter `wisata_daerahku` (aplikasi mobile) dan backend Laravel REST API Wisata Daerahku  
**Jenis pekerjaan:** Implementasi terfokus, bukan redesign atau rewrite aplikasi

---

## 1. Tujuan

Integrasikan UI Flutter **yang sudah ada** dengan autentikasi Laravel API, sehingga pengguna dapat mendaftar, login email/password, login Google, memulihkan sesi, mengambil profil, melakukan refresh token, dan logout secara aman.

Jadikan `DESIGN.md` di root repository Flutter sebagai **acuan desain utama**. Integrasi harus mengikuti struktur folder, navigasi, state management, dan pola komponen aktual, bukan membuat arsitektur paralel tanpa alasan.

**Jangan mengintegrasikan katalog, favorit, booking, payment, notifikasi, atau tiket PDF pada fase ini.**

## 2. Konteks backend yang sudah diketahui

Dari handoff implementasi backend per 29 Oktober 2026:

- Base route API menggunakan prefix `/api/v1`.
- Rute autentikasi meliputi `POST /auth/register`, `/auth/login`, `/auth/google`, `/auth/refresh`, `/auth/logout`, serta `GET /auth/me`.
- Rute profil antara lain `PATCH /profile`; fitur verifikasi email dan forgot/reset password sudah tersedia di backend.
- Laravel menggunakan **JWT access token 15 menit** serta **refresh token 30 hari**, yang disimpan sebagai hash dan dirotasi; reuse refresh token mencabut sesi terkait.
- Google Sign-In memakai **Firebase ID Token yang ditukarkan ke JWT Laravel**. Jangan menganggap Firebase ID Token sebagai token otorisasi endpoint Laravel.
- Pengujian awal backend sudah berjalan dengan SQLite; integrasi Firebase nyata dan pengujian MySQL concurrency belum sepenuhnya tervalidasi.

**Seluruh bentuk JSON, status HTTP, nama field, format error, kebijakan verifikasi email, dan perilaku endpoint wajib diperiksa langsung pada code Laravel** (`routes/api.php`, Requests, Resources, Services, konfigurasi JWT, README). Informasi di atas adalah konteks awal, bukan izin mengarang kontrak API.

## 3. Agent, skill, dan persiapan wajib

1. Gunakan **Luna — Extra High** sebagai model pengarah pekerjaan.
2. Delegasikan analisis dan implementasi Flutter kepada sub-agent `.codex/agents/flutter_engineer.toml` (`flutter_engineer`).
3. Gunakan `backend_engineer` untuk audit kontrak Laravel dan perbaikan backend **hanya jika benar-benar dibutuhkan**.
4. Gunakan `security_auditor` untuk memeriksa penyimpanan token, refresh rotation, penanganan 401, dan kebocoran data autentikasi.
5. **WAJIB baca dan gunakan `design-taste-frontend` (Taste Skill Frontend Design)** sebelum menyentuh komponen UI. Gunakan hanya untuk **mempertahankan** bahasa visual yang sudah terdokumentasi pada `DESIGN.md`, bukan mendesain ulang. Jika skill tidak tersedia, laporkan secara jujur; jangan mengklaim telah menggunakannya.
6. Baca `DESIGN.md`, `pubspec.yaml`, autentikasi Flutter existing, navigation, state management, HTTP/service layer existing, serta kontrak Laravel sebelum menulis kode.
7. Jika backend dan Flutter berada pada dua repository berbeda, pastikan kedua repository tersedia untuk dibaca. **Jangan menebak** response JSON hanya dari README/handoff.

## 4. Scope implementasi Phase 1

### A. API foundation

- Konfigurasikan API base URL sesuai environment aktual (local/dev/staging jika ada) menggunakan mekanisme konfigurasi yang paling selaras dengan proyek.
- Gunakan HTTP client/dependency existing apabila layak; jangan menambahkan package atau arsitektur baru tanpa kebutuhan jelas.
- Buat atau rapikan satu jalur komunikasi API untuk request, response, header authorization, timeout, dan pemetaan kesalahan yang konsisten.
- Pastikan error jaringan, timeout, server error, validasi (`422` bila sesuai backend), unauthenticated (`401`), serta forbidden (`403`) ditangani tanpa membocorkan informasi sensitif.
- Jangan hardcode URL backend production atau secret pada source code.

### B. Email/password authentication

- Hubungkan form login existing ke `POST /api/v1/auth/login`.
- Hubungkan form register existing ke `POST /api/v1/auth/register`.
- Gunakan field dan response yang benar-benar dinyatakan oleh Form Requests dan Resources Laravel.
- Tampilkan loading, validasi, error, dan sukses dengan komponen/pola visual existing.
- Cegah submit berulang ketika request masih berjalan.
- Ikuti kebijakan email verification backend bila memengaruhi alur login; jangan menciptakan flow baru tanpa dasar kontrak.

### C. Google Sign-In via Firebase exchange

- Pertahankan mekanisme Firebase Google Sign-In yang memang diperlukan di Flutter.
- Peroleh Firebase ID Token lewat Firebase Authentication SDK, lalu kirim ke `POST /api/v1/auth/google` sesuai payload backend.
- Gunakan access/refresh token hasil exchange Laravel untuk akses endpoint API terlindungi.
- Tangani cancel, error Firebase, token tidak valid, akun diblokir, dan kegagalan exchange tanpa membuat sesi Laravel palsu.
- Jangan membuat mekanisme penggabungan akun Google dan email sendiri; patuhi aturan backend.

### D. Session lifecycle dan token security

- Simpan access token dan refresh token dengan mekanisme penyimpanan aman yang sesuai platform. Audit dependency existing dahulu; bila belum tersedia, usulkan package yang diperlukan secara minimal.
- Implementasikan restore session saat aplikasi dibuka kembali.
- Gunakan header `Authorization: Bearer <access_token>` untuk endpoint terlindungi.
- Terapkan refresh otomatis saat access token kedaluwarsa sesuai kontrak Laravel, dengan **single-flight refresh** agar banyak request tidak memakai refresh token lama secara bersamaan.
- Simpan refresh token baru secara atomik setelah rotasi berhasil; jangan menggunakan kembali refresh token lama.
- Batasi retry request agar tidak menghasilkan loop refresh tanpa akhir. Jika refresh gagal/ditolak, bersihkan sesi lokal dan arahkan pengguna ke alur autentikasi existing.
- Logout melalui `POST /api/v1/auth/logout` bila endpoint tersedia sesuai kontrak, lalu bersihkan credential lokal, termasuk pada kegagalan jaringan dengan penanganan yang sesuai.
- Jangan log token, kredensial, Firebase ID Token, response autentikasi sensitif, atau password ke console/crash reporting.

### E. Current user / profile

- Integrasikan `GET /api/v1/auth/me` untuk memperoleh identitas pengguna yang terautentikasi.
- Petakan data profile ke model/state existing tanpa mengubah tampilan dan perilaku unrelated.
- Jika user belum login atau sesi tidak valid, gunakan authentication guard/navigation yang memang sudah ada.
- Tidak perlu membangun ulang fitur edit profil atau forgot password kecuali adaptasi minimal terbukti mutlak untuk menjaga alur autentikasi.

## 5. Batas scope — tidak boleh melebar

**Boleh diubah:** file Flutter yang memang berhubungan dengan API client, autentikasi, token/session, state, model pengguna, konfigurasi environment, dan wiring UI login/register/profile. File backend hanya boleh diubah untuk bug atau mismatch kontrak autentikasi yang telah dibuktikan; jelaskan alasannya dalam hasil akhir.

**Tidak boleh diubah tanpa kebutuhan yang dapat dibuktikan:**

- `DESIGN.md` sebagai hasil audit, color palette, tipografi, spacing, layout, animasi, atau desain visual.
- Navigasi di luar flow auth, layar katalog/destinasi, favorit, booking, payment, notifikasi, tiket, QR, dan fitur wisata lain.
- Firebase integration untuk modul lain yang tidak termasuk scope.
- Skema database, migration, business logic booking, role/privilege, atau kebijakan keamanan Laravel.
- Package/dependency, kecuali kebutuhan teknis yang tidak dapat dipenuhi dependency existing dan dijelaskan secara singkat.

Jangan membuat screen baru jika screen existing cukup. Jangan mengganti arsitektur Flutter secara menyeluruh hanya demi memanggil API. Jangan menjalankan migrasi destruktif seperti `migrate:fresh` terhadap database berisi data.

## 6. Prosedur eksekusi Codex

1. **Audit Flutter:** inventarisasi flow login/register/Google/profile, state, routing, service, dan komponen existing; cocokkan dengan `DESIGN.md`.
2. **Audit Laravel:** verifikasi route, middleware, request payload, output Resources, status/error response, aturan refresh rotation dan logout.
3. **Mapping kontrak:** buat pemetaan internal `Screen → Action → Endpoint → Request → Response → State` sebelum mulai mengubah kode. Tidak perlu membuat file dokumentasi baru.
4. **Implementasi minimal:** mulai dari API client dan login email/password, kemudian register, Google exchange, session refresh/restore, logout, dan `/auth/me`.
5. **Verifikasi:** jalankan analyzer dan pemeriksaan relevan yang sudah tersedia, lalu uji alur autentikasi terhadap Laravel lokal **jika lingkungan benar-benar tersedia**. Jangan mengaku end-to-end PASS bila Firebase/perangkat/backend tidak terhubung.
6. **Security review:** gunakan `security_auditor` untuk memeriksa race refresh token, unauthorized handling, logout, dan sensitive logging.
7. **Ringkas hasil:** laporkan file yang berubah, endpoint yang dihubungkan, verifikasi yang dijalankan, hambatan, serta pekerjaan yang sengaja ditunda.

## 7. Perhatian environment lokal

- Backend Laravel harus berjalan, MySQL terkoneksi, dan endpoint auth dapat dijangkau dari perangkat Flutter yang digunakan.
- Android Emulator umumnya memakai `10.0.2.2` untuk mengakses host development, **bukan** `localhost` emulator. Untuk perangkat fisik, gunakan alamat jaringan host yang dapat dijangkau dan pengaturan jaringan yang sesuai.
- Periksa aturan Android/iOS terkait HTTP cleartext atau HTTPS development; jangan menonaktifkan verifikasi TLS secara permanen.
- Jangan commit `.env` rahasia, service account, credential, atau token pengujian.

## 8. Acceptance criteria

- Login email/password dan register bekerja dengan API Laravel sesuai kontrak aktual.
- Google Sign-In menukar Firebase ID Token menjadi sesi Laravel (bila Firebase test environment tersedia).
- Sesi dapat dipulihkan setelah aplikasi dibuka ulang dengan penyimpanan token yang aman.
- Refresh JWT berjalan sesuai rotation backend, tidak melakukan refresh paralel menggunakan token yang sama, dan gagal dengan aman.
- Logout menghapus credential lokal dan menggunakan mekanisme revoke backend sesuai kontrak.
- Data current user diperoleh dari `/api/v1/auth/me` dan ditampilkan melalui UI existing.
- Loading, error, validasi, serta sesi kedaluwarsa ditangani tanpa perubahan desain yang tidak relevan.
- Tidak ada implementasi booking, payment, katalog, atau fitur di luar auth pada fase ini.
- Setiap acceptance criterion yang belum dapat diverifikasi secara nyata ditandai **BELUM TERVERIFIKASI**, bukan otomatis PASS.

## 9. Format laporan akhir Codex

Berikan hasil singkat yang mencakup:

1. Ringkasan perubahan dan daftar file utama yang disentuh.
2. Endpoint yang telah dihubungkan dan cara kerja sesi.
3. Hasil analyzer/test dan pengujian nyata beserta status PASS/FAIL/NOT RUN.
4. Perubahan backend bila ada, beserta alasan teknisnya.
5. Kendala/risiko dan batasan lingkungan.
6. Konfirmasi bahwa `DESIGN.md` dipatuhi dan UI existing tidak di-redesign.

**Instruksi akhir:** Eksekusi Phase 1 secara terfokus menggunakan `flutter_engineer`, `backend_engineer` bila diperlukan, dan `security_auditor`. Terapkan Taste Skill Frontend Design sebagai pedoman konsistensi, pertahankan UI existing, dan prioritaskan keamanan kontrak auth Flutter ↔ Laravel.
