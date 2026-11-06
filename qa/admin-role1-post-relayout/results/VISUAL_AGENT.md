# Visual/UX/Android review

Agent aktual: `flutter_engineer` (`/root/visual_android_qa`). Scope: baca source/docs, inspeksi preview, discovery Android; tanpa perubahan lib/test atau koneksi API. Review pada HEAD `48ab11c0a14fafa9d60383ee0c27530d675358de`.

## Hasil dan batas bukti

Visual fidelity Flutter A00-A11 = NOT VERIFIED. Dua preview committed benar-benar dilihat dengan `view_image`; preview tersebut adalah HTML V1, bukan render aplikasi Flutter. Pemeriksaan awal ini kemudian dilanjutkan dengan Android read-only login smoke di bawah. Sepuluh screenshot perangkat dibuat; semuanya login tanpa autentikasi. Admin A00-A11, TalkBack, font fisik role1, dan dock/calendar tetap belum diverifikasi di device.

`flutter emulators` exit 0: satu AVD `Pixel_7` (Google, android). SDK ada di `C:/Users/itsba/AppData/Local/Android/Sdk`. `adb devices -l` exit 0 menampilkan daftar kosong; `emulator -list-avds` exit 0 menghasilkan `Pixel_7`. Pilihan ini dikirim ke main sebelum launch; agent ini tidak menyalakan emulator atau aplikasi.

## Pemeriksaan sumber terhadap V1

| Kasus matrix | Bukti source yang diperiksa | Batas kesimpulan |
|---|---|---|
| QA-006 | `operations_chrome.dart:30` reuse `TimeBasedScenicBackground`; `auth_presentation.dart:368-370`, `:505`, `:518` memetakan 05/11/15/19, menjadwalkan boundary dan reconcile saat resume; reduced motion memakai disableAnimations | Implementasi ada; tidak mengklaim lifecycle Android lulus |
| QA-007 | `OperationsTheme` role==1 memasang `AppColors.operationsTheme`; theme Jakarta ada di `app_colors.dart:16-20`; sheet filter/picker/calendar dan booking review explicit themed; nested CRUD dialogs dibungkus OperationsTheme | Root main overlay hanya role0 yang themed (`main.dart:94-105`). Snackbar dan route flight role1 masih perlu widget/device repro; root Georgia sendiri bukan bukti kegagalan |
| QA-008/009 | Dashboard hierarchy summary + metrics, two tabs; `OperationsMetrics` memakai Wrap dan width responsif, label wrap; stacked saat width<250 atau scaler14>20 | Komposisi source diperiksa terhadap preview; tidak ada fidelity score numerik tanpa render Flutter |
| QA-010/012 | `operations_filters.dart:134-144`, `:169-170`, `:344`: role1 selalu custom filters/calendar; DropdownButtonFormField dan showDateRangePicker berada pada fallback role!=1 | Pertahankan fallback role2; perilaku klik perlu tests main |
| QA-011/016 | Custom destination picker mengambil `adminDestinations(status=all)` via server-scoped endpoint, iterasi pagination, local search, session generation guards, clearing private results, RefreshIndicator AlwaysScrollable; sheet memperhitungkan viewInsets | Assigned-only tetap membutuhkan kontrak server/mock. Keyboard nyata belum diverifikasi |
| QA-017 | Semua occurrence refresh pada booking/finance/presentation/queue/legacy ditelusuri role condition. Role1 memakai pull-refresh; fallback refresh role2 terpelihara. Retry kamera/unknown check-in adalah tindakan pemulihan spesifik, bukan manual refresh data | Tidak membenarkan menghapus tombol retry mutasi atau kamera. Semua states perlu widget/device evidence |
| QA-021/022/025/027 | Booking review decision sheet explicit themed, safe area, scroll, viewInsets; confirm bergantung canDecide; claim options sekunder; dock SafeArea dan Expanded primary. OperationsPage memakai bottomNavigationBar, bukan overlay konten | Timer expiry refetch dan concurrency perlu tests. Dock/IME/back device belum diverifikasi |
| QA-029/030 | Destinasi Kinerja/Kelola dan routes ke CRUD/kuota ada; role1 add wrapped OperationsTheme; daftar wisata membungkus detail; quota AdminPage role diteruskan | Nilai API/permission bukan bukti dari style; cek tests main |
| QA-032/033 | Scanner source mempertahankan preview lalu canConfirm, explicit confirm, rescan guard uncertain; role1 scoped error pull-refresh; permission retry dan app settings tersedia | Kamera/QR E2E tidak dijalankan karena BLOCKED_NO_ISOLATED_ADMIN_SESSION; kemampuan hardware belum diverifikasi |
| QA-034/035 | Role1 daftar pendaftar: horizontal scroll ChoiceChip Semua + kBookingStatuses, text scaling tetap aktif; route detail selalu OperationsBookingScreen | Semantics/overflow/gesture aktual belum diverifikasi |
| QA-036 | Demo/Test-only disclosure eksplisit pada finance preview dan provenance; production juga memiliki provenance sendiri sesuai environment | Tak ada API/uang nyata diakses agent ini |
| QA-037/040/041 | Shell role1 lima tabs Beranda/Booking/Scan QR/Destinasi/Profil; role2 Ringkasan/Operasi/Analitik/Kelola/Profil; scanner push role1, role2 analytics. Session invalid menghapus cached pages dan replace route; logout memanggil AuthSession | Focused regression milik main/QA agent, bukan dinyatakan PASS dari source |

