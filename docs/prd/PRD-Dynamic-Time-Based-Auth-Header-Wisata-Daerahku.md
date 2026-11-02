# PRD — Dynamic Time-Based Authentication Header

**Project:** Wisata Daerahku · Flutter Mobile  
**Status:** APPROVED CONCEPT — siap menjadi brief implementasi setelah Authentication UI Redesign  
**Tanggal:** 2 November 2026  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Prioritas:** Enhancement visual terpisah dari PRD Authentication UI Redesign  
**Owner:** Agent `flutter_engineer`  
**Skill desain wajib:** Taste Skills untuk mobile (`design-taste-frontend` atau skill setara yang tersedia di workspace) — **dipakai untuk DEVELOPMENT/IMPLEMENTASI saja**, bukan pembuatan mockup, test, screenshot, atau artifact verifikasi.  
**Design reference:** `docs/DESIGN.md` pada checkout lokal terbaru + desain Authentication UI Redesign yang sudah disetujui.

> **Arahan inti:** Implementasikan header autentikasi dinamis berbasis **waktu lokal perangkat (`DateTime.now()`)**, **100% Flutter/Dart**, menggunakan **`CustomPainter` yang sudah ada** sebagai fondasi. Setiap kali waktu memasuki periode pagi/siang/sore/malam, warna langit dan detail suasana berganti secara halus **±800 ms** tanpa mengganti halaman, mereset input, atau memengaruhi white sheet. **Tidak perlu backend, test, screenshot, preview, dokumentasi QA, atau artifact visual tambahan.**

---

## 1. Latar belakang dan tujuan

Halaman autentikasi Wisata Daerahku mempunyai identitas visual khas berupa hero biru dengan matahari, awan, dan pegunungan berlapis, serta **single white sheet `#FFFFFF`** untuk formulir. Tujuan enhancement ini adalah membuat suasana *hero/header* mengikuti waktu lokal perangkat dan tetap berubah **meskipun layar autentikasi sedang terbuka**.

Contoh utama: pukul **04.59** pengguna sedang mengetik password dengan header malam; tepat saat jam menjadi **05.00**, suasana header berubah secara halus menjadi pagi **tanpa kehilangan teks, fokus, keyboard, loading state, atau posisi scroll**.

Ini **murni dekorasi visual**, bukan sumber waktu resmi untuk autentikasi, token, OTP, booking, atau pembayaran.

## 2. Baseline repository: audit awal (public `main`)

Berdasarkan source publik yang diakses saat menyusun PRD:

- `lib/screens/user_login_screen.dart` memuat `_buildHeader()` yang menggambar background langit memakai `LinearGradient` serta `CustomPaint(painter: _ScenePainter())`.
- `_ScenePainter` di bagian bawah file tersebut menggunakan `canvas.drawCircle()` untuk matahari dan cahaya, bentuk sederhana untuk awan, serta `Path()` / `canvas.drawPath()` untuk gunung belakang dan depan.
- Painter saat ini bersifat statis, `shouldRepaint(...) => false`.
- `lib/screens/auth_presentation.dart` berisi shared presentation auth, tetapi pada source publik yang diperiksa belum ada komponen dynamic time header bersama.
- `docs/DESIGN.md` tersedia sebagai **audit design** dan menyebut penggunaan Taste Skills `design-taste-frontend`. Dokumen itu memuat observasi kode pada waktu audit, **bukan token final yang boleh mengalahkan hasil Authentication UI Redesign terbaru**.

**Penting:** branch publik bisa tertinggal dari checkout lokal. **Sebelum mengedit, baca file aktual yang ada di workspace**. Jika hasil PRD Authentication UI Redesign sebelumnya sudah memindahkan `_ScenePainter` atau membangun shared header, **extend implementasi yang sudah ada**. Jangan mengembalikan layout login lama atau menduplikasi header.

