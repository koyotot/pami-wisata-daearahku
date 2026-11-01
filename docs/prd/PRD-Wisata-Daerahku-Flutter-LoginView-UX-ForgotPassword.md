# PRD — Flutter LoginView UX Refinement & Forgot Password Entry

**Project:** Wisata Daerahku  
**Platform:** Flutter Android (Dart)  
**Type:** UI/UX refinement + navigasi autentikasi  
**Priority:** Saat ini, sebelum main business logic  
**Source of truth:** Screenshot LoginView terbaru dan lima keputusan user pada 1 November 2026.

## 1. Tujuan

Rapikan halaman login existing tanpa mengubah arsitektur authentication yang sudah berjalan. Hasil akhir harus memiliki hierarki hero dan form yang jelas, form terpusat secara horizontal dan vertikal di area white sheet ketika ruang memadai, serta akses Forgot Password yang jelas dan tombol Google dengan logo Google.

**Keputusan final:**

1. Tambahkan **“Lupa password?”** pada **kanan label “Password”**, dalam baris yang sama (bukan sebagai tombol utama).
2. **Hapus total tombol Back** di kiri atas hero LoginView.
3. **Jangan sampai judul “Selamat datang!” mepet atau tertutup white sheet**. Ciptakan jarak visual yang jelas antara bagian bawah judul hero dan bagian atas sheet.
4. **Center form dalam white sheet pada sumbu horizontal dan vertikal**, setara tujuan `justify-content: center; align-items: center` pada CSS, dengan penanganan keyboard dan perangkat kecil yang aman.
5. **Ganti ikon pintu/masuk pada tombol “Masuk dengan Google” menjadi logo Google berwarna**; pertahankan teks dan fungsi Google Sign-In.

## 2. Scope & Lokasi Kode

- Target utama: `lib/screens/user_login_screen.dart` (pastikan lokasi berdasarkan repository aktual).
- Periksa struktur layout/widget reusable, theme, navigasi, dan asset existing sebelum mengubahnya.
- Hanya bila diperlukan: tambah asset logo Google di `assets/images/` dan deklarasikan dalam `pubspec.yaml`.
- Forgot Password: gunakan screen/route existing jika tersedia; **jangan membuat tombol palsu/tidak berfungsi**.
- Jika belum ada screen Forgot Password, boleh buat **screen minimal untuk request tautan reset via email** berdasarkan kontrak Laravel existing: `POST /api/v1/auth/forgot-password` dengan `email`, lalu menampilkan respons generik. Gunakan networking/AuthSession existing; jangan membangun flow token/deep link/reset password pada PRD ini. Jangan mengklaim fitur reset end-to-end selesai.

## 3. Layout / Hierarki

### 3.1 Hero biru

- Pertahankan ilustrasi gunung, matahari, palet biru, serta branding Wisata Daerahku.
- Hapus ikon/back button dan area kliknya dari LoginView.
- Tampilkan judul “Selamat datang!” secara utuh tanpa overlap atau clipping.
- Berikan **jarak visual minimal sekitar 20–24 logical pixels** dari batas bawah teks judul ke permukaan sheet, disesuaikan dengan tinggi viewport; jangan menambah ruang kosong secara berlebihan.
- Jika sheet menggunakan `Stack` + `Positioned`, ubah koordinat/responsivitas sehingga batas atas sheet tidak menabrak judul. Hindari nilai posisi kaku yang rusak saat font scaling.
- Jangan menduplikasi headline di sheet.

### 3.2 White rounded sheet

- Pertahankan sheet putih dengan sudut atas rounded dan visual handle kecil jika sudah dipakai.
- Tinggi sheet mengisi area yang tersisa di bawah hero hingga aman terhadap system navigation area.
- **Konten inti form ditengah secara horizontal dan vertikal** di ruang sheet yang tersedia, bukan ditempelkan ke bagian atas secara default.
- Gunakan lebar form responsif: `width: double.infinity` dengan batas maksimum sekitar **400–420 dp** untuk layar lebar/tablet, serta padding horizontal sekitar **20–24 dp**.
- Isi form tetap **left-aligned** untuk label dan teks field; “center” di sini adalah posisi keseluruhan form container di sheet, **bukan semua teks diratakan tengah**.
- Copyright footer (`© 2026 Wisata Daerahku`) boleh tetap di area bawah sheet, terpisah dari grup form; jangan membuatnya menggeser form terlalu tinggi.
- Pada layar kecil/landscape, font scaling, dan saat keyboard aktif: izinkan scrolling dengan aman. **Jangan paksa centering sehingga input atau CTA tertutup / overflow.**
- Implementasi Flutter boleh menggunakan `LayoutBuilder`, `SingleChildScrollView`, `ConstrainedBox`, `Align`, `Center`, atau pendekatan sliver yang setara dengan constraints valid. Hindari `Expanded` dalam unbounded height serta `Spacer` yang menyebabkan overflow.

### 3.3 Urutan konten di sheet

1. Kalimat penjelas singkat existing (boleh dirapikan).
2. Label **Email**, lalu field email.
3. Baris label **Password** di kiri dan **Lupa password?** di kanan.
4. Field password + toggle visibility existing.
5. Primary button **Masuk**.
6. Divider **atau**.
7. Secondary button **Masuk dengan Google** memakai logo Google.
8. Teks **Belum punya akun? Daftar**.
9. Footer copyright di bawah area form.

