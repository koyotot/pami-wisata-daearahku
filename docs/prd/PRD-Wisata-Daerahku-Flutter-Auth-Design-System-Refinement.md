# PRD — Wisata Daerahku: Flutter Authentication Design System Refinement

**Status:** Siap diimplementasikan oleh Codex; belum merupakan perubahan source code.  
**Repository:** `C:\laragon\www\pami-mobile\pami-wisata-daearahku`  
**Platform:** Flutter / Dart, Android-first  
**Jenis pekerjaan:** UI/UX audit + implementasi **visual-only / presentation-focused** pada seluruh Auth Views  
**Prioritas tertinggi:** **Baca dan patuhi `DESIGN.md` di repository**; tidak ada desain baru yang boleh mengalahkan spesifikasi tersebut.

## 1. Konteks dan masalah

Authentication inti Wisata Daerahku telah berkembang secara bertahap. LoginView sudah memakai identitas visual biru, pegunungan, matahari, input rounded, dan Google branding. Namun, beberapa Auth Views baru tidak mengikuti design system yang sama:

1. **Verify Email OTP registrasi** menggunakan judul serta copy bergaya serif yang tidak selaras dengan tampilan login dan `DESIGN.md`.
2. **LoginView** membutuhkan susunan label `Password` di kiri dan aksi `Lupa password?` di kanan **dalam satu Row dengan `spaceBetween`** dan lebar komponen form yang sama.
3. **ForgotPasswordScreen** memakai AppBar, tombol, dan aksen hijau yang tidak berasal dari identitas visual proyek; typography, input, card dan whitespace berbeda dari LoginView.
4. **VerifyResetOtpScreen** mengulangi masalah warna hijau + font serif + perbedaan styling OTP; ia tampak seperti aplikasi berbeda dari VerifyEmailOtpView.
5. **ResetPasswordScreen dan RegisterView** juga wajib diaudit, bukan diasumsikan otomatis sudah konsisten.

**Problem statement:** Perubahan implementasi auth membuat inkonsistensi visual lintas layar. Target bukan redesign bebas atau desain generik, melainkan satu sistem visual yang diturunkan dari `DESIGN.md` aktual dan komponen existing.

## 2. Mandatory source of truth / urutan inspeksi

Sebelum mengubah file Dart apa pun, Codex wajib:

1. Temukan dan **baca keseluruhan `DESIGN.md`** dari root repository (atau lokasi sebenarnya jika berbeda). Catat aturan nyata tentang palet/token warna, typography/font family & weights, ukuran, spacing, border radius, elevasi, ikon, komponen, dan layout responsif. **Jangan menebak** nilai, termasuk font, hex, radius, dan tinggi komponen.
2. Baca theme, `ThemeData`, typography setup (`google_fonts` jika existing), konstanta desain, shared widgets, dan implementasi visual layar Login/Register yang sudah dekat dengan `DESIGN.md`.
3. Audit enam Auth Views + komponen yang digunakan. Buat **gap matrix** singkat `DESIGN.md requirement → pelanggaran layar → perubahan yang diusulkan` sebelum patch visual.
4. Jika `DESIGN.md` tidak ditemukan atau bertentangan secara material dengan source, **laporkan kondisi itu secara eksplisit**; jangan menciptakan font atau palet sendiri. Manfaatkan token/theme repo yang benar-benar ditemukan dan tandai ketidakpastian.
5. Jika `taste-skill-frontend` tersedia di lingkungan Codex, gunakan untuk *kritik visual, hierarki, spacing, dan polish*, **bukan** menggantikan `DESIGN.md`. Jika tidak tersedia, lanjut dengan `DESIGN.md` tanpa mengklaim skill dipakai.

**Prioritas jika ada konflik:** `DESIGN.md` aktual → theme/shared components proyek → keputusan UX eksplisit dari user pada PRD ini → visual existing yang cocok. Screenshot hanya bukti masalah, bukan spesifikasi token desain.

## 3. Scope enam layar Flutter

