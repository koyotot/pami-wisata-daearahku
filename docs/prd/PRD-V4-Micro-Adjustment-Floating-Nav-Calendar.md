# PRD — V4 Micro-Adjustment: Icon Fill Navigation & Rounded Calendar

**Project:** Wisata Daerahku (Flutter, pengunjung role 0)  
**Status:** APPROVED — berdasarkan interactive wireframe dua komponen yang disetujui  
**Tanggal:** 2 November 2026  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Scope:** **Hanya 2 komponen UI**; tidak ada redesign whole page.

## 1. Tujuan

Laksanakan dua penyesuaian visual mikro pada implementasi Flutter V4 **di working tree saat ini**:

1. **Floating Bottom Navigation:** ketika tab terpilih, yang berubah hanyalah **fill bagian dalam SVG/icon**, bukan warna stroke, bukan background/pill item.
2. **Availability Calendar:** tanggal menjadi **kotak rounded-lg** dengan **angka tepat di tengah** dan jarak antarkotak lebih lega.

Persetujuan ini **menggantikan styling selected state lama** pada dua komponen tersebut, tanpa membatalkan approval V4 lainnya.

## 2. Acuan prioritas

1. Keputusan user terbaru dan interactive wireframe dua komponen yang sudah di-approve.
2. `docs/flutter-booking-success-v4-handoff.md`, `docs/flutter-uiux-redesign-v4-handoff.md`.
3. `docs/DESIGN.md` sebagai audit/landasan visual, **bukan aturan yang boleh mengalahkan approval terbaru**.
4. Source **working tree lokal terbaru**. `main` publik mungkin belum memuat file baru V4; jangan mengandalkan checkout publik sebagai sumber perubahan terakhir.

## 3. Penugasan Codex: agents & skills

- **Koordinasi (jika tersedia):** `master_orchestrator`, hanya untuk membatasi scope serta mengarahkan tugas ke agent Flutter.
- **Implementer utama (wajib):** `flutter_engineer`. Cari konfigurasi yang telah digunakan pada proyek, khususnya `C:/Users/itsba/.codex/agents/flutter_engineer.toml`, atau lokasi aktual yang tersedia pada mesin.
- **Panduan desain (wajib digunakan bila tersedia):** skill `design-taste-frontend` dan referensi `app-screens`, dengan adaptasi ke Flutter mobile; keputusan wireframe yang di-approve mengungguli contoh generik skill.
- Tidak perlu delegasi QA/test untuk tugas ini karena user **secara eksplisit tidak meminta tes**.

> Agent Codex di mesin pengguna dijalankan oleh Codex saat mengeksekusi PRD ini. Penulisan PRD tidak berarti agent telah dipanggil atau source lokal telah diubah.

## 4. Komponen A — Floating Bottom Navigation

**Target utama:** `lib/widgets/floating_bottom_nav.dart`  
**Konteks pemasangan jika diperlukan:** `lib/screens/main_navigation_screen.dart`

### FR-NAV-01 — Selected hanya mengubah icon fill

- **Hilangkan** background selected per-item (`selected pill`, chip, highlight rectangle/circle) pada empat tab standar.
- **Jangan hilangkan** surface putih/translucent dari **container floating navbar keseluruhan**. Blur, corner, shadow, elevation, safe-area, dan tinggi dasar tetap mengikuti V4.
- Saat tab standar **inactive**: fill icon `transparent`/`none`.
- Saat tab standar **active**: fill bagian dalam shape icon `#DCEBFF` (soft blue sesuai wireframe approved).
- **Stroke icon persis sama** antara active dan inactive: warna rujukan `#6F8199`, ketebalan, line-cap, line-join serta path outline **tidak berubah**.
- Jika icon existing berbasis `IconData` tidak mendukung kontrol stroke/fill terpisah, gunakan ikon/path yang sesuai atau pasangan outline/filled yang **secara visual konsisten**, tanpa perubahan stroke yang terlihat. Prefer memanfaatkan aset/ikon yang sudah ada, bukan dependency baru.
- Selected tab tetap dapat dikenali melalui filled interior dan semantics; tidak boleh kembali ke background item yang tinted.

### FR-NAV-02 — Elevated Compass di tengah tetap

- Urutan ikon **Beranda — Riwayat — Jelajah — Notifikasi — Profil** tidak berubah.
- Tombol **Jelajah/Compass** tetap raised/elevated, memakai bubble biru dan border putih seperti V4; bubble ini **bukan** selected background standar yang harus dihapus.
- Stroke ikon kompas selalu putih. Jika status selected membutuhkan pembedaan, gunakan **fill bagian dalam kompas** (mis. putih/soft white sesuai approval) tanpa mengganti stroke maupun warna bubble.
- Semua **label visual tetap dihapus** (icon-only); `Semantics`, tooltip, selected state dan ukuran target interaksi tetap dipertahankan.

