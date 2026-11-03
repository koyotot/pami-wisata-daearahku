# PRD — Flutter Profile Menu Grouping V4

**Proyek:** Wisata Daerahku  
**Platform:** Flutter Android (pengunjung / role 0)  
**Jenis perubahan:** Minor–medium UI refactor / information architecture  
**Versi dokumen:** 1.0  
**Tanggal:** 3 November 2026  
**Status:** Disetujui untuk implementasi  
**Lokasi file yang dituju dalam repository:** `docs/prd/PRD-Flutter-Profile-Menu-Grouping-V4.md`

## 1. Ringkasan

Halaman **Profil Saya** menempatkan berbagai menu yang berbeda makna dalam satu kelompok `Akun`: Riwayat Ulasan, Notifikasi, Bahasa, Ubah Password, Tentang Aplikasi, dan Hapus Akun. Sementara itu, Wisata Tersimpan memiliki section tersendiri. Pengelompokan ini membuat hierarki informasi kurang jelas, dan menu Notifikasi menduplikasi tab Notifikasi pada floating bottom navigation.

Perubahan V4 mengelompokkan menu menjadi empat section: **Aktivitas Saya**, **Pengaturan & Keamanan**, **Informasi Aplikasi**, dan **Pengelolaan Akun**. Perubahan berfokus pada komposisi UI dan mempertahankan fungsi yang sudah ada.

**Sumber acuan:**
- Flutter repository: https://github.com/koyotot/pami-wisata-daearahku
- Backend repository (tidak perlu diubah): https://github.com/joytimess/pami-wisata-daerahku-api
- Pedoman desain: `docs/DESIGN.md` (baca sebelum mengubah widget; selaraskan juga dengan implementasi V4 aktual)
- Screen utama: `lib/screens/profil_user_screen.dart`
- Shell navigasi untuk acuan saja: `lib/screens/main_navigation_screen.dart`
- Dua screenshot Profil yang diberikan pengguna dalam percakapan (referensi keadaan awal)

## 2. Sasaran

1. Menyajikan pengelompokan yang mudah dipindai berdasarkan maksud pengguna.
2. Mempertahankan **Wisata Tersimpan** sebagai preview yang langsung terlihat serta akses **Lihat semua**.
3. Menghilangkan duplikasi akses **Notifikasi** dari Profil, tanpa mengubah tab Notifikasi di navigasi bawah.
4. Mempertahankan desain V4: palet biru pengunjung, latar terang, aksen section oranye, tipografi, rounded cards, dynamic scenic header, edge-to-edge, dan floating icon-only bottom navigation.
5. Menjaga semua operasi eksisting: edit profil/avatar, riwayat ulasan, favorit, pemilihan bahasa, informasi aplikasi, placeholder fitur belum tersedia, dan logout.

## 3. Non-sasaran / Batasan

- **Tidak** membuat tabel, endpoint, migration, service, atau permission backend baru.
- **Tidak** memisahkan Bookmark dan Favorit menjadi dua business logic berbeda; tetap gunakan `FavoriteState` dan endpoint `/favorites` eksisting.
- **Tidak** merancang ulang header profil, editor profil, avatar preview/crop, atau form nomor telepon.
- **Tidak** membangun halaman ubah password, hapus akun, ataupun multibahasa baru dalam scope ini.
- **Tidak** mengganti pola navigasi utama atau memodifikasi tab Notifikasi.
- **Tidak** menambahkan package, service, state manager, atau arsitektur baru untuk perubahan pengelompokan.
- **Tidak** melakukan perubahan visual lintas seluruh aplikasi.

## 4. Struktur Informasi Baru

Urutan vertikal halaman Profil:

```text
Profil Saya
└── Scenic header dinamis + profile header card (dipertahankan)

Aktivitas Saya
└── Group card
    ├── Wisata Tersimpan
    │   ├── Preview chip destinasi (maksimum 5)
    │   ├── + Lihat semua
    │   └── State loading / kosong / error / belum login
    ├── divider
    └── Riwayat Ulasan
        └── Ulasan yang pernah kamu tulis

Pengaturan & Keamanan
└── Group card
    ├── Bahasa
    │   └── Indonesia · bahasa lain belum tersedia
    ├── divider
    └── Ubah Password
        └── Belum tersedia untuk akun API

Informasi Aplikasi
└── Group card
    └── Tentang Aplikasi
        └── Wisata Daerahku · versi [versi yang digunakan aplikasi]

Pengelolaan Akun
└── Group card
    └── Hapus Akun (danger)
        └── Belum tersedia untuk akun API

└── Tombol Keluar (danger; terpisah dari group card)

[Icon-only floating bottom navigation tetap tampil]
```

**Keputusan utama:** baris **Notifikasi** dihapus **hanya dari daftar menu Profil** karena akses notifikasi sudah tersedia pada bottom navigation. Jangan menghapus tab, route, inbox, callback publik, atau fitur notifikasi yang mungkin masih digunakan bagian lain.

