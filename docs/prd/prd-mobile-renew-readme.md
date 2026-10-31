# Task: Update README.md — Wisata Daerahku Flutter Mobile

Lakukan audit menyeluruh terhadap repository Flutter Wisata Daerahku dan perbarui file `README.md` agar sesuai dengan kondisi aplikasi terbaru setelah migrasi Firebase → Laravel Phase 1–6 selesai.

Repository:
`https://github.com/koyotot/pami-wisata-daearahku`

Local development path:
`C:\laragon\www\pami-mobile\pami-wisata-daearahku`

## Instruksi Utama

1. Audit struktur Flutter, dependency, authentication, networking, repository layer, state management, serta fitur pengguna dan admin.
2. Periksa `pubspec.yaml`, konfigurasi Android, `lib/`, `test/`, dan dokumentasi migrasi.
3. Gunakan source code aktual sebagai *single source of truth*.
4. Jangan menyalin dokumentasi Firebase lama yang sudah tidak relevan.
5. Jangan menganggap sebuah fitur tersedia hanya berdasarkan dokumentasi sebelumnya.
6. Dokumentasi harus menggunakan **Bahasa Indonesia profesional** dan mudah dipahami developer baru.
7. Fokus hanya pada `README.md`. Jangan mengubah kode Dart, UI/UX, asset, konfigurasi Firebase, dependency, maupun source code lain.
8. Jangan melakukan commit Git.

## Konteks Project

Wisata Daerahku merupakan aplikasi Flutter untuk pengguna wisata dan administrator.

Setelah migrasi Phase 1–6:

- Data bisnis utama sudah menggunakan Laravel REST API.
- Authentication email/password ditangani Laravel.
- JWT access/refresh token digunakan untuk sesi aplikasi.
- Google Sign-In tetap menggunakan Firebase Authentication, kemudian dilakukan token exchange dengan Laravel.
- Firebase Cloud Messaging tetap digunakan untuk push notification.
- Firestore dan Firebase Storage tidak lagi digunakan untuk penyimpanan data bisnis.
- Role User, Admin, dan Superadmin berasal dari backend Laravel.
- Pengguna dan admin menggunakan unified login flow.
- Google Login hanya diperbolehkan bagi user sesuai aturan backend.
- Katalog, favorites, booking, profile, review, check-in, dan dokumen menggunakan API Laravel.
- Tiket PDF berasal dari backend Laravel.

Verifikasi seluruh konteks tersebut terhadap source code sebelum memasukkannya ke README.

## Struktur README.md

### 1. Project Overview
Jelaskan tujuan aplikasi Wisata Daerahku, pengguna yang dilayani, dan hubungannya dengan Laravel Backend.

### 2. Technology Stack
Dokumentasikan Flutter, Dart, Android SDK, Firebase Authentication, Firebase Cloud Messaging, HTTP client, secure storage, dan package penting lainnya berdasarkan `pubspec.yaml`.

### 3. Application Architecture
Jelaskan alur:

Flutter Application → Laravel REST API → MySQL.

Jelaskan juga secara terpisah:
- Google Sign-In → Firebase Authentication → Laravel token exchange.
- Laravel → Firebase Cloud Messaging → Flutter device.

Tegaskan bahwa Firebase tidak lagi menjadi database bisnis aplikasi.

### 4. Application Features
Kelompokkan fitur berdasarkan role:

- User.
- Admin.
- Superadmin, jika terdapat implementasi khusus.

Dokumentasikan katalog, pencarian, filter, favorites, booking, riwayat, profil, review, check-in, tiket PDF, dan fitur lainnya berdasarkan implementasi nyata.

### 5. Project Structure
Jelaskan struktur aktual folder `lib/` dan tanggung jawab masing-masing bagian penting, termasuk networking, repositories, models, screens, services, dan session management apabila tersedia.

### 6. Development Requirements
Cantumkan kebutuhan berdasarkan konfigurasi project:

- Flutter SDK.
- Dart SDK.
- Android Studio.
- Android SDK dan Emulator.
- Java/JDK jika relevan.
- Laravel Backend yang berjalan.
- Firebase configuration yang diperlukan untuk Google Sign-In dan FCM.

Hindari mencantumkan versi yang tidak diverifikasi.

