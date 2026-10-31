# Wisata Daerahku — Aplikasi Mobile Flutter

Aplikasi mobile Android untuk menjelajahi destinasi wisata dan memesan kunjungan, sekaligus
alat kerja administrator untuk mengelola katalog, kuota, dan persetujuan pemesanan.

Aplikasi ini adalah klien dari **Laravel REST API**. Seluruh data bisnis (katalog, favorit,
booking, profil, review, check-in, dokumen) dikelola backend Laravel + MySQL. Firebase hanya
dipakai untuk dua hal: **Google Sign-In** dan **Firebase Cloud Messaging (FCM)**.

> README ini disusun dari source code aktual repository. Bagian yang tidak dapat diverifikasi
> dari kode ditandai eksplisit pada [Known Limitations](#15-known-limitations).

## Daftar Isi

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Application Architecture](#3-application-architecture)
4. [Application Features](#4-application-features)
5. [Project Structure](#5-project-structure)
6. [Development Requirements](#6-development-requirements)
7. [Installation & Setup](#7-installation--setup)
8. [Running Android Emulator](#8-running-android-emulator)
9. [Connecting Flutter to Local Laravel API](#9-connecting-flutter-to-local-laravel-api)
10. [Authentication & Session Management](#10-authentication--session-management)
11. [Firebase Integration](#11-firebase-integration)
12. [Testing & Quality Assurance](#12-testing--quality-assurance)
13. [Build Android](#13-build-android)
14. [Troubleshooting](#14-troubleshooting)
15. [Known Limitations](#15-known-limitations)
16. [Dokumentasi Lain di Repository](#16-dokumentasi-lain-di-repository)

---

## 1. Project Overview

**Wisata Daerahku** melayani dua kelompok pengguna dalam satu aplikasi:

| Pengguna | Kebutuhan |
| --- | --- |
| **Wisatawan (User)** | Mencari destinasi, menyimpan favorit, memesan kunjungan, melihat riwayat, mengunduh tiket PDF, check-in, dan memberi ulasan. |
| **Administrator (Admin / Superadmin)** | Mengelola destinasi, kuota harian, keputusan booking, dan (khusus Superadmin) kategori serta akun admin. |

Hubungan dengan backend: aplikasi **tidak menyimpan atau memutuskan data bisnis sendiri**.
Aplikasi memanggil Laravel REST API pada prefix `/api/v1`; peran (role), status akun, kuota,
dan aturan booking ditentukan backend. Guard di Flutter hanya mengatur navigasi, sedangkan
otorisasi sebenarnya ada di Laravel.

Backend Laravel berada di repository terpisah dan **tidak termasuk** dalam repository ini.

## 2. Technology Stack

Sumber: `pubspec.yaml`, `android/`, dan `lib/`.

| Komponen | Detail |
| --- | --- |
| Framework | Flutter (Material 3), Dart SDK constraint `>=3.0.0 <4.0.0` |
| Target platform | Android (kode `FcmDeviceManager` hanya aktif di Android; registrasi perangkat mengirim `platform: android`) |
| HTTP client | `http` ^1.2.2 — dibungkus `AuthSession` / `ApiClient` (timeout 20 detik) |
| Secure storage | `flutter_secure_storage` ^11.2.0 — menyimpan sesi JWT (key `laravel_session`) |
| Firebase Authentication | `firebase_core` ^3.6.0, `firebase_auth` ^5.3.1 — hanya perantara Google Sign-In |
| Push notification | `firebase_messaging` ^15.2.10 |
| Upload gambar | `image_picker` ^1.2.2 (admin, multipart ke Laravel) |
| Tipografi / ikon | `google_fonts` ^8.2.1, `cupertino_icons` ^1.0.2 |
| Lint | `flutter_lints` ^2.0.0 (`analysis_options.yaml`) |
| State management | Tanpa package eksternal: `ChangeNotifier`, `ValueNotifier`, dan `StatefulWidget` |
| Android build | Gradle wrapper 8.14, Android Gradle Plugin 8.11.1, Kotlin 2.2.20, Java 17 (`compileOptions`/`jvmTarget`) |
| Application ID | `id.wisatadaerahku.app` |

`cloud_firestore`, `firebase_storage`, dan `qr_flutter` **sudah dihapus** dari dependency
(Phase 6) dan tidak boleh ditambahkan kembali sebagai penyimpanan data bisnis.

## 3. Application Architecture

### 3.1 Alur data bisnis

```text
Flutter Application  ──HTTPS/JSON──▶  Laravel REST API (/api/v1)  ──▶  MySQL
 (UI → *State → BusinessRepository → AuthSession)
```

- Layar (`screens/`) membaca state (`data/*_state.dart`).
- State memanggil `BusinessRepository` (`data/business_repository.dart`).
- Repository memanggil `ApiClient`, yang meneruskan ke `AuthSession` (menambahkan header,
  Bearer token, refresh token otomatis, dan penanganan error).
- Respons sukses dibungkus `{"data": …}`; koleksi berpaginasi menambah `links` dan `meta`.

### 3.2 Alur Google Sign-In (terpisah dari data bisnis)

```text
Flutter ─▶ Firebase Authentication (Google provider) ─▶ Firebase ID token
        ─▶ POST /api/v1/auth/google {id_token} ─▶ Laravel memverifikasi token
        ─▶ Laravel menerbitkan JWT access + refresh token
```

Sesi Firebase hanya perantara. Setelah pertukaran token, `FirebaseAuth.signOut()` selalu
dipanggil; identitas Firebase **tidak** dipakai untuk menentukan role maupun akses.

### 3.3 Alur push notification

```text
Laravel ─▶ Firebase Cloud Messaging ─▶ perangkat Android (Flutter)
```

Flutter mengambil FCM token lalu mendaftarkannya ke Laravel (`PUT /devices`) setelah login,
dan menghapusnya (`DELETE /devices`) saat logout atau token berganti.

### 3.4 Peran Firebase

**Firebase bukan lagi database bisnis aplikasi.** Firestore dan Firebase Storage tidak lagi
menjadi dependency. Lihat [Firebase Integration](#11-firebase-integration).

## 4. Application Features

Fitur di bawah ini diverifikasi dari kode UI dan repository, bukan dari dokumentasi lama.
Role berasal dari backend: `0` = User, `1` = Admin, `2` = Superadmin.

### 4.1 User (role 0)

| Fitur | Implementasi |
| --- | --- |
| Registrasi & login email/password | `UserRegisterScreen`, `UserLoginScreen` → Laravel `auth/register`, `auth/login` |
| Login Google | Firebase Auth → `auth/google` (hanya role 0) |
| Katalog & kategori | `GET categories`, `GET destinations` |
| Pencarian & filter | Parameter `search` dan `category` dikirim ke server; tampilan grid/daftar (`CariWisataScreen`) |
| Detail destinasi | `GET destinations/{guid}`, gambar dimuat lewat `ApiImage` (memakai header/token dari `ApiClient`) |
| Ketersediaan kuota | `GET destinations/{guid}/availability` |
| Favorit | `GET/PUT/DELETE favorites` |
| Booking | `POST bookings` dengan `Idempotency-Key`; intent disimpan lalu direkonsiliasi bila hasil tidak pasti (`booking_intent.dart`) |
| Riwayat & detail booking | `GET bookings`, `GET bookings/{guid}` (`BuktiPendaftaranScreen`) |
| Pembatalan | `POST bookings/{guid}/cancel` (hanya status `pending_approval`, aturan di backend) |
| Dokumen PDF | `GET bookings/{guid}/documents` dan `…/documents/{invoice\|ticket}`; file diverifikasi header `%PDF` lalu disimpan |
| Check-in | `POST bookings/{guid}/check-in` (tombol muncul bila `can_check_in`) |
| Review | `POST bookings/{guid}/review`, daftar ulasan destinasi, riwayat ulasan pengguna |
| Profil | Lihat/ubah nama & telepon (`PATCH profile`), statistik (`GET profile/statistics`), daftar wisata tersimpan |
| Notifikasi push | Token FCM didaftarkan ke Laravel; saat aplikasi di foreground dan pesan membawa `notification_guid`, muncul SnackBar |

Tiket dan invoice berasal dari **PDF yang diterbitkan backend Laravel**. Menurut kontrak API,
invoice adalah konfirmasi booking, **bukan bukti pembayaran**.

### 4.2 Admin (role 1)

Dashboard admin (`AdminDashboard`) menampilkan jumlah destinasi/booking dan booking terbaru.
Menu yang tersedia untuk role 1 dan 2:

| Fitur | Implementasi |
| --- | --- |
| Tambah / tampilkan / ubah wisata | `POST/PATCH destinations`, `GET admin/destinations`, upload gambar multipart |
| Hapus wisata | `DELETE destinations/{guid}` — menurut kontrak API ini **menonaktifkan** (soft delete) |
| Data pendaftar (booking) | `GET admin/bookings`; setujui/tolak (`approve` / `reject`) dengan alasan opsional |
| Kelola kuota | `GET/PUT destinations/{guid}/quotas` |

### 4.3 Superadmin (role 2)

Selain seluruh fitur Admin, Superadmin memiliki menu tambahan (`canManageCategories`,
`canManageAdmins` di `lib/data/admin_state.dart` hanya `true` untuk role 2):

| Fitur | Implementasi |
| --- | --- |
| Kelola kategori | `GET admin/categories`, `POST/PATCH/DELETE categories` |
| Kelola admin | `GET admin/accounts`, `POST admin/accounts`, `PATCH admin/accounts/{guid}` (ubah role/status) |

### 4.4 Yang belum tersedia

- **Ubah Password** dan **Hapus Akun** di layar profil hanya menampilkan pesan
  *"Fitur ini belum tersedia untuk akun API."*
- Pengaturan **Notifikasi** dan **Bahasa** di profil adalah tampilan lokal tanpa pemanggilan API.
- Belum ada layar inbox notifikasi; membuka notifikasi tidak berpindah halaman.
- Belum ada payment gateway; pembayaran/refund tidak diimplementasikan di aplikasi.
- Belum ada penampil atau fitur bagikan PDF (lihat [Known Limitations](#15-known-limitations)).

## 5. Project Structure

```text
lib/
├── main.dart                    # Inisialisasi Firebase, FCM, restore sesi, MaterialApp, routing saat sesi berubah
├── firebase_options.dart        # Konfigurasi Firebase (hasil FlutterFire)
├── services/
│   ├── auth_session.dart        # JWT, login/register/google, refresh, restore, logout, secure storage,
│   │                            # transport HTTP, ApiException, upload multipart, unduh biner
│   ├── api_client.dart          # ApiClient (object/collection), ApiPage, RequestState
│   └── fcm_device_manager.dart  # Token FCM, registrasi/unregister perangkat ke Laravel
├── data/
│   ├── business_repository.dart # Seluruh pemanggilan endpoint bisnis + model API (Destination, Booking, Review, …)
│   ├── catalog_state.dart       # State katalog & kategori
│   ├── favorite_state.dart      # State favorit
│   ├── booking_state.dart       # State riwayat/detail booking, unduh & simpan dokumen
│   ├── booking_intent.dart      # Penyimpanan & rekonsiliasi intent booking (idempotensi)
│   ├── booking_errors.dart      # Pemetaan kode error booking ke pesan
│   ├── review_state.dart        # State review
│   ├── admin_state.dart         # Paginasi, guard aksi, keputusan booking, aturan akses per role
│   └── app_data.dart            # Model presentasi (User, Wisata, Pendaftar) dan `currentUser`
├── models/                      # Model presentasi (wisata.dart, pendaftaran.dart)
├── screens/                     # Layar user & admin
│   ├── session_destination.dart # Menentukan layar awal berdasarkan sesi & role
│   ├── user_login_screen.dart   # Login terpadu (user & admin); admin_login.dart hanya alias kompatibilitas
│   ├── main_navigation_screen.dart, beranda_user_screen.dart, cari_wisata_screen.dart,
│   │   detail_wisata_screen.dart, daftar_kunjungan_screen.dart, bukti_pendaftaran_screen.dart,
│   │   profil_user_screen.dart                      # alur user
│   └── admin_dashboard.dart, tambah_wisata_screen.dart, daftar_wisata_screen.dart,
│       daftar_pendaftar_screen.dart, kelola_kuota_screen.dart, kelola_kategori_screen.dart,
│       kelola_admin_screen.dart, admin_common.dart  # alur admin
├── widgets/                     # ApiImage, ReviewsSheet
└── theme/app_colors.dart

test/                            # Unit, kontrak repository, dan widget test (lihat bagian 12)
docs/                            # Dokumentasi migrasi Phase 1–6 dan kontrak API
android/                         # Proyek Android (Gradle Kotlin DSL)
assets/images/                   # Dua gambar aset lokal
```

## 6. Development Requirements

| Kebutuhan | Keterangan |
| --- | --- |
| Flutter SDK | Stable channel. Constraint Dart project: `>=3.0.0 <4.0.0`. Pengembangan terakhir dikonfirmasi dengan Flutter 3.44.4 / Dart 3.12.2 (hasil `flutter --version` di mesin pengembang). |
| Android Studio | Untuk Android SDK, AVD Manager, dan emulator. |
| Android SDK | Termasuk `platform-tools` (berisi `adb`). Versi `compileSdk`, `minSdk`, `targetSdk` mengikuti default Flutter SDK yang terpasang. |
| JDK | **Java 17** (project dikompilasi dengan `JavaVersion.VERSION_17`). JDK bawaan Android Studio umumnya sudah mencukupi. |
| Laravel Backend | Harus berjalan dan menyediakan `/api/v1`. Berada di repository terpisah. |
| Firebase | Konfigurasi Android untuk Google Sign-In & FCM (lihat bagian 7.4 dan 11). |
| Koneksi internet | Untuk mengunduh dependency Gradle/Pub dan untuk Firebase. |

## 7. Installation & Setup

Perintah di bawah ditulis untuk **Windows PowerShell**.

### 7.1 Clone dan dependency

```powershell
git clone https://github.com/koyotot/pami-wisata-daearahku.git
cd pami-wisata-daearahku
flutter doctor
flutter pub get
flutter devices
```

`flutter doctor` harus menunjukkan toolchain Flutter dan Android tanpa error. Jika lisensi
Android belum diterima:

```powershell
flutter doctor --android-licenses
```

### 7.2 File konfigurasi lokal Android

`android/local.properties` (berisi `flutter.sdk` dan `sdk.dir`) dibuat otomatis oleh Flutter /
Android Studio dan **tidak** ikut di-commit. Jika `settings.gradle.kts` melaporkan
`flutter.sdk not set in local.properties`, jalankan `flutter pub get` atau buka folder `android/`
sekali di Android Studio.

### 7.3 Menyiapkan Laravel Backend

Jalankan backend Laravel dari repository-nya (ikuti README backend tersebut: dependency,
`.env`, migrasi database, dan `php artisan serve` atau Laragon). Pastikan endpoint berikut
merespons sebelum menjalankan aplikasi:

```text
<BASE_URL>/auth/login      (POST)
<BASE_URL>/destinations    (GET)
```

dengan `<BASE_URL>` berakhiran `/api/v1`. Cara menghubungkan emulator ke backend lokal ada di
[bagian 9](#9-connecting-flutter-to-local-laravel-api).

### 7.4 Konfigurasi Firebase

Repository ini sudah menyertakan konfigurasi Firebase klien untuk project Firebase yang ada:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`

Catatan penting:

- File di atas adalah konfigurasi klien (bukan service account / secret server). **Jangan
  pernah** meng-commit service account, private key, atau kredensial Firebase Admin.
- Jika Anda memakai **project Firebase sendiri**, buat ulang konfigurasi dengan FlutterFire CLI
  (`dart pub global activate flutterfire_cli`, lalu `flutterfire configure`) dan pastikan
  *package name* Android sama dengan `applicationId` (`id.wisatadaerahku.app`).
- **Google Sign-In** memerlukan provider Google aktif di Firebase Authentication dan sidik jari
  **SHA-1 / SHA-256** keystore yang dipakai build (debug keystore untuk pengembangan) terdaftar
  di aplikasi Android pada Firebase Console.
- Laravel harus dikonfigurasi memverifikasi ID token dari **project Firebase yang sama**,
  dan FCM server-side pada Laravel harus memakai kredensial project yang sama. Konfigurasi
  sisi backend tersebut tidak diverifikasi dari repository ini.

### 7.5 Menjalankan aplikasi

Lanjutkan ke [bagian 8](#8-running-android-emulator) dan [bagian 9](#9-connecting-flutter-to-local-laravel-api).

## 8. Running Android Emulator

Panduan khusus **Windows 10/11 + Android Studio**.

### 8.1 Membuat dan menjalankan emulator

1. Buka Android Studio → **Device Manager** → *Create Device* (misalnya Pixel dengan system
   image yang berisi Google Play / Google APIs, agar Google Sign-In dapat berjalan).
2. Cek emulator yang tersedia dan jalankan:

```powershell
flutter emulators
flutter emulators --launch <EMULATOR_ID>
flutter devices
adb devices
```

`<EMULATOR_ID>` adalah kolom **Id** pada keluaran `flutter emulators`. Contoh keluaran pada mesin
pengembang saat README ini diperiksa:

```text
Id      • Name    • Manufacturer • Platform
Pixel_7 • Pixel 7 • Google       • android
```

sehingga perintahnya `flutter emulators --launch Pixel_7`. ID Anda bisa berbeda.

### 8.2 Menemukan Device ID yang sebenarnya

`<EMULATOR_ID>` (nama AVD) **berbeda** dengan `<DEVICE_ID>` yang dipakai `flutter run -d`.
Setelah emulator menyala, ambil Device ID dari kolom kedua `flutter devices`, atau dari kolom
pertama `adb devices`. Bentuk umumnya `emulator-5554` (angka port bisa berbeda):

```text
List of devices attached
emulator-5554   device
```

Status harus `device`. Status `offline` atau `unauthorized` berarti emulator belum siap.

### 8.3 Jika `adb` tidak dikenali

Pada pemeriksaan README ini, `adb` tidak ada di `PATH` shell, tetapi ada di lokasi SDK default
`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. Tambahkan ke PATH untuk sesi PowerShell
saat ini:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
adb version
```

Agar permanen, tambahkan folder tersebut ke *Environment Variables → Path* Windows. Jika SDK
Anda berada di lokasi lain, gunakan path *Android SDK Location* dari Android Studio
(Settings → Languages & Frameworks → Android SDK), dan arahkan Flutter ke sana bila perlu:

```powershell
flutter config --android-sdk "<PATH_ANDROID_SDK>"
```

## 9. Connecting Flutter to Local Laravel API

### 9.1 Cara aplikasi membaca `API_BASE_URL`

Base URL dibaca sekali di `AuthSession` melalui:

```dart
const String.fromEnvironment('API_BASE_URL')
```

sehingga **wajib** diberikan lewat `--dart-define`. Tidak ada nilai default. Hal yang diverifikasi dari
`lib/services/auth_session.dart`:

- Nilai harus berupa URL dengan skema `http` atau `https`.
- Path endpoint ditambahkan langsung setelah base URL (`<API_BASE_URL>/auth/login`,
  dst.), jadi **`API_BASE_URL` harus sudah memuat `/api/v1`**. Garis miring di akhir diabaikan.
- Pada **build release**, skema selain `https` ditolak
  (`Konfigurasi API_BASE_URL belum valid. Gunakan HTTPS untuk rilis.`). `http` hanya diterima
  pada mode debug.
- Bila `API_BASE_URL` kosong atau tidak valid, semua request gagal dengan pesan konfigurasi tersebut.

### 9.2 Opsi A — `adb reverse` (direkomendasikan)

`adb reverse` membuat `127.0.0.1:<port>` di emulator menunjuk ke `127.0.0.1:<port>` di PC.

Jalankan Laravel di port 8000:

```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

Lalu, dari terminal lain:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Format URL di atas sudah sesuai dengan cara kode membaca `API_BASE_URL` (memuat `/api/v1`).

> `adb reverse` hilang bila emulator/ADB di-restart. Jalankan ulang bila koneksi terputus.

### 9.3 Opsi B — Laragon pada `127.0.0.1:8080` (virtual host)

`AuthSession._headers` memiliki penanganan khusus **hanya pada mode debug**: bila host
`127.0.0.1` dan port `8080`, request mengirim header `Host: pami-wisata-daerahku-api.test`
agar Laragon memilih virtual host yang benar. Contoh:

```powershell
adb reverse tcp:8080 tcp:8080
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

Ini hanya berlaku bila virtual host Laragon Anda bernama `pami-wisata-daerahku-api.test`.
Jika berbeda, header tersebut perlu disesuaikan di kode (di luar cakupan README ini).

### 9.4 Opsi C — `10.0.2.2` (alamat host dari Android Emulator)

Emulator Android dapat mengakses PC lewat `10.0.2.2`:

```powershell
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Server harus listen di alamat yang dapat dijangkau emulator. `php artisan serve --host=127.0.0.1`
**tidak** dapat dijangkau lewat `10.0.2.2`; gunakan `--host=0.0.0.0` (dan perhatikan firewall
Windows). Header `Host` khusus Laragon (opsi B) **tidak** ditambahkan untuk `10.0.2.2`.
Untuk perangkat fisik, gunakan IP LAN PC atau `adb reverse`.

### 9.5 Cleartext HTTP

Lalu lintas `http://` hanya diizinkan pada build **debug**: `android:usesCleartextTraffic="true"`
terdapat di `android/app/src/debug/AndroidManifest.xml`, **tidak** di manifest `main` maupun
`profile`. Build release hanya menerima HTTPS (baik di sisi Android maupun validasi `AuthSession`).

## 10. Authentication & Session Management

Seluruh logika berada di `lib/services/auth_session.dart` (singleton `AuthSession.instance`).

### 10.1 Login terpadu (unified login)

Satu layar, `UserLoginScreen`, dipakai semua role. Role **tidak dipilih** pengguna; role dibaca
dari respons `GET auth/me`. `AdminLogin` hanya subclass kompatibilitas dari `UserLoginScreen`.

### 10.2 Email / password

`login` → `POST auth/login`; `register` → `POST auth/register` (`name`, `email`, `password`,
`password_confirmation`). Server mengembalikan `access_token`, `refresh_token`, dan `user`.
Setelah token disimpan, aplikasi memanggil `GET auth/me` untuk memvalidasi identitas.

### 10.3 Google Sign-In melalui Firebase

1. `FirebaseAuth.signInWithProvider(GoogleAuthProvider())` → memperoleh Firebase ID token.
2. `POST auth/google {id_token}` ke Laravel.
3. Hasilnya diproses seperti login biasa, dengan `allowedRoles = {0}`.
4. Firebase `signOut()` selalu dijalankan di blok `finally`.

Google Login **hanya untuk role 0**. Bila hasil `auth/me` adalah role 1/2, sesi dibersihkan,
token Laravel yang telah terbit dicabut (`POST auth/logout`, best effort), dan pengguna melihat
pesan bahwa admin wajib masuk dengan email dan password. Pembatasan serupa juga didokumentasikan
sebagai ditegakkan oleh backend (`docs/phase6_firebase_cleanup.md`); penegakan di backend perlu
dikonfirmasi pada repository Laravel.

### 10.4 Validasi identitas

`auth/me` diterima hanya bila `guid` tidak kosong, `name` & `email` berupa string, `role` ∈ {0,1,2},
dan `status == 'active'`. Selain itu sesi ditolak (`403`) dan dibersihkan.

### 10.5 JWT, refresh token, dan secure storage

- Access token dikirim sebagai `Authorization: Bearer <token>`.
- Kedua token (access & refresh) disimpan bersama dalam satu nilai di `flutter_secure_storage`
  dengan key `laravel_session`.
- Bila request terautentikasi menerima **401**, `AuthSession` memanggil `POST auth/refresh`
  sekali (permintaan refresh bersamaan digabung), menyimpan token baru, lalu mengulang request
  satu kali. Bila refresh gagal atau ulangan tetap 401, sesi dibersihkan dan pengguna kembali
  ke layar login.
- Setiap perubahan akun menaikkan *session generation*; respons terlambat dari sesi lama
  dibuang sehingga tidak bocor ke akun berikutnya.

### 10.6 Session restoration

Pada `main()`, urutannya: `Firebase.initializeApp` → `FcmDeviceManager.attach()` →
`AuthSession.instance.restore()` → `runApp`. `restore()` membaca token dari secure storage dan
memvalidasi lewat `GET auth/me`. Bila gagal, penyimpanan dibersihkan dan aplikasi membuka
layar login.

### 10.7 Role-based navigation

`sessionDestination()` (`lib/screens/session_destination.dart`):

| Kondisi | Tujuan |
| --- | --- |
| Belum login / perangkat belum siap | `UserLoginScreen` |
| Role `0` | `MainNavigationScreen` (beranda user) |
| Role `1` atau `2` | `AdminDashboard` |
| Lainnya | `UserLoginScreen` |

Menu Kelola Kategori dan Kelola Admin hanya muncul untuk role 2. `main.dart` memantau
perubahan sesi dan otomatis mengarahkan ulang ke login atau tujuan baru.

### 10.8 Logout

`logout()` mencabut registrasi FCM perangkat, memanggil `POST auth/logout`, dan membersihkan token
di memori serta secure storage (dalam `finally`, sehingga sesi lokal tetap dihapus walau panggilan
server gagal). Layar profil lalu memanggil `FirebaseAuth.signOut()` dan kembali ke login.

## 11. Firebase Integration

Firebase masih dipertahankan karena dua kebutuhan yang tidak digantikan Laravel:

| Layanan Firebase | Dipakai untuk | Batas tanggung jawab |
| --- | --- | --- |
| **Firebase Authentication** | Memperoleh Google ID token pada Google Sign-In | Hanya identitas perantara. Laravel yang memverifikasi token, menentukan role, dan menerbitkan JWT. Firebase UID bukan GUID Laravel. |
| **Firebase Cloud Messaging** | Menerima push notification | Token FCM didaftarkan ke Laravel (`PUT/DELETE devices`); Laravel yang mengirim pesan. Pesan bersifat *data-only* dan belum ada layar inbox. |
| ~~Cloud Firestore~~ | — | **Tidak dipakai.** Data bisnis ada di Laravel + MySQL. |
| ~~Firebase Storage~~ | — | **Tidak dipakai.** Gambar destinasi disajikan Laravel dan dimuat lewat `ApiImage`. |

Kegagalan FCM tidak menghalangi login maupun startup aplikasi (error diabaikan secara sengaja
di `FcmDeviceManager`). Izin notifikasi Android (`POST_NOTIFICATIONS`) diminta saat aplikasi mulai.

Data historis Firebase (mis. koleksi pengguna, wisata, pendaftar, ulasan lama) **tidak
dimigrasikan** ke Laravel (lihat `docs/phase6_firebase_cleanup.md`).

## 12. Testing & Quality Assurance

### 12.1 Perintah

```powershell
flutter test
flutter analyze
```

Satu file saja:

```powershell
flutter test test/auth_session_test.dart
```

Folder `test/` berisi pengujian untuk fondasi API, sesi & token (`auth_session_test.dart`,
`session_transport_test.dart`), routing terpadu, katalog, favorit, booking & intent, alur admin,
review (termasuk widget test), dan `phase6_live_api_test.dart`. Tes `phase6_live_api_test.dart`
adalah tes *live* yang membutuhkan backend nyata dan bersifat opt-in; lihat isi file tersebut
sebelum menjalankannya.

### 12.2 Status hasil

README ini **tidak** menyatakan hasil `flutter test` atau `flutter analyze` terbaru karena
keduanya tidak dijalankan saat dokumen ini disusun. Sebagai catatan historis,
`docs/phase6_firebase_cleanup.md` (30 Oktober 2026) mencatat `flutter analyze` berakhir dengan
exit code 1 karena lint lama: 0 error, 4 warning, 176 info; tidak ada error kompilasi. Jalankan ulang
di mesin Anda untuk status terkini.

### 12.3 Manual testing dengan Android Emulator

1. Jalankan Laravel dan sambungkan emulator ([bagian 9](#9-connecting-flutter-to-local-laravel-api)).
2. `flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=…`
3. Uji alur berikut:
   - **User:** registrasi/login → cari & filter → detail → favorit → booking → riwayat →
     batalkan (saat `pending_approval`) → unduh tiket/invoice → check-in → ulasan → edit profil → logout.
   - **Admin:** login email/password → dashboard → tambah/ubah wisata (+ gambar) → atur kuota →
     setujui/tolak booking.
   - **Superadmin:** kelola kategori dan kelola admin.
   - **Sesi:** tutup aplikasi lalu buka lagi (sesi harus pulih); logout lalu login akun lain
     (data akun sebelumnya tidak boleh tampil).
   - **Google Login:** coba dengan akun user; akun admin harus ditolak.
4. Gunakan *hot reload* (`r`) atau *hot restart* (`R`) di terminal `flutter run`.

Catatan: Google Sign-In dan FCM sebaiknya diuji juga di perangkat fisik atau emulator dengan
Google Play services, karena bergantung pada layanan eksternal.

## 13. Build Android

### 13.1 Build debug / pengujian

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Hasil: `build\app\outputs\flutter-apk\app-debug.apk`.

### 13.2 Build release

```powershell
flutter build apk --dart-define=API_BASE_URL=https://<DOMAIN_API>/api/v1
flutter build appbundle --dart-define=API_BASE_URL=https://<DOMAIN_API>/api/v1
```

Hasil: `build\app\outputs\flutter-apk\app-release.apk` dan
`build\app\outputs\bundle\release\app-release.aab`.

Hal yang terverifikasi dari konfigurasi:

- `API_BASE_URL` **wajib HTTPS** untuk release; nilai diambil saat compile (`--dart-define`).
- Versi aplikasi mengikuti `version: 1.0.0+1` di `pubspec.yaml` (`versionName` = `1.0.0`,
  `versionCode` = `1`).
- `applicationId` adalah `id.wisatadaerahku.app`.

### 13.3 Signing — belum siap rilis

`android/app/build.gradle.kts` saat ini mengatur build `release` memakai
`signingConfigs.getByName("debug")`. Artinya APK/AAB release **masih ditandatangani dengan
debug key** dan **belum layak diunggah ke Google Play**. Sebelum rilis sebenarnya:

1. Buat upload keystore dan konfigurasi `signingConfigs.release` (mis. via `android/key.properties`;
   `key.properties`, `*.keystore`, dan `*.jks` sudah ada di `android/.gitignore`).
2. Daftarkan SHA-1/SHA-256 keystore rilis di Firebase agar Google Sign-In berfungsi.
3. Jangan meng-commit keystore atau password.

Selain itu `namespace` Gradle masih `com.example.wisata_daerahku` (berbeda dari `applicationId`).

## 14. Troubleshooting

| Masalah | Penyebab umum | Solusi |
| --- | --- | --- |
| **Emulator tidak terdeteksi** | Emulator belum selesai boot, atau ADB mati | `flutter emulators` → `flutter emulators --launch <EMULATOR_ID>` → tunggu sampai home screen → `flutter devices`. Bila tetap kosong: `adb kill-server` lalu `adb start-server`. |
| **`adb` tidak dikenali** | `platform-tools` tidak ada di PATH | Lihat [8.3](#83-jika-adb-tidak-dikenali). |
| **Android SDK / lisensi bermasalah** | SDK tidak lengkap atau lisensi belum diterima | `flutter doctor -v`, lalu `flutter doctor --android-licenses`. Set `flutter config --android-sdk "<PATH>"` bila perlu. |
| **`flutter.sdk not set in local.properties`** | `android/local.properties` belum ada | Jalankan `flutter pub get` atau buka proyek di Android Studio. |
| **Build Gradle gagal terkait Java** | JDK bukan versi 17 | Pastikan `java -version` menunjukkan 17, atau arahkan Flutter ke JDK Android Studio: `flutter config --jdk-dir "<PATH_JDK>"`. |
| **Pesan "Konfigurasi API_BASE_URL belum valid"** | `--dart-define=API_BASE_URL` tidak diberikan / bukan URL valid / `http` pada build release | Berikan URL lengkap termasuk `/api/v1`. Untuk release gunakan HTTPS. Setelah mengubah `--dart-define`, jalankan ulang (bukan hot reload). |
| **"Tidak dapat terhubung ke layanan"** | Backend tidak berjalan, port salah, atau emulator tidak bisa menjangkau host | Pastikan Laravel hidup dan dapat dibuka dari browser PC. Untuk `127.0.0.1` jalankan `adb reverse`; untuk `10.0.2.2` jalankan server dengan `--host=0.0.0.0`. |
| **"Koneksi habis waktu"** | Timeout 20 detik terlampaui | Periksa backend lambat/macet, firewall Windows, atau jaringan. |
| **`localhost` / `127.0.0.1` gagal di emulator** | Di emulator, `127.0.0.1` adalah emulator itu sendiri | Gunakan `adb reverse` ([9.2](#92-opsi-a--adb-reverse-direkomendasikan)) atau `10.0.2.2`. |
| **Laravel via Laragon port 8080 menampilkan situs lain / 404** | Virtual host tidak cocok | Gunakan opsi [9.3](#93-opsi-b--laragon-pada-1270018080-virtual-host) dengan virtual host `pami-wisata-daerahku-api.test`, atau pakai `php artisan serve` pada port 8000. |
| **Cleartext HTTP not permitted** | Menjalankan build release/non-debug dengan URL `http://` | Gunakan build debug untuk HTTP lokal ([9.5](#95-cleartext-http)), atau HTTPS. |
| **Sesi berakhir terus / kembali ke login** | Access token kedaluwarsa dan refresh token tidak valid (kedaluwarsa, dicabut, role/status akun diubah backend) | Login ulang. Bila berulang, periksa `POST auth/refresh` di backend dan pastikan jam PC/emulator wajar. |
| **Akun nonaktif / "Akun tidak aktif…"** | `status` bukan `active` atau role di luar 0–2 | Aktifkan akun dari sisi backend / Superadmin. |
| **Google Sign-In gagal** | SHA-1/SHA-256 belum terdaftar, provider Google belum aktif, `google-services.json`/`firebase_options.dart` tidak cocok dengan project, atau emulator tanpa Google Play services | Daftarkan sidik jari keystore, aktifkan provider Google, perbarui konfigurasi via `flutterfire configure`, dan gunakan emulator dengan Google APIs/Play. Pembatalan oleh pengguna tidak menampilkan error. |
| **Google Login ditolak untuk admin** | Perilaku yang disengaja | Admin/Superadmin harus login dengan email dan password. |
| **Firebase/FCM tidak terinisialisasi** | Konfigurasi Firebase tidak sesuai atau Google Play services tidak ada | Periksa `firebase_options.dart` dan `google-services.json`, jalankan `flutter clean` lalu `flutter pub get`. Kegagalan FCM tidak menghalangi login, tetapi push tidak akan diterima. |
| **Push tidak muncul** | Izin notifikasi ditolak, token belum terdaftar, atau Laravel tidak mengirim | Izinkan notifikasi di pengaturan Android, cek `PUT devices` berhasil, dan cek konfigurasi FCM di backend. Pesan data-only tidak menampilkan notifikasi sistem. |
| **Dependency / build cache aneh** | Cache lama | `flutter clean` lalu `flutter pub get`. |

## 15. Known Limitations

Berdasarkan kode dan dokumentasi repository:

- **Release signing** masih memakai debug key; belum siap publikasi Play Store (bagian 13.3).
- **Tidak ada payment gateway.** Status seperti `awaiting_payment` tidak berarti sudah dibayar;
  invoice adalah konfirmasi booking, bukan bukti pembayaran. Pembatalan hanya untuk
  `pending_approval`; kebijakan pembayaran/refund belum tersedia.
- **Tidak ada QR resmi** pada tiket; QR lokal lama telah dihapus.
- **PDF** (tiket/invoice) hanya disimpan ke direktori sementara dan path ditampilkan; belum ada
  penampil/bagikan, dan OS dapat menghapus file tersebut.
- **Ubah Password dan Hapus Akun** belum tersedia. Pengaturan Notifikasi/Bahasa hanya UI lokal.
- **Belum ada inbox notifikasi;** push bersifat data-only dengan SnackBar saat foreground.
- **Hanya Android** yang dikonfigurasi/diuji untuk FCM dan registrasi perangkat. Folder platform
  lain (`ios/`, `web/`, `windows/`, dst.) ada karena template Flutter, tetapi tidak diverifikasi.
- **Sesi hasil restore tidak membedakan** login Google dan password; penegakan "Google hanya role 0"
  pada exchange token bergantung pada backend.
- **Header `Host` khusus Laragon** di-hardcode pada mode debug untuk `127.0.0.1:8080`.
- **Data historis Firebase** tidak dimigrasikan; tidak ada pemetaan Firebase UID → GUID Laravel.
- **Belum diverifikasi** (menurut dokumentasi Phase 6): Google ID token nyata, push FCM nyata,
  perangkat fisik/iOS, serta lingkungan staging/produksi. Tidak ada klaim *production-ready*.
- **Backend Laravel** harus tersedia dan terkonfigurasi (database, JWT, kredensial Firebase untuk
  verifikasi token dan pengiriman FCM). Aplikasi tidak dapat berfungsi tanpanya.
- **Lint lama:** `flutter analyze` memiliki temuan lama non-error (lihat 12.2).
- Beberapa kalimat di dokumen migrasi lama sudah kedaluwarsa (lihat bagian 16).

## 16. Dokumentasi Lain di Repository

| File | Isi |
| --- | --- |
| `docs/phase1_api_migration.md` | Fondasi API Phase 1 |
| `docs/phase3_favorites_migration.md` | Migrasi favorit |
| `docs/phase4_booking_migration.md` | Migrasi booking |
| `docs/phase5_admin_migration.md` | Migrasi alur admin |
| `docs/phase5_unified_auth.md` | Autentikasi terpadu (**sebagian kedaluwarsa**: pernyataan *SECURITY BLOCKER* Google admin dan sisa dependensi Firestore sudah digantikan Phase 6) |
| `docs/phase6_firebase_cleanup.md` | Pembersihan Firebase, kontrak check-in/review/statistik, inventaris data historis |
| `docs/api_contract_phase4_5.md` | Kontrak API Phase 4–5 (kode error 409, status booking, endpoint admin) |
| `docs/DESIGN.md`, `docs/prd/` | Desain dan PRD |

Jika terjadi perbedaan antara dokumen di atas dan source code, **source code adalah acuan utama**.