| Screen | File yang perlu dicari/konfirmasi | Wajib dilakukan |
|---|---|---|
| Login | `lib/screens/user_login_screen.dart` | Konsistensi hero/card, typography, input, CTA, spacing; label Password dan `Lupa password?` `spaceBetween` |
| Register | `lib/screens/user_register_screen.dart` | Samakan typography, form fields, CTA, validasi, spacing, state dan navigasi visual |
| Verify Email OTP (register) | `lib/screens/verify_email_otp_screen.dart` | Hapus serif yang tidak sesuai, samakan komponen OTP/input/button dengan reset OTP |
| Forgot Password | `lib/screens/forgot_password_screen.dart` | Ganti hijau acak dengan palette/theme `DESIGN.md`, font, header, card, input, CTA konsisten |
| Verify Reset OTP | `lib/screens/verify_reset_otp_screen.dart` | Hilangkan hijau/serif inkonsisten; samakan OTP slots & visual hierarchy dengan Verify Email OTP |
| Reset Password | `lib/screens/reset_password_screen.dart` | Audit dan rapikan menyeluruh: font, warna, form, password toggles, validation, spacing |

Nama file final harus diverifikasi dari repository; jangan membuat duplikat screens atau mengasumsikan kelas bernama `*View` jika file proyek menggunakan `*Screen`.

## 4. Persyaratan UX & layout terinci

### 4.1 Shared visual identity

- Gunakan **font family, textTheme, color tokens dan komponen dari `DESIGN.md`** untuk seluruh enam layar; tidak boleh ada font serif sebagai default karena widget tidak mendapatkan theme yang benar.
- Hilangkan **AppBar dan CTA hijau yang tidak punya dasar di design system** dari Forgot Password / Verify Reset OTP; gunakan skema warna proyek sesuai `DESIGN.md`. Warna semantic seperti success/error hanya jika didefinisikan di sana.
- Jaga identitas visual Wisata Daerahku: nuansa biru / ilustrasi destinasi yang memang sudah dipakai, serta form/card putih rounded **sepanjang sesuai `DESIGN.md`**. Hindari memperkenalkan theme alternatif spesifik screen.
- Buat komponen visual OTP, input, button, helper text, error text, loading state, cooldown, dan form container menjadi **shared/reusable bila benar-benar mengurangi duplikasi** tanpa overengineering. Satu widget shared dengan parameter tujuan/pesan boleh; **jangan menyatukan business logic OTP registrasi dan recovery**.
- Tipografi hierarkis, kontras teks dan placeholder yang cukup, padding konsisten, dan tombol interaktif dapat dibedakan dari state disabled.

### 4.2 LoginView — label password + Forgot action

- Susun `Password` dan `Lupa password?` dalam **satu `Row`** yang menggunakan `mainAxisAlignment: MainAxisAlignment.spaceBetween` (atau layout ekuivalen yang benar-benar memberi alignment kiri/kanan). Tidak boleh `Lupa password?` menempel ke label atau berada mengambang di sisi tengah.
- Row wajib selebar field Password/form container; jangan lebar penuh layar jika field dibatasi padding horizontal.
- Keduanya sejajar secara vertikal pada baseline yang wajar, `Lupa password?` bisa diklik, dengan touch target dan semantics yang cukup.
- Pertahankan **tidak ada back button di LoginView**; jangan reintroduce tombol tersebut.
- Pastikan hero `Selamat datang!` punya jarak aman dari white sheet, tidak terpotong/overlap, dan form group tetap center dalam available viewport (vertikal & horizontal) **ketika ruang cukup**; form tetap scrollable saat keyboard aktif dan layar sempit.
- Pertahankan logo Google `G` berwarna pada tombol serta flow native Google Sign-In existing.

### 4.3 RegisterView

- Gunakan desain input, label, error, tombol, CTA sekunder, dan hierarchy yang sama dengan LoginView.
- Jangan mengembalikan kewajiban nomor telepon yang sudah dihapus karena tidak ada di kontrak Laravel.
- Error validasi server tetap terlihat per-field; disabled/loading/double-submit behavior tetap ada.

### 4.4 VerifyEmailOtpView (OTP registrasi)

- Ganti seluruh typography serif / font fallback yang tidak sesuai dengan `DESIGN.md`.
- Heading, supporting copy, alamat email tersamarkan, 6-slot OTP, tombol Verifikasi, countdown/resend harus mengikuti theme dan komponen shared.
- Pertahankan 1 underlying input dengan enam slot visual jika itulah implementasi existing, agar paste, autofill, keyboard numerik, accessibility, dan angka nol awal tetap benar.
- Layout responsif di small viewport; tidak memotong slot OTP atau menabrak keyboard.

