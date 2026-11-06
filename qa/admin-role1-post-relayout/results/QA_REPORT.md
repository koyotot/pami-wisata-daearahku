# QA Admin Role 1 — 6 November 2026

**Verdict: FAIL / NOT RELEASE READY.** Dua regression test membuktikan scanner mempertahankan preview dan CTA konfirmasi setelah revalidasi role/assignment pada generation yang sama (D-003, S2). Android fidelity Admin A00–A11 juga **BLOCKED / NOT VERIFIED** karena sesi Admin dengan dataset terisolasi belum tersedia.

| Gate | Hasil akhir |
|---|---|
| Functional/widget/state | **FAIL**: 180 PASS, 2 FAIL, 0 skipped, 182 tes di 27 file; dua kegagalan adalah D-003 |
| Regression role0 | Targeted mock auth/OTP/Google, route/nav, availability, booking detail dan favorite state PASS; profile/favorites UI lebih luas NOT_RUN |
| Regression role2 | **FAIL** pada downgrade scanner role2→role1; executive/analytics/management, native picker, reassign, navigation dan resume yang diuji PASS |
| Android visual fidelity A00–A11 | **BLOCKED_NO_ISOLATED_ADMIN_SESSION**; tidak ada skor fidelity atau klaim Android Admin PASS |
| Android launch/login smoke | PASS untuk tampilan yang diamati pada 360×800 dan 393×852, text scale 1.0/1.3, blank keyboard dan Back; 10 PNG nyata |
| Analyzer | Exit 1: final scope 0 errors, 1 warning, 11 infos; seluruh 12 diagnostic sudah ada pada baseline scope sama; 0 diagnostic baru |
| Format / whitespace | PASS: format 28 Dart, 0 berubah; `git diff --check` exit 0 |

Run gabungan akhir selesai dalam 25.105 detik. Hitungan berasal dari event `testDone` non-hidden pada `logs/tests-final.jsonl`; loading/setup/teardown tidak dihitung sebagai tes. Ringkasan mesin dan daftar per tes: `logs/tests-final-summary.json`, `logs/tests-final-cases.json`. Tes scanner yang gagal tetap aktif, tanpa skip atau penghapusan assertion.

## Baseline dan environment

- CWD aktual: `C:/laragon/www/pami-mobile/pami-wisata-daearahku`.
- Branch `main`; HEAD tetap `48ab11c0a14fafa9d60383ee0c27530d675358de`, parent `5096e3703f2e04abcac6aba0ecba5c3fd6dcc60b`. Cocok dengan baseline remote yang diberikan user; tidak melakukan fetch/pull atau verifikasi remote baru.
- Preflight awal: tidak ada tracked modification. Dua input pengguna untracked: `docs/matrix/` dan `docs/prd/PRD_QA_Regression_Testing_Flutter_Admin_Role1_V1.md`. Keduanya dipertahankan.
- Commit baseline memuat 17 Dart yang diaudit. `logs/baseline-commit.txt`, `baseline-status.txt` menyimpan snapshot sebelum perubahan produk/test; direktori QA sudah dibuat ketika status file disimpan.
- Flutter **3.44.4**, Dart **3.12.2**, Windows 10.0.26200.9711. Dependencies yang ada digunakan melalui `--no-pub`; tidak menjalankan pub get/upgrade.
- Awalnya hanya Windows/Chrome/Edge terhubung. AVD terpasang `Pixel_7` diluncurkan; device aktual **emulator-5554**, Android 17/API37, android-x64.
- Referensi ditemukan: PRD implementasi, PRD QA pada `docs/prd/`, matrix pada `docs/matrix/`, HTML V1 pada `docs/references/`, kedua preview dan **29 screenshot lama**. Screenshot lama dipakai sebagai cakupan/pain point, tidak sebagai target styling.
- Global instructions, dua definisi agent dan lima skill relevan dibaca. Lihat `SKILLS_USED.md`, `VISUAL_AGENT.md`, `FUNCTIONAL_AGENT.md`.

## Safety dan batas API