Spacing antar field dan CTA konsisten mengikuti theme; hindari jarak kosong arbitrer yang membuat form tampak berantakan.

## 4. Forgot Password Entry

- Teks aksi: **“Lupa password?”**, warna aksen biru/primary dengan kontras cukup.
- Letakkan pada baris yang sama dengan `Password`, rata kanan.
- Ukuran tap target harus nyaman untuk mobile (sekitar 44–48 dp), tanpa membuat baris terlalu tinggi.
- Klik membawa pengguna ke screen Forgot Password yang nyata; boleh prefill email yang telah diketik.
- Jika screen belum tersedia, buat versi minimal untuk pengajuan tautan reset email melalui Laravel existing, dengan input email, loading, validasi, error koneksi, dan pesan sukses generik (tidak mengungkap apakah email terdaftar).
- **Tidak** mengimplementasikan reset token handler, Android App Links, maupun perubahan `PASSWORD_RESET_URL` dalam scope ini. Bila link reset belum memiliki tujuan yang berfungsi, tulis sebagai blocker terpisah.
- Jangan menciptakan endpoint baru atau mengganti kontrak backend.

## 5. Tombol Google

- Ganti ikon `login` / `door` / `sign-in` menjadi **logo Google “G” resmi, berwarna**, ukuran visual kira-kira **18–22 dp**.
- Gunakan asset lokal yang valid (PNG atau format yang didukung proyek); jangan menambah dependency hanya demi satu ikon jika tidak diperlukan.
- Pertahankan outline, rounded corners, label “Masuk dengan Google”, visual disabled/loading, dan interaksi Google Sign-In native yang **sudah berhasil di emulator**.
- Jangan mengubah `google_sign_in`, Firebase credential, Laravel token exchange, atau konfigurasi Gradle yang sudah diperbaiki.

## 6. Behavior & Compatibility

- Satu LoginView untuk role 0/1/2; jangan membuat halaman admin terpisah.
- Google Sign-In tetap sesuai kebijakan existing (hanya role 0).
- Pertahankan navigasi Daftar, error/login validation, toggle password, loading, form submit, dan state lifecycle.
- Pertahankan `AuthSession` (JWT, refresh, secure storage, generation guard) dan seluruh Email Verification OTP.
- Tidak boleh ada network call, logout, atau reset state baru hanya akibat redesign layout.
- Pastikan perilaku tombol Back Android (system back) mengikuti route policy existing; permintaan ini hanya menghapus tombol back visual di hero.

## 7. Acceptance Criteria

1. Tidak ada tombol Back visual di hero LoginView.
2. Headline “Selamat datang!” tidak overlap, terpotong, atau menempel ke sheet di ukuran emulator referensi.
3. Seluruh grup form berada secara horizontal dan vertikal di pusat area sheet saat keyboard tertutup dan ruang mencukupi.
4. Saat keyboard terbuka atau tinggi viewport terbatas, user tetap dapat scroll ke seluruh input, tombol, dan pesan validasi tanpa overflow.
5. “Lupa password?” terlihat di kanan label Password dan berfungsi menuju view terkait (tanpa aksi dummy).
6. Tombol Google menampilkan logo Google warna asli, bukan ikon pintu, dan proses login existing tetap berfungsi.
7. Email/password login, navigasi register, dan autentikasi Google tidak mengalami regresi.
8. Tidak ada perubahan backend Laravel atau main business logic wisata.

## 8. Pengujian Minimal (Efisien)

- Widget test terarah: Back visual tidak ada; teks “Lupa password?” ada dan dapat ditekan; logo Google tampil; form tetap dapat submit.
- Widget/layout test: layar Android kecil, keyboard terlihat, font scaling, dan tidak ada RenderFlex overflow.
- Jalankan analyzer terarah file yang diubah dan focused widget tests; full suite bila perubahan berdampak ke shared auth code.
- Manual visual di Android Emulator: tangkap screenshot LoginView dan uji tap Forgot Password, email login, serta tombol Google.
- Hasil pengiriman email/tautan reset dilaporkan `NOT VERIFIED` bila belum diuji sungguhan.

## 9. Agen Codex

Gunakan lokasi agent **global** (bukan `.codex/agents/` dalam repo):

- Utama: `C:\Users\itsba\.codex\agents\flutter_engineer.toml`
- QA bila diperlukan: `C:\Users\itsba\.codex\agents\qa_engineer.toml`

Pastikan konfigurasi benar-benar dapat digunakan; jika runtime hanya dapat membaca instruksinya tanpa memuat agent langsung, laporkan dengan jujur.

## 10. Larangan & Deliverables

**Jangan:** mengganti desain visual total, mengubah backend, memodifikasi OTP flow, merusak native Google Sign-In, meng-upgrade massal dependency, mengerjakan modul wisata, atau melakukan commit/push/deploy.

**Output Codex:** ringkasan file berubah, screenshot tampilan sebelum/sesudah bila tersedia, hasil tests/analyzer, status fungsi Forgot Password, status Android Google Sign-In setelah perubahan, serta blocker yang memang tersisa.

**Urutan implementasi disarankan:** audit layout existing → hilangkan Back → rapikan hero-sheet gap → center form responsif → tambahkan Forgot Password → ganti Google logo → targeted verification.
