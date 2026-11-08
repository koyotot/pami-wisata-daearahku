# V4 Addendum — Booking Success & Icon-Only Navigation

Tanggal: 2 November 2026. Implementasi pada working tree V4 existing, tanpa reset, commit, push, deploy, atau perubahan Laravel.

Referensi: `DESIGN.md`, `flutter-uiux-redesign-v4-handoff.md`, dan `prd/PRD_Addendum_V4_Final.md`. Nama `PRD-Addendum-V4-Booking-Success-Screen-Navigation.md` tidak tersedia; addendum final yang ada berisi spesifikasi yang diminta. DESIGN merupakan audit historis; token biru V4 dan approval addendum tetap menjadi acuan source terkini. Konfigurasi global flutter_engineer diperiksa. Implementasi utama oleh flutter_engineer, validasi independen qa_engineer, review arsitektur/security statis system_architect. Skill ponytail serta design-taste-frontend/references/app-screens digunakan; browser inspector bukan bukti Flutter.

## Perubahan dalam addendum ini

| File | Perubahan |
| --- | --- |
| `lib/screens/permintaan_terkirim_screen.dart` (baru) | Success standalone, judul tanpa Back, checkmark semantik hijau, summary server, CTA Riwayat/Beranda, session guard, scroll dan SafeArea. |
| `lib/screens/daftar_kunjungan_screen.dart` | `_onBooked` mengganti route sekali; menghapus inline success dan teks submit sukses disabled. |
| `lib/screens/main_navigation_screen.dart` | Menargetkan shell existing melalui navigator/identitas route dengan pemeriksaan session; membersihkan route di atasnya. |
| `lib/widgets/floating_bottom_nav.dart` | Menghapus seluruh label visual dan ruang label; Compass elevated, selected border/tint, tooltip/semantics, badge glyph Bell. |
| `test/user_booking_form_test.dart` | Regression submit/reconcile/replay/abandon, satu replacement, payload/key, false success, dan logout. |
| `test/v4_booking_success_navigation_test.dart` (baru) | Summary aktual, session stale/logout, CTA/back dengan shell nyata, semantics, count badge dan viewport sempit. |
| `test/v4_visual_test.dart` | Tap ikon menggantikan label visual lama. |
| `docs/visual/README.md`, `docs/visual/v4-components-{320,390,430}.png` | Render fixture komponen diperbarui untuk navbar icon-only. |

File dirty V4 lainnya sudah ada sebelum addendum ini. BookingIntent, business repository, API, auth dan state notifikasi tidak diubah.

## Navigation stack dan batas konfirmasi

Sebelum: shell → Detail → Booking. Setelah hasil server: shell → Detail → Permintaan Terkirim (`pushReplacement`, Booking dikeluarkan). `_completed` membatasi satu replacement di titik konvergensi `_onBooked` untuk submit langsung, 409 completed reconciliation, periksa hasil completed, safe replay, serta abandon yang ternyata completed.

Success memiliki `PopScope(canPop: false)` dan `automaticallyImplyLeading: false`. System Back menargetkan Beranda. CTA Riwayat menargetkan indeks 1, Beranda indeks 0. Helper memakai shell mounted pada navigator yang sama, route identity dan session valid, lalu `popUntil` shell: Detail/success dikeluarkan, IndexedStack dan elemen shell tetap sama. Tidak membuat MainNavigationScreen kedua. Bila tidak ada shell cocok, fallback kembali ke route pertama existing.

Generation sesi ditangkap sebelum deferred route builder dan diteruskan ke success. Session generation/auth/device readiness/role diperiksa saat inisialisasi dan perubahan sesi; session invalid menyembunyikan booking sebelum kembali ke root. Success tidak melakukan POST, reconcile, atau mutation API. Error 422, unresolved 409, unknown outcome dan pending intent tetap di form. Original payload/key replay tidak berubah.

## Pemetaan data server

`Booking` hasil repository/BookingIntent diteruskan langsung ke success, tanpa memakai angka wireframe atau menghitung status lokal:

| UI | Data |
| --- | --- |
| Nama destinasi | `booking.destinationName` (`destination_name`) |
| Tanggal kunjungan | `booking.visitDate` (`visit_date`) |
| Jumlah | `booking.quantity` (`quantity`) |
| Status | `bookingStatusLabel(booking.status)` dari `status` server |
| Nomor booking bila tersedia | `booking.bookingNumber` (`booking_number`) |

Confirmed outcome berarti keberadaan booking dikonfirmasi server, bukan memaksa status literal `confirmed`. Test menunjukkan status awaiting_payment/rejected/cancelled tetap mengikuti respons server, serta quantity 5 dan nama server yang berbeda dari form.

## Navbar dan aksesibilitas

