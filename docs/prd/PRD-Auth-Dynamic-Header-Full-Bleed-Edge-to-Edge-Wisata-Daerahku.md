# PRD Addendum — Full-Bleed Edge-to-Edge Dynamic Authentication Header

**Proyek:** Wisata Daerahku (Flutter Mobile)

**Status:** Approved visual refinement, 2 November 2026

**Scope:** Flutter authentication presentation **saja**; tidak mengubah business logic, Laravel API, Firebase/Google Sign-In, routing, maupun state formulir.

**Implementasi owner:** Agent `flutter_engineer`; gunakan Taste Skills mobile (`design-taste-frontend` bila tersedia) untuk **development UI saja**, tidak perlu membuat screenshot, mockup, test, atau artifact QA.

**Design authority:** `docs/DESIGN.md` dari checkout lokal terbaru; integrasikan dengan PRD Authentication UI Redesign dan Dynamic Time-Based Auth Header yang sudah diimplementasikan.

## 1. Masalah dan tujuan

Screenshot setelah Dynamic Header diimplementasikan masih menampilkan strip horizontal **navy solid** di atas ilustrasi langit (tepat di belakang jam, kamera, ikon sinyal, baterai). Pengguna menginginkan **background langit menyambung mulus sampai ujung fisik layar**: status bar sistem hanya meng-overlay ilustrasi yang sama, bukan punya background mandiri.

**Definisi selesai:** Tidak ada garis batas atau strip berwarna terpisah antara status bar Android dan sky gradient; langit memenuhi area di belakang jam, ikon, kamera/punch-hole. Semua elemen interaktif tetap aman terhadap status bar/notch dan keyboard.

## 2. Perilaku dan visual wajib

1. **Full-bleed khusus area header:** Background `AuthDynamicHeader` / painter `CustomPainter` membentang dari `top = 0` secara visual hingga bagian ilustrasi pegunungan dan overlap white sheet.
2. **Status bar transparan:** Di atas area langit yang sama, jam, Wi-Fi, sinyal, dan baterai tetap terlihat. Hindari solid navy strip di `Scaffold`, `AppBar`, `SafeArea`, `Container`, atau parent layout.
3. **Tidak menutupi status bar atau menyembunyikannya.** Ini *edge-to-edge behind status bar*, bukan fullscreen/immersive mode.
4. **Safe top inset tetap berlaku untuk konten:** chip merek, judul `Selamat datang!`, matahari, awan, serta teks harus dijauhkan dari ikon status bar dan area punch-hole. Gunakan `MediaQuery.paddingOf(context).top`, `SafeArea` hanya untuk **foreground content**, atau padding ekuivalen; jangan bungkus background header dengan `SafeArea(top: true)`.
5. **Jangan mengubah white sheet:** background `#FFFFFF`, radius top, overlap dengan gunung, posisi form, scroll, keyboard interaction, serta tombol/label yang disepakati harus dipertahankan. Jangan menambah drag handle.
6. **Keempat suasana tetap aktif:** pagi 05.00–10.59, siang 11.00–14.59, sore 15.00–18.59, malam 19.00–04.59, seluruhnya berdasarkan `DateTime.now()` di device.
7. **Animasi 800 ms `Curves.easeInOut`:** Warna langit di balik status bar turut bertransisi secara kontinu bersama seluruh header tanpa jeda, flash, atau garis warna berbeda. Tetap hormati `reduced motion`.
8. **Status bar icons:** Pilih `SystemUiOverlayStyle`/`AnnotatedRegion<SystemUiOverlayStyle>` atau mekanisme rute yang sesuai untuk menjaga kontras ikon sistem pada semua suasana. Jika perlu, tambahkan scrim/gradient **sangat lembut di bagian atas yang menyatu dengan langit**; jangan ubah menjadi strip opaque baru.
9. **Jaga cakupan:** Berfungsi pada keenam layar autentikasi yang memakai shared header; jangan memaksa edge-to-edge/bentuk status bar baru pada seluruh layar aplikasi lain.
10. **Bottom navigation region:** Pertahankan existing behavior, white sheet dan safe bottom inset agar home indicator/gesture bar tidak menindih CTA; perubahan utama hanya bagian top header.

## 3. Catatan implementasi Flutter/Android

