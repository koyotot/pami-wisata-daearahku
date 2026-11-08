# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Wisata Daerahku — Total Iconography Migration to Phosphor V1

**Status:** APPROVED BRIEF / READY FOR CODEX IMPLEMENTATION (belum diimplementasikan oleh dokumen ini)
**Tanggal:** 7 November 2026 (Asia/Jakarta)
**Repository:** https://github.com/koyotot/pami-wisata-daearahku
**Remote `main` saat audit:** `3fbf22b6a70c11dd4544c64db7550e484c64e5c7` — `feat(admin): redesign role 1 dashboards and destination management`
**Aplikasi:** Flutter Android (dengan kode UI shared untuk platform lain)
**Roles:** User (`role=0`), Admin (`role=1`), Superadmin (`role=2`)
**Dependency pilihan:** `phosphor_icons: ^3.0.1` (fork FuncCloud, MIT; kompatibel Flutter 3.43+/3.44; verifikasi Flutter SDK lokal sebelum mengunci versi)
**Dokumen eksternal:** https://pub.dev/packages/phosphor_icons ; https://pub.dev/documentation/phosphor_icons/latest/ ; https://github.com/funccloud/phosphor-icons ; https://phosphoricons.com

---

## 1. Tujuan dan definisi selesai

Ganti **seluruh ikon antarmuka fungsional milik aplikasi** yang sekarang memakai `Icons.*` Material, `CupertinoIcons.*` (jika ditemukan), ikon buatan `CustomPainter` untuk tombol/navigasi, atau aset ikon internal yang merepresentasikan aksi/menu/status, menjadi satu keluarga visual **Phosphor Icons**. Migrasi berlaku lintas semua layar aktif role 0, 1, dan 2, termasuk login/OTP, seluruh bottom navigation, destinasi, pemesanan, tiket, pembayaran demo, notifikasi, profil, scanner, kalender, edit/CRUD, dan modal.

**Definition of Done (DoD) tanpa menjalankan QA:**
1. Ada satu dependency Phosphor yang telah dikunci bersama lockfile (`pubspec.yaml`/`pubspec.lock`) dan satu import path yang konsisten: `package:phosphor_icons/phosphor_icons.dart`.
2. Semua ikon UI fungsional milik aplikasi menggunakan `PhosphorIconsRegular`, `PhosphorIconsFill`, atau style Phosphor relevan; tidak tersisa `Icons.*`/`CupertinoIcons.*` untuk ikon aplikasi di `lib/` kecuali pengecualian **yang tercatat jelas dan beralasan** (contoh API pihak ketiga memaksa glyph tertentu, bukan preferensi personal).
3. `_NavIconPainter` dan `_OperationsIconPainter` untuk menggambar glyph navbar manual digantikan dengan icon data Phosphor; visual floating navbar, posisi center elevated, perubahan tab, dan semantics tetap sama.
4. Selected = **Fill**, unselected = **Regular** untuk item navigasi; ikon aksi/metadata/form default **Regular**, ikon status/empty state mengikuti panduan §5.
5. Hanya representasi gambar ikon yang berubah; data, API, repository, auth, roles, payment, booking, QR, permissions, rules, state, dan navigasi **tidak berubah**.
6. Perubahan berlaku pada semua entry point dan komponen shared, bukan hanya jalur visual paling populer. Laporkan file dan icon mapping yang diganti serta pengecualian yang tersisa.
7. Sesuai permintaan pengguna: **TIDAK ADA QA, REGRESI, TESTING, `flutter test`, `flutter analyze`, `flutter run`, `flutter build`, emulator/screenshot testing, atau delegasi `qa_engineer` dalam eksekusi ini.** Hanya format, inspeksi sumber, pengecekan diff, dan pembaruan dependency sebagai tugas implementasi.

**Bukan scope:** redesign layout, perubahan warna/font/theme utama, perubahan behavior action button, perubahan layar V3 Kelola/Preview, pembaruan backend Laravel, feature baru, penulisan ulang custom painter non-ikon, penggantian logo brand/gambar destinasi/QR bitmap, atau icon-library campuran.

## 2. Baseline yang telah diaudit