### FR-NAV-03 — Notifikasi tidak mengalami regresi

- Badge unread **harus anchored terhadap glyph Bell**, bukan terhadap keseluruhan tab/dock: `Stack(clipBehavior: Clip.none)` dan `Positioned(top: -5, right: -7)` relatif pada wrapper glyph.
- Background badge oranye `#FF9800`, angka putih; 0 disembunyikan, 1–99 angka aktual, 100+ `99+`.
- Badge tetap mengikuti `NotificationState`/API existing. Tidak menambah angka simulasi.
- Navbar tetap milik lima root tab; Detail, Booking, dan Permintaan Terkirim tidak memakai navbar.

## 5. Komponen B — Availability Calendar

**Target utama:** `lib/widgets/availability_calendar.dart`  
**Konteks pemasangan jika benar-benar diperlukan:** `lib/screens/daftar_kunjungan_screen.dart`

### FR-CAL-01 — Kotak rounded-lg (Flutter)

- Setiap tanggal berbentuk **kotak** (lebar dan tinggi seimbang, adaptif terhadap grid 7 kolom) dengan `BorderRadius.circular(8)` / **8dp**, setara konsep `rounded-lg`.
- Bentuk visual harus **kotak dengan sudut membulat**, bukan lingkaran/capsule, bukan tile yang berdempetan.
- Gunakan gap visual sekitar **4dp horizontal dan vertikal** (`crossAxisSpacing` dan `mainAxisSpacing`) dan **padding internal minimal**, supaya antartanggal tampak berjarak.
- Pada viewport sempit, hitung ukuran sel dari lebar container memakai constraint/layout yang ada; **jangan paksa ukuran kotak yang membuat overflow**.

### FR-CAL-02 — Nomor di tengah

- Angka tanggal **center horizontal dan center vertical** di dalam setiap kotak (`Alignment.center`).
- Dot indikator status (jika masih digunakan komponen existing) tetap **center di bawah angka**, menggunakan `Stack`/`Positioned(bottom: ...)` agar tidak menggeser angka dari titik tengah tile.
- Jaga font, readability, dan alignment konsisten pada 1–2 digit. Baris nama hari (`Sen`, `Sel`, dst.) sejajar terhadap kolom tanggal.

### FR-CAL-03 — Warna status dan pemilihan tetap

- Jangan mengubah interpretasi status server: hijau = Banyak tersedia, kuning = Terbatas, merah = Hampir penuh, abu-abu = Tidak tersedia.
- Pertahankan status warna langsung pada angka/tile tanggal dan legenda empat kategori di bagian bawah.
- Selected day memakai **outline/border biru** yang tidak menghilangkan warna kategori kuota.
- Tanggal disabled tetap tidak selectable sesuai `bookable` dari server.
- Header bulan, panah bulan, timezone destinasi dan label availability dipertahankan.
- **Jangan hardcode** tanggal, warna status berdasarkan nomor tanggal, atau kuota seperti pada data demo wireframe.

## 6. Guardrails — Jangan disentuh

- **Tidak mengubah Laravel**, endpoint, kontrak API, model bisnis, `BookingIntent`, idempotency key/payload replay, quota computation, timezone computation, guard 409/422, maupun state notifikasi.
- **Tidak mengubah** halaman Permintaan Terkirim, navigasi route replacement, CTA Riwayat/Beranda atau back handling yang sudah disetujui, kecuali benar-benar diperlukan untuk mencegah perubahan visual ini merusaknya.
- Tidak membuat screen baru, redesign whole page, mengubah UI auth/admin, atau menambah package dependency hanya untuk efek sederhana.
- **Tidak ada commit, push, deploy.**

## 7. Kriteria hasil desain (tanpa rencana test)

- [ ] Tidak ada pill/background selected pada item navbar; **hanya isi icon yang berubah**, stroke konstan.
- [ ] Floating dock global, raised Compass, urutan lima icon dan icon-only tetap sama.
- [ ] Badge unread melekat di **kanan atas glyph Bell** dan aturan 0/99+ tidak berubah.
- [ ] Kalender memakai **kotak rounded-lg radius 8dp**, dengan gap sekitar 4dp dan padding lebih lega secara visual.
- [ ] Nomor tanggal **persis di tengah**, dot tetap di bawah tanpa menggeser angka.
- [ ] Legend, warna availability, selected outline, disabled/bookable, dan timezone tidak berubah secara semantik.
- [ ] Perubahan hanya menyentuh UI komponen yang disetujui.

## 8. Handoff setelah pengerjaan

Laporkan secara ringkas **file yang berubah**, perbedaan visual selected/inactive navbar, parameter radius/spacing/centering kalender, serta apakah ada batasan komponen existing yang perlu diketahui. **Tidak perlu membuat/menjalankan test, screenshot, atau laporan analyzer sebagai bagian dari tugas ini.**
