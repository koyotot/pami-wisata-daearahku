# DESIGN.md — Audit UI/UX Wisata Daerahku

Dokumen ini mencatat **kode yang ada**, bukan spesifikasi desain baru. Audit dilakukan secara statis pada checkout ini; nilai pada widget lokal tidak otomatis merupakan token resmi. Rujukan `lib/screens/<nama>.dart` disingkat menjadi nama file pada bagian layar dan komponen. Perilaku aktual pada perangkat, kontras terukur, aksesibilitas dan layanan remote belum diverifikasi. Evaluasi memakai prinsip hierarki, komposisi, warna, komponen, responsivitas dan state dari skill `design-taste-frontend`; inspector dan screenshot tidak dijalankan sesuai brief.

## 1. Ringkasan Proyek

Aplikasi wisata untuk pengunjung dan administrator: melihat destinasi, mendaftar kunjungan, mengelola data wisata dan pendaftar (`lib/screens/`, `lib/data/app_data.dart`). Versi aplikasi `1.0.0+1`; constraint Dart `>=3.0.0 <4.0.0` pada `pubspec.yaml`; `pubspec.lock` saat audit mengunci Dart `>=3.11.0 <4.0.0`, Flutter `>=3.38.4`. Constraint Flutter eksplisit di pubspec: Tidak ditemukan di kode. Proyek memiliki direktori Android, iOS, web dan desktop, tetapi `lib/firebase_options.dart` hanya menyediakan konfigurasi Android; web/iOS/macOS/Windows/Linux melempar `UnsupportedError`. Ini bukan bukti aplikasi berhasil berjalan pada Android.

| Dependency langsung | Penggunaan yang ditemukan | Versi lock |
|---|---|---|
| flutter, firebase_core | Material/widgets; inisialisasi Firebase pada `lib/main.dart:1` | SDK; 3.15.2 |
| firebase_auth, cloud_firestore | autentikasi pengunjung dan data; `user_login_screen.dart`, `lib/data/app_data.dart` | 5.7.0; 5.6.12 |
| image_picker, http | pilih foto dan unggah multipart; `tambah_wisata_screen.dart:91`, `:209` | 1.2.2; 1.6.0 |
| qr_flutter | tampilan QR bukti; `bukti_konfirmasi_screen.dart`, `bukti_pendaftaran_screen.dart` | 4.1.0 |
| google_fonts | Plus Jakarta Sans pada sejumlah layar; misalnya `home_screen.dart:20` | 8.2.1 |
| firebase_storage, cupertino_icons | terdaftar; import/pemakaian di `lib/` tidak ditemukan | 12.4.10; 1.0.9 |
| flutter_test, flutter_lints | dependency development; lint di `analysis_options.yaml` | lihat `pubspec.lock` |

## 2. Struktur Folder

```text
lib/
  main.dart                  # inisialisasi Firebase, MaterialApp dan tema
  firebase_options.dart      # pilihan konfigurasi platform Firebase
  data/app_data.dart         # model, state global dan operasi Firestore
  models/pendaftaran.dart    # model Pendaftaran terpisah
  models/wisata.dart         # model Wisata terpisah
  theme/app_colors.dart      # konstanta AppColors, tidak ditemukan pemakaiannya
  screens/
    home_screen.dart  user_login_screen.dart  user_register_screen.dart
    admin_login.dart  admin_dashboard.dart  main_navigation_screen.dart
    beranda_user_screen.dart  cari_wisata_screen.dart  detail_wisata_screen.dart
    daftar_kunjungan_screen.dart  bukti_konfirmasi_screen.dart
    bukti_pendaftaran_screen.dart  profil_user_screen.dart
    daftar_wisata_screen.dart  tambah_wisata_screen.dart
    daftar_pendaftar_screen.dart  kelola_admin_screen.dart
```

Tidak ditemukan folder service, router atau widget bersama di `lib/`. Navigasi dan komponen privat berada dalam file layar; model utama yang dipakai alur Firestore berada di `data/app_data.dart`, berbeda dari model dalam `models/`.