## Temuan untuk triage

1. Potensi S2 aksesibilitas shared nav (`floating_bottom_nav.dart:65-72`): outer `Semantics(button:true, excludeSemantics:true)` tidak menyetel `onTap`, sementara InkWell berada pada subtree yang dikecualikan. Langkah repro yang dikirim main: render nav, ensureSemantics, assert tiap label mempunyai SemanticsAction.tap dan lakukan action tersebut. Expected: TalkBack dapat mengaktifkan semua tab. Agent ini belum menjalankan test; jangan catat sebagai confirmed runtime defect sebelum hasil main.
2. S3 kontras legacy terukur: token `AdminColors.textMuted=#728099` terhadap `AdminColors.bg=#F5F8FD` menghasilkan rasio 3.748:1, di bawah 4.5:1 untuk teks normal. Contoh teks12 pada `kelola_kuota_screen.dart:238/243`, teks13 pada `admin_common.dart:326`. Core operations banyak memakai navy atau #526787 (5.755:1 di putih). Jangan mengganti palette shared approved sebagai side effect review; catat utang aksesibilitas dan verifikasi rendered guideline bila akan diperbaiki.
3. Risiko font offline: `pubspec.yaml` tidak membundel TTF/OTF Jakarta, memakai `google_fonts: ^8.2.1`. First-launch offline membutuhkan device proof untuk fallback. Ini belum dikonfirmasi sebagai defect.

Pemeriksaan kontras benar-benar dieksekusi memakai Python sRGB relative luminance: #728099/#F5F8FD=3.748, #526787/#FFFFFF=5.755, #9AA7BC/#FFFFFF=2.434, #1976D2/#FFFFFF=4.602; exit0. Hasil ini matematis dari token opak, bukan pengukuran piksel screenshot.

## Skill dan referensi yang dibaca

- `C:/Users/itsba/.agents/skills/flutter-custom-design-system/SKILL.md` dan `references/tokens.md`: cek reuse AppColors, OperationsTheme, existing shell/controls; tidak menambah ThemeExtension atau Pressable baru karena brief melarang redesign.
- `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/SKILL.md` dan `references/recipes.md`: cek named controls, Semantics, target48, text scale, IME dan reduced motion; menghasilkan candidate nav semantics dan measured legacy contrast.
- `C:/Users/itsba/.agents/skills/impeccable/SKILL.md`, `reference/audit.md`, `reference/audit.native.md`, `reference/android.md`: source audit native. `impeccable.cmd context --target lib/screens/operations_dashboard.dart` exit0, memakai binary lokal `scripts/bin/windows-x64/impeccable.exe`, tanpa download. Output meminta baca `docs/DESIGN.md`, sudah dibaca. PRODUCT.md tidak ada; scoped audit existing diteruskan sesuai directive. Tidak mengadakan interview/init atau menulis DESIGN baru.
- `C:/Users/itsba/.agents/skills/humanizer/SKILL.md`: merapikan prosa laporan tanpa mengubah evidence atau technical identifiers.

Referensi produk: PRD relayout V1, QA PRD V1, matrix45 cases, HTML `docs/references/wisata_admin_interactive_wireframe_v1.html`, preview `docs/previews/mobile.png` dan `desktop.png`; `docs/DESIGN.md` adalah audit lama yang menyebut Firestore dan path lama, sehingga source terkini + PRD V1 didahulukan. Tak ada skor platform/fidelity diberikan sebelum perangkat diverifikasi.

Tidak menjalankan flutter test/analyze atau mengubah produk; main thread memiliki eksekusi tests dan integrasi. Risiko tersisa: fidelity Android admin, IME admin, gesture/back admin, TalkBack, dan font fallback role1 belum terbukti.


## Lanjutan Android read-only smoke

Setelah main berhasil build/install/run, agent menerima ownership device evidence dan menjalankan ADB pada Pixel_7/emulator-5554. Sepuluh screenshot nyata telah dicapture dan diperiksa: dua viewport393x852/360x800 pada font1.0/1.3, blank email keyboard, drag dismissal, dan Back yang menutup keyboard sambil mempertahankan login. Tidak terlihat severe overflow/yellow Flutter error banner pada login. Tidak ada data diketik atau tombol login/Google disentuh. Dataset lokal belum terbukti terisolasi, jadi admin A00-A11 tetap BLOCKED_NO_ISOLATED_ADMIN_SESSION.