Referensi:
- [Login header & painter](https://github.com/koyotot/pami-wisata-daearahku/blob/main/lib/screens/user_login_screen.dart)
- [Shared auth presentation](https://github.com/koyotot/pami-wisata-daearahku/blob/main/lib/screens/auth_presentation.dart)
- [Design audit](https://github.com/koyotot/pami-wisata-daearahku/blob/main/docs/DESIGN.md)

## 3. Ruang lingkup

### In scope

1. Mengaktifkan **empat suasana** pada header autentikasi berdasarkan **jam lokal perangkat**.
2. Mengubah warna/langit, matahari atau bulan, cahaya, awan/bintang, dan **warna** layer gunung tanpa mengganti geometri pegunungan aslinya.
3. Transisi otomatis **800 ms** dengan kurva `Curves.easeInOut` (atau interpolasi visual Flutter yang setara).
4. Menangani pergantian jam **ketika halaman sedang aktif**, serta menyelaraskan state ketika aplikasi dibuka lagi dari background.
5. Menjadikan header **reusable** di halaman Login, Daftar, Lupa Password, Verifikasi OTP reset password, Password Baru, dan halaman Success — jika halaman-halaman itu memakai shared header pada checkout terbaru.
6. Memisahkan repaint/animasi header dari state formulir dan menjaga kontras tipografi/status bar.

### Out of scope — jangan dikerjakan

- Laravel API, backend clock, NTP, sinkronisasi server, GPS, geolocation, weather API, internet request, konfigurasi timezone dari server.
- Timezone WIB/WITA/WIT yang dipaksakan: ikuti **timezone yang diatur pada device** (termasuk jika user bepergian ke luar Indonesia).
- Menentukan sunrise/sunset astronomis, berdasarkan lokasi, tanggal astronomi, atau cuaca asli.
- Perubahan business logic autentikasi, sesi, API, role routing, Google Sign-In/Firebase, JWT, email verification, OTP cooldown, reset ticket, input validation, dan navigasi.
- Redesign ulang white sheet, form, CTA, layout, atau header typography dari PRD Authentication sebelumnya.
- Animasi berjalan terus-menerus, parallax rumit, partikel bintang terus bergerak, Lottie, video, gambar PNG/JPG baru, dan package tambahan yang tidak perlu.
- **Pengujian otomatis, widget test, integration test, `flutter test`, screenshot, visual regression, pembuatan demo/mockup baru, rekaman video, atau artifact QA/verifikasi.** Ini **development only** atas permintaan pengguna.

## 4. Periode waktu — keputusan final

Gunakan `DateTime.now()` **dari Flutter mobile** dan tentukan suasana berdasarkan **jam lokal perangkat**, dengan batas waktu **inklusif pada jam awal**.

| Segmen | Rentang waktu lokal | Desain suasana |
|---|---|---|
| `morning` / Pagi | **05.00–10.59** | Langit biru muda dengan sentuhan peach/lembut; matahari pagi, glow tipis, gunung biru cerah. |
| `day` / Siang | **11.00–14.59** | Langit biru cerah, matahari lebih terang/tinggi, awan putih tipis, gunung seperti desain biru existing. |
| `evening` / Sore | **15.00–18.59** | Gradien jingga-peach ke ungu/biru lembut, matahari lebih rendah, gunung sedikit lebih hangat/gelap. |
| `night` / Malam | **19.00–04.59** | Langit navy/biru gelap, bulan sabit, sedikit bintang statis, siluet gunung biru tua. |

**Batas pergantian:** `05:00`, `11:00`, `15:00`, `19:00`. Tidak ada periode abu-abu/gap dan tidak ada pergantian di tengah rentang. Jam pada tabel adalah **rentang UI**, bukan waktu astronomis.

## 5. Perilaku yang diwajibkan

### Saat layar pertama kali dibuka

- Baca `DateTime.now()` sekali untuk memperoleh segmen saat ini; tampilkan scene yang sesuai **langsung**, tanpa memutar animasi panjang dari mode default.
- Jangan flicker dari scene siang ke malam akibat penggunaan state default yang salah.
- Tampilan awal sebaiknya meminimalkan rebuild dan layout shift.

### Saat masuk ke batas waktu

- Dari segmen yang sedang tampil, **interpolasikan** ke konfigurasi segmen baru dengan durasi **800 ms**, `easeInOut`.
- **Contoh wajib:** user membuka Login jam 04.59 dan terus mengetik; ketika jam 05.00 tercapai, header berubah dari `night` menjadi `morning` secara otomatis; **form, controller, teks, fokus, keyboard, scroll, validasi, dan request API tetap utuh**.
- Berikan perubahan bertahap pada warna background, warna gunung, posisi/opasitas matahari/bulan, awan dan bintang. Jangan menampilkan perubahan yang patah/berkedip.
- Bintang **boleh statis** saat malam dan menghilang melalui perubahan opacity; tidak wajib `twinkle` terus-menerus.

### Saat berpindah halaman autentikasi

- Semua auth screen memakai aturan periode dan palet yang sama.
- Jangan restart animasi dari siang jika user pindah dari Login ke Daftar/OTP pada malam hari. Saat layar dibuka kembali, gunakan waktu terkini.
- Jika ada shared state/controller lintas route yang sudah tersedia, manfaatkan secara wajar; **tidak perlu membuat global singleton rumit**. Konsistensi scene lebih penting daripada mempertahankan frame animasi antar-route.

### Saat aplikasi background / resume

- Saat aplikasi di-background, **jangan mengandalkan timer dapat berjalan tepat waktu**; sistem mobile bisa menunda/suspend timer.
- Gunakan lifecycle (misalnya `WidgetsBindingObserver` / `AppLifecycleListener` sesuai implementasi aktual) untuk menghitung ulang segmen ketika aplikasi `resumed`.
- Bila segmen telah berubah saat background, sesuaikan ke periode yang benar ketika resume (transisi singkat diperbolehkan). Jangan menjalankan animasi yang tertinggal secara berurutan.
- `dispose()` seluruh timer, animation controller, observer, dan listener saat widget selesai dipakai.

### Saat pengaturan waktu perangkat berubah

- Jam perangkat adalah **sumber tampilan**, termasuk bila pengguna mengubahnya manual. Lakukan rekonsiliasi ketika aplikasi resume dan pada pemeriksaan berikutnya.
- Jadwalkan ulang boundary dari `DateTime.now()` setiap kali melakukan rekonsiliasi. Jika pembaruan manual jam terjadi saat foreground tanpa lifecycle event, tidak perlu menjanjikan deteksi instan; boleh gunakan satu *safety check* ringan (mis. tiap ±1 menit) bila diperlukan. **Dilarang polling setiap frame/tiap detik.**

## 6. Implementasi Flutter yang direkomendasikan

### Arsitektur ringan

Gunakan komponen/konsep berikut **jika tidak sudah ada** pada kode pasca-auth-redesign:

- `enum AuthHeaderPeriod { morning, day, evening, night }`.
- Fungsi pure `periodFor(DateTime localNow)` untuk pemetaan 4 segmen.
- `AuthHeaderPalette`/`AuthSkyScene`: data warna, opacity, dan posisi benda langit per periode.
- `AuthDynamicHeader`: widget stateful yang memegang current/target scene, timer boundary dan lifecycle listener.
- `AuthScenePainter`: adaptasi `_ScenePainter` existing agar menerima state visual terinterpolasi, dengan `shouldRepaint` / `repaint` yang benar ketika state scene berubah.

**Boleh menggunakan nama lain** bila struktur repository terbaru sudah memiliki komponen serupa. Pilih pendekatan minimal, mudah dirawat, dan tidak menambah dependency.

### Jadwal perubahan segmen

Prioritaskan **one-shot `Timer` menuju batas waktu terdekat**, bukan ticker yang membangun ulang halaman setiap detik:

1. Dapatkan `now = DateTime.now()` dalam zona lokal perangkat.
2. Hitung boundary terdekat berikutnya di antara `05:00`, `11:00`, `15:00`, `19:00` dan **05:00 hari berikutnya** bila jam sekarang sudah melewati 19:00.
3. Jadwalkan `Timer(boundary.difference(now), reconcile)` dengan durasi tidak negatif; jadwalkan ulang setiap reconcile.
4. Saat callback berjalan, **ambil ulang `DateTime.now()`**, hitung segmen yang benar, animasikan jika segmen berbeda, lalu pasang timer berikutnya. Jangan mengasumsikan callback selalu tepat karena scheduler mobile dapat delay.
5. Saat resume, cancel/recompute timer dan scene agar tidak memakai deadline lama.

Tambahkan pengaman sederhana agar interval nol tidak menyebabkan loop timer, terutama saat waktu clock diubah. Jangan membuat request jaringan atau server clock helper.

### Animasi

- Animasi default **800 ms** dengan `Curves.easeInOut`.
- Gunakan `AnimationController` / tween warna dan `Offset` seperlunya, atau `TweenAnimationBuilder` jika lebih sederhana.
- **Pertahankan bentuk `Path` pegunungan existing**; tween hanya warnanya.
- Interpolasikan gradient langit dengan jumlah stop/warna yang konsisten; interpolate alpha matahari/bulan dan bintang agar pergantian terasa natural.
- Untuk peralihan ke mode malam, sun fade-out dan moon fade-in; jangan tiba-tiba mengganti satu benda menjadi benda lain dengan hard switch.
- Gunakan `RepaintBoundary` atau `AnimatedBuilder` yang **hanya** melakukan repaint pada header; hindari `setState` parent `Scaffold` setiap frame.
- Perhatikan `MediaQuery.disableAnimations` / preferensi *reduced motion*: bila animasi dimatikan sistem, tampilkan state target langsung atau durasi minimal tanpa efek berat.
- Tidak ada animasi pergerakan awan/bintang sepanjang hari. Header **diam** ketika tidak berpindah segmen.

### Visual dan readability

- Identitas asli **gunung berlapis tetap sama**; perbedaan atmosfer berasal dari warna dan pencahayaan.
- Badge brand, judul hero, status bar (sinyal, jam, baterai) **harus tetap terbaca** pada semua mode. Gunakan contrast overlay/warna teks yang sesuai bila diperlukan; jangan mengorbankan branding.
- Matahari, bulan, bintang dan awan harus tidak menabrak status bar, punch-hole, maupun judul utama; hormati safe-area/top inset.
- Tinggi header, posisi teks, radius overlap, dan semua white sheet tetap seperti hasil Authentication UI Redesign.
- White sheet dan seluruh formulir **`#FFFFFF`**, tidak ikut gelap pada mode malam, **tidak ada gray card** atau panel berwarna tambahan.

## 7. File kandidat perubahan (bukan daftar mutlak)

| File / kandidat | Tindakan yang diperbolehkan |
|---|---|
| `lib/screens/user_login_screen.dart` | Temukan `_ScenePainter`, `_buildHeader` atau komponen penggantinya. **Refactor/migrasi seperlunya**, bukan tulis ulang auth screen. |
| `lib/screens/auth_presentation.dart` | Jika shared auth shell ada di sini, integrasikan dynamic header pada komponen yang sudah reusable. |
| `lib/widgets/auth_dynamic_header.dart` *(baru, opsional)* | Widget reusable, periode lokal, timer, controller, dan scene painter — hanya jika shared header belum tersedia. |
| `lib/screens/user_register_screen.dart` | Integrasi header **hanya** bila belum memakai shared header. |
| `lib/screens/forgot_password_screen.dart` | Integrasi header **hanya** bila belum memakai shared header. |
| `lib/screens/verify_reset_otp_screen.dart` | Integrasi header **hanya** bila belum memakai shared header. |
| `lib/screens/reset_password_screen.dart` | Integrasi header **hanya** bila belum memakai shared header. |
| Success/reset-success screen terbaru *(nama dari checkout lokal)* | Integrasi shared header bila relevan. |
| `docs/DESIGN.md` | **Read only** sebagai rujukan. Jangan menulis ulang audit desain untuk tugas ini. |
| `lib/services/auth_session.dart`, backend, config Firebase | **Do not modify**. |

Gunakan *shared widget* sehingga idealnya layar autentikasi tidak perlu disentuh satu per satu bila sudah mengonsumsi shared auth shell. Jangan menambah asset PNG/SVG atau dependency baru hanya untuk scene ini.

## 8. Agent dan Taste Skills — development only

1. **Wajib menunjuk agent `flutter_engineer`**; jika tersedia, baca `.codex/agents/flutter_engineer.toml` dari workspace lokal. Bila tidak tersedia, cari nama/path aktual yang ekuivalen dan jangan mengklaim telah membaca yang tidak ada.
2. **Wajib memakai Taste Skills untuk Mobile** (`design-taste-frontend` atau padanan lokal) **sebagai panduan development UI Flutter**: konsistensi palet, hierarki visual, contrast, spacing, motion yang tenang, dan reuse komponen.
3. `docs/DESIGN.md` dan hasil Authentication UI Redesign yang telah diimplementasikan adalah landasan visual sebelum menentukan warna final.
4. Skill **tidak ditugaskan membuat artifact terpisah**: tidak perlu menghasilkan mockup, image, screenshot, video, demo, laporan visual, deck, QA artifact, atau galeri state.
5. **Tidak perlu menjalankan ataupun menulis test** untuk task ini, dan **jangan menjadikan test/screenshot/visual verification sebagai dependency penyelesaian**. Scope yang diminta adalah development fitur. Jangan melaporkan PASS bila tidak dijalankan.
6. Jangan membuat commit Git otomatis, kecuali pemilik repository meminta secara eksplisit.

## 9. Kriteria selesai (berbasis implementasi, bukan instruksi test)

Fitur dianggap memenuhi brief ketika implementasi ditujukan untuk menghasilkan perilaku berikut:

- [ ] Hero menampilkan scene yang sesuai **waktu lokal device** dengan empat periode yang ditetapkan.
- [ ] Pergantian **04.59 → 05.00** serta **10.59 → 11.00**, **14.59 → 15.00**, **18.59 → 19.00** memicu transisi otomatis tanpa reload screen.
- [ ] Durasi transisi standar **800 ms**, easing halus, dan visual saat idle statis/hemat resource.
- [ ] Header diimplementasikan dengan **Flutter code / `CustomPainter`**, tanpa gambar baru, package animasi berat atau backend.
- [ ] Scene berubah lewat warna/cahaya/opacity benda langit **tanpa mengganti bentuk dasar gunung**.
- [ ] Semua halaman auth yang memakai shared header mendapatkan visual sesuai periode.
- [ ] White sheet form tetap **#FFFFFF** pada semua periode.
- [ ] Text controller, OTP, password, fokus, keyboard, scroll, dan navigation tetap utuh ketika header berubah.
- [ ] Resume dari background langsung merekonsiliasi segmen saat ini, dan seluruh timer/animasi dibersihkan saat widget dispose.
- [ ] Penanganan reduced motion dan status bar/safe area tidak mengorbankan keterbacaan.
- [ ] Tidak ada perubahan auth business logic, Laravel, Google OAuth, FCM, JWT, ataupun validasi keamanan.
- [ ] Tidak membuat test/screenshot/artifact QA/commit yang tidak diminta.

## 10. Instruksi eksekusi singkat untuk Codex

> Implementasikan PRD `docs/prd/PRD-Dynamic-Time-Based-Auth-Header-Wisata-Daerahku.md` pada Flutter terbaru. Kerjakan **setelah** Authentication UI Redesign sudah terintegrasi. Gunakan agent **`flutter_engineer`** dan **Taste Skills untuk mobile** sebagai panduan **development UI saja**. Baca **`docs/DESIGN.md`** pada checkout lokal; inspect implementasi shared auth header dan `_ScenePainter` aktual sebelum mengedit. Jadikan header **time-aware** dengan `DateTime.now()`, empat segmen (pagi 05:00, siang 11:00, sore 15:00, malam 19:00), transisi 800 ms, `Curves.easeInOut`, serta one-shot timer ke boundary berikutnya dan reconcile saat resume. Implementasi seluruhnya lokal Flutter; pertahankan background white sheet, form, business logic, dan route existing. **Development only:** tidak perlu test, screenshot, mockup, QA artifact, atau commit otomatis. Setelah coding, cukup ringkas file yang diubah dan perubahan fitur secara faktual; jangan mengklaim pengujian yang tidak dijalankan.

---

**Dokumen ini adalah PRD implementasi; belum mengubah source code repository.**