## 3. Design Tokens

### Warna

Nilai adalah ARGB; sumber dan pemakaian membedakan tema, konstanta dan gaya lokal. `AppColors` adalah deklarasi terpusat, tetapi `rg` tidak menemukan referensi class di luar file tersebut; jangan menganggapnya tema aktif.

| Nama/peran | Nilai | Sumber dan penggunaan |
|---|---|---|
| seed/aksi, latar scaffold | `#FF0A6E5E`, `#FFF7F4EF` | `lib/main.dart:30-37`, ThemeData light |
| AppBar/tombol, teks | `#FF0A6E5E`, `#FFFFFFFF` | `lib/main.dart:38-62` |
| input: surface, border enabled/focused, label/hint | `#FFFFFFFF`, `#FFE0D9CE`, `#FF0A6E5E`, `#FF7A7065`, `#FFB0A898` | `lib/main.dart:65-82` |
| blue, blueDeep, navy, orange | `#FF1976D2`, `#FF1558B0`, `#FF102D59`, `#FFFF9800` | konstanta lokal `home_screen.dart:31-34`, `_C` serupa `main_navigation_screen.dart:24-31` dan `beranda_user_screen.dart:16-23` |
| background, muted, border, danger | `#FFF5F8FD`, `#FF728099`, `#FFDCE4F0`, `#FFE5484D` | `_C` lokal misalnya `admin_dashboard.dart:22-35` |
| AppColors bg/surface/card/border/borderAlt | `#FF0D1B1E`, `#FF142226`, `#FF1A2D32`, `#FF254A44`, `#FF1F3A40` | `lib/theme/app_colors.dart:15-19`; pemanggil Tidak ditemukan di kode |
| AppColors teal/tealDark/tealDeep | `#FF0BC5A0`, `#FF07897A`, `#FF054D44` | `lib/theme/app_colors.dart:22-24`; pemanggil tidak ditemukan |
| AppColors gold/goldLight, text/textMuted/textDim | `#FFE8B86D`, `#FFF5D49A`, `#FFEEF2F0`, `#FF7FA89C`, `#FF4A706A` | `lib/theme/app_colors.dart:27-34`; pemanggil tidak ditemukan |
| AppColors danger/success/info/warning/purple/slate | `#FFFF6B6B`, `#FF4ADE80`, `#FF38BDF8`, `#FFFB923C`, `#FFA78BFA`, `#FF94A3B8` | `lib/theme/app_colors.dart:37-45`; pemanggil tidak ditemukan |

Warna lokal lain dan transparansi ditentukan langsung pada masing-masing layar; contohnya gradien `#FF2A93F0` → blue → blueDeep pada `beranda_user_screen.dart:233-237`. Nilai lain yang tidak ditetapkan eksplisit mengikuti Flutter/ColorScheme, bukan nilai yang dapat dipastikan dari kode ini.

### Tipografi, ruang, bentuk dan efek

