# PRD Addendum V4 — Booking Success Screen & Icon-Only Floating Navigation

**Proyek:** Wisata Daerahku (Flutter, user/role 0)  
**Tanggal:** 2 November 2026  
**Prioritas:** P1 — UI/UX flow correction, regression-safe  
**Status:** APPROVED — Booking Success flow + icon-only floating navbar; code implementation and Android verification pending  
**Dasar:** Interactive Wireframe V4 yang telah disetujui, screenshot aplikasi booking yang masih menampilkan kartu sukses inline, screenshot wireframe "Permintaan Terkirim", `docs/DESIGN.md`, serta `docs/flutter-uiux-redesign-v4-handoff.md`.  
**Scope:** Flutter UI, navigation, success presentation, icon-only floating bottom navbar, widget tests. **Non-scope:** Laravel, BookingIntent business logic, idempotency/replay semantics, payment/notification contracts.

## A. Problem statement

Pada aplikasi berjalan, setelah pendaftaran sudah dikonfirmasi server, pengguna tetap berada di `Daftar Kunjungan` dengan blok **"Pendaftaran diterima server"**, nomor booking, status, dan tombol disabled **"Pendaftaran Terkonfirmasi Server"**. Hal ini melanggar wireframe V4: setelah booking dipastikan berhasil, pengguna harus masuk ke **layar tersendiri "Permintaan Terkirim"**, tanpa tombol Back di header.

**Temuan referensi source publik (bukan klaim bahwa working tree lokal identik):** `lib/screens/daftar_kunjungan_screen.dart` memiliki `_onBooked(Booking)` yang menetapkan `_booking` dan `_completed`, lalu bagian `build` menyisipkan `_buildSuccess(_booking!)` inline. Audit ulang working tree lokal yang berisi implementasi V4 sebelum mengedit.

## B. Expected user flow

1. Pengguna berada pada `Daftar Kunjungan`, mengisi data dan memilih tanggal/jumlah.
2. Pengguna menekan `Konfirmasi Pendaftaran` satu kali.
3. UI menunggu hasil server atau hasil rekonsiliasi yang **terkonfirmasi berhasil**. Selama pending, tampilkan loading dan blokir duplicate submit; jangan menampilkan sukses prematur.
4. Jika server mengembalikan booking valid, arahkan **otomatis** ke route layar **Permintaan Terkirim** dengan informasi booking yang baru dibuat.
5. Layar sukses **tidak mempunyai arrow/back control** atau floating bottom navbar, serta tidak menampilkan form, kalender, pesan konfirmasi inline atau CTA submit lagi.
6. Primary CTA **Lihat Riwayat** menuju tab Riwayat di shell utama; idealnya membuka/highlight booking berdasarkan GUID jika navigasi existing mendukung. Secondary CTA **Kembali ke Beranda** menuju tab Beranda.
7. Android system Back / predictive-back / back gesture dari layar sukses tidak mengembalikan ke form yang sudah berhasil. Arahkan ke Beranda (atau root shell yang aman) tanpa menambah duplikat `MainNavigationScreen`.
8. Jika API 422, 409 yang belum terselesaikan, timeout outcome-unknown, atau error lainnya: **tetap di form** dengan mekanisme error/reconcile yang sudah ada. Jangan pernah menampilkan layar sukses dari asumsi lokal.

## C. UI contract — Permintaan Terkirim

- Layout full-screen dengan background netral `#F5F8FD`, warna branding sesuai `docs/DESIGN.md` dan approval V4.
- Header ringkas, title **Permintaan Terkirim** di tengah, **tanpa tombol Back** di kiri/kanan.
- Ikon centang sukses hijau di dalam lingkaran soft-green; hijau hanya warna semantik sukses, bukan default theme/transisi layar.
- Heading **Pendaftaran tercatat!**.
- Supporting copy produksi: **Permintaan kunjungan berhasil diterima. Pantau status pendaftaranmu melalui Riwayat.** (tidak ada kata "simulasi" atau "belum dikirim ke Laravel").
- Summary card rounded putih, menampilkan nama destinasi dari booking/destinasi yang benar, tanggal kunjungan terkonfirmasi, jumlah pengunjung, dan badge status sesuai nilai **server** (mis. `Menunggu persetujuan` pada contoh aktual). Tambahkan nomor booking dari server apabila berguna, tanpa mengganti nama utama kartu.
- Primary button solid/gradient biru: **Lihat Riwayat** dengan ikon panah kanan.
- Secondary outlined button: **Kembali ke Beranda**.
- Aman terhadap 320dp, text scale, edge-to-edge, status/navigation bars, SafeArea; responsif jika nama wisata atau nomor booking panjang; gunakan scrollable content jika diperlukan.
- Tidak ada app bar Back, `Navigator.canPop` back arrow otomatis, bottom navbar, maupun CTA submit pada halaman sukses.

