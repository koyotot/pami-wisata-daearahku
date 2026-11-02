# PRD — Flutter Authentication UI Redesign | Wisata Daerahku

**Status:** APPROVED — acuan implementasi UI berdasarkan interactive wireframe final dalam percakapan, 2 November 2026  
**Project:** Wisata Daerahku (Flutter mobile)  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Platform utama:** Android / Android Emulator; pertahankan kompatibilitas platform yang sudah didukung  
**Area:** Authentication presentation (Login, Register, Forgot Password, Reset OTP, New Password, Success)  
**Implementation owner:** `flutter_engineer`  
**Mandatory mobile-design skill:** Taste Skills / `design-taste-frontend` (adaptasikan prinsip untuk Flutter mobile)  
**Design authority:** `docs/DESIGN.md` pada checkout terbaru + interactive wireframe final yang disetujui user.

> **BRIEF UTAMA UNTUK AGENT:** Implementasikan tampilan dan interaksi persis mengikuti wireframe final yang disepakati: *blue mountain header* di bagian atas dan *single white sheet* yang berlanjut hingga bawah. **Jangan** mengganti business logic, alur role, OAuth, `AuthSession`, API Laravel, atau keamanan reset password. Tidak ada card abu-abu tambahan di dalam white sheet. Khusus halaman Register: **tidak ada tombol Back di atas**; cukup tautan **“Sudah punya akun? Masuk”** tepat setelah CTA **“Daftar →”**.

## 1. Dokumen dan sumber kebenaran

1. Baca **`docs/DESIGN.md`** sepenuhnya dari **checkout lokal yang sedang dikerjakan**. File ini adalah audit UI/UX dan rujukan identitas visual yang sudah ada, **bukan izin untuk menghidupkan kembali arsitektur Firebase lama**. Jika terdapat revisi `DESIGN.md` lokal lebih baru, prioritaskan versi lokal tersebut.
2. Pahami interactive wireframe final yang disetujui user dalam percakapan ini, khususnya versi akhir yang mencakup **Login, Daftar, Lupa Password, OTP, Password Baru, dan Berhasil**, termasuk permintaan warna putih merata.
3. Inspeksi implementasi aktual dan pemeriksaan `git status` / `git diff` **sebelum menulis perubahan**. Jangan menimpa perubahan lokal yang belum di-commit.
4. Untuk keputusan identitas (font, palet, radius, spacing, elevation), selaraskan dengan `docs/DESIGN.md` dan style autentikasi yang aktif. Untuk susunan layar dan UX autentikasi, gunakan approved wireframe. Jika terdapat konflik dengan backend/auth flow, **pertahankan kontrak business logic yang berlaku**.
5. Jangan menganggap source kode dari cache/commit lama sebagai versi final. Public `main` pernah memperlihatkan snapshot lebih lama; checkout lokal terbaru wajib menjadi otoritas implementasi.

### Penugasan Agent dan Skills (WAJIB)

- **Agent utama:** `flutter_engineer`. Cari dan baca `.codex/agents/flutter_engineer.toml` apabila tersedia pada workspace lokal; gunakan aturan kerja Flutter di sana. Bila letak/nama file berbeda, temukan definisi agent yang benar dan laporkan lokasinya, jangan membuat path palsu.
- **Skill wajib:** **Taste Skills untuk Mobile**, termasuk skill bernama `design-taste-frontend` bila tersedia. Terapkan prinsip visual hierarchy, spacing rhythm, contrast, component fidelity, typography, interaction states, dan responsive mobile behavior; implementasi **Flutter/Dart native**, bukan HTML/CSS atau webview.
- Jika skill/agent tidak tersedia di environment eksekusi, jangan mengklaim telah digunakan. Laporkan keterbatasan dan lanjutkan dengan pedoman `docs/DESIGN.md` serta spesifikasi di PRD.
- Fokus pengembangan: implementasi UI oleh `flutter_engineer`; validasi melalui Flutter widget tests dan pemeriksaan kompilasi, tanpa meminta perubahan backend.

## 2. Latar belakang dan masalah

Alur autentikasi Flutter sudah ada dan telah diintegrasikan ke Laravel, namun halaman-halaman memiliki presentasi tidak seragam. Login mempunyai identitas gunung/biru; halaman recovery pada source yang diperiksa menggunakan Scaffold biru, AppBar dan card putih terpusat; Register memakai struktur visual terpisah. Ini menghasilkan fragmentasi UX, termasuk kesan panel abu-abu pada OTP.

