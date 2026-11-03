# PRD — Flutter Home Rich Personal Dashboard V1.1

**Project:** Wisata Daerahku  
**Platform:** Flutter Android  
**Mobile repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Implementation target:** `docs/prd/PRD-Flutter-Home-Rich-Personal-Dashboard-V1.1.md`  
**Design authority:** `DESIGN.md`  
**Status:** Approved concept — siap diimplementasikan  
**Type:** Visual refinement / addendum Beranda Personal Travel Dashboard V1

## 1. Background & Objective

Beranda V1 sudah dipisahkan dari Jelajah, tetapi hasil visual terasa kosong: booking card didominasi teks, favorit satu item terlalu besar, inspirasi menyerupai katalog dan CTA memakai terlalu banyak ruang. V1.1 memperkaya **hierarki visual, informasi, dan komposisi** tanpa menambah fitur bisnis yang tidak diperlukan.

**Positioning:**
- **Beranda:** Personal Travel Dashboard, aktivitas dan inspirasi pilihan.
- **Jelajah:** Pencarian, kategori, filter, dan katalog lengkap destinasi.

**Goal:** Layout mobile lebih hidup dan padat secara terukur, tetap jelas, elegan, dan mudah dinavigasi.

## 2. Visual Reference & Design Principles

Acuan komposisi: **interactive wireframe Beranda V1.1 yang disetujui dalam chat ChatGPT**. Wireframe tersebut bukan URL publik dan tidak otomatis tersedia bagi Codex; apabila screenshot tersedia, gunakan sebagai referensi tambahan.

`DESIGN.md` tetap sumber utama untuk warna, typography, spacing, radius, komponen, animasi, serta state UI. Pertahankan scenic header berdasarkan waktu perangkat (pagi/siang/sore/malam), transisi existing, edge-to-edge dan floating bottom navigation icon-only dengan urutan **Beranda — Riwayat — Jelajah — Notifikasi — Profil**. Jangan menduplikasi komponen katalog Jelajah di Beranda.

## 3. Information Architecture / Urutan Layar

1. **Dynamic Scenic Hero** — greeting dan headline existing; tidak dibuat hero kedua.
2. **Perjalanan Kamu** — booking card gaya boarding pass, primary action.
3. **Favorit Kamu** — compact destination card atau horizontal list adaptif.
4. **Inspirasi Wisata** — satu editorial featured image + hingga dua mini cards.
5. **Explore CTA** — compact gradient banner menuju Jelajah.

Section memiliki ritme vertikal lebih rapat dan konsisten. Hindari card kosong atau placeholder yang membuat halaman panjang tanpa informasi.

## 4. Component Requirements

### 4.1 Dynamic Scenic Hero

- Reuse implementasi scenic hero existing sepenuhnya: empat suasana sesuai waktu perangkat, animasi, dan edge-to-edge.
- Tampilkan greeting pengguna, headline singkat, subheadline satu-dua baris.
- Jangan menambah search bar, filter kategori, atau banner promosi besar di hero.

### 4.2 Perjalanan Kamu — Boarding-Pass Card

**Visual composition:**
- Card tunggal dengan rounded corners, border/elevation lembut.
- Row utama: **thumbnail destinasi di kiri**; **badge status, nama, tanggal, dan kuantitas tiket di kanan**.
- Separator putus-putus (dashed) yang memberi karakter boarding pass tanpa mengganggu aksesibilitas.
- Area bawah: status helper text singkat dan **satu tombol CTA kontekstual**.
- Tidak perlu mengulang semua rincian booking di Beranda; detail lengkap tetap pada screen existing.

**Pemilihan booking** (berdasarkan data/status nyata dari Laravel):
1. Booking dengan pembayaran yang masih valid dan membutuhkan tindakan, bila flow pembayaran memang sudah tersedia.
2. Booking yang menunggu persetujuan/konfirmasi.
3. Tiket terkonfirmasi untuk kunjungan mendatang.
4. Jika tidak ada yang relevan, tampilkan empty state compact yang mengarahkan ke Jelajah.

Jika terdapat lebih dari satu booking pada tingkat prioritas sama, tampilkan yang paling mendesak/relevan menurut tanggal kedaluwarsa atau kunjungan yang tersedia pada data server. Jangan menjadikan booking canceled/expired sebagai card utama. Gunakan status, deadline, serta otorisasi backend sebagai satu-satunya sumber kebenaran.

**CTA:**
- Pending approval → buka detail pendaftaran/tiket existing.
- Confirmed upcoming → buka Detail Tiket existing.
- Pending payment → hanya tampilkan action pembayaran jika implementasi pembayaran fungsional; jika belum, arahkan ke detail/status booking yang tersedia.
- Empty → buka Jelajah.

### 4.3 Favorit Kamu — Adaptive Compact Collection