- **Audit checkout lokal terlebih dahulu**; implementasi header dinamis terbaru menurut laporan ada di `lib/screens/auth_presentation.dart`, tetapi `main` publik yang dapat diakses pada saat perencanaan belum tentu berisi commit tersebut. Temukan kelas widget shared header aktual sebelum mengedit.
- Audit `Scaffold`, `SafeArea`, `AppBar`, `AnnotatedRegion<SystemUiOverlayStyle>`, `SystemChrome`, dan wrapper/layout yang menambahkan padding top/warna navy.
- Android SDK 35+ menggunakan edge-to-edge secara default. Mengatur `statusBarColor: Colors.transparent` saja **tidak cukup**, dan bisa tidak berpengaruh pada Android 15/16. Pastikan **actual Flutter painting surface** benar-benar berada di belakang status bar.
- Gunakan `SystemUiMode.edgeToEdge` bila memang diperlukan untuk versi Android lebih lama; **jangan** menggunakan `immersive`, `leanBack`, `SystemUiMode.manual` untuk menyembunyikan status bar, atau workaround `windowOptOutEdgeToEdgeEnforcement`.
- Prefer **route-scoped** `AnnotatedRegion<SystemUiOverlayStyle>` di auth shared shell. Pertimbangkan `statusBarIconBrightness` dan aturan platform (mis. `statusBarBrightness` pada iOS). Jangan mengubah style global yang mempengaruhi screen wisata/admin tanpa kebutuhan.
- Implementasi layout bisa berupa background `Stack`/`Positioned(top: 0, ...)` atau mekanisme `Scaffold(extendBodyBehindAppBar: true)` bila sesuai struktur actual. **Jangan menyisipkan AppBar hanya untuk mengejar efek edge-to-edge**; pilih patch paling kecil.
- **Beda antara background dan foreground**: painter/sky mengisi status bar region, foreground header content mendapatkan top inset. Hindari menggeser white sheet sehingga form berubah tinggi secara tidak sengaja.
- Perubahan mode waktu tidak boleh mereset `TextEditingController`, `FocusNode`, email, password, OTP, hasil API, scroll atau menutup keyboard. Hindari rebuild parent auth form berlebihan.
- Jika Android 3-button navigation atau perangkat dengan notch membutuhkan perlakuan khusus, manfaatkan insets sistem yang sudah ada dan scope lokal.

## 4. File kandidat dan batasan

| File | Perubahan |
|---|---|
| `lib/screens/auth_presentation.dart` | **Primary target:** shared dynamic scenic header, top inset, overlay, full-bleed painting area. |
| `lib/screens/user_login_screen.dart`, `user_register_screen.dart`, `forgot_password_screen.dart`, `verify_reset_otp_screen.dart`, `reset_password_screen.dart`, success screen aktual | **Conditional only:** pastikan semua screen memakai shared shell; ubah wrapper `Scaffold`/`SafeArea` yang menyebabkan status bar terpisah bila benar-benar diperlukan. |
| `lib/main.dart`, `android/app/src/main/res/values/styles.xml`, `values-night/styles.xml` | **Read first, modify only if unavoidable:** jangan lakukan perubahan global/manifest sekadar workaround. |
| `docs/DESIGN.md` | **Read only:** rujukan design utama. |

## 5. Acceptance criteria visual/fungsional (untuk implementasi, tidak mewajibkan test)

- [ ] Header langit terlihat sampai ujung fisik atas layar di belakang Android status bar, tanpa blok navy terpisah atau garis horizontal.
- [ ] Ikon status bar tetap tampak dan terbaca di pagi, siang, sore, malam.
- [ ] Matahari/awan/brand/judul tidak bertabrakan dengan punch-hole atau status icons.
- [ ] Langit yang mengisi belakang status bar ikut berubah halus saat boundary waktu (05.00/11.00/15.00/19.00).
- [ ] White sheet `#FFFFFF`, enam layar auth, navigasi serta business logic tidak berubah.
- [ ] Field, keyboard, fokus, scroll, password/OTP dan CTA tidak ter-reset oleh transisi.
- [ ] Tidak membuat package baru, image asset baru, screenshot, mockup atau artifact QA.
- [ ] Tidak ada perubahan Laravel/backend dan tidak membuat Git commit.

## 6. Instruksi pekerjaan (development only)

Gunakan agent `flutter_engineer` dan Taste Skills mobile untuk development; baca `docs/DESIGN.md`; audit kode yang sebenarnya sudah ter-merge pada checkout lokal; patch **khusus** top-scene/layout status bar agar full-bleed, lalu jelaskan file yang berubah dan mekanismenya. **Tidak perlu menjalankan test/build, membuat screenshot, atau artifact QA**, sesuai brief pengguna. Jangan mengklaim sudah melakukan verifikasi perangkat jika memang belum.

## 7. Referensi

- Flutter: https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge
- Flutter: https://api.flutter.dev/flutter/services/SystemUiMode.html
- Flutter: https://api.flutter.dev/flutter/services/SystemUiOverlayStyle-class.html
- Android: https://developer.android.com/develop/ui/views/layout/edge-to-edge
- Repo: https://github.com/koyotot/pami-wisata-daearahku