`.env.development` dibaca tanpa mencetak isinya/kredensial. Key yang relevan menunjukkan `APP_ENV=development` dan host `http://127.0.0.1:8000`. Host lokal **belum membuktikan** data test terisolasi. Live mutable E2E ditetapkan **BLOCKED_UNSAFE_ENV**.

Semua claim/approval/release/CRUD/QR confirm pada tes memakai MockClient dengan host fixture `example.test`; tidak mengirim mutasi ke backend live. Android memakai entrypoint aplikasi biasa dan config development, tetap pada login kosong tanpa login, account picker, pembayaran atau input kredensial. Screenshot hanya memuat UI publik; raw UI dump tidak disimpan dan full logcat tidak dibaca. Tidak ada JWT/API key/google-services contents/QR aktual pada laporan. Identitas fixture dalam source/log pengujian adalah sintetis.

Laravel tidak diubah dan source backend tidak diverifikasi secara terpisah. Karena itu enforcement assignment/RBAC, QR restriction dan boundary tanggal backend aktual tidak diberi PASS live. Tidak melakukan DOKU production/refund/settlement/webhook.

## Eksekusi dan perbaikan

Batch existing dijalankan dahulu. A menghasilkan 15 PASS/14 FAIL; B 13 PASS/7 FAIL; C 8 PASS; D awal 64 PASS/8 FAIL; regression E awal 42 PASS/1 FAIL. Kegagalan lama dipisahkan dari defect produk: ekspektasi UI sebelumnya, Ahem overflow, kontrol di luar viewport, dan safe-area yang mendahului PRD full-bleed diperbaiki pada tes dengan assertion perilaku tetap dipertahankan.

Dua defect produk direproduksi sebelum fix:

- **D-001/S2 FIXED**: tab navbar tidak memiliki semantics tap; menambah satu callback pada `lib/widgets/floating_bottom_nav.dart`. Tiga role dan empat guideline Flutter lulus.
- **D-002/S3 FIXED**: ticker indeterminate pada tab tersembunyi terus berjalan setelah kembali dari scanner; `TickerMode` per halaman pada `lib/screens/operations_navigation_shell.dart`. Test hidden ticker dan scanner-return lulus.

Retest terfokus setelah fix: **49 PASS** (`logs/tests-fixed-targeted.log`). Pemeriksaan tambahan queue, action center, management/quota, profile logout dan DEMO finance: **7 PASS** (`logs/tests-queue-finance-final.log`). Run akhir menggabungkan seluruh target agar hitungan tidak menjumlahkan tes yang sama berulang kali: **180 PASS/2 FAIL**.

Defect tersisa:

- **D-003/S2 OPEN**: dua tes scanner same-generation scope gagal. Backend authorization bypass tidak dibuktikan; state/CTA stale terbukti. QR/guard/recovery tidak diubah karena perbaikannya perlu menjaga unknown-confirm/idempotency. Gate tetap FAIL.
- **D-004/S3 OPEN**: metadata legacy `#728099` pada `#F5F8FD` berkontras **3.748:1**, di bawah 4.5:1 untuk teks normal. Palette shared belum diubah.

S0: 0 terbukti. S1: 0 terbukti. S2: 1 fixed, 1 open. S3: 1 fixed, 1 open. Lint debt baseline dicatat terpisah. Langkah repro, root cause, file dan bukti terdapat pada `DEFECTS.md`.

## Analyzer dan regression detail

`flutter analyze --no-pub` pada baseline penuh: **0 errors / 2 warnings / 102 infos** (exit1). Scope akhir berisi 28 file Dart: 17 file commit relayout ditambah produk/test yang terpengaruh. Final: **0 errors / 1 warning / 11 infos** (exit1). Baseline yang difilter pada scope akhir memiliki **1 warning / 11 infos** juga. Delta mempertahankan jumlah diagnostic per severity/path/code, mengabaikan pergeseran nomor baris; **0 diagnostic baru** (`logs/analyzer-delta.json`). Penurunan total dari104 ke12 berasal dari perbedaan scope, bukan penghapusan lint.