| Kategori | Nilai aktual dan sumber |
|---|---|
| Font global | `Georgia`, `ThemeData` (`lib/main.dart:36`); file font Georgia tidak didaftarkan di pubspec, sehingga ketersediaan/fallback bergantung platform. |
| Font lokal | `GoogleFonts.plusJakartaSans`, helper `_font` misalnya `home_screen.dart:14-26`, `admin_dashboard.dart:38-51`; sebagian layar memakai `plusJakartaSansTextTheme` (`profil_user_screen.dart:283`). |
| Ukuran/weight/tracking | AppBar 18/bold/0.5 dan ElevatedButton 15/bold (`lib/main.dart:43-62`); contoh lokal judul 18/w800/-0.4 (`home_screen.dart:133`), 20/w800/-0.5 (`admin_dashboard.dart:491`). Ukuran dan tracking lain ditentukan per widget; skala resmi tunggal tidak ditemukan. |
| Spacing | ElevatedButton horizontal 24, vertikal 16 (`lib/main.dart:58`); `home_screen.dart:74-89` memakai gap 12, 14, 16 dan 22. Tidak ada token spacing global ditemukan. |
| Radius/border | Tema input dan tombol 14, card 20; input enabled 1.5, focused 2 (`lib/main.dart:53-88`). Lokal misalnya hero beranda 28 dan kartu 24 (`beranda_user_screen.dart:233`, `:716`), action home 18 dan border 1.4 (`home_screen.dart:293-324`). |
| Elevation/shadow | AppBar dan Card theme elevation 0 (`lib/main.dart:41,85`); hero home memakai `BoxShadow` blur 28, offset (0,12) (`home_screen.dart:153-156`); kartu dashboard blur 20, offset (0,8) (`admin_dashboard.dart:469-472`). |
| Ikon | Material `Icons`, `uses-material-design: true` (`pubspec.yaml`, `home_screen.dart:124`); ukuran ditentukan lokal atau default Flutter jika tidak dinyatakan. Package `cupertino_icons` terdaftar tetapi penggunaan tidak ditemukan. |
| Mode | `ColorScheme.fromSeed` dengan `Brightness.light`; `darkTheme`/`themeMode` tidak ditemukan (`lib/main.dart:28-92`). Ada layar bergaya gelap secara lokal, bukan dukungan dark mode global. |

## 4. Komponen UI Reusable

Tidak ditemukan custom widget publik yang dipakai lintas file. Ada **43 subclass widget privat lokal** dalam 17 file layar; masing-masing dipakai di file tempat didefinisikan, sehingga nama identik antarfile bukan class bersama. Komponen berikut merupakan inventaris; parameter tertulis sesuai field constructor, dan parameter `key` bawaan dicantumkan bila ada. Styling dan state rinci dapat ditelusuri pada deklarasi; default Flutter berlaku untuk properti yang tidak ditentukan.