- Pada remote `main` terbaru terdapat file UI untuk auth/visitor, operasi Admin/Superadmin, editor, laporan, scanner, peta, dan shared widgets. `pubspec.yaml` belum mendeklarasikan Phosphor; saat audit masih ada `cupertino_icons`, `flutter_svg`, `google_fonts`, dan Material.
- `lib/widgets/floating_bottom_nav.dart` menggambar ikon secara manual melalui `_NavIconPainter` dan `_OperationsIconPainter` (bukan memakai library ikon). **Ini prioritas tertinggi** karena terlihat di semua role.
- `lib/screens/operations_presentation.dart`, `operations_home.dart`, `operations_reports.dart`, `operations_filters.dart`, `operations_financial.dart`, `operations_booking_screen.dart`, dan `operations_queue_screen.dart` masih memakai `Icons.*`.
- `lib/screens/daftar_wisata_screen.dart` (Kelola Terpadu/Preview), `detail_wisata_screen.dart` (UI detail pengunjung), `tambah_wisata_screen.dart` (form editor), dan `kelola_kuota_screen.dart` (kuota) memakai `Icons.*`; **tetap pertahankan pemisahan Preview read-only vs Kelola yang baru**.
- Sisi user menggunakan `Icons.*` di auth, Beranda, Jelajah, detail, kalender, Riwayat/tiket, notifikasi, profil, avatar, dan galeri.
- `lib/screens/home_screen.dart` memiliki `_ScenePainter` dan `auth_presentation.dart` memiliki painter scenic; keduanya **ilustrasi**, bukan ikon menu, dan tidak perlu dipindah.
- `lib/widgets/profile_avatar.dart` memiliki `_AvatarCropOverlay`: crop guide tidak termasuk ikon. `DestinationHeroGallery` serta QR SVG bukan replacement glyph.
- Audit sumber menggunakan branch remote saja. **Codex wajib memeriksa HEAD, status lokal dan perubahan uncommitted sebelum mengubah apa pun**; jangan reset/checkout/force-update yang membuang perubahan pengguna.

## 3. Aturan pemilihan package dan kompatibilitas

Pakai `phosphor_icons: ^3.0.1` dari FuncCloud, **bukan** `phosphor_flutter ^2.1.0` yang tidak ditargetkan ke Flutter 3.43+ dan **bukan** `phosphoricons_flutter` kecuali blocker dependency terukur dan disetujui pengguna. Source resmi paket tersedia di pub.dev dan GitHub; package ini adalah community-maintained fork.

Contoh API yang didokumentasikan oleh maintainer:

```yaml
dependencies:
  phosphor_icons: ^3.0.1
```

```dart
import 'package:phosphor_icons/phosphor_icons.dart';

const Icon(PhosphorIconsRegular.house, size: 24);
const Icon(PhosphorIconsFill.house, size: 24);
const PhosphorIcon(PhosphorIconsDuotone.star, size: 32);
```

Untuk penggunaan biasa, `Icon(PhosphorIconsRegular.xxx)` boleh dipakai tanpa mengganti widget existing. Gunakan `PhosphorIcon` khusus **Duotone** karena icon dua-layer tidak dirender setara oleh widget `Icon` bawaan. **Dahulukan class style-spesifik** (`PhosphorIconsRegular`/`PhosphorIconsFill`) untuk tree shaking; jangan gunakan selector style dinamis kalau tidak diperlukan. **Semua nama property yang dipakai harus diperiksa terhadap definisi ikon terpasang di package lokal**; tabel mapping §5 adalah maksud semantik, bukan jaminan identifier Dart tersedia persis.

`flutter pub get` diperlukan untuk resolusi dependency/lockfile dan **bukan** QA/testing. Jika dependency terkendala akses jaringan, laporkan blocker; jangan mengarang lockfile, menyalin font, atau mengganti diam-diam ke versi lama yang tidak kompatibel.

## 4. Hierarki visual dan design tokens