### 4.5 ForgotPasswordScreen

- Hapus green-themed appbar/button yang menyalahi desain. Header/back behavior untuk sub-screen boleh dipertahankan sesuai pola navigasi dan `DESIGN.md`, **bukan** meniru LoginView tanpa back button secara buta.
- Samakan heading, copy, form input email, CTA `Kirim kode OTP`, card/sheet, iconography dan spacing dengan Auth Views lain. Gunakan bahasa pengguna yang konsisten, bukan copy generik yang menyesatkan.
- Respons Forgot Password tetap generik (tidak mengungkap email terdaftar/tidak) dan navigasi menuju VerifyResetOtpScreen tidak terganggu.

### 4.6 VerifyResetOtpScreen

- Ganti hijau/serif inkonsisten, gunakan komponen enam slot OTP visual yang sama dengan VerifyEmailOtpView.
- Konten menekankan **tujuan recovery** (bukan verifikasi email registrasi); copy, button/loading, cooldown 60 detik, resend, error, dan `Ubah email` sesuai logic existing.
- Jangan gabungkan state/callback/API endpoint dari OTP registrasi dengan OTP reset; hanya visual yang dishare.

### 4.7 ResetPasswordScreen

- Pastikan password baru, konfirmasi, toggle visibility, field validation, CTA, dan success/failure feedback konsisten dengan Login/Register.
- Jangan membuat akses/reset ticket atau TTL tidak aman karena refactor UI.

## 5. Responsive behavior & accessibility

- Gunakan idiom Flutter (`SafeArea`, `LayoutBuilder`/constraints, `Center`, `ConstrainedBox`, `SingleChildScrollView`/sliver sesuai kebutuhan). Hindari `Column` tanpa constraints yang overflow ketika keyboard tampil.
- Pendekatan setara web `display:flex; justify-content:center; align-items:center` hanya **saat viewport cukup**; dalam viewport sempit, prioritas konten tetap dapat discroll tanpa memotong CTA.
- Verifikasi pada Android portrait minimal: normal, layar kecil, keyboard terbuka, dan text scale diperbesar. Ukuran tap target, label/semantics OTP, kontras status/error, focus order, serta feedback loading wajib diperhatikan.
- Hormati system insets/status bar/navigation bar. Tidak boleh ada heading menempel ke sheet, form bergeser ekstrem, CTA tertutup keyboard atau scroll terkunci.

## 6. Functional invariants — tidak boleh regresi

**Pekerjaan ini desain/UI, bukan perubahan bisnis.** Pertahankan:

- Register email/password `role=0` → OTP email → verified; target pengalaman produk yang disepakati adalah **langsung Dashboard setelah OTP berhasil** *hanya ketika server menyatakan email terverifikasi dan sesi sah*. Jika target ini belum diimplementasikan, **laporkan sebagai gap fungsional terpisah**; jangan diam-diam membuka Dashboard dengan state palsu melalui perubahan desain.
- Login terpadu user/admin/superadmin; admin tidak ikut OTP registrasi user.
- Google Sign-In native Android → Firebase Credential → Laravel exchange (sudah berhasil diuji manual), Google role restrictions dan logout.
- JWT/refresh rotation, generation guard, secure storage, restoration, unverified guard.
- Forgot Password → reset OTP email → verify → reset ticket (in-memory only) → password baru → Login. Token/OTP jangan ditulis ke logs/storage.
- Perbedaan OTP tujuan `verify_email` dan `password_reset`; seluruh endpoint existing tetap identik.
- Semua error, loading, cooldown, resend, offline, stale response dan double submit handling yang sudah ada.

**Tidak boleh menyentuh** backend Laravel, `.env`, API contracts, Firebase config, Gradle/Android signing, MySQL, mailer, main business logic wisata, atau dependensi tanpa alasan mutlak yang dibuktikan. Tidak ada commit/push/deploy.

## 7. Agent assignment dan design skill