**Hasil yang diinginkan:** enam tahap autentikasi tampak satu keluarga, menggunakan hero gunung biru dan white sheet **`#FFFFFF`** yang menyatu, dengan formulir sederhana, spacing rapi, kontras terbaca, serta interaksi yang tetap aman dan menggunakan backend yang sudah berjalan.

## 3. Scope dan non-scope

### In scope

- Redesign **Login**, **Daftar/Register**, **Lupa Password**, **Verifikasi OTP Reset Password**, **Buat Password Baru**, dan **Reset Berhasil**.
- Komponen presentasi bersama: reusable scenic header, white sheet/shell, field, CTA gradient, link, divider, password visibility toggle, OTP six-box, status/error/loading dan success illustration/icon.
- Navigation UX dan route transition **sebatas kebutuhan menampilkan halaman**, mempertahankan `AuthSession` dan kondisi route/role yang sudah ada.
- Keyboard behavior, SafeArea/system bar, scroll, ukuran layar sempit, autofill, focus, accessibility labels, validation UI, loading/disabled states.
- Widget tests pada perilaku dan navigasi autentikasi yang terpengaruh.

### Out of scope (DILARANG)

- Perubahan backend Laravel, database, migrasi, struktur JSON/endpoint, token, reset ticket, cooldown backend, atau rate limiting.
- Mengganti Google Sign-In/Firebase ID token exchange dan alur Laravel JWT.
- Mengganti login terpadu user/admin dan aturan role `0/1/2`, email verification flow, secure storage, refresh rotation, logout/session generation, atau mekanisme FCM.
- Menambah Firebase Firestore business flow, menghidupkan ulang admin login terpisah, mengganti state management seluruh aplikasi, redesign layar wisata/dashboard, atau menambah dependency besar tanpa kebutuhan jelas.
- Hardcode kode OTP demo `123456` pada aplikasi nyata; nilai tersebut **hanya berlaku untuk wireframe interaktif**.

## 4. Audit repository dan kandidat file

Repository yang ditinjau: `https://github.com/koyotot/pami-wisata-daearahku`. `docs/DESIGN.md` ditemukan di subfolder `docs/` (bukan root). Pada source yang dapat diakses, file-file berikut teridentifikasi:

| File | Jenis perubahan | Kebutuhan |
|---|---|---|
| `lib/screens/user_login_screen.dart` | **Modify** | Layout Login, scenic header, white sheet, UI form, Google outlined button, link ke Register dan Forgot. Pertahankan `session.login`, Google Sign-In dan navigasi role. |
| `lib/screens/user_register_screen.dart` | **Modify** | Layout Register baru, dua kelompok field, **tanpa tombol back atas**, link Masuk di bawah CTA, tampilkan validasi server. Pertahankan `AuthSession.register` dan destination pascaregistrasi. |
| `lib/screens/forgot_password_screen.dart` | **Modify** | Ganti background biru/card terpusat dengan shared shell + email form putih. Pertahankan request forgot-password dan error generik anti-enumeration. |
| `lib/screens/verify_reset_otp_screen.dart` | **Modify** | Reuse six-box OTP, unified shell, resend/change email, state loading/error; pertahankan `reset_ticket`, cooldown, error 422/429. |
| `lib/screens/reset_password_screen.dart` | **Modify** | Password + confirmation dalam white sheet, countdown validitas reset ticket, error state, dan transisi ke layar sukses setelah API berhasil. |
| `lib/screens/auth_presentation.dart` | **Modify / extend** | Prioritas untuk shared `AuthTheme`, scenic scaffold/shell, form field, OTP presentation, CTA, error. Hindari duplikasi komponen dan warna. |
| `lib/screens/reset_password_success_screen.dart` | **New, jika diperlukan** | Halaman sukses reset yang konsisten; alternatif reusable success screen dalam susunan yang sudah ada. |
| `lib/screens/session_destination.dart` | **Read only / minimal only if necessary** | Tetap pertahankan route role user/admin dan email verification. |
| `lib/services/auth_session.dart` | **Read only** | Kontrak existing wajib dipakai, **jangan refactor auth business logic**. |
| `lib/screens/verify_email_otp_screen.dart` | **Read only** | Flow verifikasi email **berbeda** dari reset password OTP; jangan campur state/ticket. |
| `lib/main.dart`, `lib/theme/*`, `pubspec.yaml` | **Conditional** | Ubah hanya jika dibuktikan perlu untuk shared styles/assets; jangan mengubah global theme yang dapat merusak layar non-auth. |
| `test/**` | **Add / modify targeted tests** | Widget tests state, navigation, responsive, registration and recovery paths. Gunakan struktur test aktual. |