Warning tersisa adalah unused `blueDeep` pada `daftar_wisata_screen.dart`; infos meliputi prefer-const, braces dan unnecessary import pada source baseline. Tidak melakukan refactor massal lint.

Coverage aktual mencakup client API/null metrics, scoped picker/search/pagination/reset, role1 custom vs role2 fallback calendar, preset, leap/reverse range, operational/financial boundary berbeda, queue ownership, explicit claim/review/approve/blank reject/release, changed-owner/resume, 409/unknown recovery, logout/stale responses, scanner preview/confirm same-key, finance provenance dan foreign-scope rejection, sembilan status chips/legacy route, role0 auth/calendar/booking/favorite state, role2 shell/analytics/reassign, dan notification/session routing.

**Belum lengkap:** empat segmen scenic berdasarkan jam runtime; TTL/deadline yang melintas saat decision sheet terus terbuka; seluruh kombinasi 404/422/500 pada widget keputusan; broader role0 profile/favorites UI. Tidak mengartikan nama tes sebagai bukti branch yang tidak dieksekusi. `operations_test_support.dart` dan `admin_test_support.dart` adalah helper, tidak dijalankan sebagai test entrypoint.

## Visual evidence

Android APK development berhasil dibangun, dipasang, dan dijalankan dengan device ID aktual. `logs/android-run.log` memuat build; warning Kotlin/Java plugin lama tidak menyebabkan build gagal. Debug runner QA dihentikan setelah capture; emulator dan login kosong dipertahankan. Override ukuran/density/font dikembalikan ke setting sebelum QA: **1179×2556 / 480 / 1.0**.

- `screenshots/`: **10 PNG ADB asli**, dua viewport/scales serta keyboard/Back login. Semua diperiksa agent melalui view_image. Tidak terlihat severe overflow/error stripe pada capture login yang diamati.
- `widget-renders/`: **10 render Flutter widget aktual dari fixture HTTP**, dengan font produk tracked. Empat dibandingkan langsung dengan preview/HTML; enam diindeks tanpa pemeriksaan individual. Ini bukan screenshot Android Admin.
- `SCREENSHOT_INDEX.md` memisahkan kedua jenis bukti dan state masing-masing. Current widget comparison dan perbedaan komposisi ada pada `VISUAL_AGENT.md`.

Nilai fixture adalah simulasi tes; finance fixture pada render dashboard tidak memiliki envelope finance valid sehingga menunjukkan error jujur. Tes finance terpisah memakai envelope/provenance valid. Tidak memakai angka HTML sebagai angka backend dan tidak mengklaim data fixture sebagai KPI live.

A00–A11 pada device, permission/camera, TalkBack, predictive-back gesture, actual admin keyboard/safe-area, offline first-launch Jakarta font, dan backend E2E tetap belum terverifikasi. Font produk hanya dimuat ke test harness; tidak menambahkan font asset produksi sebagai perubahan QA.

## Matrix dan working tree akhir

Seluruh **45 case** asli dipertahankan: **27 PASS, 4 FAIL, 10 BLOCKED, 4 NOT_RUN**. P0: **18 PASS, 3 FAIL, 5 BLOCKED, 2 NOT_RUN**. Satu defect dapat menggagalkan lebih dari satu case. Matrix PASS berarti lingkup metode/evidence pada Notes, bukan sertifikasi backend/device yang tidak dijalankan.

Produk berubah pada dua file saja. Enam test existing diperbarui dan empat file test baru ditambahkan; daftar alasan lengkap pada `CHANGELOG_QA_FIXES.md`. Artefak baru berada di `qa/admin-role1-post-relayout/`. Git tetap dirty dan HEAD tidak berubah; status lengkap `logs/final-status.txt`. Tidak auto-commit/push.

Gate berikutnya memerlukan perbaikan D-003 dengan retest unknown-confirm/idempotency serta akun/data Admin sandbox terisolasi untuk A00–A11 dan QR. Laporan ini tidak memberikan release sign-off.
