# PRD — Konfigurasi Environment Flutter Wisata Daerahku

## 1. Ringkasan

Implementasikan konfigurasi environment yang terpusat untuk aplikasi mobile Flutter **Wisata Daerahku** agar URL backend Laravel dapat ditentukan melalui file environment saat perintah `flutter run` atau `flutter build` dijalankan, tanpa perlu mengganti kode Dart secara manual. Gunakan mekanisme bawaan Flutter `--dart-define-from-file` dan `const String.fromEnvironment`.

**Scope:** Flutter mobile saja. Backend Laravel dan business logic yang sudah berjalan tidak boleh diubah.

## 2. Kondisi Proyek Saat Ini

- Nama package di `pubspec.yaml`: `wisata_daerahku`.
- Project menggunakan `http`, `flutter_secure_storage`, Firebase Auth (untuk Google), Firebase Messaging (FCM), serta Laravel REST API.
- `ApiClient` merupakan pembungkus request/response dan mendelegasikan request ke `AuthSession.requestEnvelope()` atau `AuthSession.publicEnvelope()`.
- Lokasi sesungguhnya penyusunan base URL perlu diverifikasi di source, terutama `auth_session.dart` dan helper HTTP terkait. **Jangan berasumsi bahwa URL disusun dalam `api_client.dart`.**
- Session JWT, refresh rotation, request generation guard, login, booking, catalog, profile, admin, dan integrasi Firebase yang masih dipakai harus tetap berfungsi.

## 3. Tujuan

1. Memisahkan konfigurasi **local**, **development**, dan **production**.
2. Menyediakan satu sumber kebenaran melalui `AppConfig` untuk `APP_ENV` dan `API_BASE_URL`.
3. Memastikan seluruh request Laravel memakai endpoint sesuai environment yang dipilih saat build.
4. Menghindari penambahan dependency atau pendaftaran `.env` sebagai Flutter asset.
5. Mencegah build production menggunakan endpoint localhost atau URL placeholder tanpa sengaja.

## 4. Struktur File Target

```text
pami-wisata-daearahku/
├── .env
├── .env.development
├── .env.production
├── .env.example
├── .gitignore
├── pubspec.yaml
└── lib/
    └── core/
        └── config/
            └── app_config.dart
```

Jika project sudah punya lokasi kelas konfigurasi yang setara, adaptasikan struktur existing alih-alih menciptakan duplikasi.

## 5. Spesifikasi Environment

### `.env` — local

```dotenv
APP_ENV=local
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

### `.env.development` — development emulator

```dotenv
APP_ENV=development
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

### `.env.production` — production

```dotenv
APP_ENV=production
API_BASE_URL=https://YOUR-PRODUCTION-API-DOMAIN/api/v1
```

**Penting:** URL production di atas hanyalah placeholder. **Wajib diganti dengan URL Laravel production yang sebenarnya sebelum rilis**. Jangan mengasumsikan domain Dokumen-Kita merupakan domain API Wisata Daerahku.

### `.env.example`

```dotenv
APP_ENV=development
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Gunakan key yang sama di semua environment. Jangan menaruh JWT secret, `APP_KEY` Laravel, password database, credential server, ataupun data rahasia lainnya dalam file konfigurasi yang dikompilasi ke aplikasi.

## 6. AppConfig — Pusat Konfigurasi

Buat `lib/core/config/app_config.dart` dengan desain sederhana, tanpa state runtime dan tanpa package tambahan.

Contoh kontrak (boleh disesuaikan dengan gaya source existing):

```dart
class AppConfig {
  AppConfig._();

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get isProduction => appEnv == 'production';
  static bool get isDevelopment =>
      appEnv == 'development' || appEnv == 'local';

