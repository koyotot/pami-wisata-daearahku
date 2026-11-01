# PRD — Pemulihan Google Sign-In Android (Firebase Baru) — Wisata Daerahku

**Tipe:** Implementation brief untuk Codex  
**Prioritas:** High  
**Cakupan utama:** Flutter Android, Gradle Kotlin DSL, debug signing, verifikasi Firebase configuration  
**Tidak termasuk:** Migrasi ulang Laravel/MySQL, redesign UI, perubahan fitur bisnis, pembuatan project Firebase baru

## 1. Konteks dan masalah

Project Flutter `C:\laragon\www\pami-mobile\pami-wisata-daearahku` sudah bermigrasi dari Firebase untuk data bisnis ke Laravel 13 + MySQL. Firebase **tetap digunakan** hanya untuk Google Authentication dan FCM.

Project Firebase sebelumnya (`wisata-daerahku-3cf6b`) tidak dapat digunakan; Google mengembalikan `403` dengan project suspended. Project pengganti sudah dibuat:

| Parameter | Nilai |
|---|---|
| Firebase Project ID baru | `wisata-daerahku-37451` |
| Firebase Project Number / messagingSenderId | `769381226723` |
| Android package/application ID | `id.wisatadaerahku.app` |
| Firebase Android App ID | `1:769381226723:android:1dbc95d2928b268ff54dd6` |
| Backend Laravel lokal | `C:\laragon\www\pami-wisata-daerahku-api` |
| Flutter Android module | `android/app` |

Saat ini:

- `android/app/google-services.json` sudah menunjuk project baru.
- `lib/firebase_options.dart` telah diregenerasi dan diverifikasi menunjuk project baru.
- Laravel membaca `FIREBASE_PROJECT_ID=wisata-daerahku-37451` dan `FIREBASE_CREDENTIALS` menuju `storage/app/private/firebase-service-account.json` dari project baru.
- Google provider sudah dicoba diaktifkan. Firebase sempat mengembalikan `Can't enable Google Sign-In. OAuth brand has been deleted`; ini **masalah console/OAuth tersendiri** yang tidak bisa dianggap otomatis selesai oleh perubahan Flutter.
- Di Google Cloud project baru sudah ada OAuth **Web client**; **Android OAuth client** belum berhasil dibuat.
- Saat membuat Android OAuth client untuk package di atas dengan SHA-1 debug lama, Google mengembalikan `Android package name and fingerprint are already in use`. Ini berarti pasangan package + SHA-1 telah digunakan di project Google lain. Project lama diduga pemiliknya, tetapi tidak bisa dipastikan dari error saja.

Fingerprint debug lama (JANGAN digunakan untuk OAuth Android baru):

```text
SHA-1   88:95:CD:73:41:CB:CA:9A:BA:9D:82:CA:4A:D5:4B:C1:40:54:19:27
SHA-256 FD:B2:B7:EF:B6:FD:77:8B:B5:AB:D2:8E:F2:30:CA:98:43:10:4E:79:12:B3:54:87:35:9A:06:42:94:7C:36:82
```

Sebuah **debug keystore baru sudah dibuat secara lokal** melalui Android Studio JBR `keytool`:

```text
C:\laragon\www\pami-mobile\pami-wisata-daearahku\android\app\wisata-debug.keystore
alias: androiddebugkey
```

**JANGAN generate ulang keystore ini dan JANGAN hapus debug.keystore global.** Pekerjaan Codex adalah menghubungkan existing keystore baru tersebut ke build debug secara aman, lalu menghasilkan fingerprint baru yang benar.

## 2. Objective

1. Android Flutter **debug build** menggunakan `android/app/wisata-debug.keystore` yang sudah dibuat, bukan `C:\Users\itsba\.android\debug.keystore` global.
2. `./gradlew signingReport` memperlihatkan SHA-1 dan SHA-256 baru untuk `Variant: debug`, berbeda dari fingerprint lama.
3. `applicationId` tetap `id.wisatadaerahku.app`.
4. Keystore tidak terlacak/ter-commit Git.
5. Flutter Google Sign-In tetap menggunakan Firebase baru. Sediakan instruksi manual final ke Firebase/Google Cloud, karena Codex tidak boleh mengklaim console berhasil tanpa verifikasi.
6. Jangan merusak signing release, Firebase service account, Laravel JWT, atau flow aplikasi saat ini.

## 3. Batasan wajib