**Wajib memakai data server** (contoh screenshot berjalan berisi **5 orang**, bukan "1 pengunjung" milik wireframe demo). Status tidak boleh di-hardcode jadi selalu menunggu; booking replay/reconcile yang sudah dikonfirmasi sukses wajib menunjukkan status aktual.

## D. UI contract — Icon-Only Floating Bottom Navigation (approved revision)

**Perubahan approval terakhir:** hapus **semua teks label yang terlihat** di floating bottom navigation. Tombol tetap berjumlah lima, urutan dan fungsinya **tidak berubah**:

| Posisi | Tujuan navigasi | Ikon yang tampil | Perlakuan |
| --- | --- | --- | --- |
| 1 | Beranda | House / Home | Icon-only, state aktif jelas |
| 2 | Riwayat | Ticket / History | Icon-only, state aktif jelas |
| 3 (tengah) | Jelajah | Compass | **Main hook** elevated biru, tetap paling menonjol |
| 4 | Notifikasi | Bell | Icon-only, unread badge oranye **di kanan atas ikon Bell**, bukan di pojok item/navbar |
| 5 | Profil | User / Profile | Icon-only, state aktif jelas |

**Implementasi UI wajib:**

- Hapus widget `Text`/label visual di bawah ikon **untuk kelima item**, termasuk `Jelajah` di bawah kompas tengah. Jangan hanya membuat teks transparan yang masih menyisakan tinggi/ruang layout.
- Sesuaikan kembali tinggi, alignment, padding dan spacing navbar untuk komposisi ikon saja; posisi tombol kompas tetap elevated di tengah. Tetap floating, rounded, blur/translucent, elevation lembut dan menggunakan SafeArea Android/iOS.
- Pastikan state **selected/unselected** mudah dibedakan melalui gaya ikon dan/atau background, tidak bergantung pada teks. Jangan mengubah destination, IndexedStack/tab state, mekanisme Android Back, atau navigasi booking yang sudah bekerja.
- Badge notifikasi harus di-`Stack` yang **membungkus glyph Bell**, dengan `Positioned(top: ..., right: ...)` relatif ke glyph, `clipBehavior: Clip.none`, tidak bergeser ketika tab aktif. Unread 1–99 tampil sebagai angka, di atasnya `99+`, dan unread 0 menyembunyikan badge. Warna oranye `#FF9800`, angka putih.
- **Aksesibilitas tetap wajib:** walaupun tanpa label yang terlihat, tombol memiliki `Semantics(label: 'Beranda' / 'Riwayat' / 'Jelajah' / 'Notifikasi' / 'Profil')`, selected state dan tooltip yang tepat. Untuk Notifikasi, unread count dapat diumumkan pada semantics tanpa menggandakan pembacaan teks badge. Pastikan touch target yang layak dan dukungan text scaling/TalkBack.
- Floating navbar **hanya** tampil pada lima root tab. Pada Detail, Daftar Kunjungan, dan **Permintaan Terkirim**, jangan tampilkan navbar; gunakan CTA kontekstual sesuai PRD.
- Perubahan ini **menggantikan spesifikasi label navbar yang terlihat** pada wireframe/PRD V4 sebelumnya. Tidak menghapus judul halaman, label form, tooltip, semantic labels, atau tulisan lain di luar floating navbar.

**Kandidat source:** `lib/widgets/floating_bottom_nav.dart` dan, hanya jika diperlukan, `lib/screens/main_navigation_screen.dart`; gunakan komponen existing, jangan buat navigasi kedua.

## E. Flutter implementation guidance

**Audit kandidat file (sesuaikan dengan checkout lokal):**