**Lokasi agent global yang benar:** `C:\Users\itsba\.codex\agents\`

- `flutter_engineer.toml` — **lead** implementasi Flutter/Dart dan konsistensi theme.
- `qa_engineer.toml` — widget/golden-style tests bila infrastructure existing ada, analyzer, regressions dan manual visual acceptance.
- `security_auditor.toml` — review terbatas terhadap dampak UI/refactor pada auth/session/OTP; hanya jika perubahan menyentuh alur sensitif.

`frontend_engineer.toml` (web) **jangan** dipakai sebagai agent utama Flutter. `taste-skill-frontend` dipakai hanya jika tersedia; laporkan bila tidak ada. Pastikan agent benar-benar dapat digunakan sesuai runtime, jangan mengklaim TOML di-*load* bila hanya dibaca.

## 8. Execution plan (minimum change)

**Step 0 — Audit design:** baca `DESIGN.md`, `ThemeData`, shared components, dan keenam screens. Keluarkan gap matrix, jangan langsung coding dari tebakan.

**Step 1 — Shared foundation:** rapikan pemakaian theme/token & komponen yang sudah ada; buat shared OTP visual/form bits hanya bila menghilangkan ketidakkonsistenan tanpa mengubah layanan.

**Step 2 — High-priority screens:** VerifyEmailOtpScreen → ForgotPasswordScreen → VerifyResetOtpScreen. Selesaikan serif dan hijau yang salah, typography, spacing, alignment.

**Step 3 — Consistency pass:** LoginView (Row `spaceBetween`, form centering, hero spacing) → RegisterView → ResetPasswordScreen.

**Step 4 — QA/visual:** Jalankan pemeriksaan terarah dahulu, regresi penuh sekali setelah perubahan stabil. Ambil screenshot **keenam** screens dari emulator dan periksa berdampingan. Periksa keyboard normal + small viewport; laporkan visual diff/deskripsi terhadap aturan `DESIGN.md`.

## 9. Acceptance criteria

- [ ] `DESIGN.md` benar-benar dibaca dan setiap keputusan token design mengikuti aturan aktual; daftar rule yang digunakan disertakan.
- [ ] Tidak ada typography serif/fallback inkonsisten pada 6 Auth Views.
- [ ] Tidak ada warna hijau/AppBar/CTA acak di Forgot Password/Verify Reset OTP; semua mengikuti palette `DESIGN.md`.
- [ ] OTP registrasi dan OTP reset secara visual seragam: enam slot, typography, button, spacing, state; logic tetap terpisah.
- [ ] Login `Password` kiri / `Lupa password?` kanan dalam `Row` selebar form.
- [ ] Login tanpa tombol Back; judul hero tidak mepet white sheet; centering responsive dan scroll keyboard berfungsi.
- [ ] Register, Forgot, Reset mempunyai visual field/button/form yang setara dengan theme; tidak ada layout baru yang bertabrakan.
- [ ] Enam layar tampil baik pada emulator portrait, keyboard terbuka, layar kecil dan text scale diperbesar.
- [ ] Alur Login, Google, register OTP, resend, recovery OTP dan sesi existing tidak regresi.
- [ ] Widget/focused tests PASS; full Flutter regression PASS atau kegagalan dijelaskan; analyzer pada touched files tanpa error baru.
- [ ] Hasil emulator **nyata** dan screenshot keenam layar disampaikan; mock test tidak disebut bukti visual E2E.

## 10. Handoff/report wajib

Laporan akhir harus memuat:

1. Lokasi `DESIGN.md` aktual dan ringkasan aturan yang diterapkan (font/theme/color/spacing/components) — **jangan isi dengan tebakan**.
2. Gap matrix sebelum/sesudah per screen.
3. File changed + alasan yang spesifik untuk tiap perubahan, termasuk shared widget jika ada.
4. Hasil testing focused/full, analyzer, dan bukti screenshot emulator (semua enam layar) serta catatan keyboard/layout.
5. Status `PASS`, `FAIL`, `NOT VERIFIED` untuk **visual** dan **auth flow** secara terpisah.
6. Hal yang belum selesai atau blocker nyata, terutama bila flow OTP→Dashboard masih terpisah dari UI scope.

**Done berarti visual enam layar konsisten terhadap `DESIGN.md` sekaligus fungsi auth existing tetap bekerja. Bukan sekadar menghilangkan font serif/hijau secara kosmetik.**