### 7. Installation & Setup
Berikan panduan dari fresh clone hingga Flutter dapat dijalankan, termasuk:

```powershell
flutter doctor
flutter pub get
flutter devices
```

Jelaskan konfigurasi Firebase yang diperlukan dan cara menghubungkan Flutter dengan backend Laravel.

### 8. Running Android Emulator

Dokumentasikan petunjuk khusus Windows 10 + Android Studio, termasuk:

```powershell
flutter emulators
flutter emulators --launch <EMULATOR_ID>
flutter devices
adb devices
```

Jelaskan cara menemukan device ID yang sebenarnya.

### 9. Connecting Flutter to Local Laravel API

Berikan contoh koneksi menggunakan `adb reverse`:

```powershell
adb reverse tcp:8000 tcp:8000
```

Kemudian contoh menjalankan Flutter:

```powershell
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Periksa terlebih dahulu implementasi pembacaan `API_BASE_URL` untuk memastikan format URL tersebut benar.

Jelaskan juga opsi `10.0.2.2` untuk Android Emulator dan kebutuhan konfigurasi cleartext HTTP khusus debug jika relevan.

### 10. Authentication & Session Management
Dokumentasikan:

- Email/password login.
- Google Sign-In melalui Firebase.
- Laravel JWT.
- Refresh token dan session restoration.
- Secure token storage.
- Logout.
- Role-based navigation.
- Unified login.

Sertakan penjelasan berdasarkan alur dan kode aktual.

### 11. Firebase Integration
Jelaskan mengapa Firebase masih digunakan dan batas tanggung jawabnya.

Bedakan dengan jelas antara Firebase Authentication, Firebase Cloud Messaging, dan data bisnis yang sudah menggunakan Laravel.

### 12. Testing & Quality Assurance
Dokumentasikan command yang sesuai dengan project:

```powershell
flutter test
flutter analyze
```

Jelaskan juga cara manual testing menggunakan Android Emulator.

Jangan menyatakan hasil pengujian terbaru jika tidak diverifikasi. Jika ada lint existing, jelaskan secara proporsional berdasarkan bukti repository.

### 13. Build Android
Berikan petunjuk build APK dan Android App Bundle berdasarkan konfigurasi aktual, termasuk:

```powershell
flutter build apk
flutter build appbundle
```

Jelaskan konfigurasi build environment, signing, dan kebutuhan rilis hanya sejauh terverifikasi.

### 14. Troubleshooting
Tambahkan masalah development umum yang relevan:

- Emulator tidak terdeteksi.
- Android SDK atau ADB bermasalah.
- API Laravel tidak dapat diakses.
- Kegagalan koneksi ke localhost.
- HTTP cleartext tidak diizinkan.
- JWT expired atau gagal refresh.
- Google Sign-In gagal.
- Firebase/FCM tidak terinisialisasi.
- Laravel backend tidak berjalan.

Berikan solusi yang didukung konfigurasi aktual.

### 15. Known Limitations
Dokumentasikan keterbatasan, fitur belum terverifikasi, dan persyaratan layanan eksternal secara akurat.

## Ketentuan Penting

- README harus dapat digunakan developer baru tanpa bergantung pada pengetahuan dari percakapan sebelumnya.
- Pastikan command PowerShell valid.
- Jangan expose secrets, token, maupun konfigurasi Firebase yang bersifat privat.
- Jangan mengubah UI/UX existing.
- Jangan menambahkan Firebase Firestore/Storage sebagai dependency bisnis.
- Jangan mengklaim payment gateway atau fitur production-ready tanpa bukti implementasi.
- Jangan mengubah hasil migrasi Phase 1–6.
- Hindari dokumentasi generik yang tidak sesuai dengan project.

## Expected Output

Perbarui `README.md` langsung dalam repository Flutter.

Setelah selesai, berikan laporan singkat mengenai:
- Bagian README yang diperbarui.
- Penjelasan perubahan arsitektur Firebase → Laravel.
- Command development dan emulator yang telah diverifikasi terhadap repository.
- Informasi yang masih membutuhkan konfigurasi atau verifikasi manual.

Scope hanya dokumentasi. Tidak perlu commit, screenshot, redesign, refactoring, maupun menjalankan keseluruhan test suite.