- `lib/screens/daftar_kunjungan_screen.dart`: success dispatch point seperti `_onBooked`, hapus success inline dari body dan disabled success CTA dari form setelah sukses; jaga session generation/mounted check serta BookingEvents.notify existing.
- `lib/screens/permintaan_terkirim_screen.dart` (**baru bila belum ada implementasi sepadan**): purely presentational success screen yang menerima `Booking` server-confirmed dan metadata destinasi yang diperlukan; no API mutation.
- `lib/screens/main_navigation_screen.dart`: gunakan mekanisme pindah root tab existing untuk CTA Riwayat/Beranda, hindari membuat dua shell dalam stack. Jangan ubah urutan navbar V4.
- `test/business_booking_widgets_test.dart` dan test UI/navigation V4: tambah regresi untuk semua jalur sukses dan Android Back.

**Single source of success transition:** Panggil navigasi di titik konvergensi setelah booking **confirmed** (submit biasa, `IntentCompleted` dari reconcile, replay safe yang berhasil, atau hasil abandon yang ternyata completed). Guard agar perpindahan route sekali saja dan tetap menghormati identitas/session generation. Pertahankan `BookingIntent` asli dan semantik idempotency. 

**Navigation recommendation:** Gunakan route replacement yang benar sesuai navigator aktual supaya form sukses dikeluarkan dari stack; screen sukses menolak pop ke form. Tombol navigasi ke root harus me-reset/menargetkan shell existing dengan tab yang benar. Jangan asal `push` halaman sukses di atas form, jangan menggunakan `Navigator.pop` untuk kembali ke booking setelah berhasil, dan jangan melakukan refresh/mutation booking kedua kalinya di screen sukses.

## F. Acceptance criteria / QA

- [ ] Setelah POST booking terkonfirmasi sukses, halaman **Daftar Kunjungan** hilang dan layar **Permintaan Terkirim** muncul otomatis.
- [ ] Tidak ada kartu "Pendaftaran diterima server" inline maupun tombol "Pendaftaran Terkonfirmasi Server" disabled pada state sukses.
- [ ] Tidak ada Back arrow pada header layar sukses; system Back / gesture tidak kembali ke form sukses.
- [ ] Ringkasan layar sukses menampilkan nama destinasi, tanggal, quantity, status dan (jika ditampilkan) nomor booking **dari hasil server**.
- [ ] Tombol **Lihat Riwayat** membuka root tab Riwayat. Tombol **Kembali ke Beranda** membuka root Beranda; tidak menggandakan app shell.
- [ ] 422/409 unresolved/unknown outcome tidak membuka layar sukses; penanganan dan replay existing tetap bekerja.
- [ ] Semua outcome **confirmed** termasuk reconcile dan replay hanya menavigasi sekali; tidak terjadi booking ganda.
- [ ] Logout/session berubah saat request masih berjalan tidak memunculkan layar sukses untuk akun lain.
- [ ] Animasi transisi tidak memunculkan flash hijau, status bar kontras, system navigation bar dan safe area benar.
- [ ] Widget/navigation tests cover CTA, system Back, text scale, 320dp dan 390dp; targeted tests, `flutter test`, `flutter analyze`, format, dan `git diff --check` dilaporkan beserta baseline historis.
- [ ] Floating bottom navigation menampilkan **lima ikon tanpa satu pun label visual** di semua root tab; Compass tetap elevated di tengah dan urutan destinasi tidak berubah.
- [ ] Count unread Notifikasi tetap melekat pada **pojok kanan atas glyph Bell** (bukan corner item/nav), benar pada 0, 1, 99 dan 100+; perilaku mark-read tetap menggunakan sumber data existing.
- [ ] Seluruh icon-only tab memiliki nama yang tepat untuk TalkBack/semantics, selected state, touch target, dan tetap responsif pada 320dp / text scale 1.8.
- [ ] Navbar tidak muncul pada Detail, Daftar Kunjungan, atau Permintaan Terkirim; posisi kompas, safe area, keyboard insets dan Android Back tidak regresi.
- [ ] Screenshot perangkat Android dari hasil riil tersedia untuk verifikasi visual, bukan hanya fixture test.

## G. Required implementation handoff

Laporkan perubahan file, route stack strategy, pemetaan data booking server → summary, jalur konfirmasi yang diuji, perubahan icon-only navbar dan semantics, hasil test serta bukti Android. **Tidak melakukan perubahan Laravel, commit, push, atau deploy tanpa izin.**

**Kriteria akhir:** user selesai daftar → layar tersendiri "Permintaan Terkirim" tanpa Back → Riwayat/Beranda; pada root tab floating navbar tampil icon-only dengan Compass elevated dan badge Bell pada glyph; semua state booking bisnis existing tetap aman.
