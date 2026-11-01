# PRD — Perbaikan Google Sign-In Native Android (Flutter)

**Proyek:** Wisata Daerahku  
**Platform utama:** Flutter Android Emulator / Android native  
**Backend autentikasi:** Firebase Authentication → Firebase ID token → Laravel API exchange → JWT Laravel  
**Status dokumen:** Siap diimplementasikan Codex, belum merupakan laporan implementasi  
**Prioritas:** Perbaikan terfokus, tidak mengulang PRD autentikasi sebelumnya

## 1. Latar Belakang dan Gejala

Pada pengujian Google Sign-In Android, browser menampilkan akun Google lalu kembali ke handler `*.firebaseapp.com` dan gagal dengan:

> Unable to process request due to missing initial state.

Gejala ini menunjukkan kegagalan pada rangkaian OAuth/redirect Firebase sebelum login Laravel dapat dibuktikan berhasil. **Jangan mengasumsikan akar masalah tanpa audit kode dan konfigurasi.** `signInWithProvider` pada Android memang dapat membuka Chrome Custom Tab, tetapi untuk Google native disarankan mengevaluasi alur `google_sign_in` + `FirebaseAuth.signInWithCredential`.

Dependency sudah berhasil ditambahkan oleh pengguna:

- `google_sign_in: 7.2.0`
- `google_sign_in_android: 7.2.18` (transitif)
- `firebase_auth: 5.7.0` (existing)

Pesan 39 paket memiliki versi baru **bukan** kegagalan pemasangan. Jangan melakukan pembaruan dependency massal.

**Perhatian terhadap identitas proyek:** screenshot OAuth menunjukkan domain `wisata-daearahku-37451.firebaseapp.com`. Audit kesesuaian proyek Firebase yang *benar-benar digunakan* di `google-services.json`, `firebase_options.dart`, serta validasi token di Laravel. Jangan menganggap domain screenshot pasti cocok dengan konfigurasi saat ini; jangan pula membuat proyek Firebase baru tanpa bukti.

## 2. Tujuan

1. Google Sign-In pada Android native menghasilkan Firebase ID token valid tanpa kegagalan `missing initial state`.
2. Firebase ID token dikirim melalui endpoint **Google exchange Laravel existing**, yang mengembalikan sesi/JWT Laravel sesuai arsitektur saat ini.
3. Mempertahankan guard role: hanya user `role = 0` diizinkan untuk Google Sign-In; admin/superadmin tetap mengikuti login email/password.
4. Tidak merusak `AuthSession`, session generation guard, refresh rotation, secure storage, restore sesi, atau logout.
5. Membuktikan perilaku melalui tes terarah dan pengujian emulator nyata, dengan status yang jujur.

## 3. Codex Agents

**Utama:** `C:\Users\itsba\.codex\agents\flutter_engineer.toml`  
**QA terarah:** `C:\Users\itsba\.codex\agents\qa_engineer.toml`  
**Security review hanya bila relevan:** `C:\Users\itsba\.codex\agents\security_auditor.toml`

Minta Codex **memeriksa agent global**, bukan `.codex/agents/frontend_engineer.toml` di repository. Jika konfigurasi agent tidak dapat dimuat, tulis keterbatasannya; jangan mengklaim agent telah dipakai. Hindari pemanggilan banyak agent untuk audit identik demi efisiensi usage.

## 4. Audit Terarah (sebelum perubahan)

- Temukan alur aktual tombol Google dari `user_login_screen.dart` menuju `lib/services/auth_session.dart` dan helper lain.
- Identifikasi apakah kode menggunakan `FirebaseAuth.signInWithProvider`, `signInWithRedirect`, plugin Google native, atau kombinasi beberapa mekanisme.
- Temukan method Google exchange Laravel yang sudah ada, mekanisme penyimpanan token, pembatasan role, serta pembersihan state ketika gagal.
- Audit `android/app/google-services.json`, `lib/firebase_options.dart`, Gradle Google Services, `applicationId`/package ID (`id.wisatadaerahku.app`), SHA-1/SHA-256 untuk build **debug** dan konfigurasi Firebase Authentication Google provider.
- Pastikan proyek Firebase dan audience token yang diterima Laravel sesuai. Audit tanpa menampilkan nilai token, secret, atau App Password dalam laporan.
- Cek keberadaan entri OAuth Web client (`oauth_client.client_type = 3`) di `google-services.json` dan Android OAuth client untuk package/signing certificate yang benar.
- Verifikasi apakah alur saat ini benar-benar Android native; jangan mengubah implementasi Web/iOS jika tidak diperlukan.

