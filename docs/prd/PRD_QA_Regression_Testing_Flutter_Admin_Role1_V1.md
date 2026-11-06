# PRD QA, REGRESSION & TESTING — FLUTTER ADMIN ROLE 1 POST-RELAYOUT V1

**Proyek:** Wisata Daerahku · Flutter Android · Laravel 13 API
**Tanggal PRD:** 6 November 2026 · **Status:** Ready for QA execution (belum dieksekusi oleh penulis dokumen)
**Target:** Working tree lokal `C:\laragon\www\pami-mobile\pami-wisata-daearahku` · role Admin `users.role = 1`
**Jenis:** Visual fidelity audit, UX QA, functional/widget/state testing, focused regression, Android emulator smoke, defect remediation & evidence.
**Dasar:** User menyetujui relayout UI V1 dan secara eksplisit mengizinkan QA, regresi, testing, serta penggunaan subagents pada fase ini. Larangan testing pada PRD relayout sebelumnya **tidak berlaku** untuk PRD QA ini.

## 0. Konteks, sumber kebenaran, dan batas validasi

**GitHub `main` sudah diverifikasi (6 November 2026):** commit terbaru adalah [`48ab11c0a14fafa9d60383ee0c27530d675358de`](https://github.com/koyotot/pami-wisata-daearahku/commit/48ab11c0a14fafa9d60383ee0c27530d675358de), pesan `feat(admin): terapkan relayout UI/UX operasional role 1`, tanggal 2026-11-06 06:36:17 UTC / 13:36:17 WIB, parent `5096e3703f2e04abcac6aba0ecba5c3fd6dcc60b`. GitHub melaporkan **47 file berubah, 17 di antaranya file Dart** (4.378 penambahan, 2.195 penghapusan), ditambah PRD, HTML V1, preview dan 29 screenshot. Ini adalah **baseline remote yang terbukti**, belum berarti semua tes lulus. Status CI gabungan tidak memuat status yang dapat digunakan sebagai bukti kelulusan.

Laporan sebelumnya dari Codex menyatakan `dart format` dan `git diff --check` PASS namun pengujian runtime/analyzer belum dilakukan ketika laporan itu dibuat. Sekarang testing **diberikan izin eksplisit**, termasuk targeted analyze, tests, emulator smoke, visual QA dan regresi. **Codex harus mengecek `git status` dan HEAD lokal sebelum menyentuh apa pun**; jangan menimpa perubahan lokal yang lebih baru dari commit remote ini.

Sumber kebenaran berdasarkan prioritas:
1. **Runtime aktual Flutter dan sumber kode lokal terakhir**, termasuk perubahan yang belum di-commit. Jangan mengambil remote `main` sebagai pengganti perubahan lokal.
2. **Kontrak dan aturan Laravel** yang sudah ada; frontend dilarang mengakali klaim, approval, pembayaran, RBAC, TTL atau idempotensi.
3. **PRD dan 10 keputusan final** di `docs/prd/PRD-Flutter-Admin-Role1-UIUX-Relayout-V1.md` (ada pada remote HEAD; cek workspace).
4. **Approved Interactive Wireframe V1** di `docs/references/wisata_admin_interactive_wireframe_v1.html` (ada pada remote HEAD).
5. **29 screenshot baseline lama** di `docs/references/screenshots/` (ada pada remote HEAD); screenshot lama adalah bukti cakupan/pain point, BUKAN target estetika.
6. **Preview V1** di `docs/previews/mobile.png` dan `docs/previews/desktop.png` sebagai komposisi visual, bukan pembenaran untuk meng-copy nilai simulasi HTML.

Jika item tidak ada, catat sebagai `MISSING_REFERENCE`, lanjutkan dengan sumber yang ada dan jangan invent data/kode. Tidak perlu memulai ulang implementasi, membuat PRD baru, atau menanyakan 10 pilihan lagi.

### Cakupan perubahan yang dilaporkan (17 Dart; validasi file dengan git status)

- **Tema/chrome**: `lib/theme/app_colors.dart`, `lib/widgets/operations_chrome.dart`, `lib/screens/admin_common.dart`.
- **Operasional**: `operations_dashboard.dart`, `operations_presentation.dart`, `operations_filters.dart`, `operations_queue_screen.dart`, `operations_booking_screen.dart`, `operations_reports.dart`, `operations_financial.dart`, `operations_navigation_shell.dart` di `lib/screens/`.
- **Jalur legacy**: `daftar_pendaftar_screen.dart`, `daftar_wisata_screen.dart`, `detail_wisata_screen.dart`, `tambah_wisata_screen.dart`, `kelola_kuota_screen.dart`, `admin_ticket_scanner_screen.dart` di `lib/screens/`.

**Catatan:** daftar 17 Dart di atas **telah dicocokkan dengan file yang berubah pada commit GitHub**. Tetap periksa `git diff --name-only`, `git status`, dan file tambahan/untracked di lokal; simpan snapshot sebelum mengubah.


### Audit GitHub yang sudah terkonfirmasi pada baseline

- `lib/widgets/operations_chrome.dart` baru, `OperationsTheme` + `OperationsScenicHeader` memakai scenic user; `lib/theme/app_colors.dart` ikut dimodifikasi. QA harus menguji typography dalam nested routes, dialog, bottom sheet dan role lain.
- `lib/screens/operations_filters.dart` mengandung **dua jalur**: komponen kalender custom untuk kondisi Admin dan `showDateRangePicker()` untuk kondisi lainnya; `DropdownButtonFormField` juga masih ditemukan. **Jangan refactor membabi buta**: uji branch `role == 1` secara eksplisit; bila fallback role 2 memang ada, pastikan tidak bocor ke role 1.
- `lib/screens/operations_booking_screen.dart` memiliki decision sheet dan claim menu serta timer/refetch. QA harus menguji saat claim kedaluwarsa ketika sheet terbuka, HTTP 409, unknown outcome, serta disabled/keyboard/scroll/CTA.
- `lib/screens/operations_navigation_shell.dart`, `operations_reports.dart`, `daftar_pendaftar_screen.dart`, `admin_ticket_scanner_screen.dart`, dan entry legacy ikut berubah; regresi tidak cukup hanya widget dashboard.
- `test/` pada GitHub mencakup `operations_dashboard_layout_test.dart`, `operations_booking_test.dart`, `approval_queue_state_test.dart`, `operations_shell_test.dart`, `operations_reports_test.dart`, `operations_contract_test.dart`, `smart_ticket_test.dart`, `unified_routing_test.dart` dan `v4_visual_test.dart`. **Belum ada `integration_test/` pada remote HEAD**. Tidak mengarang hasil test atau klaim emulator sudah dijalankan.

## 1. Tujuan dan non-goals

**Goal G1 — Visual fidelity:** Implementasi Flutter Admin role 1 meniru hierarki, kepadatan, spacing, type scale, warna, action placement, calendar, picker, dan states HTML V1 tanpa memperkenalkan visual slop.

**Goal G2 — Functional correctness:** Seluruh kontrol benar-benar berfungsi, tetap server-authoritative, dan dapat dipakai pada error/empty/loading/expired/409 states.

**Goal G3 — Safety/regression:** Perubahan shared component tidak merusak `role 0` dan `role 2`, QR scanner, auth/logout, booking, payment/demo disclosure, atau otorisasi.

**Goal G4 — Traceable evidence:** Tiap pengujian punya hasil PASS/FAIL/BLOCKED/NOT_RUN, screenshot/log/sumber file, severity, dan tindakan koreksi.

**Bukan tujuan:** fitur baru; redesign role 2; perubahan schema/API Laravel; gateway DOKU production; transaksi/pembayaran nyata; live approvals pada data produksi; full refactor; snapshot palsu; memaksa seluruh test suite jika tidak berkaitan.

## 2. Aturan keselamatan dan akses

1. Jalankan pengujian mutasi terhadap **fake repository/mock**, database test terisolasi, atau server sandbox/demo dengan booking khusus QA. **Jangan** claim/approve/reject/release/confirm check-in pada booking pengguna nyata atau lingkungan production.
2. Audit dulu `.env.development`, `--dart-define-from-file` dan API base URL **tanpa mencetak secrets**. Jika target environment tidak dapat dipastikan aman, jalankan widget/unit/mock tests saja dan tandai emulator E2E mutatif sebagai `BLOCKED_UNSAFE_ENV`.
3. Tidak ada DOKU production, pembayaran nyata, refund/settlement nyata, atau webhooks nyata. Disclosures DEMO/SANDBOX/TEST_ONLY harus tetap jujur.
4. Jangan ubah role, auth, token, gateway mapping, API contract, `ApprovalDetailState`, QR security, backend Laravel, migration atau seeder untuk 'membuat tes hijau'. Perbaikan kode Flutter minimal dan berbasis defect diperbolehkan, tetapi perubahan invariants memerlukan stop-and-report.
5. Simpan working tree pengguna. Jangan `git reset --hard`, `git clean -fd`, checkout paksa, rebase, commit atau push otomatis. Jangan meng-overwrite pekerjaan unrelated.
6. Gunakan log redacted; jangan catat email, nomor telepon, JWT, QR token atau PII pada screenshot/QA report. Jangan upload screenshot privat ke layanan publik.
7. Tes kamera fisik hanya bila device/perizinan tersedia. Jika emulator kamera tidak mendukung, bukti widget/state + `BLOCKED_HARDWARE` lebih jujur daripada PASS palsu.

## 3. Keputusan desain terkunci: tidak untuk diperdebatkan ulang

| # | Keputusan final | Gate QA |
|---|---|---|
| 1 A | Dashboard tab **Destinasi / Kinerja Saya** | Keduanya dapat dipilih; data tidak tercampur |
| 2 A | KPI memprioritaskan operasional | Pending/approval/SLA dan penugasan jelas |
| 3 B | 1 summary utama + 4 KPI | Hierarki & responsive stabil |
| 4 A | Destination picker searchable single-select bottom sheet | Assigned-only, search, select, reset, kosong |
| 5 B | Periode: 7 hari / 30 hari / bulan ini / custom start-end | Kalender custom, 366 hari sesuai kontrak, validasi |
| 6 A | Antrean: Semua / Tersedia / Claim Saya | Label/status server benar |
| 7 A | Sticky bottom CTA kontekstual | Tidak menutup konten atau floating nav |
| 8 A | Claim → Tinjau Keputusan → Setujui/Tolak; release sekunder | Tidak auto-claim dan tidak mem-bypass guard |
| 9 B | Alasan tolak opsional sesuai backend | Blank reason tidak memicu rejection client-side palsu |
| 10 A | Destinasi: segmen Kinerja / Kelola | CRUD/kuota tetap dapat dicapai |

**Global acceptance:** Plus Jakarta Sans; scenic empat periode (05:00/11:00/15:00/19:00) dengan lifecycle; tidak ada tombol refresh di role1; pull-to-refresh pada loading/empty/error ber-scroll; picker/date tidak native stock Android; 5 icon-only floating tabs role1 (Beranda, Booking, Scan QR, Destinasi, Profil); tidak ada angka keuangan/okupansi/attendance yang direkayasa.

## 4. Strategi QA, berurutan dan berbasis risiko

### Fase 0 — Preflight, baseline dan agent/skill discovery

- Catat path root, branch, HEAD SHA, `git status --short`, `git diff --stat`, file untracked, Flutter/Dart versions, `flutter devices`, Android emulator jika ada, dan lokasi referensi V1. **Jangan melakukan commit/push.**
- Baca `C:\Users\itsba\.codex\Agents.md`, inventaris subagents yang benar-benar tersedia di `C:\Users\itsba\.codex\agents\` dan pilih **maksimal dua** subagents dengan tugas independen: (a) visual/UX/emulator, (b) widget/state/regresi. Main agent orchestrates fixes, evidence, verification. Bila agent tidak tersedia, jalankan langsung; jangan invent agent.
- Inventaris installed `SKILL.md` pada `C:\Users\itsba\.agents\skills\`, `C:\Users\itsba\.codex\skills\`, `<repo>\.agents\skills\`, dan plugin skills relevan. **Baca SKILL.md sebelum menyebut 'used'**. Kandidat (hanya bila benar-benar terpasang/relevan): `design-taste-frontend`, `ui-ux-pro-max`, `flutter-custom-design-system`, `flutter-improving-accessibility`, skill Flutter testing/QA apa pun yang benar-benar ada, `impeccable` untuk polish, `humanizer` untuk microcopy. `ponytail` bila preflight membuktikan relevansi. `anatomy` dan `reverse-engineer-anything` biasanya N/A; jangan install/MCP/rea setup.
- Pastikan environment emulator dapat dijalankan aman, termasuk `flutter pub get` bila diperlukan (catat dependency resolver), jangan upgrade dependencies acak.

### Fase 1 — Static/code review & bounded analyzer

- Audit route/theme ownership role1; footer/header; `RefreshIndicator` + always scrollable; custom calendar date rules; scoped search; claim guard source; PII privacy, server-auth statuses, screenshot fake values.
- Jalankan `dart format --output=none --set-exit-if-changed` untuk file Dart yang berubah bila tersedia; `git diff --check`. Jika formatter gagal, boleh format hanya file yang benar-benar diubah, dengan memeriksa diff supaya tidak membuat churn.
- Jalankan analyzer **dengan scope eksplisit atau project-level bila biaya cukup**, pisahkan error yang sudah ada sebelumnya dari error yang diperkenalkan. Jangan diam-diam menyatakan PASS jika analyzer tidak selesai atau gagal dari legacy.
- Buat daftar test yang sudah ada, jangan menulis ulang semua test semata demi test count.

### Fase 2 — Targeted automated tests (jalankan dahulu)

1. Tests yang teramati di remote repo sebelum perubahan lokal (cek keberadaan aktual di workspace):
   - `test/operations_dashboard_layout_test.dart`
   - `test/operations_booking_test.dart`
   - `test/approval_queue_state_test.dart`
   - `test/operations_shell_test.dart`
   - `test/operations_reports_test.dart`
   - `test/operations_contract_test.dart`
   - `test/smart_ticket_test.dart`
   - `test/unified_routing_test.dart`
   - `test/v4_visual_test.dart`
2. Jalankan batch kecil agar kegagalan terlokalisasi. **Tes lama yang berasumsi UI kuno harus dievaluasi terhadap kontrak baru**; update ekspektasi bila obsolete, JANGAN menghapus tes yang mengungkap defect nyata.
3. Tambahkan/ubah targeted widget/unit tests untuk gap berikut (nama file saran, tidak wajib): `test/operations_filters_relayout_test.dart`, `test/operations_chrome_relayout_test.dart`, `test/operations_action_dock_test.dart`, `test/operations_legacy_entry_test.dart`.
4. Gunakan fake repository dan clock injection/fake time bila memungkinkan; jangan menggunakan pembayaran/API production.
5. Jangan membuat assertion hanya memeriksa bahwa widget ada; uji tindakan, perubahan state dan hasil render.
6. Full regression suite adalah *escalation gate* bila ditemukan breaking shared changes, bukan default. Jika memutuskan menjalankannya, catat alasan, runtime dan kegagalan baseline.

### Fase 3 — Emulator visual/UX QA (perangkat nyata bila tersedia)

- Jalankan pada emulator Android yang tersedia; target referensi device **360×800** dan **393×852** bila dapat disimulasikan; area font scaling 100% & 130%, keyboard visible, safe areas, bottom nav and status/navigation bars.
- Captures screenshot aktual (minimal: A00, A01, A02 picker, A02 kalender range, A03 antrean tersedia/empty, A04 unclaimed, A04 claimed/decision sheet, A05 409, A06, A07 Kinerja, A07 Kelola, A08, A09, A10, A11), dengan redaksi PII. Bandingkan langsung terhadap HTML V1 dan preview, *jangan* hanya membandingkan screenshot lama.
- Scenic header diperiksa empat segmen waktu dengan clock/time injection bila ada; hindari mengubah jam sistem device produksi; kembalikan setting emulator usai uji.
- Status 360dp, font scale 1.3, keyboard sheet dibuka: tidak ada overflow, filter apply tetap reachable, CTA sticky tidak tertutup keyboard/floating nav/gesture bar.
- Explicit refresh buttons role1 tidak boleh muncul (termasuk error/empty states, legacy detail). Pull-to-refresh benar-benar memanggil load. Refresh setelah mutation/reopen berlaku tanpa button.
- Test eksplorasi visual juga mencakup komposisi card, density, type size, tap target, contrast, focus, disabled vs loading, truncation, long labels. Catat `Fidelity score` berdasarkan checklist, jangan mengarang metrik image diff yang belum dibuat.

### Fase 4 — Functional state, edge-cases, concurrency

- A02: search tujuan assigned-only; default scope; reset; date presets lintas bulan/tahun; leap-year; start > end; tepat boundary 366; validasi inkonsisten inklusif/eksklusif tidak boleh berubah dari API; change filter triggers correct query.
- A03: Semua/Tersedia/Claim Saya; empty/network error; pagination; claim expired; destination scope berubah; aman bila pull down saat request berjalan.
- A04/A05: unclaimed → manual claim → decision sheet → approve/reject (opsional reason); release sekunder; waiting/pending/expired/claimed by others; server 403/404/409/422/500; request timeout/unknown outcome, same idempotency key recover; no duplicate write; app background/resume; logout while in-flight; push/pop/back guards; action CTA disabled when state invalid.
- A06: Action Center uses urgency server; no fabricated SLA; booking tile routes to authoritative detail.
- A07: Kinerja & Kelola toggles; capacity numeric; occupancy denominator null -> `—`; existing CRUD/kuota navigation remains correct, scoped.
- A08: visitor attendance/no-show null -> `—`; scanner online-only preview → explicit confirm; QR H-5 and timezone restrictions remain server-auth; no self-checkin; camera permission denial gracefully handled.
- A09: 9 booking status chips horizontal; filter resets/stays as expected; legacy detail route funnels to claim-gated screen; no direct approve/reject bypass.
- A10: financial summary cannot turn DEMO/TEST_ONLY into real revenue; no DOKU production mutation; A11 profile/logout keeps guard and clears private views.

### Fase 5 — Focused role 0/2 regression

| Surface | Minimum check | Risk |
|---|---|---|
| Role 0 | Login/route, V4 scenic header, 5-tab nav, profile, booking detail and availability calendar | Shared theme/navigation regression |
| Role 0 | Date availability/bookability still based on API; no admin date picker leakage | Reuse collision |
| Role 2 | Executive shell, global scope, operations queue, profile, QR/analytics central tab | Wrong role or scope |
| Role 2 | Reassign & claim scope if tested only with isolated mocks | Approval safety |
| Shared | Logout wipes private child routes, session generation, status bar and keyboard safe areas | PII/security |
| Backend | API/data schema unchanged; admin only assigned destinations, no fake metrics | Invariant |

## 5. Test Matrix: deliverable & priorities

`qa/admin-role1-post-relayout/TEST_MATRIX.csv` (salin dari paket ini) adalah matriks pengujian kanonis. Case IDs `QA-001...`, priority `P0` blocks release, `P1` materially impacts UX, `P2` is useful nonblocking. Codex MUST fill results with actual evidence, not synthetic PASS. It may add cases but not silently delete P0 items.

Severity rubric:
- **S0 Critical:** unauthorized access, writes to real payments/users, data corruption, approval without claim, credentials/PII exposure.
- **S1 Blocker:** app cannot launch/role navigation broken, approval conflicts bypassed, major unhandled exception or crash.
- **S2 Major:** calendar/filter incorrect, CTA unreachable, severe overflow/keyboard blocking, broken empty/error recovery.
- **S3 Minor:** spacing, typography mismatch, icon alignment, microcopy, nonblocking visual polish.

**Policy:** Fix S0/S1 first, then S2 in-scope, then S3 highest visual impact. One targeted retest for each fix plus adjacent regression. Mark other defects explicitly as deferred with owner/action; no dishonest blanket PASS.

## 6. Commands (adapt to actual local setup; never print secrets)

```powershell
# Execute from repo root; keep all existing modifications
pwd
git branch --show-current
git rev-parse --short HEAD
git status --short
git diff --stat
git diff --check
flutter --version
flutter devices

# Targeted tests — ONLY if corresponding files exist in LOCAL workspace
flutter test --no-pub test/operations_dashboard_layout_test.dart test/operations_booking_test.dart test/approval_queue_state_test.dart
flutter test --no-pub test/operations_shell_test.dart test/operations_reports_test.dart test/operations_contract_test.dart
flutter test --no-pub test/smart_ticket_test.dart test/unified_routing_test.dart test/v4_visual_test.dart

# Analyzer gate (scope selected by Codex based on Flutter CLI and changed files)
# e.g. flutter analyze --no-pub lib/screens

# Android demo smoke if SAFE .env.development confirmed and device listed
flutter run -d emulator-5554 --dart-define-from-file=.env.development
```

**Tidak boleh menyalin `emulator-5554` membabi buta bila device ID berbeda**. `--no-pub` mungkin perlu dihilangkan bila dependency belum tersedia; jelaskan alasannya. Screenshot gunakan direktori QA yang **tidak** mencakup personal data. Jangan melakukan test mutatif pada API URL yang belum dikonfirmasi lokal/sandbox. Jika menggunakan `--dart-define-from-file`, inspeksi hanya **nama key dan host aman** tanpa mencetak kredensial. Aplikasi tidak punya `integration_test/` pada remote baseline, jadi real-device QA dapat memakai langkah manual yang terdokumentasi dan screenshot nyata; jangan menambahkan dependency test baru kecuali perlu dan disetujui.

## 7. Agent delegation & skill contract

**Main orchestrator**: preflight, git-safe controls, test batch scheduling, defect triage, minimal fixes, retests, final report.

**Subagent #1 — Visual/UX QA**: baca HTML V1, perangkat layouts, typography, scenic time states, calendar, sheets, bottom nav, accessibility; menghasilkan screenshot evidence + visual findings. Read-only review pada awal, dapat mengusulkan perbaikan; jangan menyentuh files yang sama dengan agent lain sekaligus.

**Subagent #2 — Functional/regression QA**: targeted widget/state tests, 403/404/409/timeout, session role, no fake metrics/finance/QR, legacy path. Write test files hanya setelah alokasi main agent. Main agent yang memutuskan fix. Max 2 subagents sekaligus/total (gunakan agent names yang benar-benar terdeteksi).

Skill invoking rules:
- Read real `SKILL.md`, follow its exact workflow, record path and actual usage in `SKILLS_USED.md`.
- Use design skills for visual QA and Flutter skills for code/testing; no FigCraft or UI re-generation; no tool installation or MCP changes without permission.
- If skill not available, say `NOT_INSTALLED` instead of claiming it was used. Do not call `anatomy` or `reverse-engineer-anything` unless an unexpected real need exists and is justified in report.
- Keep output high-signal; project is near 5h usage cap. Prefer reusable test commands, few agent messages, and proof over verbose narrations.

## 8. Deliverables — mandatory, files only in working tree, no auto commit

Output in `qa/admin-role1-post-relayout/results/` (create directory if needed):

1. `QA_REPORT.md`: environment, git baseline, executed test batches, counts PASS/FAIL/BLOCKED/NOT_RUN, defects and final gate.
2. `TEST_MATRIX_EXECUTED.csv`: one row per matrix case with actual status, evidence and notes.
3. `DEFECTS.md`: case ID, priority/severity, steps, expected vs actual, affected file/lines, screenshot/log, fix & retest result.
4. `SKILLS_USED.md`: agent names and skill path/use with actual read evidence (no invented invocation).
5. `screenshots/` + small `SCREENSHOT_INDEX.md`: redacted screenshots only if emulator run; otherwise `BLOCKED_NO_DEVICE` and no fake images.
6. `CHANGELOG_QA_FIXES.md`: exact Dart/test files changed, why, link to defect; no unrelated changes.
7. `COMMAND_LOG.md`: commands, exit codes and short console summaries, no sensitive tokens.

### Exit gates / definition of done

- P0 test cases all **PASS** or explicit `BLOCKED` with documented blockers and a clear `NOT VERIFIED` verdict; no silent PASS.
- No open S0/S1 defects. If any remain, final result is **FAIL / NOT RELEASE READY**.
- Every resolved defect has retest PASS with evidence.
- Role0 and role2 focused smoke PASS or clearly BLOCKED; no unverifiable 'unchanged' claim.
- Every Admin core route scroll/refresh (including empty/error), selected custom picker and date range, visible typography/scenic, and booking action state validated.
- Document `VISUAL QA PASS` separately from `FUNCTIONAL TEST PASS` and `REGRESSION PASS` (different evidence).
- No real payments, production mutations, hidden auth changes, backend/schema edits, commit/push.

## 9. Final response format from Codex (brief, Indonesian)

1. **Verdict** `PASS`, `PASS WITH KNOWN LIMITATIONS`, `FAIL`, atau `BLOCKED` — based on evidence.
2. Tests: count pass/fail/skipped/blocked, commands and affected paths; distinguish static/analyzer/widget/emulator.
3. Visual: match/mismatches vs wireframe, screenshots for actual device if available.
4. S0/S1/S2/S3 defects: resolved/unresolved and file references.
5. Regressions: role0 and role2 actually tested or blocked, no assumption.
6. Agents/skills actually used; files edited; uncommitted git status; report directory.
7. Explicitly list unverified device/E2E functions if environment not safe/available.

**Do not substitute `dart format` / `git diff --check` for Flutter QA. Do not claim finished merely because the command returns 0 if visual/functional requirements have not been evidenced.**


## 10. Catatan revisi berbasis pemeriksaan GitHub (2026-11-06)

- **HEAD baseline yang benar:** `48ab11c0a14fafa9d60383ee0c27530d675358de` (remote `main` pada saat penyusunan PRD ini). Jika HEAD lokal berbeda, Codex wajib menyebutkan SHA aktual dan membandingkannya dulu, bukan checkout/reset otomatis.
- **Lokasi file sebenarnya:** `lib/widgets/operations_chrome.dart` (bukan di `lib/screens/`); HTML V1 berada di `docs/references/wisata_admin_interactive_wireframe_v1.html`; PRD implementasi berada di `docs/prd/PRD-Flutter-Admin-Role1-UIUX-Relayout-V1.md`.
- **Bukti kelulusan:** commit tersedia; status CI yang didapat tidak cukup untuk bukti tes. Seluruh `PASS` wajib berasal dari output perintah atau interaksi perangkat yang benar-benar dijalankan Codex pada checkout lokal.
- **No auto-rewrite:** selama QA, jangan mengutak-atik desain yang telah disetujui atau membongkar mekanisme Laravel demi perasaan 'lebih baik'; hanya defect yang didokumentasikan dan teruji boleh di-fix.