## 5. Spesifikasi UI

### 5.1 Header Profil

- **Tidak dirombak**: pertahankan scenic background berdasarkan waktu, transisi animasi yang sudah berlaku, status bar edge-to-edge, header card, identitas pengguna, avatar preview overlay, dan edit profil.
- Jangan menghilangkan akses ke pengeditan avatar dan informasi pengguna.
- Pertahankan penghormatan terhadap reduced-motion yang telah digunakan layar.

### 5.2 Judul Section

- Gunakan label pendek: `Aktivitas Saya`, `Pengaturan & Keamanan`, `Informasi Aplikasi`, `Pengelolaan Akun`.
- Gunakan bahasa visual section yang sudah ada: teks navy/biru tua dengan aksen vertikal oranye, bukan gaya heading baru.
- Spasi antarsection konsisten dan cukup lega agar masing-masing kelompok terlihat terpisah.

### 5.3 Group Card

- Satu kontainer putih/terang dengan sudut rounded, border lembut, serta divider tipis antarbaris bila berisi lebih dari satu baris.
- Ikon menu di dalam kotak kecil dengan tint lembut; teks utama jelas; subtitle lebih ringan; chevron untuk menu yang mengarah ke aksi/halaman.
- Gunakan helper yang sudah ada (`_sectionLabel`, `_buildMenuGroup`, `_MenuItemData`) jika masih sesuai; perluas secara lokal hanya bila diperlukan.
- Hindari card di dalam card yang membuat border bertumpuk.
- Tinggi target sentuh nyaman, padding horizontal konsisten, dan tidak ada overflow pada layar Android kecil.

### 5.4 Aktivitas Saya

- **Wisata Tersimpan** adalah blok teratas dalam group card Aktivitas Saya; beri identitas bookmark yang konsisten.
- Pertahankan data yang berasal dari `FavoriteState.instance`, bukan daftar statis.
- Pertahankan preview maksimum lima chip, wrapping jika ruang sempit, serta aksi `+ Lihat semua` yang sudah ada.
- Pertahankan state loading, empty, error, dan unauthenticated; jangan menghilangkan mekanisme reload.
- Di bawah blok tersimpan, tampilkan divider dan baris `Riwayat Ulasan` yang tetap menggunakan aksi `_bukaRiwayatUlasan(context)` atau handler eksisting ekuivalen.
- Pengelompokan ini **bukan** tugas untuk menambah fitur bookmark pada kartu Beranda/Jelajah atau memisahkan favorit.

### 5.5 Pengaturan & Keamanan

- **Bahasa**: gunakan ikon globe, label `Bahasa`, subtitle yang jelas seperti `Indonesia · bahasa lain belum tersedia`; pertahankan handler eksisting, tanpa berpura-pura multibahasa sudah didukung.
- **Ubah Password**: gunakan ikon keamanan/gembok, label `Ubah Password`, subtitle `Belum tersedia untuk akun API` selama fitur memang belum tersedia dalam profil; pertahankan feedback/placeholder eksisting, jangan menciptakan form atau pemanggilan API baru.
- Dua baris berada dalam satu group card dengan divider.

### 5.6 Informasi Aplikasi

- Satu baris `Tentang Aplikasi` dengan ikon info; pertahankan dialog/layar eksisting `_tampilkanTentang(context)`.
- Tampilkan versi aplikasi sesuai sumber yang benar di repo jika sudah tersedia; jangan menaikkan atau mengarang nomor versi.

### 5.7 Pengelolaan Akun

- **Hapus Akun** berada pada card tersendiri dalam section Pengelolaan Akun, dengan warna teks/ikon danger.
- Karena backend belum mendukung penghapusan akun pada UI yang diperiksa, handler eksisting tetap menampilkan informasi **belum tersedia**; dilarang melakukan penghapusan data lokal maupun server sebagai substitusi.
- Tombol **Keluar** dibuat terpisah di bawah card dengan treatment danger lembut, ukuran penuh, radius konsisten, dan mempertahankan dialog konfirmasi serta alur logout yang ada.

### 5.8 Navigasi dan Insets

- Tetap ada tab `Beranda`, `Riwayat`, `Jelajah` (center elevated), `Notifikasi`, `Profil` pada floating bottom navigation; label ikon tetap tersembunyi sesuai desain V4.
- Halaman Profil harus bisa discroll sampai tombol `Keluar` terlihat utuh dan bisa disentuh; perhitungkan overlay bottom navigation, safe area perangkat, dan system gesture inset.
- Pertahankan scenic header full-bleed di bawah status bar; jangan tambahkan AppBar solid yang menghilangkan efek edge-to-edge.
- Teks panjang, font scaling, dan lebar sekitar 320–430 dp tidak boleh menyebabkan clipped content atau horizontal overflow.

## 6. Perilaku dan Integrasi yang Dipertahankan