## 5. Implementasi yang Diinginkan

### 5.1 Google Sign-In native pada Android

Untuk Android, gunakan pola API `google_sign_in` **v7.x** yang sesuai dokumentasi paket:

1. Inisialisasi `GoogleSignIn.instance` **sekali** dan tunggu hasil `initialize()` sebelum autentikasi.
2. Gunakan `GoogleSignIn.instance.authenticate()` melalui interaksi pengguna.
3. Baca `googleAccount.authentication.idToken` dan validasi token tersedia.
4. Buat `GoogleAuthProvider.credential(idToken: ...)`.
5. Jalankan `FirebaseAuth.instance.signInWithCredential(credential)`.
6. Dapatkan **Firebase ID token dari Firebase user** (`user.getIdToken()`), bukan menyamakan Google ID token dengan Firebase ID token.
7. Panggil fungsi Google exchange Laravel **existing**; lanjutkan alur JWT Laravel dan role gate existing.

Jangan menggunakan API lama `GoogleSignIn().signIn()` yang tidak sesuai v7.x. Jangan menulis credential, Firebase token, atau JWT ke debug log.

`serverClientId` pada Android tidak perlu dipaksakan apabila `google-services.json` dan konfigurasi Gradle telah menyediakan OAuth Web client yang sesuai; jika muncul error konfigurasi, periksa dahulu `client_type: 3`, package name, SHA signing, dan petunjuk resmi. Jangan menanam client ID baru tanpa memastikan sumber dan kebutuhan sebenarnya.

### 5.2 Session, cancellation, error

- Pertahankan single-flight/double-tap protection pada tombol masuk Google.
- Bedakan pembatalan pengguna dari error konfigurasi/bermasalah agar UI memberi pesan yang sesuai.
- Jika Firebase berhasil tetapi exchange Laravel gagal, lakukan pembersihan state sementara secara terkendali tanpa merusak sesi login sebelumnya atau race logout/login.
- Pertahankan seluruh pemeriksaan `sessionGeneration`, guard stale results, dan aturan role.
- Setelah exchange sukses, user `role = 0` diarahkan ke destination existing. Role lain ditolak menurut kebijakan existing, tanpa menyimpan JWT aktif.
- `FirebaseAuth` bukan sumber otorisasi API bisnis: request Laravel tetap memakai JWT Laravel.
- Logout harus tetap membatalkan sesi Laravel dan membersihkan state provider sesuai kebutuhan, tanpa memicu login otomatis tak diinginkan.

### 5.3 Multi-platform

Pindahkan kode spesifik Android ke helper/adaptor yang sesuai apabila bermanfaat untuk testability. Jika aplikasi berjalan di Web/iOS/desktop, **jangan memaksa** alur Android kepada platform tersebut. Pertahankan mekanisme existing atau laporkan ketidaktersediaannya; tidak perlu membangun ulang autentikasi semua platform.

## 6. Scope Restrictions

**Boleh diubah (bila memang diperlukan):** kode Google Sign-In pada `AuthSession`/helper autentikasi, pemanggil UI Login, fixture/mock tes, dan konfigurasi Android yang terbukti salah.

**Tidak boleh diubah:** backend Laravel, kontrak Google exchange, flow Email OTP, email/password Login/Register, Forgot/Reset Password, modul wisata, admin, database, atau UI redesign yang tidak relevan.

- Tidak membuat proyek Firebase baru atau merotasi kredensial tanpa persetujuan.
- Tidak melakukan pembaruan besar Firebase/Flutter dependency hanya karena `flutter pub outdated` menunjukkan versi terbaru.
- Tidak melakukan commit, push, atau deployment.

## 7. Testing dan Acceptance Criteria