  static void validate() {
    if (!{'local', 'development', 'production'}.contains(appEnv)) {
      throw StateError('APP_ENV tidak valid atau belum diatur.');
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL tidak valid atau belum diatur.');
    }

    if (isProduction &&
        (uri.scheme != 'https' ||
            uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == 'YOUR-PRODUCTION-API-DOMAIN')) {
      throw StateError('API_BASE_URL production harus HTTPS dan bukan localhost/placeholder.');
    }
  }
}
```

Aturan implementasi:
- Pastikan nilai diambil menggunakan **`const ...fromEnvironment`**, karena sifatnya compile-time.
- Panggil validasi dari bootstrap aplikasi di titik yang aman dan jelas sebelum request API pertama; pertahankan urutan inisialisasi Firebase dan session yang sudah ada.
- Perubahan file `.env` perlu **run/build ulang** agar nilai compile-time berubah; hot reload saja tidak cukup.
- Normalisasi slash URL hanya jika dibutuhkan oleh kode existing; hindari merusak penggabungan path endpoint.
- **Jangan menambahkan fallback localhost** untuk production jika `API_BASE_URL` tidak disediakan.

## 7. Integrasi ke Existing Networking

1. Audit alur `ApiClient` → `AuthSession` → HTTP layer untuk menemukan lokasi base URL yang benar.
2. Ganti pembacaan `API_BASE_URL` yang tersebar menjadi referensi ke `AppConfig.apiBaseUrl`, **tanpa mengubah signature publik, auth flow, atau kontrak response**.
3. Pertahankan `ApiClient.object()`, `ApiClient.collection()`, `_request()`, `RequestState`, dan pengecekan `sessionGeneration` yang sudah ada.
4. Pertahankan mekanisme token bearer, refresh, logout, public/authenticated endpoint, exception handling, dan timeouts existing.
5. Bila constructor atau test menyediakan override URL, **pertahankan injection/override tersebut** agar kompatibilitas tidak rusak.
6. Hapus import `AppConfig` dari `api_client.dart` jika tidak digunakan setelah integrasi; import hanya di file yang memang membaca konfigurasi.
7. Cari seluruh URL Laravel yang di-hardcode atau pembacaan `String.fromEnvironment('API_BASE_URL')` di source, lalu konsolidasikan dengan tetap menghormati konfigurasi Firebase dan layanan pihak ketiga yang berbeda.

## 8. `pubspec.yaml` dan `.gitignore`

- **Jangan** menambah dependency `flutter_dotenv`.
- **Jangan** menambahkan `.env`, `.env.development`, atau `.env.production` ke `flutter.assets`.
- Pertahankan `pubspec.yaml` existing bila tidak ada kebutuhan lain.
- Pastikan `.gitignore` mencakup:

```gitignore
.env
.env.*
!.env.example
```

- `.env.example` boleh dilacak oleh Git; file environment sebenarnya tetap lokal/tidak di-commit.
- Jangan melakukan reset file lain atau memodifikasi konfigurasi Firebase/Google Sign-In.

## 9. Perintah Pengoperasian (PowerShell Windows)

### Menyalakan backend Laravel

Jalankan pada terminal backend Laravel (sesuaikan path repository backend):

```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

### Menghubungkan Android Emulator ke Laravel lokal

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse --list
```

### Menjalankan development

```powershell
cd C:\laragon\www\pami-mobile\pami-wisata-daearahku
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=.env.development
```

`emulator-5554` adalah contoh device ID; sesuaikan dengan keluaran `flutter devices`. Untuk HTTP lokal pada Android, pertahankan izin cleartext **khusus debug/development** apabila memang diperlukan oleh konfigurasi yang ada.

### Build production

```powershell
flutter build appbundle --release --dart-define-from-file=.env.production
```

Jangan jalankan build release production sampai domain API sesungguhnya sudah diisi dan validasi lolos.

## 10. Batasan / Non-Goals

- Tidak ada perubahan UI/UX, navigasi, atau redesign halaman.
- Tidak mengubah backend Laravel, migration, database, API contract, maupun payment flow.
- Tidak mengubah Firebase Auth, Firebase Messaging, atau kredensial Google OAuth.
- Tidak mengubah logika bisnis katalog, booking, quota, pembayaran, check-in, review, profile, serta dashboard admin.
- Tidak membuat `ApiClient` baru, dependency injection framework baru, atau sistem flavor Android/iOS yang belum dibutuhkan.

## 11. Acceptance Criteria

1. `AppConfig` menjadi sumber konfigurasi Flutter untuk `APP_ENV` dan `API_BASE_URL`.
2. Development pada Android Emulator berhasil mengakses Laravel lokal melalui `adb reverse`.
3. Endpoint authenticated dan public sama-sama menggunakan API base URL yang dipilih.
4. Konfigurasi kosong, malformed, atau placeholder untuk production terdeteksi dengan pesan yang jelas sebelum request.
5. Perintah `flutter run ... --dart-define-from-file=.env.development` bekerja tanpa package tambahan.
6. Perintah build release menggunakan `.env.production` dan tidak diam-diam fallback ke localhost.
7. Tidak ada regresi pada JWT/session/refresh, Firebase Google Login/FCM, dan business logic existing.
8. Tidak ada file `.env` terdaftar sebagai asset atau rahasia backend ditanamkan ke aplikasi.
9. Tidak menambah error analyzer baru; verifikasi request nyata lokal bila environment pengujian tersedia.

## 12. Instruksi Eksekusi untuk Codex

- **Audit kode yang ada sebelum mengubahnya**; jangan menebak nama class, field, lokasi `AuthSession`, atau cara pembentukan URL.
- Gunakan agent frontend Flutter yang tersedia (misalnya `.codex/agents/frontend_engineer.toml` jika relevan dan memang ada di repository); fokus pada konfigurasi, bukan styling.
- Lakukan perubahan minimal, kompatibel dengan arsitektur existing.
- Tampilkan ringkasan file yang diubah, contoh perintah local/development/production, dan hasil verifikasi beserta keterbatasannya.
- Jangan commit, deploy, atau mengubah environment production server tanpa instruksi eksplisit.
