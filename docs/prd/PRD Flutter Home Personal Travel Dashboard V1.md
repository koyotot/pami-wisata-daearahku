# PRD — Flutter Home Personal Travel Dashboard V1

**Project:** Wisata Daerahku  
**Platform:** Flutter Android  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Design Authority:** `DESIGN.md`  
**Scope:** Redesign Beranda User

## 1. Objective

Mengubah Beranda dari halaman katalog destinasi menjadi **Personal Travel Dashboard** yang menampilkan aktivitas booking, favorit, dan inspirasi wisata secara personal.

Pemisahan fungsi:
- **Beranda:** Aktivitas pengguna, perjalanan aktif, favorit, dan inspirasi.
- **Jelajah:** Pencarian, filter, kategori, dan katalog seluruh destinasi.

## 2. Komponen Utama

### A. Dynamic Scenic Hero

- Pertahankan implementasi scenic header berdasarkan waktu perangkat: pagi, siang, sore, dan malam.
- Pertahankan edge-to-edge dan animasi transisi existing.
- Greeting kontekstual berdasarkan waktu.
- Headline: "Siap untuk petualangan baru?"
- Subheadline singkat yang mengundang eksplorasi.
- Jangan menambahkan hero kedua yang menduplikasi scenic header.

### B. Perjalanan Kamu — Primary Card

Komponen utama yang mengutamakan satu booking paling relevan.

Informasi:
- Nama destinasi.
- Tanggal kunjungan.
- Jumlah tiket.
- Status booking dan pembayaran.
- CTA berdasarkan status aktual.

Prioritas:
1. Booking yang membutuhkan pembayaran.
2. Booking menunggu konfirmasi.
3. Kunjungan mendatang dengan tiket terkonfirmasi.
4. Empty state apabila tidak ada booking relevan.

Aturan:
- Satu primary card saja.
- CTA mengikuti kemampuan dan navigasi existing.
- Jika pembayaran belum terintegrasi, jangan membuat alur pembayaran palsu.
- Semua deadline, status, dan hak akses mengikuti Laravel.
- CTA riwayat menuju tab Riwayat.
- CTA detail tiket menuju screen Detail Tiket existing.

### C. Favorit Kamu — Horizontal Carousel

- Menampilkan maksimal 5 destinasi favorit.
- Card ringkas berisi thumbnail, nama, dan lokasi.
- Tap card membuka Detail Destinasi.
- Tombol "Lihat Semua" mengarah ke daftar favorit existing.
- Sembunyikan section apabila favorit kosong.
- Gunakan data Favorites API existing.

### D. Inspirasi Wisata — Curated Destinations

- Menampilkan maksimal 4 destinasi pilihan.
- Gunakan horizontal carousel atau editorial cards.
- Prioritaskan data rekomendasi/featured jika tersedia; jika tidak, gunakan destinasi aktif terbaru.
- Hindari klaim popularitas tanpa data.
- Setiap card mengarah ke Detail Destinasi.
- CTA "Lihat Semua" mengarah ke Jelajah.
- Jangan menampilkan grid katalog panjang.

### E. Explore CTA

- Section penutup dengan headline "Masih mencari destinasi impian?"
- Deskripsi singkat.
- CTA "Jelajahi Destinasi".
- Navigasi ke tab Jelajah existing.

## 3. Komponen yang Dihapus dari Beranda

- Search bar permanen.
- Filter kategori Semua/Kuliner/Musik.
- Label total destinasi sebagai fokus utama.
- Grid destinasi katalog panjang.

Seluruh fungsi pencarian dan filter tetap dipertahankan pada Jelajah.

## 4. UI/UX Requirements

- `DESIGN.md` menjadi landasan visual utama.
- Konsisten dengan UI/UX Flutter V4.
- Pertahankan dynamic scenic header.
- Pertahankan floating bottom navigation icon-only.
- Pertahankan urutan Beranda, Riwayat, Jelajah, Notifikasi, Profil.
- Gunakan spacing, typography, color tokens, elevation, radius, dan animations sesuai design system.
- Layout responsif, termasuk perangkat dengan layar sempit.
- Section kondisional tidak boleh meninggalkan ruang kosong.
- Sediakan loading, empty, dan error state yang konsisten.
- Hindari nested scrolling yang mengganggu vertical scrolling Beranda.

## 5. Data & Architecture

Manfaatkan implementasi existing:
- Laravel Booking API.
- Laravel Favorites API.
- Laravel Destinations API.
- AuthSession dan repository existing.
- Navigasi dan Detail Tiket existing.

Jangan mengubah kontrak API atau business logic booking tanpa kebutuhan nyata. Jangan menambah dependency atau endpoint apabila data yang diperlukan sudah tersedia.

## 6. Expected Deliverables

- Beranda user dengan lima komponen utama.
- Penghapusan duplikasi fungsi Jelajah.
- Integrasi data nyata melalui repository existing.
- Perjalanan Kamu dengan konten kondisional.
- Navigasi tetap terhubung ke screen existing.
- Dokumentasi implementasi singkat.

**Expected Result:** Beranda menjadi pusat aktivitas wisata personal, sementara Jelajah tetap menjadi pusat pencarian destinasi.