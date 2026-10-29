# TASK: Flutter Design System Audit & Documentation

Kamu adalah **Senior Flutter Engineer, UI/UX Design System Analyst, dan Technical Documenter**.

Tugasmu adalah melakukan audit menyeluruh terhadap implementasi UI/UX existing pada proyek Flutter **Wisata Daerahku** (`wisata_daerahku`) dan menghasilkan satu file dokumentasi bernama `DESIGN.md` di root repository.

Dokumen ini akan menjadi **sumber acuan desain utama bagi Codex** saat mengembangkan fitur, memperbaiki tampilan, dan mengintegrasikan aplikasi Flutter dengan Laravel REST API di tahap berikutnya.

**PENTING: Tugas ini hanya dokumentasi. Jangan melakukan implementasi, refactoring, redesign, atau perubahan behavior aplikasi.**

## 1. Mandatory Agent & Skill

### Sub-agent Flutter

Gunakan sub-agent:

`.codex/agents/flutter_engineer.toml`

Delegasikan pekerjaan eksplorasi Flutter, analisis struktur widget, navigasi, state management, dan dokumentasi desain kepada agent `flutter_engineer`.

Pastikan agent membaca source code existing sebelum menyimpulkan apa pun.

### Taste Skill Frontend Design

**WAJIB gunakan `design-taste-frontend` (Taste Skill Frontend Design) sebelum melakukan audit UI/UX.**

Temukan dan baca instruksi skill yang tersedia pada environment Codex.

Gunakan skill sebagai pedoman untuk mengevaluasi:

- Visual hierarchy dan konsistensi tipografi.
- Layout composition, spacing, alignment, dan visual balance.
- Color palette, contrast, dan semantic colors.
- Reusable components dan consistency.
- Responsive layout dan mobile adaptability.
- Interaction feedback, usability, dan visual states.

**Batas penggunaan skill:**

- Hanya untuk analisis dan dokumentasi.
- Dilarang menghasilkan desain atau komponen pengganti.
- Dilarang mengganti warna, font, spacing, dan layout.
- Pisahkan fakta hasil audit dari rekomendasi perbaikan.
- Jika skill tidak ditemukan, laporkan keterbatasannya. Jangan mengklaim skill sudah digunakan.

## 2. Scope Analisis

Baca secara menyeluruh:

- `pubspec.yaml` dan `pubspec.lock`
- `analysis_options.yaml`
- `lib/main.dart` dan seluruh subfolder `lib/`
- Seluruh screen, page, widget, component, theme, routing, model, service, dan state management.
- `assets/` terutama gambar, icon, font, dan aset UI.
- `firebase.json` dan konfigurasi Firebase yang relevan.
- Konfigurasi platform jika diperlukan untuk mengetahui platform aktif.

Gunakan nama dan struktur folder berdasarkan kondisi repository sebenarnya. Jangan mengasumsikan nama folder dari contoh di atas.

Telusuri penggunaan setiap widget sampai ke tempat pemanggilannya agar komponen reusable dan alur navigasi dapat didokumentasikan dengan akurat.

Jangan menyalin credential, API key, token, atau informasi rahasia ke dokumentasi.

## 3. Aturan Mutlak

1. **Read before write:** audit source code sebelum membuat dokumentasi.
2. **No hallucination:** seluruh informasi wajib berdasarkan implementasi aktual.
3. Sertakan path file sumber pada setiap temuan penting. Tambahkan nomor baris jika memungkinkan.
4. Untuk nilai yang tidak tersedia, tulis `Tidak ditemukan di kode`.
5. Bedakan nilai dari `ThemeData`, widget lokal, konstanta, dan default Flutter.
6. Jangan menganggap nilai yang sering digunakan otomatis merupakan design token resmi.
7. Dokumentasikan UI berdasarkan implementasi existing, bukan desain ideal.
8. Gunakan bahasa Indonesia; nama class, widget, property, dan package tetap asli.
9. Jangan membuat file tambahan.
10. Output perubahan repository hanya `DESIGN.md`.

