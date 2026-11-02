# PRD — V4 Dynamic Time-Based Home Hero

**Project:** Wisata Daerahku — Flutter (role 0 / Pengunjung)  
**Status:** Requested UI enhancement; implement per approved auth-header behavior  
**Date:** 2 November 2026  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Destination:** `docs/prd/PRD-V4-Dynamic-Home-Hero-Time-Based.md`

## 1. Goal

Ubah **kartu hero/header sapaan pada Beranda** dari gradient biru statis menjadi suasana **dinamis berdasarkan waktu lokal perangkat**, dengan bahasa visual dan timing **sama seperti dynamic header autentikasi/Login yang sudah diimplementasikan pada working tree Flutter terbaru**.

**Scope hanya hero card Beranda**, bukan AppBar/status bar, background seluruh halaman, login flow, bottom navigation, atau halaman lain.

## 2. Source of truth & implementation ownership

1. Baca `docs/DESIGN.md`, handoff V4 terbaru, dan implementasi time-based header Login yang benar-benar tersedia pada **working tree lokal**. `docs/DESIGN.md` adalah audit historis; jangan perlakukan token lama sebagai pengganti keputusan visual terbaru.
2. Primary implementation agent: **`flutter_engineer`**, gunakan `C:/Users/itsba/.codex/agents/flutter_engineer.toml` jika tersedia; apabila path bergeser, temukan lokasi agent terpasang tanpa mengasumsikan direktori baru.
3. Gunakan panduan **`design-taste-frontend`**, termasuk `app-screens` atau mobile design skill yang memang tersedia. Jangan mengklaim skill/agent telah dipanggil tanpa benar-benar menggunakannya.
4. Candidate utama: `lib/screens/beranda_user_screen.dart`, khusus builder hero (misalnya `_buildHero` pada source publik). Bila logika time-of-day auth sudah reusable, gunakan itu; jangan membuat service/timer/enum duplikat hanya untuk hero.
5. Jangan reset atau menimpa V4 dan addendum terbaru yang belum commit pada working tree.

## 3. Visual requirements

### FR-HERO-01 — Empat periode waktu (sama persis dengan Login)

Interpretasi waktu menggunakan `DateTime.now()` **lokal perangkat**, tidak menggunakan timezone destinasi atau server untuk dekorasi hero:

| Waktu lokal | Identitas suasana | Arah visual |
| --- | --- | --- |
| **05:00–10:59** | Pagi | Sky blue + warm sunrise; matahari rendah, hangat, soft glow |
| **11:00–14:59** | Siang | Bright/clear blue; matahari lebih tinggi dan lebih terang |
| **15:00–18:59** | Sore | Blue-to-amber/pink sunset; warm sunset glow, tetap kontras |
| **19:00–04:59** | Malam | Deep navy/indigo night; bulan sabit atau bulan dengan bintang halus |

**Palet, assets, gradient, urutan layer, ilustrasi dan atmosfer HARUS mengikuti implementasi auth-header aktual** sejauh cocok untuk rasio kartu hero. Nilai warna dalam tabel adalah arahan, bukan perintah membuat palet baru yang tidak konsisten dengan Login. Jika visual auth memakai variasi berbeda, samakan implementasi Beranda dengan auth.

### FR-HERO-02 — Jangan ubah struktur/konten kartu

Pertahankan seluruh hal di bawah ini:

- Radius kartu, margin, alignment, padding, tinggi responsif, shadow/elevation dan komposisi existing kecuali adjustment minimal untuk menjaga visual aman.
- Avatar/inisial pengguna, sapaan `Halo, ...`, subteks `Mau jelajah mana hari ini?`, dan truncation nama panjang.
- **Tiga statistik dinamis** Destinasi, Kategori, dan Terdaftar/pendaftaran: nilai, state loading, maupun sumber data Laravel existing tidak diubah.
- Stat pills tetap translucent, mudah dibaca pada setiap periode. Kontras teks putih/foreground harus cukup pada warna pagi/siang/sore/malam.
- Bentuk ilustrasi dekoratif tidak boleh menimpa avatar, nama, maupun angka statistik; tidak menyebabkan overflow pada 320dp atau text scale besar.

### FR-HERO-03 — Transisi halus dan ramah aksesibilitas

- Gunakan transisi visual **800 ms, `Curves.easeInOut`**, menyamakan header Login, misalnya animasi gradient/background dan crossfade figur langit bila cocok.
- Jangan mem-flash putih, hijau/teal, atau background default saat hero dibuka, saat periode berubah, atau ketika Beranda dibuka kembali dari tab lain.
- Hormati preferensi **reduce motion**: perubahan suasana berlangsung tanpa animasi berlebihan bila animasi dinonaktifkan sistem.
- Hanya layer dekorasi yang berganti; statistik/API tidak direload dan scroll position/selected bottom tab tidak direset akibat pergantian periode.

## 4. State, time updates, lifecycle

### FR-HERO-04 — Sinkron dengan mekanisme autentikasi

- Tentukan periode berdasarkan waktu perangkat ketika pertama tampil.
- Selaraskan perubahan tepat pada batas **05:00, 11:00, 15:00, 19:00**. Gunakan mekanisme pemeriksaan berkala (maksimal interval 1 menit) dan pemeriksaan ulang pada **app resume**, sebagaimana header Login yang sudah ada.
- Saat tab Beranda kembali aktif, periksa ulang periode tanpa memaksa refresh konten bisnis.
- Hindari timer ganda, listener bocor, update `setState` sesudah `dispose`, atau polling berat untuk mengubah efek visual.
- Tangani perubahan jam/timezone perangkat dengan menghitung ulang dari `DateTime.now()`; fallback ke periode waktu saat ini, tidak ke theme hijau.

## 5. Non-goals and technical boundaries

- Tidak merombak Auth/Login, tab Jelajah, Riwayat, Notifikasi, Profil, Detail Wisata, Booking, Calendar, atau navbar.
- Tidak mengubah Laravel, kontrak API, FCM, `BookingIntent`, session/auth, kuota atau business state.
- Tidak menggunakan jam server atau timezone destinasi untuk suasana hero.
- Tidak menambah dependensi, remote assets, artificial loading, background job, atau perubahan navigasi jika komponen native Flutter dan sumber auth existing mencukupi.
- Tidak perlu menambah copy salam dinamis (misalnya `Selamat pagi`) jika Login tidak memakainya; fokus pada **background dan elemen langit**.

## 6. Acceptance visual (tanpa test task)

1. Hero Beranda memiliki **empat suasana waktu** yang konsisten dengan Login.
2. Matahari berubah sesuai pagi/siang/sore dan **malam menggunakan bulan/bintang**, bukan matahari siang yang menetap.
3. Animasi perpindahan **800 ms easeInOut** dan menghormati reduce motion.
4. Avatar, teks sapaan, stats dinamis dan legibility tetap utuh.
5. Tidak ada flash hijau, overflow, atau perpindahan tab yang mereset isi hero.
6. Implementasi hanya menyentuh widget visual dan lifecycle yang diperlukan.

## 7. Delivery instructions

Implementasikan langsung dengan `flutter_engineer` pada **working tree terbaru**; gunakan guidance `design-taste-frontend` dan `app-screens`. Setelah selesai cukup laporkan **file yang disentuh, cara reuse dynamic header Login, empat scene visual dan perilaku lifecycle**. **Jangan membuat/menjalankan tests, `flutter analyze`, render/screenshot, atau QA task** untuk PRD ini sesuai permintaan. **Jangan commit, push, atau deploy.**