| Layar/file dan komponen | Parameter dan fungsi/state visual |
|---|---|
| `home_screen.dart:278` `_ActionButton` | `icon`, `label`, `filled`, `onTap`: aksi berikon, isi gradien atau outline, radius 18; tap. |
| `admin_login.dart:406` `_FieldLabel`, `_LoginTextField`, `_PasswordTextField`, `_ErrorBanner`, `_LoginButton` | berturut-turut `label`; `controller`, `hint`, `prefixIcon`, `textInputAction`, `validator`; `controller`, `obscure`, `onToggle`, `onSubmit`, `validator`; `message`; `isLoading`, `onPressed`. Label, input, toggle password, banner dan tombol loading; dipakai AdminLogin. |
| `user_login_screen.dart:792` `_ErrorBanner` | `message`; banner error login. |
| `user_register_screen.dart:649` `_RegField`, `_PasswordStrength`, `_GradientButton`, `_ErrorBanner`, `_SuccessDialog` | field: `controller`, `label`, `hint`, `icon`, `enabled`, `obscure`, `keyboardType`, `textInputAction`, `textCapitalization`, `inputFormatters`, `autofillHints`, `validator`, `onFieldSubmitted`, `onChanged`, `onToggleObscure`; lainnya `password`; `label`, `icon`, `isLoading`, `onTap`; `message`; `namaUser`. State: validasi/disabled/obscure, kekuatan password, loading, error dan dialog sukses. |
| `beranda_user_screen.dart:667` `_WisataCard` | `wisata`, `index`, `onTap`; kartu destinasi bergambar, animasi dan tap. |
| `cari_wisata_screen.dart:589` `_FadeSlide`, `_Thumb`, `_KategoriBadge`, `_HeroCard`, `_GridCard`, `_ListCard` | `key`, `index`, `child`; `wisata`; `kategori`, `kecil`; tiga kartu masing-masing `wisata`. Animasi, thumbnail/placeholder, badge kategori dan kartu detail; kartu dapat membuka detail. |
| `detail_wisata_screen.dart:755` `_FasilitasBadge` | `icon`, `label`; label fasilitas. |
| `daftar_kunjungan_screen.dart:500` `_DestinasiCard`, `_DarkField`, `_CounterBtn` | `wisata`; `controller`, `label`, `hint`, `icon`, `keyboardType`, `inputFormatters`, `validator`, `maxLines`; `icon`, `onTap`. Kartu, field dan counter; `onTap` null menandai counter tidak aktif. |
| `bukti_pendaftaran_screen.dart:80` `_FotoWisata`, `:597` `_StatTile`, `:663` `_FadeSlide`, `:687` `_TicketCard`, `:1170` `_FormUlasanSheet`, `:1435` `_InfoItem`, `:1516` `_StatusBadge`, `:1551` `_TiketBottomSheet` | Foto: `wisata`, `style`; statistik: `label`, `count`, `accent`, `selected`, `onTap`; animasi: `key`, `index`, `child`; tiket/sheet tiket: `pendaftar`; ulasan: `pendaftar`, `onSelesai`; info: `icon`, `label`, `value`; badge: `status`, `onPhoto`. Menampilkan status, filter, detail dan QR; ulasan memiliki validasi/loading. |
| `daftar_wisata_screen.dart:650` `_WisataCard` | `wisata`, `mode`, `accent`, `onTap`, `onEdit`, `onHapus`; kartu untuk mode lihat/edit/hapus, gambar dan aksi sesuai mode. |
| `daftar_pendaftar_screen.dart:294` `_PendaftarCard`, `:725` `_RingkasanRow` | `pendaftar`; `list`. Kartu status dan aksi persetujuan/penolakan, ringkasan jumlah. |
| `admin_dashboard.dart:1112` `_PulseDot` | `color`; indikator animasi. |
| `profil_user_screen.dart:1204` `_GantiPasswordSheet`, `:1649` `_SheetPasswordField`, `:1707` `_EditProfilSheet`, `:1891` `_RiwayatUlasanSheet`, `:2008` `_NotifikasiSheet`, `:2122` `_PilihBahasaSheet`, `:2226` `_SemuaWisataTersimpanSheet`, `:2321` `_ErrorBanner` | `_GantiPasswordSheet`: tanpa parameter; `_SheetPasswordField`: `controller`, `obscure`, `onToggle`, `onSubmit`; `_EditProfilSheet`: `namaAwal`, `teleponAwal`, `onSimpan`; dua sheet riwayat/tersimpan: `userId`; notifikasi dan bahasa: tanpa parameter; banner: `message`. Ada state form, loading dan error pada operasi terkait; pengaturan notifikasi/bahasa lokal sheet. |

`CustomPainter` `_ScenePainter`, `_DashPainter`, `_DashedLinePainter` adalah painter, bukan widget. `Scaffold`, `AppBar`, `TextField`, `Card`, `SnackBar`, dialog, bottom sheet, `CircularProgressIndicator` dan empty state juga ditulis langsung/lokal; implementasi dan style tidak seluruhnya dibagi bersama. Lihat masing-masing layar untuk pemanggilan dan parameter lengkap.

## 5. Daftar Layar

Seluruh path pada tabel adalah `lib/screens/<file>`. Kolom state menyebut yang tampak di kode; state yang tidak disebut untuk layar tersebut **tidak ditemukan secara eksplisit**, bukan klaim bahwa Flutter tidak menyediakan default. Responsivitas umumnya memakai scroll dan inset; breakpoint adaptif khusus tidak ditemukan kecuali yang disebut. Tidak ada pembuktian ukuran perangkat.