| Elemen | Ketentuan |
|---|---|
| Bottom navigation inactive | Phosphor **Regular**, 24–26dp, warna muted lama |
| Bottom navigation active | Phosphor **Fill**, 24–26dp, biru lama; khusus center raised icon berwarna putih |
| Header back/menu/search/notification | **Regular** 22–24dp; ukuran container/tap target existing dipertahankan |
| Tombol aksi, input, picker, dropdown, dialog | **Regular** 18–22dp, `IconButton`/`InputDecoration` existing tetap |
| KPI / metrics | **Regular** 22–24dp; Duotone boleh hanya pada dekoratif summary/empty state, bukan setiap card |
| Status info/sukses/peringatan/bahaya | Phosphor Regular/Fill sesuai emphasis; **makna warna dan teks** tetap terlihat |
| Empty states | Regular 32–40dp atau Duotone 40–56dp jika ditata sebagai satu ilustrasi ikon |
| Category/facility/amenity icons | Regular 18–24dp dengan siluet semantik sesuai kategori, bukan dipakai asal |
| Disabled/loading | Ikon tetap satu keluarga; state dan opacity existing, tidak ditambah animasi |
| Semantics / accessibility | Pertahankan `Tooltip`, `Semantics`, label, focus order, tombol 48dp dan `onTap`; icon dekoratif tidak perlu label duplikat |

**Warna identitas yang tidak diganti:** blue `#1976D2`, navy `#102D59`, background `#F5F8FD`, border `#DCE4F0`, Plus Jakarta Sans. Jangan ubah scenic header berdasarkan waktu atau floating shell.

### Aturan navbar lintas role (tetap 5 slot dan fungsinya)

| Slot | User role 0 | Admin role 1 | Superadmin role 2 |
|---|---|---|---|
| 0 | Beranda → House | Beranda → House | Ringkasan → Chart/House (pilih makna paling jelas) |
| 1 | Riwayat → Ticket | Booking → Ticket | Operasi → Clipboard/List |
| 2 | Jelajah → Compass (center raised) | Scan QR → QR Code (center raised, tap membuka scanner) | Analitik → Chart Bar (center raised/tab sebenarnya) |
| 3 | Notifikasi → Bell | Destinasi → Map Pin/Mountains | Kelola → Squares Four/Gear |
| 4 | Profil → User Circle | Profil → User Circle | Profil → User Circle |

Ikon aktif berubah dari `Regular` ke `Fill`. Tombol center tetap **background biru + ikon putih** sesuai desain V4, dan tidak boleh berubah dari modal scanner menjadi tab biasa atau sebaliknya. Semantics tab yang diperbaiki oleh commit QA sebelumnya (`onTap`) harus tetap dipertahankan; **jangan kembali memakai painter lama atau menghilangkan aksi untuk screen reader**.

## 5. Mapping semantik komponen (wajib diterapkan secara menyeluruh)

**Catatan**: pilih properti Phosphor yang benar-benar ada dalam versi dependency terpasang. Nama dalam kolom “Konsep” adalah target makna; bila nama literal tidak ada, cari padanan dalam koleksi Phosphor dan catat dalam matriks hasil.

| Domain | Komponen/aksi | Konsep Phosphor |
|---|---|---|
| Navigasi | Beranda, Riwayat, Jelajah, Notifikasi, Profil | house, ticket, compass, bell, userCircle |
| Admin nav | Scan QR, Destinasi, Analitik, Kelola | qrCode, mapPin, chartBar, squaresFour |
| Aksi dasar | Kembali, kanan, bawah, tutup, tambah, hapus, ubah | arrowLeft, caretRight, caretDown, x, plus, trash, pencilSimple |
| Search/filter | Cari, tidak ditemukan, filter, reset pencarian | magnifyingGlass, magnifyingGlassMinus, slidersHorizontal, x |
| Kalender/periode | Kalender, jadwal, sebelumnya/berikutnya | calendarBlank, calendarCheck, caretLeft, caretRight |
| Booking/tiket | Ticket, grup/jumlah, harga, salin, kirim | ticket, users, currencyCircleDollar/coins, copy, paperPlaneTilt |
| Workflow claim | Menunggu, disetujui, ditolak, expired, locked | clock, checkCircle, xCircle, timer, lock |
| Akses & error | Warning, info, no network, disabled, refresh-state indicator | warningCircle, info, wifiSlash, prohibition, arrowsClockwise |
| Profil/auth | User, mail, password, show/hide, logout | userCircle, envelope, lockKey, eye, eyeSlash, signOut |
| Favorite/review | Disimpan, belum disimpan, rating, review | heart fill/regular, star fill/regular, chatText |
| Galeri | Foto, tambah foto, album, fullscreen, kamera | image, imageSquare, images, arrowsOut, camera |
| Lokasi/map | Pin lokasi, lokasi saya, arah, peta | mapPin, crosshair, navigationArrow, mapTrifold |
| Kategori wisata | Alam, budaya, bahari, kuliner, kota | tree/leaf, bank, sailboat/waves, forkKnife, buildings |
| Fasilitas wisata | Toilet, Wi-Fi, parkir, aksesibilitas | toilet, wifiHigh, car, wheelchair |
| Admin CRUD | Edit, nonaktif, aktifkan, stok/kuota | pencil, eyeSlash, arrowCounterClockwise, calendarCheck |
| Keuangan demo | Wallet, pembayaran, transaksi, status | wallet, money, receipt, checkCircle |
| Scanner | Kamera, senter hidup/mati, check-in, preview | camera, flashlight, flashlightSlash, checkCircle, eye |
| Notifikasi | Bel, selesai, alert, menuju detail | bell, checks, warningCircle, caretRight |