**Penting:** file baru `reset_password_success_screen.dart` masih **proposal**, bukan klaim file sudah ada. Nama file aktual lain dapat berbeda di checkout lokal; lakukan pencarian dahulu. Hindari modifikasi file di luar scope kecuali diperlukan dan dijelaskan.

### Hasil pemeriksaan logika eksisting yang perlu dijaga

- `sessionDestination()` meneruskan user role `0` ke `MainNavigationScreen`, role `1/2` ke `AdminDashboard`, dan dapat meneruskan ke verifikasi email jika perlu. Jangan putus alur ini.
- Forgot password menggunakan endpoint **`POST auth/forgot-password`** dan kemudian membuka `VerifyResetOtpScreen`.
- OTP verification menggunakan **`POST auth/password-reset/verify-otp`** dengan email dan OTP; respons menyediakan `reset_ticket` + `expires_in_seconds` untuk tahap berikutnya.
- Resend menggunakan **`POST auth/password-reset/resend-otp`** dan cooldown sekitar 60 detik pada kode yang ditinjau. **Jangan** mengganti ini menjadi 59 detik hardcoded hanya demi mockup.
- Reset menggunakan **`POST auth/reset-password`** dengan email, `reset_ticket`, password, konfirmasi. Jika tiket invalid/expired harus kembali ke alur recovery; jangan membuat sukses palsu.
- `AuthOtpInput` di `auth_presentation.dart` sudah menampilkan 6 kotak melalui **satu `TextField`** dengan digits-only dan `AutofillHints.oneTimeCode`; prioritaskan mempertahankan pendekatan ini untuk input/paste/autofill dan menambah polish fokus/error, bukan membuat enam controller yang rapuh.

## 5. Prinsip visual — semua layar

### Layout yang disetujui

1. **Header biru di atas:** ilustrasi pegunungan berlapis, matahari, awan kecil, badge brand `Wisata Daerahku`, dan judul kontekstual. Reuse painter/aset existing jika memungkinkan.
2. **White sheet permanen:** panel putih `#FFFFFF` dengan radius hanya pada sudut kiri/kanan atas, sedikit overlap dengan header. **Bukan bottom sheet dragable**: hilangkan handle/garis abu-abu atas.
3. Isi halaman di dalam sheet menggunakan padding konsisten, mengikuti design audit/approved wireframe, bukan card kedua.
4. **Surface form putih sepenuhnya:** `Scaffold` untuk area isi, `SafeArea`, `sheet`, `section` dan area OTP harus senada `#FFFFFF`. **Jangan** letakkan container `#F8F8F8`, `#F5F8FD`, `surfaceVariant`, atau tint Material di belakang body OTP.
5. Input email/password boleh memakai warna light-blue `#F5F8FD` atau token resmi dari design lokal, dengan border pale blue. **Enam kotak OTP menggunakan isi putih**; saat salah, border + angka merah tetapi isi tetap putih.
6. Font utama auth **Plus Jakarta Sans** sesuai penggunaan layar biru yang tercatat di `docs/DESIGN.md`, dengan hierarki judul bold, label jelas, helper muted tetapi kontras tetap terbaca.
7. Primary CTA memakai gaya **biru/gradient** yang senada dengan identitas visual aktual. Google CTA outlined putih; action links biru; helper dan disabled boleh muted.
8. Radius, border, shadow, spacing dan ukuran tulisan mengikuti `docs/DESIGN.md` serta approved wireframe; jangan memperkenalkan keluarga desain baru. Fokus keyboard, tap targets, text scaling dan aksesibilitas.
9. Sun/awan **tidak boleh bertabrakan** dengan status bar, ikon sinyal, baterai atau punch-hole perangkat. Gunakan `MediaQuery.paddingOf(context)` / SafeArea sesuai kebutuhan.
10. Hindari layout fixed-height berbasis screenshot. `SingleChildScrollView` / `LayoutBuilder` / minHeight harus mencegah overflow ketika keyboard muncul dan layar kecil. CTA selalu dapat dijangkau.