| Layar dan sumber | Layout, data dan aksi | State; navigasi dan responsivitas |
|---|---|---|
| `HomeScreen`, `home_screen.dart:28` | Header/identitas, ilustrasi hero, tombol masuk user dan admin; data statis. | Tidak ada loading/empty/error/success eksplisit; masuk aplikasi → login user/admin. Scroll dan animasi lokal. |
| `UserLoginScreen`, `user_login_screen.dart:43` | Form email/password, toggle visibility, login dan tautan daftar. Firebase Auth dan profil user. | Validasi, banner error, loading/disabled; sukses → MainNavigation, daftar → UserRegister, kembali → Home. `LayoutBuilder`, inset status bar. |
| `UserRegisterScreen`, `user_register_screen.dart:41` | Form nama, email, telepon, password dan konfirmasi; indikator kekuatan. | Validasi, loading/disabled, error dan dialog sukses; masuk dari login, selesai kembali ke login. `LayoutBuilder` dan scroll. |
| `AdminLogin`, `admin_login.dart:66` | Header, username/password, toggle dan tombol login; dokumen `admins`. | Validasi/loading/error; Home → login → AdminDashboard. Tinggi layar dan inset melalui `MediaQuery`. |
| `MainNavigationScreen`, `main_navigation_screen.dart:60` | Shell drawer dan tab Beranda, Cari, Riwayat, Profil; identitas pengguna. | State tab lokal; dialog konfirmasi logout; kembali dari tab ke Beranda; login → shell, logout → awal. State data dikelola layar anak. |
| `BerandaUserScreen`, `beranda_user_screen.dart:41` | Header pengguna, hero, pencarian, kategori dan grid kartu wisata dari `daftarWisata`. | Loading dan kosong; buka drawer/detail; grid dua kolom dengan rasio tetap (`:635-642`); error load eksplisit tidak ditemukan. |
| `CariWisataScreen`, `cari_wisata_screen.dart:69` | Header, pencarian, kategori, pilihan grid/list, kartu hasil dari `daftarWisata`. | Hasil kosong/reset; detail dari kartu, mode embedded di shell atau kembali; grid dua kolom (`:184-185`), tidak ditemukan loading/error fetch tersendiri. |
| `DetailWisataScreen`, `detail_wisata_screen.dart:38` | Foto, nama/lokasi, deskripsi dan info/fasilitas, favorit, tombol daftar; menerima `Wisata`. | Gambar placeholder/loading, feedback favorit Snackbar; masuk dari kartu, keluar kembali atau → DaftarKunjungan. Scroll; breakpoint khusus tidak ditemukan. |
| `DaftarKunjunganScreen`, `daftar_kunjungan_screen.dart:33` | Kartu destinasi, form identitas, tanggal, jumlah 1–50 dan catatan, tombol kirim. | Validasi, loading/disabled; simpan → BuktiKonfirmasi; kembali → detail. Error penyimpanan eksplisit tidak ditemukan (`:139-169`); scroll. |
| `BuktiKonfirmasiScreen`, `bukti_konfirmasi_screen.dart:44` | Rincian pendaftaran/destinasi, QR dan kode, aksi salin/lanjut. | Snackbar salin; tidak ditemukan loading/empty/error async; dari pendaftaran → navigasi utama. Menghitung inset atas/bawah (`:120`, `:169`). |
| `BuktiPendaftaranScreen`, `bukti_pendaftaran_screen.dart:125` | Statistik/filter, daftar tiket expandable dan QR pada status disetujui, sheet ulasan; stream pendaftar user. | Loading, empty dan hasil filter kosong, feedback ulasan; tab Riwayat atau layar mandiri, aksi jelajah/kembali. Sheet menyesuaikan inset keyboard (`:1254`); error stream eksplisit tidak ditemukan (`:204-236`). |
| `ProfilUserScreen`, `profil_user_screen.dart:66` | Identitas/statistik, wisata tersimpan dan menu edit, password, ulasan, notifikasi, bahasa, logout/hapus akun. | Loading/empty pada beberapa stream, validasi dan Snackbar pada operasi; tab Profil, menu membuka sheet/dialog; keyboard inset dan tinggi sheet maksimum 75% (`:1357`, `:1899`). Notifikasi/bahasa berupa state lokal sheet. |
| `AdminDashboard`, `admin_dashboard.dart:69` | Header/admin, statistik, menu dan pendaftar terbaru, drawer; data global Firestore. | Loading/kosong sebagian; login admin → dashboard → pengelolaan wisata/pendaftar/admin; menu admin bergantung superadmin. Error load yang terlihat khusus tidak ditemukan. |
| `DaftarWisataScreen`, `daftar_wisata_screen.dart:57` | Pencarian, filter kategori dan daftar kartu dalam mode lihat/edit/hapus. | Loading, empty dan dialog hapus; dari dashboard → detail atau TambahWisata; kembali. Scroll; breakpoint khusus tidak ditemukan. |
| `TambahWisataScreen`, `tambah_wisata_screen.dart:37` | Pilih gambar kamera/galeri, form data destinasi/kategori/rating dan simpan; edit menerima `wisataEdit`. | Validasi, loading/disabled dan Snackbar sukses/gagal; dashboard atau daftar → form → kembali. Memperhitungkan inset bawah (`:592`). |
| `DaftarPendaftarScreen`, `daftar_pendaftar_screen.dart:30` | Ringkasan, daftar kartu pendaftar dan aksi setujui/tolak. | Loading, empty dan dialog/feedback aksi; dari dashboard lalu kembali; scroll. Error load khusus tidak ditemukan. |
| `KelolaAdminScreen`, `kelola_admin_screen.dart:9` | Daftar admin, form tambah dan dialog hapus; stream `admins`. | Loading/empty, validasi, loading form dan Snackbar; menu dashboard untuk superadmin → layar → kembali; inset atas (`:213`). |