### 5.1 Catatan non-regresi visual/fungsional spesifik

- `floating_bottom_nav.dart`: ganti **hanya painter glyph** menjadi ikon Phosphor; jangan mengubah labels, index, badges, tapping, tooltip, semantics, center geometry, blur, atau role switch. Jika painter sudah tak dipakai setelah migrasi, hapus kelas painter-nya saja.
- `operations_navigation_shell.dart` dan `operations_tabs.dart`: jaga mapping tab role/center scan QR dan lifecycle/TickerMode.
- `operations_reports.dart`, `operations_home.dart`, `daftar_wisata_screen.dart`: pertahankan management hub, tombol **Preview** vs **Kelola**, read-only preview, segmented Kinerja/Kelola, dan filter state.
- `detail_wisata_screen.dart`: jangan menghidupkan kembali booking dari Preview Admin; migrasi ikon tidak membolehkan perubahan guard.
- `operations_booking_screen.dart` dan `approval_queue_state.dart`: tidak boleh mengubah claim, retry/idempotency key, server authorization, atau HTTP handling.
- `admin_ticket_scanner_screen.dart` dan `ticket_scanner_state.dart`: jangan mengubah QR/scope/confirm/preview lifecycle. Temuan historis D-003 stale scanner dari QA terdahulu **bukan scope migrasi ikon**; jangan menyembunyikan/menghapus failing test atau mengklaim sudah fixed.
- `availability_calendar.dart`/custom date-range: mengganti panah/lock/calendar glyph saja, tidak menyentuh timezone, date selection atau 366-day guard.
- `profile_avatar.dart`: ganti camera/edit/close icons; jangan menyentuh crop overlay/pinch zoom.
- `international_phone_field.dart`: ganti dropdown/search/check; bendera negara **tetap**.
- `destination_location_map_preview.dart` dan picker peta: ganti app-provided pin/location glyph; **jangan** mengganti peta/tile/Google Maps branding.
- `booking_ticket_qr_section.dart`: jangan mengganti SVG/QR asli dengan ikon.

## 6. Penanganan pengecualian (wajib dan terbatas)

**Tetap:** foto destinasi, hero/scenic illustration `AuthMountainPainter`/`_ScenePainter`, chart/path data visualisasi, `_AvatarCropOverlay`, dashed ticket divider, QR payload/bitmap/SVG, peta tiles dan koordinat, logo Google pada `assets/images/google_g.png`, logo app, bendera telepon, serta elemen kontrol sistem yang benar-benar dibuat OS/SDK pihak ketiga dan tidak dikendalikan langsung oleh Flutter UI.

**Ganti:** semua glyph aksi/status/dekoratif yang memang berfungsi sebagai ikon antarmuka, termasuk ketika kini diimplementasikan dengan `CustomPainter` (mis. `_NavIconPainter`, `_OperationsIconPainter`), `IconData` map, `InputDecoration.prefixIcon/suffixIcon`, dropdown, FAB, button, badge, bottom sheets, SliverAppBar leading/actions, serta fallback image/empty state.

Untuk ikon dari package pihak ketiga yang tidak dapat dioverride tanpa forking package, jangan mengubah dependency/internal SDK. Laporkan sebagai **EXCEPTION** dengan file, alasan, dan dampaknya; jangan klaim 100% tanpa bukti cakupan.

## 7. Inventaris modul prioritas (semua wajib ditelusuri kembali saat implementasi)