### Sketsa hierarki bersama

```text
[ Android system status bar / safe area ]
┌──────────────────────────────────────┐
│ BLUE HERO — badge + title + mountains│
├── WHITE SHEET (rounded top corners) ─┤
│ [Screen-specific form, no gray card] │
│                                      │
│ [Primary CTA]                        │
│ [Secondary links when applicable]    │
│                                      │
│ [safe navigation / bottom padding]   │
└──────────────────────────────────────┘
```

## 6. Spesifikasi layar

### AUTH-01 — Login

- Hero title: **“Selamat datang!”**; brand chip + pemandangan gunung dipertahankan.
- White sheet memuat deskripsi: **“Masuk untuk melanjutkan ke akun Wisata Daerahku.”**
- Field `Email`: mail icon, email keyboard, autofill; field `Password`: lock icon, show/hide; posisi **“Lupa password?”** rata kanan pada baris label Password.
- Primary **“Masuk →”**, separator **“atau”**, secondary outlined **“Masuk dengan Google”**, footer **“Belum punya akun? Daftar”**.
- Hilangkan drag-handle dekoratif; rapikan kontras, jarak label-field, dan spacing form.
- Saat submit: pertahankan login terpadu email/password untuk semua role dan Google hanya untuk role yang diizinkan oleh backend (user role 0); jangan ubah login logic, Google SDK/ID-token flow, auth session, atau penanganan cancel.
- Loading disables repeated taps; error tampil tanpa menggeser layout berlebihan. Setelah berhasil, ikuti **`sessionDestination`** / current routing, bukan langsung memaksa dashboard user.

### AUTH-02 — Daftar / Register (approved final)

- Hero title: **“Mulai petualangan!”**; **white sheet** yang sama.
- **TIDAK ADA tombol Back / Kembali di atas form Register.** Back hardware Android tetap ditangani wajar oleh Navigator.
- Judul **“Buat akun baru”**, subtitle **“Mulai petualanganmu dan jelajahi Nusantara.”**
- Divider halus, section heading **“Informasi pribadi”**:
  - `Nama lengkap` + ikon orang + placeholder **“Masukkan nama lengkap”**.
  - `Email` + mail icon + placeholder **“nama@email.com”**.
- Divider halus, section heading **“Keamanan akun”**:
  - `Password` + lock icon + placeholder **“Minimal 8 karakter”** + icon show/hide.
  - `Konfirmasi password` + lock icon + placeholder **“Ulangi password”** + independent show/hide.
- CTA full-width **“Daftar →”**. **Tepat di bawah CTA** (satu kelompok visual) teks **“Sudah punya akun? Masuk”**; `Masuk` dapat di-tap untuk kembali ke Login. Jangan menaruh link ini di footer yang terlalu jauh, dan jangan menambah tombol back lain.
- Client-side validasi: nama tidak kosong, email valid, password memenuhi syarat backend (minimal delapan jika itu aturan yang aktif), konfirmasi cocok. **Server validation tetap otoritatif**; pertahankan `fieldErrors` Laravel (name/email/password/password_confirmation), loading, dan error.
- Sukses pendaftaran mengikuti behavior `AuthSession.register` / verifikasi email / session destination yang sudah ada. **Jangan membuat OTP reset-password sebagai bagian pendaftaran** dan jangan otomatis memaksakan login bila aturan existing berbeda.

### AUTH-03 — Lupa Password

- Hero title **“Pulihkan akun”**; tautan kecil di awal form **“← Kembali ke Login”**.
- Judul **“Lupa password?”**, deskripsi **“Masukkan email yang terdaftar untuk melanjutkan proses pemulihan akun.”**
- Field `Email` dengan ikonnya; jika berasal dari Login, prefill email yang sudah diketik bila ada.
- CTA **“Kirim kode OTP →”**; validasi email lokal + loading dan error jaringan.
- Setelah **response sukses dari Laravel**, navigasi ke verifikasi OTP dengan email yang sama. Jangan tampilkan konfirmasi yang membocorkan apakah email terdaftar; tetap mengikuti pesan generik server/flow yang ada.