- Jika **1 favorit**: satu compact horizontal card berisi thumbnail kiri, nama, lokasi, indikator favorit, dan link detail.
- Jika **lebih dari 1**: carousel horizontal compact, tidak memakai card besar seperti katalog.
- Jika **0**: sembunyikan section; bila perlu gunakan CTA ringan pada section lain, tanpa empty card raksasa.
- Aksi card menuju Detail Destinasi existing; tombol `Lihat Semua` menggunakan jalur favorit existing.
- Gunakan Favorites API dan model destinasi existing. Favorite state konsisten dengan backend; tidak membuat item palsu untuk mengisi ruang.

### 4.4 Inspirasi Wisata — Editorial Feature

- Pilih **1 destinasi unggulan** sebagai hero editorial card dengan cover image besar berasio konsisten.
- Gunakan subtle bottom gradient untuk memastikan nama, lokasi, serta label kategori terbaca.
- Tambahkan **maksimal 2 mini destination cards** di bawahnya (thumbnail, nama, kategori/lokasi).
- Seluruh card membuka Detail Destinasi existing.
- Pilih destinasi aktif dari repository existing: gunakan featured jika tersedia, jika tidak gunakan urutan terbaru yang tersedia dan stabil.
- Deduplicate berdasarkan GUID: mini cards tidak mengulang destinasi utama.
- Jika hanya tersedia 1 atau 2 destinasi, komposisi menyesuaikan tanpa slot kosong. Jika tidak ada destinasi, gunakan fallback section ringan yang tidak mengarang data.
- Gunakan cover gallery aktual (`images` / sequence) beserta caching/loading/fallback image existing. **Jangan memasukkan gambar ilustrasi wireframe sebagai data aplikasi.**
- Hindari klaim seperti “paling populer” jika backend tidak mempunyai metrik pendukung.

### 4.5 Explore CTA — Compact Banner

- Ganti white CTA card yang terlalu tinggi dengan **banner gradient ringkas**.
- Isi: judul “Masih ingin eksplorasi?”, deskripsi satu-dua baris, trailing circular arrow.
- Seluruh banner tappable dan membuka tab Jelajah melalui existing navigation, tanpa membuat stack screen yang duplikatif.

## 5. Interaction, State & Responsive Behavior

- Vertical page scroll tunggal; carousel horizontal tidak mengganggu scrolling utama.
- Tampilkan loading/skeleton yang mengikuti ukuran komponen, error state ringkas dengan aksi pemulihan yang sesuai, dan empty state kondisional.
- Konten berada di atas floating nav dengan bottom safe spacing yang cukup.
- Gambar mempertahankan aspect ratio dan crop yang tepat; tidak ada teks tertutup gradient, overflow, ataupun item terpotong secara tidak sengaja.
- Saat screen dibuka kembali, ikuti mekanisme refresh data existing tanpa request berulang yang tidak perlu.
- Batas jumlah item UI: **1 primary booking, favorit sesuai jumlah yang tersedia dalam tampilan compact, 1 featured + maksimal 2 mini inspiration cards**.

## 6. Data, Architecture & Constraints

**Data existing:** Laravel Booking API, Favorites API, Destinations API; `AuthSession`; repository/model dan navigasi Flutter saat ini. Pertahankan kontrak GUID, status backend, dan behavior navigasi existing.

**Kandidat file untuk ditinjau** (sesuaikan dengan struktur aktual repository):
- `DESIGN.md`
- `lib/screens/beranda_user_screen.dart`
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/cari_wisata_screen.dart` (referensi saja, **tanpa redesign**)
- `lib/data/business_repository.dart`
- `lib/data/app_data.dart`
- Komponen reusable galeri/image, favorite dan booking yang sudah tersedia.

**Out of scope:** perubahan business logic Laravel, payment flow baru, authentication, redesign Jelajah, redesign admin, perubahan floating navigation, package baru tanpa alasan kuat, dan refactor arsitektur yang tidak relevan.

## 7. Definition of Done — Hasil Produk

- Beranda tidak lagi terasa seperti katalog kedua.
- Booking tampil sebagai boarding-pass card compact dan action-nya sesuai status aktual.
- Satu favorit tetap tampak proporsional; banyak favorit menjadi horizontal collection.
- Inspirasi mempunyai satu visual utama dan hingga dua rekomendasi kecil tanpa duplikasi GUID.
- CTA Jelajah ringkas dan seluruh areanya bisa ditekan.
- Scenic header, DESIGN.md, edge-to-edge, floating nav dan seluruh alur existing terjaga.
- Semua item dan gambar menggunakan data aplikasi, bukan konten dummy permanen.
- Dokumentasi PRD tersimpan pada path target di repository.

## 8. Implementation Direction for Codex

Gunakan **SOL, Low Effort**, dengan **satu agent `flutter_engineer`** dan `taste-skill-frontend` bila tersedia. Baca `DESIGN.md` dan PRD ini, pelajari codebase aktual, implementasikan langsung dalam scope Beranda, serta laporkan file yang berubah dan keputusan visual yang diterapkan. Jangan commit atau push otomatis.