### 7.1 Automated / source verification

1. `flutter pub get` dan focused analyzer pada file yang diubah lulus tanpa issue baru.
2. Widget/unit tests mencakup login sukses, cancel, gagal initialize, token Firebase null, gagal exchange Laravel, role bukan 0, double tap, logout saat request berlangsung, dan stale generation.
3. Pengujian tidak bergantung pada koneksi Google asli; mock boundary di layer service/provider saja.
4. Jalankan targeted tests dahulu, kemudian full Flutter regression sekali setelah stabil.
5. `flutter build apk --debug --dart-define-from-file=.env.development` berhasil.
6. `git diff --check` lulus; laporkan issue analyzer existing secara terpisah.

### 7.2 Manual Android E2E (wajib dibedakan dari mock)

1. Pastikan Laravel lokal, MySQL, Android Emulator, dan `adb reverse tcp:8000 tcp:8000` aktif.
2. Jalankan aplikasi dengan `.env.development`.
3. Ketuk `Masuk dengan Google`, pilih akun di perangkat, dan pastikan proses **tidak** berhenti pada `missing initial state`.
4. Pastikan Firebase ID token berhasil dipertukarkan dengan Laravel dan `auth/me` mengenali user `role = 0`.
5. Pastikan session restore, logout, dan login ulang bekerja.
6. Uji cancel, offline/network error, dan akun yang tidak memenuhi role.
7. Tidak boleh ada token atau credential sensitif dalam output log.

Jika login berhasil tetapi Laravel exchange gagal, pisahkan diagnosis **Firebase native** dari **Laravel API**. Jika emulator/inbox/akun tidak tersedia, nyatakan `NOT VERIFIED`, bukan `PASS`.

## 8. Runbook untuk Developer (PowerShell Windows)

Dari root Flutter:

```powershell
cd C:\laragon\www\pami-mobile\pami-wisata-daearahku
flutter devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
flutter run -d emulator-5554 --dart-define-from-file=.env.development
```

Sesuaikan ID emulator dengan `flutter devices`. Untuk melihat signing fingerprint **debug**, gunakan Gradle signing report jika perlu:

```powershell
cd android
.\gradlew.bat signingReport
```

Pastikan SHA cocok dengan konfigurasi Firebase untuk `id.wisatadaerahku.app`. Jangan mengganti file `google-services.json` berdasarkan asumsi; lakukan hanya bila mismatch sudah dibuktikan.

## 9. Deliverables Codex

- Root cause berdasarkan source/configuration yang ditemukan dan penjelasan mengapa solusi dipilih.
- Daftar file diubah, diff ringkas, serta versi dependency yang dipertahankan.
- Hasil `flutter test`, analyzer, build, Android real E2E sebagai `PASS` / `FAIL` / `NOT VERIFIED`.
- Konfirmasi Firebase token → Laravel exchange → JWT Laravel tetap utuh, atau blocker spesifik beserta pesan error aman.
- Catatan jika ada ketidakcocokan antara Firebase project di screenshot, `google-services.json`, `firebase_options.dart`, dan Laravel verifier.
- Tidak mengklaim masalah berhasil diperbaiki sebelum E2E native diverifikasi.

## 10. Referensi Teknis

- Google Sign-In v7 API: https://pub.dev/packages/google_sign_in
- Google Sign-In Android setup/troubleshooting: https://pub.dev/packages/google_sign_in_android
- Firebase Auth federated login Flutter: https://firebase.google.com/docs/auth/flutter/federated-auth

---

### Prompt Codex pendek

Implementasikan PRD ini dari kode Flutter existing, dengan agent utama `C:\Users\itsba\.codex\agents\flutter_engineer.toml`. Fokus hanya memperbaiki Google Sign-In Android dengan `google_sign_in 7.2.0`, Firebase credential, dan Google exchange Laravel existing. Audit konsistensi proyek Firebase, OAuth client/SHA, session generation, serta pembatasan role. Jangan mengulang auth OTP, tidak usah upgrade dependency massal. Jalankan targeted tests, build, lalu lakukan E2E pada emulator bila tersedia. Laporkan status yang benar tanpa commit/push/deploy.