Urutan Home, Ticket/History, Compass, Bell, User tetap. Tidak ada Text label yang menempati layout; hanya angka badge yang terlihat. Floating blur, rounded corners, shadow dan SafeArea dipertahankan. Compass biru lebih tinggi 8dp; selected memakai border navy, tab biasa memakai tint biru. Setiap tombol memiliki semantics nama/selected/button dan tooltip, dengan target minimal 48dp.

Badge memakai `Stack(clipBehavior: Clip.none)` yang membungkus glyph Bell dan `Positioned(top: -5, right: -7)`, oranye `#FF9800` dengan angka putih: 0 hilang, 1–99 asli, 100+ `99+`. Angka badge tidak di-scale agar glyph tetap terlihat; semantics mengumumkan jumlah penuh. Sumber unread NotificationState/API existing tetap. Navbar hanya milik lima root tab; Detail, Booking, success tidak menampilkannya. Keyboard hiding dan Android Back tab existing dipertahankan.

## Verifikasi akhir

| Pemeriksaan | Hasil |
| --- | --- |
| Targeted enam file booking/intent/success/navbar/visual/widget | **PASS 45 test** |
| `flutter test --no-pub` | **FAIL: 338 PASS, 1 SKIP, 1 FAIL**; satu kegagalan auth historis di bawah |
| `flutter analyze --no-pub` | **FAIL lint: 152 temuan, 0 error, 3 warning, 149 info** |
| Perbandingan analyzer terhadap arsip HEAD | **0 temuan baru**; HEAD 175 → working tree 152, dibanding path/rule/pesan/jumlah tanpa nomor baris |
| `dart format --output=none --set-exit-if-changed` tujuh Dart addendum | **PASS, 0 changed** |
| `git diff --check` | **PASS** |
| Review arsitektur/security statis | **Tidak ada blocker tersisa pada scope yang diperiksa** |
| QA independen dengan capture fixture | **PASS 15 test** (success/navigation, notification, visual) |
| Android debug current APK | **Build/install dan login smoke teramati**; CLI exit 1 akibat PowerShell menangkap warning KGP existing, bukan clean command PASS |

Targeted: `user_booking_form_test.dart`, `booking_intent_test.dart`, `v4_booking_success_navigation_test.dart`, `v4_navigation_notifications_test.dart`, `v4_visual_test.dart`, `business_booking_widgets_test.dart`.

Satu full-suite failure: `auth_prd_redesign_test.dart` / `scrolled header stays below status bar on narrow scaled viewport`, expected 44, actual 0. Direproduksi pada arsip HEAD di direktori TEMP terpisah: 4 PASS, 1 FAIL pada test yang sama. Full suite sebelum addendum juga 325 PASS, 1 SKIP, 1 FAIL yang sama. Modul auth tidak diperbaiki di luar scope.

Test membuktikan tidak ada inline success/Back/navbar di success, CTA/system Back memakai shell yang sama dan membersihkan route intermediate, satu replacement untuk outcome confirmed termasuk replay/reconcile/abandon, duplicate tap hanya satu POST, error bukan false success, dan replay key/fields identik. Layout success serta badge diuji pada 320/390/430dp dengan text scale 1.8, nama panjang dan SafeArea. Reduced motion/IndexedStack/keyboard behavior existing dipertahankan; bukti widget bukan bukti predictive-back/TalkBack native.

## Bukti visual, batas perangkat, dan DoD

Lihat `visual/README.md` dan render fixture komponen 320/390/430. Ini Flutter renderer dengan data uji berlabel, bukan screenshot success Android atau integrasi server. Font capture Arial; fallback bendera Windows tetap terbatas.

Android: `flutter run -d emulator-5554 --debug --no-resident --dart-define-from-file=.env.development` menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`, memasang APK, dan menampilkan login. Screenshot nyata tersedia di [Android login smoke](visual/v4-addendum-android-login.png). Ini hanya bukti aplikasi berjalan, bukan bukti feature success/navbar. Percobaan awal tanpa konfigurasi ditolak AppConfig; retry memakai file konfigurasi existing. Log pada `%TEMP%/v4-addendum-android-configured-run.log`; warning KGP berasal dari konfigurasi/plugin existing dan tidak diperbaiki di luar scope.

Implementasi dan regression checks dalam scope selesai. **DoD perangkat/visual belum lengkap:** perlu sesi pengunjung valid untuk alur booking server nyata, screenshot success/navbar Android, transisi tanpa flash hijau, predictive-back/gesture, TalkBack, status/navigation bars dan keyboard native. Emulator Android tersedia, tetapi tidak ada sesi pengunjung aktif; tidak dilakukan booking remote atau injeksi data mock ke production UI. Tidak ada klaim production-ready.