### AUTH-04 — Verifikasi OTP Reset Password

- Hero title **“Pulihkan akun”**; link **“← Kembali ke Lupa Password”**.
- Judul **“Verifikasi kode OTP”**.
- Copy: **“Masukkan 6 digit kode verifikasi yang dikirimkan ke i***@gmail.com untuk mengatur ulang password.”** `i***@gmail.com` adalah contoh; masked email harus dihitung dari alamat sebenarnya dan tidak mengungkap full address.
- Label **“Kode verifikasi”**; tampilkan **6 kotak putih** dengan border biru muda, state fokus biru dan invalid merah. Tidak ada panel abu-abu/tint di belakang kotak.
- Hanya digit; max 6; dukung mengetik, backspace, paste, dan autofill OTP. Boleh gunakan `AuthOtpInput` existing dengan underlying one TextField; pastikan fokus dan aksesibilitas jelas.
- CTA **“Verifikasi kode →”** disabled bila kode belum tepat enam digit, loading saat request; **tidak pernah memverifikasi terhadap angka yang di-hardcode di Flutter**.
- Error 422/invalid/expired menampilkan inline error yang jelas dan bisa diperbaiki; tidak menavigasi ke reset screen tanpa `reset_ticket` yang valid.
- Di bawah CTA, tombol **“Kirim ulang kode (xx dtk)”** dan **“Ubah email”** tersusun vertikal. Cooldown mengikuti existing backend/config (observed default 60 s), `429`/Retry-After tetap dihormati. Reset countdown hanya setelah response sebagaimana kontrak berlaku.
- Helper opsional **“Periksa kotak masuk atau folder spam emailmu.”**
- `Ubah email` kembali ke Forgot dengan data email yang dapat diedit. Navigasi lewat back Android harus aman dan tidak membawa tiket lama.

### AUTH-05 — Buat Password Baru

- Hero title **“Pulihkan akun”**; **“← Kembali ke Verifikasi”** hanya jika back flow masih valid; bila OTP sudah consumed dan API tidak mengizinkan back, arahkan aman untuk minta kode baru, bukan menampilkan OTP yang tidak valid.
- Judul **“Buat password baru”**; deskripsi menyatakan OTP berhasil diverifikasi.
- Field **“Password baru”**, **“Konfirmasi password”** dengan masing-masing show/hide.
- Hint minimal delapan karakter sesuai kontrak saat ini; tampilkan error 422 per-field; disable double submit.
- **Pertahankan informasi masa berlaku `reset_ticket`**, misalnya **“Sisa waktu kode reset: mm:ss”** atau pesan kedaluwarsa, meskipun wireframe ringkas tidak menggambar semua metadata. Jangan menghapus proteksi expiry demi visual.
- Submit memakai endpoint dan payload existing; jika reset ticket expired/invalid, jalankan recovery aman (minta kode baru). Jika hasil request unknown/network timeout, **jangan otomatis menampilkan sukses**.
- Setelah **server mengonfirmasi sukses**, navigasi ke AUTH-06 menggunakan route replacement / clear stack supaya password/OTP/reset-ticket tidak tersisa pada back stack.

### AUTH-06 — Password Berhasil Diubah

- Hero biru pegunungan dan white sheet tetap konsisten.
- Ikon check biru di lingkaran biru muda; title **“Password berhasil diubah!”**.
- Subtitle **“Password akunmu telah diperbarui. Silakan masuk kembali menggunakan password baru.”**
- Primary CTA **“Kembali ke Login →”**, navigasi ke Login dengan back stack bersih.
- **Halaman ini hanya ditampilkan jika API reset-password berhasil** (bukan saat OTP lolos saja atau hasil request tidak pasti).
- Tidak ada auto-login, tidak menampilkan password/tiket, dan tidak menyimpan OTP dalam log.

## 7. Komponen Flutter dan implementasi yang dianjurkan

Implementasi ideal bisa berupa perluasan `lib/screens/auth_presentation.dart` atau komponen kecil yang terpisah **hanya jika relevan dan tidak memaksakan refactor**. Kandidat reusable:

- `AuthScenicShell` / `AuthMountainHeader`: scene painter, status bar overlay, chip brand, hero title, white sheet, scroll & safe-area.
- `AuthTextField`: label, icon, text controller, autofill, obscured state, per-field error, focus state.
- `AuthPrimaryButton`: CTA gradient, enabled/loading/disabled, aksesibilitas.
- `AuthTextLink`, `AuthSectionDivider`, `AuthSectionHeading` dan `AuthGoogleButton`.
- `AuthOtpInput`: adaptasi dari widget existing, satu controller tersembunyi dan enam kotak visual; tidak memindahkan verifikasi kode ke widget.

**Jangan** mengubah tema global `ThemeData` untuk menyesuaikan auth saja bila berisiko merusak halaman wisata/admin. Terapkan scoped theme (existing `AuthTheme`) dengan penggunaan `#FFFFFF` pada area *auth white sheet*. Tidak menambahkan `Card` warna putih di atas sheet putih atau wrapper abu-abu yang membuat konten tampak terpisah.

## 8. State, error dan accessibility

- Visual states: idle, focused, filled, validation error, API error, loading, disabled, success.
- `TextInputType.emailAddress` + autofill email, `TextInputAction.next/done`; password obscured by default, ikon mata masing-masing field independen.
- Flutter `Form`/`TextFormField` atau pola existing yang benar-benar dipakai; tidak wajib mengganti seluruh arsitektur form untuk alasan estetika.
- Jangan menampilkan error merah sebelum pengguna berinteraksi/submit jika validasi belum diminta. Saat error telah muncul, perbarui ketika user memperbaiki input.
- Tap targets bisa dijangkau jari, semantics label untuk ikon mata dan OTP, teks dengan `MediaQuery.textScaler`, hindari clipping pada ukuran kecil dan mode keyboard.
- Pertahankan async guards: `mounted`, current `sessionGeneration`, current route, single-submit lock dan cancel Google; jangan memunculkan navigasi terlambat setelah logout/perubahan sesi.
- **OTP reset** dan **OTP verifikasi email** adalah dua alur terpisah. Kode, payload dan status tiket tidak boleh tercampur.
- Tidak hardcode OTP dalam source produksi, tidak mencetak password/OTP/reset-ticket/token ke log atau Snackbar.

## 9. Rencana implementasi yang diminta

1. **Audit checkout lokal:** baca `docs/DESIGN.md`, definisi agent `flutter_engineer`, Taste Skills mobile (`design-taste-frontend`), seluruh enam screen, shared presentation, auth service, destination, serta test existing. Catat status git dan perubahan lokal.
2. **Bangun shared auth visual shell** terlebih dahulu: scenic header, white sheet `#FFFFFF`, safe area & keyboard scroll, warna/tipografi/radius sesuai design.
3. **Refactor Login dan Register:** pertahankan Google/Login/backend routing; pastikan Register tanpa back atas, dua section jelas, link Masuk setelah CTA.
4. **Refactor Forgot dan OTP:** pastikan white-sheet tanpa gray sub-card dan perilaku 6-digit/cooldown sesuai existing API.
5. **Refactor Reset dan Success:** pertahankan ticket expiry/errors; buat success screen yang hanya muncul sesudah sukses server.
6. **Validasi dan rapikan:** widget tests, analyzer terfokus, run emulator Android, cek ukuran kecil/keyboard; pertahankan file non-auth dan dokumentasikan diff.

## 10. Acceptance Criteria — wajib lulus