**P0 — Global & shared navigation:**
- `lib/widgets/floating_bottom_nav.dart`
- `lib/widgets/operations_tabs.dart`
- `lib/widgets/operations_chrome.dart`
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/operations_navigation_shell.dart`
- `lib/theme/app_colors.dart`, `lib/main.dart` (jika memang memegang konfigurasi IconTheme; jangan ubah Georgia global, font tetap Plus Jakarta di role operations)

**P1 — Visitor/Auth:**
- `lib/screens/auth_presentation.dart`, `user_login_screen.dart`, `user_register_screen.dart`, `forgot_password_screen.dart`, `verify_email_otp_screen.dart`, `verify_reset_otp_screen.dart`, `reset_password_screen.dart`, `admin_login.dart`
- `lib/screens/beranda_user_screen.dart`, `home_screen.dart`, `cari_wisata_screen.dart`, `detail_wisata_screen.dart`, `daftar_kunjungan_screen.dart`, `bukti_pendaftaran_screen.dart`, `permintaan_terkirim_screen.dart`, `notifikasi_screen.dart`, `profil_user_screen.dart`

**P2 — Admin/Superadmin operations:**
- `lib/screens/admin_common.dart`, `admin_dashboard.dart`, `admin_ticket_scanner_screen.dart`, `daftar_pendaftar_screen.dart`, `daftar_wisata_screen.dart`, `tambah_wisata_screen.dart`, `kelola_kuota_screen.dart`, `kelola_admin_screen.dart`, `kelola_fasilitas_screen.dart`, `kelola_kategori_screen.dart`, `destination_admin_assignments_screen.dart`
- `lib/screens/operations_dashboard.dart`, `operations_home.dart`, `operations_booking_screen.dart`, `operations_filters.dart`, `operations_financial.dart`, `operations_presentation.dart`, `operations_queue_screen.dart`, `operations_reports.dart`, `demo_checkout_screen.dart`

**P3 — Widgets, media dan map:**
- `lib/widgets/availability_calendar.dart`, `admin_destination_gallery_editor.dart`, `booking_payment_section.dart`, `booking_ticket_qr_section.dart`, `destination_hero_gallery.dart`, `destination_location_map_preview.dart`, `api_image.dart`, `profile_avatar.dart`, `reviews_sheet.dart`, `international_phone_field.dart`, `payment_deadline.dart`
- `lib/screens/destination_location_picker_screen.dart`, `destination_map_screen.dart`

**P4 — Semua sisa `lib/**/*.dart`:** lakukan scan menyeluruh juga pada file di luar daftar di atas (termasuk file baru setelah baseline) sebelum menyatakan migrasi total. `IconData` dan parameter ikon dinamis perlu diperiksa walau tidak ada literal `Icons.` di file tersebut.

## 8. Alur kerja implementasi, agents, dan skills

1. Preflight: periksa `git status --short`, `git rev-parse HEAD`, `git log -1`, `pubspec.yaml`, SDK Flutter, AGENTS precedence dan perubahan lokal. **Tidak boleh** reset, clean, stash paksa, branch rewrite, commit/push tanpa izin.
2. Baca `C:\Users\itsba\.codex\Agents.md` dan inventory `C:\Users\itsba\.codex\agents` serta aturan repo `AGENTS.md` jika ada. Maksimal **2 agents** aktif: `flutter_engineer` untuk migrasi source; `ui_ux_engineer` / `system_architect` hanya jika tersedia untuk pemetaan style read-only. Jangan melibatkan `qa_engineer` karena pengguna menolak QA/testing untuk fase ini.
3. Discovery skills: `C:\Users\itsba\.agents\skills`, `C:\Users\itsba\.codex\skills`, `.agents\skills`, `.codex\skills`, dan daftar skills yang disediakan CLI runtime. **Baca SKILL.md** sebelum menerapkan tiap skill relevan. Kandidat: `design-taste-frontend`, `ui-ux-pro-max`, `flutter-custom-design-system`, `flutter-improving-accessibility`, `impeccable`, `humanizer`, `ponytail` / `code-simplification`. Nama hanyalah kandidat; **jangan mengaku installed/used jika tidak ditemukan**.
4. Inventaris **semua** glyph: `Icons.`, `CupertinoIcons.`, `IconData`, custom nav glyph painter, `SvgPicture` yang dipakai sebagai ikon, image icon khusus, `Icon`, `IconButton`, `InputDecoration`, bottom nav. Simpan matriks before→after untuk review internal (bukan QA).
5. Tambahkan dependency Phosphor yang kompatibel dan dapat di-resolve, perbarui lockfile menggunakan `flutter pub get` jika environment siap. Jangan memodifikasi package internals.
6. Implementasi urut P0→P1→P2→P3→P4; standardisasi selected/inactive, penggantian icon dataset, penghapusan painter glyph yang tidak lagi digunakan. Hindari wrapper besar/abstraksi tanpa kebutuhan.
7. Static completeness inspection: cek literal Material/Cupertino dalam `lib`, cek import Phosphor yang tak terpakai, check perubahan icon helper, `dart format` pada file berubah, `git diff --check`. Ini **inspeksi statis minimum**, bukan QA, test, atau analyzer.
8. Laporan akhir berisi: baseline SHA, package resolved/version, jumlah file diubah, migrasi per role/domain, daftar perubahan/exception, skill yang benar-benar dibaca, hasil format/diff check jika dilakukan, dan transparansi bahwa QA/testing/analyze/build **tidak dijalankan**. Tinggalkan working tree dirty, tanpa commit/push.

## 9. Acceptance criteria terukur (melalui code review/inspection, **bukan tes**)

| ID | Kriteria |
|---|---|
| IC-01 | Semua `lib/**/*.dart` yang punya ikon Flutter UI diperiksa, termasuk entry legacy dan helper `IconData` |
| IC-02 | Single Phosphor dependency; tidak ada font/icon pack sekunder baru |
| IC-03 | Bottom nav role 0/1/2 menggunakan regular vs fill; semantics/tab order/center unchanged |
| IC-04 | Komponen auth/visitor/profile/ticket/map/form/list/status sudah Phosphor |
| IC-05 | Komponen Admin/Superadmin dashboard, queue, action center, analytics, finance demo, scanner, CRUD sudah Phosphor |
| IC-06 | Preview Pengunjung Admin tetap read-only, Kelola aksi tetap utuh |
| IC-07 | Custom-painted glyph navigation dihapus; painters ilustrasi/grafik tetap |
| IC-08 | IconData mapping dinamis dan fallback ikon sudah diganti |
| IC-09 | Properti Dart Phosphor diverifikasi terhadap package ter-install; tidak ada nama guessed tanpa pengecekan |
| IC-10 | Semua pengecualian dicatat secara eksplisit; tidak ada klaim 100% bila masih ada pengecualian produk |
| IC-11 | Tidak ada QA, regression, test, analyze, emulator, build, screenshot QA |
| IC-12 | Tidak commit/push/reset; perubahan pengguna dan status Git lokal terjaga |

## 10. Risiko yang harus diantisipasi (tanpa menjalankan pengujian)

- Package Phosphor tertentu memakai API berbeda dari blog/tutorial lama; pin `phosphor_icons ^3.0.1` dan verifikasi class/getter pada paket yang terpasang.
- Font glyph mungkin memiliki optical bounds berbeda dari custom painter; **jangan ubah layout** demi membuatnya identik pixel-perfect. Jaga ukuran, padding dan alignment existing.
- Mengganti `Icons.*` lewat regex global bisa merusak maksud ikon dan penggunaan `const`; migrasi harus berdasarkan semantics dan setiap call site.
- `IconData` yang disimpan pada map/tuple/set memerlukan anggota `PhosphorIconsRegular.<name>` valid; hindari membangun nama ikon dari string jika tidak benar-benar perlu.
- InkWell/semantics navbar pernah diperbaiki di QA, harus tetap menjaga onTap dan Tooltip.
- **D-003 scope scanner** dan **D-004 kontras legacy** yang dilaporkan dalam QA terdahulu bukan otomatis diperbaiki oleh migrasi ikon. Jangan claim resolved.
- Tanpa QA/testing/analyze/build, hasil implementasi **tidak bisa dilabeli release-ready** dan mungkin menyisakan issue runtime/asset. Transparan dalam handoff.

## 11. Referensi sumber

- Repo Flutter (baseline diaudit): https://github.com/koyotot/pami-wisata-daearahku/commit/3fbf22b6a70c11dd4544c64db7550e484c64e5c7
- Phosphor package: https://pub.dev/packages/phosphor_icons
- Phosphor API: https://pub.dev/documentation/phosphor_icons/latest/
- Phosphor repository: https://github.com/funccloud/phosphor-icons
- Phosphor catalog: https://phosphoricons.com