- Kerjakan di project Flutter existing, bukan membuat project baru.
- Inspeksi file aktual sebelum mengubah apa pun: `android/app/build.gradle.kts`, `android/build.gradle.kts` bila perlu, `.gitignore`, dan konfigurasi Firebase yang relevan.
- Kotlin DSL (`.kts`), bukan contoh Groovy `build.gradle`.
- Jangan membuat blok `android`, `buildTypes`, atau `signingConfigs` duplikat. Integrasikan dengan struktur existing.
- Konfigurasi `debug` memakai keystore baru. **Jangan mengubah konfigurasi `release` tanpa diminta**; bila saat ini release memakai debug signing, laporkan sebagai risiko terpisah, jangan diam-diam melakukan migrasi release.
- Jangan mengganti package name, Firebase Project ID, Android App ID, service account backend, JWT, database, Google Sign-In logic, atau source fitur bisnis.
- Tidak boleh menyalin, membaca isi sensitif, mempublikasikan, atau meng-commit `firebase-service-account.json`.
- Jangan memodifikasi OAuth Web Client yang sudah ada, jangan membuat project Firebase lagi, jangan menghapus client/project apa pun.
- Jangan meng-uninstall aplikasi emulator tanpa izin, karena data lokal aplikasi akan hilang.
- Jika keystore baru tidak ditemukan, **berhenti dan laporkan**, jangan membuat file baru tanpa konfirmasi.

## 4. Implementasi teknis oleh Codex

### 4.1 Audit awal

1. Pastikan working directory adalah root Flutter: `C:\laragon\www\pami-mobile\pami-wisata-daearahku`.
2. Pastikan file `android/app/wisata-debug.keystore` ada, tanpa menampilkan data sensitif.
3. Periksa existing signing config pada `android/app/build.gradle.kts`; pahami hubungan `debug`, `profile`, dan `release` sebelum mengubah.
4. Catat perubahan Git awal agar tidak menimpa pekerjaan pengguna; jangan reset/clean file pengguna.

### 4.2 Debug signing Kotlin DSL

Terapkan signing config **khusus debug** yang menunjuk ke `file("wisata-debug.keystore")` dari direktori modul `android/app`. Untuk referensi konseptual saja (sesuaikan ke struktur nyata):

```kotlin
android {
    signingConfigs {
        create("wisataDebug") {
            storeFile = file("wisata-debug.keystore")
            storePassword = "android" // lokal debug only; lihat kebijakan repo
            keyAlias = "androiddebugkey"
            keyPassword = "android" // lokal debug only
        }
    }
    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("wisataDebug")
        }
        // Jangan mengubah konfigurasi release existing.
    }
}
```

Contoh tersebut **bukan instruksi mengganti seluruh blok**. Lebih baik mengikuti pola existing project. Keystore debug baru dibuat dengan password lokal debug `android`; **jangan menggunakannya untuk release**. Jika repo punya kebijakan pengelolaan password berbeda, adaptasi dengan aman dan jelaskan.

### 4.3 Perlindungan Git

Tambahkan ignore rule yang tepat untuk `android/app/wisata-debug.keystore` (atau rule lebih luas untuk keystore lokal bila sudah sesuai kebijakan repo). Periksa bahwa file tidak tracked:

```powershell
git check-ignore -v android/app/wisata-debug.keystore
git ls-files --error-unmatch android/app/wisata-debug.keystore
```

Perintah kedua seharusnya exit non-zero jika untracked; **jangan** memaksa add/commit keystore.

### 4.4 Validasi signing, bukan tebak fingerprint

Dari folder `android`:

```powershell
.\gradlew signingReport
```

Ambil SHA-1 dan SHA-256 pada `Task :app:signingReport`, `Variant: debug`.

Validasi:

- `Store` benar-benar mengarah ke `android/app/wisata-debug.keystore`.
- `SHA1` berbeda dari `88:95:CD:73:41:CB:CA:9A:BA:9D:82:CA:4A:D5:4B:C1:40:54:19:27`.
- `SHA-256` berbeda dari fingerprint lama yang disebutkan sebelumnya.
- Gradle berhasil, tanpa memperkenalkan error baru.

Jika `signingReport` menampilkan keystore berbeda atau gagal, perbaiki Gradle hingga debug mengarah ke keystore baru. Jika perlu, gunakan `keytool -list -v` dari `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe` untuk membandingkan sertifikat langsung.

### 4.5 Pemeriksaan Firebase lokal

Periksa saja (jangan otomatis overwrite bila sudah benar):

```text
android/app/google-services.json
lib/firebase_options.dart
```