## 6. Navigasi dan Alur Pengguna

Entry point `main()` menginisialisasi Firebase lalu `MaterialApp(home: HomeScreen())` (`lib/main.dart:7-22,91`). Navigasi memakai `Navigator`, `MaterialPageRoute` atau `PageRouteBuilder` dan state tab (`main_navigation_screen.dart`); named routes, router package, deep link dan auth guard saat startup: Tidak ditemukan di kode. Menu superadmin pada dashboard adalah pembatas tampilan, bukan bukti aturan otorisasi backend.

1. Home → login pengunjung → Firebase Auth → MainNavigation; pendaftaran akun tersedia dari login. Login admin melakukan query username dan password ke koleksi `admins`, mengisi `currentAdmin` dalam memori, dan membuat superadmin awal jika koleksi kosong (`admin_login.dart:108-155`); nilai kredensial tidak dicantumkan.
2. Beranda atau Cari → detail wisata → favorit atau daftar kunjungan → simpan `pendaftar` → konfirmasi; Riwayat menampilkan status `menunggu`, `disetujui`, `ditolak` dan tiket/QR pada alur yang tersedia (`bukti_pendaftaran_screen.dart`). Tidak ditemukan pembayaran/checkout.
3. Profil menyediakan data akun, tersimpan, ulasan, password dan pengaturan lokal. Tidak ditemukan layanan push notification atau sistem lokalisasi yang mengikat pilihan bahasa (`profil_user_screen.dart:2008,2122`).
4. AdminDashboard membuka daftar/tambah/edit/hapus wisata dan pendaftar; kelola admin ditampilkan untuk superadmin. Lihat `admin_dashboard.dart`, `daftar_wisata_screen.dart`, `daftar_pendaftar_screen.dart`, `kelola_admin_screen.dart`.

## 7. Data dan Integrasi

| Model | Field dan tipe | Sumber |
|---|---|---|
| `User` | `String id, namaLengkap, email, noTelepon, password`; `DateTime createdAt` | `lib/data/app_data.dart` |
| `Wisata` utama | `String id, nama, lokasi, deskripsi, hargaTiket, jamBuka, kategori`; `String? imagePath`; `double rating` | `lib/data/app_data.dart`; `toMap/fromMap` untuk Firestore |
| `Pendaftar` | `String? id`; `String userId, namaPengunjung, noTelepon, email, wisata, tanggal, nomorBukti, catatan, status`; `int jumlahOrang` | `lib/data/app_data.dart`; status default `menunggu`, `toMap/fromMap` |
| `Wisata` terpisah | `int id`; `String nama, lokasi, deskripsi, hargaTiket, jamBuka, kategori`; `String? imagePath` | `lib/models/wisata.dart`; model terpisah dari model utama |
| `Pendaftaran` | `int id, jumlahOrang`; `String namaPengunjung, noTelepon, wisata, tanggal, nomorBukti` | `lib/models/pendaftaran.dart` |
| `AdminUser` | `String id, username, namaLengkap`; `bool isSuperAdmin` | `lib/screens/admin_login.dart:42` |