| Fitur | Perilaku target |
|---|---|
| Avatar & Edit Profil | Seluruh handler, crop/preview, foto, identitas, dan nomor telepon tetap bekerja seperti implementasi saat ini |
| Wisata Tersimpan | Data live `FavoriteState`, maksimal lima chip, `+ Lihat semua`, state loading/empty/error |
| Riwayat Ulasan | Tetap membuka daftar ulasan melalui handler yang sudah ada |
| Bahasa | Tetap menampilkan opsi/penjelasan yang benar-benar tersedia saat ini |
| Ubah Password | Status belum tersedia dinyatakan secara jujur; tidak ada fitur palsu |
| Tentang Aplikasi | Dialog informasi eksisting tetap digunakan |
| Hapus Akun | Placeholder belum tersedia tetap aman; tidak melakukan delete |
| Keluar | Dialog konfirmasi, proses sesi, dan navigasi login tetap dipertahankan |
| Notifikasi | Tab bawah tetap berfungsi; hanya menu duplikat di Profil yang dihilangkan |

## 7. Area Kode Kandidat

**Prioritas utama**
- `lib/screens/profil_user_screen.dart` — susunan `Column` halaman Profil, grouping menu, variasi kontainer untuk Wisata Tersimpan, spacing, footer dan scroll inset.

**Diperiksa sebagai referensi; ubah hanya jika benar-benar dibutuhkan**
- `lib/screens/main_navigation_screen.dart` — memastikan bottom navigation dan inset tetap konsisten.
- `lib/data/app_data.dart` atau file yang mendefinisikan `FavoriteState` — dibaca untuk memahami state, tidak perlu dimodifikasi untuk grouping.
- `docs/DESIGN.md` — acuan, bukan target rewrite.

**Tidak disentuh:** API Laravel, database, route API, endpoint favorit, autentikasi, payment, booking, katalog, maupun halaman non-Profil.

## 8. Strategi Implementasi

1. Baca `docs/DESIGN.md` dan screen Profil terbaru pada working tree lokal (jika berbeda dengan GitHub, **kode lokal** menjadi acuan implementasi).
2. Identifikasi builder section, saved-preview, menu rows, dialog, logout, callback navigasi, serta layout overlay bottom navigation.
3. Refactor bagian daftar menu menjadi empat kelompok, gunakan kembali primitive/helper yang sudah ada.
4. Pindahkan komponen **Wisata Tersimpan** ke blok Aktivitas Saya tanpa mengubah sumber data atau handler.
5. Hapus hanya entri **Notifikasi** pada menu Profil; pertahankan fitur notifikasi lainnya.
6. Sesuaikan spacing, divider, padding, state kosong/loading/error, dan bottom inset agar komposisi rapi.
7. Jaga ruang lingkup diff tetap kecil; hindari rewrite besar file screen dan jangan mengubah desain global.
8. Laporkan file yang berubah serta ringkasan perubahan implementasi secara singkat.

## 9. Kriteria Selesai

- [ ] Tidak ada lagi section besar bernama `Akun` yang mencampur seluruh menu.
- [ ] Section berurutan: `Aktivitas Saya`, `Pengaturan & Keamanan`, `Informasi Aplikasi`, `Pengelolaan Akun`.
- [ ] Preview `Wisata Tersimpan` dan `+ Lihat semua` masih terhubung ke favorit Laravel eksisting.
- [ ] Riwayat Ulasan masih bisa dibuka.
- [ ] Bahasa, Ubah Password, Tentang Aplikasi, Hapus Akun memakai perilaku eksisting dan keterangan ketersediaan yang akurat.
- [ ] Menu Notifikasi tidak muncul lagi di Profil; tab Notifikasi bawah tetap ada.
- [ ] Tombol Keluar terpisah, terlihat penuh saat scroll ke bawah, serta menggunakan konfirmasi logout eksisting.
- [ ] Scenic header, edge-to-edge, avatar/edit profil, dan floating bottom nav V4 tidak berubah perilakunya.
- [ ] Desain mengikuti `docs/DESIGN.md` dan implementasi V4 terbaru, tanpa dependensi/backend baru.

## 10. Keputusan Produk yang Dikunci

1. **Grouping adalah satu-satunya scope pekerjaan kali ini.**
2. **Bookmark/Favorit tetap satu sistem data**, bernama **Wisata Tersimpan** di Profil; keputusan penyatuan visual tombol pada layar lain adalah pekerjaan terpisah.
3. **Notifikasi dihapus dari menu Profil saja**, bukan dihapus dari aplikasi.
4. **Fitur yang belum tersedia tidak dipalsukan.**
5. **Hanya satu penanggung jawab implementasi Flutter** (`flutter_engineer`) jika menggunakan agen; tidak perlu orkestra banyak agen.

---

**Handoff:** Implementasikan langsung sebagai perubahan fokus di Flutter; jangan membuat proposal, redesign alternatif, atau penambahan fitur di luar scope PRD ini.