`SCREENSHOT_INDEX.md` dan `logs/device-ui.log` mencatat setiap file serta commands/corrections. Capture awal yang memakai nama keyboard ketika IME ternyata tertutup telah diganti dengan capture keyboard yang benar; after-drag diberi nama sesuai state aktual. Kamera fisik/emulasi, permission scanner, TalkBack, dan predictive Back tidak dicoba.

Original device physical1080x2400/density420, preexisting override1179x2556/density480,font1.0. Semua override dikembalikan persis dan dibaca ulang. Aplikasi ditinggalkan pada login kosong tanpa keyboard. Activity resolve digunakan setelah satu reopen shorthand salah menghasilkan Error type3; ini koreksi target automation, tidak dikategorikan bug aplikasi.

Computer-use skill `C:/Users/itsba/.codex/plugins/cache/openai-bundled/computer-use/26.1027.30824/skills/computer-use/SKILL.md` dibaca untuk routing. Scope skill adalah otomasi aplikasi Windows; tidak dipakai untuk ADB native Android dan tidak ada Windows automation dijalankan. ADB bawaan SDK sudah cukup; tak ada tool/skill/dependency yang diinstal.

Main melaporkan candidate shared nav semantics sudah direproduksi tiga role tests gagal, lalu fix satu baris `onTap` diterapkan. Retest dan final severity/status berada pada laporan main; agent ini tidak mengklaim test PASS sendiri.

## Current widget-render comparison

Empat render Flutter saat ini benar-benar dilihat dengan `view_image`: `widget-renders/test-fixture-a00-360-top.png`, `test-fixture-a00-393-chart.png`, `test-fixture-x01-360-top.png`, dan `test-fixture-e00-360-top.png`. Sumber capture dibaca pada `test/operations_dashboard_layout_test.dart`: `OPERATIONS_CAPTURE=true` menulis RepaintBoundary setelah pump, memuat Plus Jakarta Sans dari font tracked `artifacts/phase1a-visual/font-{400,500,600,700,800}.ttf` dan MaterialIcons. Data HTTP berasal dari fixtures lokal; angka3/1/2, lima batang tanggal1-5Nov, dan snapshot05/11/202608:00 bukan data backend perangkat atau hasil bisnis nyata. Log `tests-fixed-targeted.log` berakhir49 tests passed; total ini dibaca dari log, bukan dihitung dari jumlah gambar.

Perbandingan kualitatif terhadap preview mobile/desktop dan HTML V1 yang telah diperiksa:

- A00 mempertahankan scenic biru, Plus Jakarta Sans, tab Destinasi/Kinerja Saya, canvas pucat, kartu putih berbatas, summary utama dan empat KPI, serta nav lima ikon. Teks terbaca dan komponen yang terlihat tidak menunjukkan clipping parah. Komposisi belum identik dengan V1: satu scope card menggabungkan destinasi/periode, sedangkan V1 memperlihatkan dua kontrol filter berdampingan. Summary sekarang menonjolkan Prioritas persetujuan dan CTA Tinjau antrean, sedangkan contoh V1 menonjolkan Lingkup penugasan. Ini perbedaan hierarki/komposisi yang terlihat; angka fixture dan data simulasi HTML tidak dijadikan target kesamaan.
- A00 chart393 memperlihatkan panel Aktivitas booking dengan basis UTC, lima batang fixture dan baseline/label; panel tidak tertutup nav pada posisi capture. V1 mempunyai dua batang contoh dan kepadatan lain, sehingga jumlah/tinggi batang bukan mismatch produk. Nav masih memakai keluarga ikon aplikasi: tiket/mountain untuk Booking/Destinasi berbeda dari pictogram kartu/pin pada HTML. Ini variasi visual yang masih ada, bukan bukti route salah.
- X01 no-assignment360 menampilkan state Belum ada destinasi, instruksi hubungi Superadmin dan pull-to-refresh, tanpa KPI palsu. Panel finance tetap menyatakan DEMO/TEST_ONLY. Teks Respons layanan tidak valid pada finance di fixtures muncul karena handler yang tidak menyediakan envelope finance valid mengembalikan pageEnvelope kosong; bukan bukti respons Laravel aktual gagal. State no-assignment ini tidak memiliki pasangan screenshot V1 yang setara untuk penilaian kesamaan penuh.
- E00 executive360 mempertahankan judul Ringkasan Eksekutif, global scope, empat metrik dan nav pusat analytics; refresh tetap ada pada role2. Ini sesuai pemisahan role, bukan surface yang harus disamakan dengan approved role1. Tidak terlihat kebocoran label Admin role1 pada header/global scope render yang diperiksa.

Semua capture di atas adalah widget render skala1 pada viewport sintetis dengan mock safe-insets24dp dan fixture HTTP. Test juga mengeksekusi scale2, tetapi PNG skala2 tidak ditulis. Hasil ini memperkuat bukti komposisi/render lokal saat ini; Android admin fidelity A00-A11 tetap NOT VERIFIED/BLOCKED_NO_ISOLATED_ADMIN_SESSION. Tidak ada perubahan desain atau device operation dilakukan pada langkah ini.