## 4. Struktur DESIGN.md — Wajib 11 Bagian

### 1. Ringkasan Proyek

Dokumentasikan tujuan aplikasi, pengguna, platform, versi SDK atau constraint Flutter/Dart, serta package utama yang benar-benar digunakan beserta fungsinya.

Bedakan dependency yang terdaftar dengan dependency yang ditemukan penggunaannya dalam kode.

### 2. Struktur Folder

Buat pohon struktur `lib/` dan jelaskan fungsi folder serta file penting.

Identifikasi lokasi screen, reusable widget, model, service, theme, konfigurasi, dan navigasi berdasarkan kode.

### 3. Design Tokens

Dokumentasikan dalam tabel:

- **Colors:** nama, nilai HEX/ARGB, sumber, dan lokasi penggunaan.
- **Typography:** font family, ukuran, weight, letter spacing, dan peran.
- **Spacing:** padding, margin, gap, dan pola spacing yang berulang.
- **Border:** radius, border width, serta style.
- **Elevation & Shadow:** parameter dan penggunaannya.
- **Icons:** pustaka ikon, ukuran, dan pola penggunaan.
- **Theme Mode:** light, dark, system, atau dukungan lainnya yang benar-benar tersedia.

Jangan menormalkan nilai yang berbeda atau menciptakan palette baru. Tandai inkonsistensi secara faktual.

### 4. Komponen UI Reusable

Untuk setiap reusable widget, catat nama class, file, fungsi, constructor parameter, visual styling, state interaktif, dan screen yang menggunakannya.

Identifikasi pola berulang, seperti tombol, TextField, card, AppBar, BottomNavigationBar, dialog, snackbar, loading indicator, dan empty state.

Bedakan reusable widget yang benar-benar dibuat dengan UI yang masih ditulis langsung di masing-masing screen.

### 5. Daftar Layar

Audit **semua layar yang ditemukan**, bukan hanya layar utama.

Untuk setiap screen, dokumentasikan:

- Nama dan lokasi file.
- Tujuan screen.
- Susunan layout dari atas ke bawah.
- Komponen yang digunakan.
- Data yang ditampilkan.
- Aksi pengguna.
- State loading, empty, error, success, dan disabled jika tersedia.
- Navigasi masuk dan keluar.
- Perilaku responsive yang ditemukan.

Jika sebuah state belum diimplementasikan, nyatakan secara eksplisit.

### 6. Navigasi dan Alur Pengguna

Identifikasi entry point aplikasi, mekanisme routing, authentication guard, serta perpindahan antarlayar.

Tuliskan alur pengguna secara berurutan berdasarkan implementasi:

- Autentikasi.
- Penjelajahan wisata.
- Detail destinasi.
- Booking, jika tersedia.
- Favorit, notifikasi, QR, profil, atau fitur lain yang ditemukan.

Jangan mendokumentasikan fitur rencana sebagai fitur yang sudah berfungsi.

### 7. Data dan Integrasi

Dokumentasikan:

- Model beserta field dan tipe data.
- State management yang digunakan.
- Firebase Authentication, Firestore, dan Storage jika ditemukan.
- HTTP client, endpoint, service, serta cara pemanggilannya.
- Data source setiap screen.
- Penggunaan image picker, QR, dan fitur khusus lainnya.

**Perhatian:** Proyek ini direncanakan diintegrasikan dengan Laravel REST API. Namun, jangan menganggap integrasi Laravel sudah tersedia jika belum ditemukan di source code.

Bedakan integrasi existing dan integrasi yang belum ditemukan.

### 8. Aset

Inventarisasi assets image, icon, font, dan resource UI lainnya.

Catat path, tipe aset, pendaftaran di `pubspec.yaml`, serta screen atau widget yang menggunakannya.

Identifikasi aset terdaftar tetapi tidak ditemukan penggunaannya, atau referensi aset yang tidak ditemukan pada repository.

### 9. Konvensi Kode

Dokumentasikan pola existing terkait:

- Penamaan file, class, method, dan widget.
- Pengorganisasian screen dan reusable component.
- Import dan dependency.
- Pengelolaan state.
- Null safety dan error handling.
- Konvensi lint dari `analysis_options.yaml`.

Jangan menciptakan konvensi baru yang tidak didukung implementasi.

### 10. Aturan Wajib untuk Codex

Rumuskan aturan pengembangan berdasarkan temuan audit.

Minimal mencakup:

- Pertahankan identitas visual aplikasi existing.
- Gunakan design token yang telah teridentifikasi.
- Reuse komponen sebelum membuat komponen baru.
- Pertahankan naming dan struktur folder existing.
- Hindari hardcoded style baru jika token atau pola yang sesuai sudah ada.
- Jangan menambahkan dependency tanpa kebutuhan teknis yang jelas.
- Perhatikan responsiveness, accessibility, serta loading, empty, dan error state.
- Jangan mengubah navigasi atau business logic hanya untuk penyesuaian desain.
- Ketika membuat screen baru, gunakan `DESIGN.md` sebagai referensi awal dan verifikasi kesesuaiannya dengan kode terkini.

### 11. Ketidakkonsistenan dan Utang Desain

Buat tabel temuan faktual dengan kolom:

| Temuan | Lokasi kode | Bukti | Dampak | Prioritas |
|---|---|---|---|---|

Identifikasi jika ditemukan:

- Hardcoded color atau typography yang tidak konsisten.
- Widget berulang tanpa reusable abstraction.
- Spacing atau radius yang tidak seragam.
- Screen yang belum menangani state tertentu.
- Layout dengan constraint responsive terbatas.
- Aset yang tidak digunakan.
- Inkonsistensi navigasi atau feedback UI.

Prioritas adalah penilaian hasil audit, bukan fakta dari kode. Tandai sebagai rekomendasi dan jelaskan alasannya.

**Jangan langsung memperbaiki temuan tersebut.**

## 5. Scope Protection

### DIIZINKAN

- Membaca seluruh source code dan konfigurasi terkait.
- Menganalisis tampilan berdasarkan struktur Flutter.
- Menggunakan sub-agent dan Taste Skill untuk audit.
- Membuat atau memperbarui satu file `DESIGN.md` di root repository.

### DILARANG

- Mengedit seluruh file di `lib/`.
- Mengubah `pubspec.yaml` atau dependencies.
- Mengubah konfigurasi Firebase.
- Mengubah routing dan authentication flow.
- Mengubah integrasi backend atau API.
- Mengubah UI, widget, warna, font, layout, atau animation.
- Melakukan refactoring.
- Membuat screenshot, mockup, atau prototype.
- Membuat file laporan tambahan.
- Menjalankan auto-fix atau formatter yang memodifikasi source code.

## 6. Acceptance Criteria

Tugas selesai apabila:

1. `DESIGN.md` tersedia di root repository.
2. Semua 11 bagian terisi berdasarkan audit aktual.
3. Seluruh screen dan reusable component yang ditemukan telah dicakup.
4. Nilai design token memiliki sumber yang dapat ditelusuri.
5. Tidak terdapat nilai, class, fitur, atau integrasi yang dikarang.
6. Taste Skill dan `flutter_engineer` telah digunakan, atau keterbatasannya dilaporkan dengan jujur.
7. Tidak ada perubahan repository selain `DESIGN.md`.

## 7. Final Response

Setelah selesai, berikan ringkasan singkat:

- File dokumentasi yang dihasilkan.
- Jumlah screen dan reusable widget yang teridentifikasi.
- Design system dan pola visual utama yang ditemukan.
- Temuan inkonsistensi paling penting.
- Konfirmasi bahwa tidak ada source code aplikasi yang dimodifikasi.

**Eksekusi langsung menggunakan sub-agent `flutter_engineer` dan Taste Skill Frontend Design. Fokus hanya menghasilkan dokumentasi yang akurat, bukan melakukan implementasi.**