Keduanya harus memakai project `wisata-daerahku-37451` dan Sender ID `769381226723`. Perhatikan bahwa `oauth_client: []` di JSON lama mungkin belum terisi sampai OAuth Android/Google Provider dibereskan di console. Jangan memalsukan isi `oauth_client` atau menulis OAuth Client ID sembarang.

### 4.6 Minimal build verification

Lakukan validasi build debug seperlunya setelah signing benar, misalnya `flutter build apk --debug` dari root Flutter, bila toolchain tersedia. Laporkan hasil build, tetapi **jangan mengklaim Google login end-to-end PASS hanya karena APK berhasil dibangun**.

## 5. Handoff manual yang WAJIB diberikan Codex

Setelah SHA baru ditemukan, tampilkan kepada user dalam format copy-paste:

```text
Firebase project: wisata-daerahku-37451
Android package: id.wisatadaerahku.app
SHA-1 baru: <hasil nyata>
SHA-256 baru: <hasil nyata>
```

Minta user menyelesaikan aksi console berikut:

1. Pada Firebase project baru → **Project settings → Your apps → Android**, daftarkan SHA-1 dan SHA-256 baru. Jika gagal, tampilkan error aslinya.
2. Pada Google Cloud project baru → **Google Auth Platform → Clients**, pastikan Android OAuth client benar-benar ada untuk package + SHA-1 baru (bukan fingerprint lama), tanpa membuat duplikat jika sudah otomatis dibuat.
3. Pada Firebase → **Authentication → Sign-in method**, pastikan Google Provider benar-benar tersimpan sebagai Enabled. Jika masih muncul `OAuth brand has been deleted`, **laporkan sebagai blocker Google Cloud/Firebase**, jangan mengarang fix atau mengklaim sudah selesai; kemungkinan memerlukan Firebase Support.
4. **Setelah** OAuth/Google Provider beres, download ulang `google-services.json`, ganti `android/app/google-services.json`, dan rebuild aplikasi (bukan hot reload).
5. Uji login Google di emulator → Firebase ID Token → Laravel `/auth/google` atau endpoint sebenarnya berdasarkan codebase → JWT Laravel. Gunakan endpoint yang terdefinisi nyata, jangan menebak nama endpoint.

Catatan: setelah signing certificate debug berubah, APK lama yang ditandatangani debug key sebelumnya dapat gagal di-update (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). **Minta izin user sebelum uninstall** app yang terpasang pada emulator.

## 6. Acceptance criteria

- [ ] Debug keystore baru yang sudah ada dipakai oleh `Variant: debug`.
- [ ] SHA-1 dan SHA-256 baru dilaporkan apa adanya dari Gradle/keytool.
- [ ] `Variant: debug` tidak lagi memakai global debug.keystore lama.
- [ ] Package name tetap `id.wisatadaerahku.app`.
- [ ] Signing release existing tidak berubah.
- [ ] Keystore tidak masuk Git.
- [ ] Firebase lokal tetap mengarah ke project `wisata-daerahku-37451`.
- [ ] Build debug PASS atau ada laporan kegagalan dengan sebab jelas.
- [ ] Langkah console + blocker tersisa disampaikan, tidak diklaim selesai otomatis.
- [ ] Laravel/MySQL/FCM business flow tidak diubah.

## 7. Format laporan akhir Codex

Berikan:

1. **File modified** beserta ringkasan perubahan konkret.
2. **Status verifikasi**: `signingReport`, keystore path, SHA-1/SHA-256 baru, build debug, Git ignore.
3. **Yang belum selesai di Firebase Console**: SHA input, Android OAuth Client, Google Provider status, unduh ulang JSON, dan kemungkinan blocker `OAuth brand has been deleted`.
4. **Next user action**, maksimal 3 langkah, sesuai kondisi terbaru tanpa mengulang setup yang sudah beres.

Tidak perlu redesign UI, migrasi ulang, atau commit Git otomatis.

## 8. Referensi resmi

- Firebase — OAuth Android package/SHA-1 collision: https://support.google.com/firebase/answer/6401008?hl=en
- Firebase — Android troubleshooting SHA-1: https://firebase.google.com/docs/android/troubleshooting-faq
- FlutterFire — setup: https://firebase.google.com/docs/flutter/setup

---

**Instruksi langsung untuk Codex:** Baca PRD ini, audit project aktual, implementasikan hanya scope lokal Flutter, jalankan verifikasi signing/build, lalu tampilkan SHA baru beserta langkah console yang masih harus dilakukan pengguna. Jangan berasumsi error OAuth brand telah sembuh.