State menggunakan `StatefulWidget`/`setState`, controller, Future/StreamBuilder dan list/objek global `daftarWisata`, `daftarPendaftar`, `currentUser` (`lib/data/app_data.dart`); state-management package khusus tidak ditemukan. `loadWisataFromFirestore()` membaca dan melakukan seed awal jika nama belum tersedia; `loadPendaftarFromFirestore()` dapat memfilter `userId` (`lib/data/app_data.dart:192,237`).

Firebase Auth dipakai untuk akun pengunjung; Firestore dipakai langsung oleh layar dan helper dengan koleksi `users`, `admins`, `wisata`, `pendaftar`, `wisataTersimpan`, `ulasan`; profil juga membaca `kunjungan` (`profil_user_screen.dart:128`), alur penulisan kunjungan tidak ditemukan. Firebase Storage tercantum sebagai dependency, penggunaannya tidak ditemukan. `ImagePicker` memilih gambar; `http.MultipartRequest` mengunggah ke Cloudinary pada `tambah_wisata_screen.dart:91,209`, lalu data wisata disimpan ke Firestore. QR ditampilkan oleh `qr_flutter` pada layar bukti. Endpoint Laravel REST, client API Laravel dan service integrasinya: **Tidak ditemukan di kode**. Kredensial dan nilai konfigurasi tidak disalin ke dokumen ini.

## 8. Aset

| Aset | Tipe dan pendaftaran | Penggunaan di `lib/` |
|---|---|---|
| `assets/images/Candi_Borobudur.jpg` | JPEG; eksplisit di `pubspec.yaml` | Tidak ditemukan referensi aset |
| `assets/images/Pantai_Kuta.jpg` | JPEG; eksplisit di `pubspec.yaml` | Tidak ditemukan referensi aset |
| Material Icons | font ikon Material dari Flutter; `uses-material-design: true` | `Icons` di berbagai screen, misalnya `home_screen.dart` |
| Google Fonts | package, bukan file font yang didaftarkan di assets | Plus Jakarta Sans pada helper layar; contoh `home_screen.dart:20` |

Tidak ditemukan file font/icon lain di `assets/` atau referensi `Image.asset`/`AssetImage` dalam `lib/`. Gambar wisata berasal dari `imagePath` dan seed URL di `lib/data/app_data.dart`; gambar jaringan membutuhkan layanan yang tersedia. Referensi aset lokal yang tidak ada di repository: Tidak ditemukan di kode.

## 9. Konvensi Kode

File umumnya `snake_case.dart`, class `PascalCase`, method/field `camelCase`; `_` menandakan privat per library. Layar dan widget lokal digabung dalam `lib/screens/`; tidak ada folder widget/service/router bersama. Import package Flutter/Firebase dan import relatif dipakai berdampingan. `StatefulWidget`, `setState`, controller, globals dan builder dipakai sesuai layar; Dart null safety terlihat pada `?`, `required`, `mounted` dan controller lifecycle. Error ditangani tidak seragam: misalnya upload menampilkan Snackbar (`tambah_wisata_screen.dart:291-319`), sedangkan submit kunjungan tidak memiliki catch eksplisit (`daftar_kunjungan_screen.dart:139-169`). `analysis_options.yaml` meng-include `package:flutter_lints/flutter.yaml` tanpa aturan tambahan aktif. Ini deskripsi pola, bukan jaminan semua file konsisten.

## 10. Aturan Wajib untuk Codex