- [ ] `docs/DESIGN.md` checkout lokal dibaca sebagai rujukan desain utama, dan Taste Skills mobile / `design-taste-frontend` serta agent `flutter_engineer` dipertimbangkan eksplisit.
- [ ] Semua layar auth memiliki hero gunung biru + **satu white sheet `#FFFFFF`** tanpa card/panel abu-abu di dalamnya.
- [ ] Tidak ada drag handle palsu di atas white sheet; matahari dan elemen header tidak menabrak status bar.
- [ ] `Login`: email/password, toggle eye, Forgot, Google, Daftar, loading/error tetap berfungsi.
- [ ] `Register`: empat field, dua section, divider, dua toggle eye, CTA **Daftar →**, dan tepat di bawahnya **Sudah punya akun? Masuk**. **Tidak ada tombol back atas.**
- [ ] Link **Masuk** di Register membawa kembali ke Login; link Daftar di Login membawa ke Register tanpa membuat halaman login admin terpisah.
- [ ] `Forgot`: validasi email, prefill, request existing, menuju OTP hanya jika request diterima.
- [ ] `OTP`: 6 digit, paste/autofill/backspace, disabled saat belum lengkap, error invalid/expired, masked email, resend countdown dari kontrak existing, Ubah email, dan tanpa hardcode OTP.
- [ ] Input OTP putih pada normal/focused/error, hanya border dan teks berubah saat error; **tidak ada background abu-abu** di belakang.
- [ ] `Reset`: password + konfirmasi, show/hide, ticket expiry, error 422 dan unknown outcome tetap aman.
- [ ] `Success`: tampil hanya setelah respons reset sukses dan tombol kembali Login membersihkan back stack sensitif.
- [ ] `AuthSession`, endpoint, JWT/refresh, Google Sign-In, FCM, role `0/1/2`, registrasi, email verification, serta `sessionDestination` tidak mengalami regresi.
- [ ] Tidak ada overflow pada Android Emulator ukuran sempit, keyboard muncul, text scaling lebih besar, dan status/navigation bar dengan notch/punch-hole.
- [ ] Widget tests relevan lulus; analyzer tidak menambah error atau lint baru pada file yang disentuh (baseline lint lama dilaporkan secara terpisah).
- [ ] Diff hanya menyentuh file sesuai scope atau ada alasan tertulis untuk perubahan tambahan. **Jangan melakukan Git commit kecuali diminta.**

## 11. Test plan (targeted, wajib bukan screenshot-only)

1. Login email invalid/kosong; credential salah; button loading; Google cancel/sukses; role 0 vs role 1/2; email verification required.
2. Register kosong, email malformed, password pendek, password mismatch, server 422 field errors, successful register destination; `Masuk` link; tidak ada back button visual.
3. Forgot valid/invalid, server error, generic response, prefill email, navigation ke OTP.
4. OTP 1–5 digit disabled, 6 digit enabled, paste full OTP, backspace, autofocus, kode salah/expired, kode benar & reset ticket, resend cooldown, API 429, Ubah email.
5. Reset mismatch, ticket expiry, 422 invalid ticket, network unknown, success server → success UI → login clean stack.
6. Layout: 320–360 dp / 390–430 dp width, keyboard covering lower form, text-scale larger, safe area/status bar, semantik interactive controls.
7. Regression focused on existing auth session/refresh concurrency and role routing; no need rerun unrelated destructive integration tests.

## 12. Definition of Done & output handoff

Deliverable implementasi dari `flutter_engineer`:

- Kode Flutter yang mengikuti wireframe final, **bukan gambar mockup atau HTML**.
- Daftar file aktual yang berubah dan alasan tiap perubahan.
- Konfirmasi komponen yang reused vs created, serta mapping acuan `docs/DESIGN.md` dan Taste Skills mobile.
- Ringkasan hasil test/analyzer/emulator; jika belum dijalankan, labeli **BELUM DIVERIFIKASI** dan jangan klaim PASS.
- Catatan regresi dan kompromi UI bila ada, tanpa perubahan business logic Laravel.
- **Tidak ada commit otomatis.**

## 13. Referensi source yang dipakai untuk audit PRD

- [Repository utama](https://github.com/koyotot/pami-wisata-daearahku)
- [Design audit `docs/DESIGN.md`](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/docs/DESIGN.md)
- [Login Flutter](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/user_login_screen.dart)
- [Register Flutter](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/user_register_screen.dart)
- [Forgot Password](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/forgot_password_screen.dart)
- [Verify Reset OTP](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/verify_reset_otp_screen.dart)
- [Reset Password](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/reset_password_screen.dart)
- [Shared Auth Presentation](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/auth_presentation.dart)
- [Session Destination](https://raw.githubusercontent.com/koyotot/pami-wisata-daearahku/main/lib/screens/session_destination.dart)

**Catatan audit:** source publik yang tersedia selama penyusunan dapat berbeda dari workspace lokal terbaru. PRD ini tidak mengklaim telah menguji aplikasi atau membaca file agent lokal. Agent implementasi wajib memastikan kondisi repo aktual terlebih dahulu.