- Pertahankan identitas visual layar existing dan periksa konteksnya: tema global dan gaya lokal berbeda.
- Pakai nilai teridentifikasi pada sumber yang relevan; jangan menyebut warna lokal sebagai token resmi baru atau menganggap `AppColors` aktif tanpa memeriksa pemanggil.
- Reuse komponen yang benar-benar dapat diakses sebelum membuat yang baru; komponen privat tidak bisa langsung diimpor lintas file.
- Pertahankan penamaan dan struktur existing; hindari hardcoded style baru bila pola yang sesuai sudah tersedia.
- Jangan menambah dependency tanpa kebutuhan teknis jelas. Perhatikan responsivitas, aksesibilitas, serta state loading, empty dan error sesuai fitur.
- Jangan mengubah navigasi atau business logic hanya untuk penyesuaian desain. Pertahankan batas auth dan data; cek source terkini sebelum mengubahnya.
- Untuk layar baru, gunakan dokumen ini sebagai referensi awal dan verifikasi ulang terhadap kode terkini; jangan mengasumsikan integrasi Laravel sudah tersedia.

## 11. Ketidakkonsistenan dan Utang Desain

Prioritas berikut adalah **rekomendasi audit**, bukan fakta kode; dampak berupa risiko yang perlu diuji, bukan hasil pengujian visual.

| Temuan | Lokasi kode | Bukti | Dampak | Prioritas rekomendasi |
|---|---|---|---|---|
| Tema global dan style lokal berbeda | `lib/main.dart:30-36`, `home_screen.dart:31-35` | teal/Georgia global, biru/Plus Jakarta Sans lokal | perubahan tema global mungkin tidak memengaruhi seluruh layar | Sedang: pemeliharaan visual |
| Konstanta warna duplikat; `AppColors` tidak dipakai | `lib/theme/app_colors.dart`, `main_navigation_screen.dart:24`, `beranda_user_screen.dart:16` | class `_C` terpisah dan tidak ada pemanggil `AppColors` | perubahan warna dapat tersebar dan menyimpang | Sedang: konsistensi |
| Kartu dan banner privat berulang | `beranda_user_screen.dart:667`, `daftar_wisata_screen.dart:650`, `user_login_screen.dart:792`, `user_register_screen.dart:932` | definisi lokal terpisah | perbaikan visual/feedback perlu dicocokkan antar layar | Sedang: pemeliharaan |
| Error submit kunjungan tanpa catch eksplisit | `daftar_kunjungan_screen.dart:139-169` | loading aktif sebelum Firestore add dan tidak ditemukan catch pada jalur ini | kegagalan dapat meninggalkan indikator dan tanpa pesan | Tinggi: pengguna tidak tahu hasil pendaftaran |
| Error stream riwayat tidak ditangani eksplisit | `bukti_pendaftaran_screen.dart:204-236` | loading/empty diperiksa, `hasError` tidak | kesalahan data berisiko terlihat sebagai kosong | Tinggi: status kunjungan sulit dipahami |
| Grid dengan dua kolom tetap | `beranda_user_screen.dart:635-642`, `cari_wisata_screen.dart:184-185` | `crossAxisCount: 2` | risiko kepadatan/overflow pada ukuran dan text scaling ekstrem; belum diuji | Sedang: perlu validasi perangkat |
| Dua gambar terdaftar tanpa referensi kode | `pubspec.yaml`, `assets/images/` | pencarian `lib/` tidak menemukan path aset | aset mungkin menambah ukuran bundle tanpa digunakan | Rendah: verifikasi sebelum menghapus |
| Pengaturan bahasa/notifikasi lokal | `profil_user_screen.dart:2008,2122` | sheet menyimpan pilihan lokal; layanan terkait tidak ditemukan | pengguna dapat mengira pengaturan berlaku permanen | Sedang: kejelasan feedback |
| Tampilan warna, shadow, radius dan tipografi lokal beragam | `lib/main.dart:53-88`, `home_screen.dart:145-156`, `admin_dashboard.dart:469-472` | nilai dan efek berbeda menurut layar | hierarki/konsistensi perlu ditinjau secara visual | Rendah: belum ada pengukuran kontras atau screenshot |
