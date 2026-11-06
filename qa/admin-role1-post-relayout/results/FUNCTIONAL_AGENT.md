# Functional/regression QA agent

Agent aktual: `qa_engineer` (`/root/functional_regression_qa`). Tugas terbatas pada inspeksi read-only `lib/`, test yang sudah ada, dan penambahan `test/operations_post_relayout_test.dart` serta `test/operations_scanner_scope_regression_test.dart` (alokasi tambahan parent). Tidak mengubah kode produk, backend, kontrak bisnis, dependency, atau dokumen pengguna.

## Evidence dan eksekusi

- Membaca global instructions `C:/Users/itsba/.codex/Agents.md`, PRD QA `docs/prd/PRD_QA_Regression_Testing_Flutter_Admin_Role1_V1.md`, dan matrix asli `docs/matrix/TEST_MATRIX_QA_Flutter_Admin_Role1_V1.csv`.
- Menginspeksi `operations_filters.dart`, `operations_booking_screen.dart`, `operations_queue_screen.dart`, `daftar_pendaftar_screen.dart`, `approval_queue_state.dart`, `admin_state.dart`, `ticket_scanner_state.dart`, `operations_financial.dart`, `auth_session.dart`, serta test/harness yang tersambung.
- `dart format test/operations_post_relayout_test.dart test/operations_scanner_scope_regression_test.dart`: exit 0; dua file diformat.
- Setelah diberi slot parent, menjalankan `flutter test --no-pub --reporter expanded test/operations_post_relayout_test.dart test/operations_scanner_scope_regression_test.dart` secara berurutan dengan batch main. **Final exit 1, 15 PASS / 2 FAIL**, tanpa skip: `logs/tests-functional-agent-final.log`. Seluruh 15 post-relayout widget tests PASS; kedua scanner scope regression tests FAIL. Tidak menjalankan analyzer sendiri.
- Retest awal dua file: exit 1, 14 PASS / 3 FAIL, `logs/tests-functional-agent-retest.log`. Terdapat dua scanner failures dan role2 native picker overflow di Ahem. Focused role2 diagnostic exit 1: `logs/tests-role2-calendar-diagnostic.log`; setelah memakai font produk yang sudah tracked + theme produk, focused role2 test exit 0, 1 PASS: `logs/tests-role2-calendar-font-diagnostic.log`. Final test mempertahankan font produk; tidak menghapus overflow assertion.

## Targeted widget tests baru (15 cases, final PASS)

| Coverage | Case matrix | Bukti assertion |
|---|---|---|
| Role1 searchable picker, pagination, endpoint assigned, case-insensitive search, select, reset, keyboard inset 280dp | QA-010, QA-011, QA-016 | Query hasil dipilih `destination_guid=d2`, reset menjadi kosong; seluruh request ke `/admin/destinations`; tidak memakai dropdown native. Scope assignment backend tetap hanya kontrak mock. |
| Role1 custom vs role2 fallback date picker | QA-012, QA-040 | Role1 tidak merender `DateRangePickerDialog`, custom preset dapat diterapkan; role2 tetap merender dialog native. |
| 7/30/month presets dan basis UTC/calendar | QA-013, QA-015 | Returned dates midnight, range length sesuai preset, bulan pertama sampai hari ini. |
| Operational 366/367 difference, financial 366/367 inclusive | QA-014 | Operational mempertahankan existing API rule `difference <=366`; financial `difference<=365`. Apply disabled saat melampaui batas. Test tidak menyamakan dua kontrak yang sengaja berbeda. |
| Reverse order/leap year dan reset | QA-015 | Memilih 29 Feb 2024 setelah 1 Mar mengembalikan sorted range, reset mematikan Apply. |
| Explicit claim → review → blank optional reject | QA-020, QA-021 | Tidak ada POST saat membuka detail; claim POST eksplisit; confirm awal disabled; reject HTTP body kosong diterima; status akhir mengikuti mock server. Test awal keliru memanggil jsonDecode pada empty body; harness diperbaiki sesuai repository tanpa mengubah produk. |
| Release secondary | QA-022 | Release tidak tampil di primary detail, terbuka melalui menu; request hanya `/release`, dock kembali ke claim. |
| Open sheet + changed owner on resume | QA-023, QA-025 (partial lifecycle) | Confirm berubah dari enabled ke disabled setelah reread; tidak ada decision POST. TTL real-time saat sheet terbuka tetap memerlukan bukti tambahan. |
| Nine status chips, horizontal reveal, legacy routing | QA-034, QA-035 | 9 chips termasuk Semua; chip terakhir mengirim cancelled ke server; history membuka `OperationsBookingScreen`; tidak auto POST. |

## Existing automated coverage yang ditemukan (hasil bukan diklaim PASS)

- `approval_queue_state_test.dart`: malformed/timeout unknown outcome; same key/payload recovery claim/release/reassign; access revoked; expired claim; role1 no reassign; 422; explicit claim; paginated claim lookup; 409 changed owner; failed read after write; assignment revoke; in-flight same-generation role change; reread ownership before decision.
- `admin_state_test.dart`: duplicate tap in-flight, server-authoritative booking status, 409 terminal status reread, 403 definite error, timeout reconciliation, logout stale result, pagination/filter/stale-response guards, quota UTC validation. Test bernama “403 and 422” sebenarnya hanya memberi HTTP403; jangan anggap judul sebagai bukti 422 booking decision.
- `smart_ticket_test.dart`: preview before confirm, duplicate scan guard, unknown confirm same payload/key, logout purges preview and prevents confirm. Tidak membuktikan kamera/device, QR TTL, atau backend authorization.
- `operations_contract_test.dart`: null metrics, report metadata, exact claim/release/reassign routes/key/payload. `operations_reports_test.dart` menguji null attendance/no-show/occupancy dan pagination.
- `operations_shell_test.dart`, `unified_routing_test.dart`, `v4_navigation_notifications_test.dart`, `business_integration_calendar_test.dart`: relevan role0/2 routing, lifecycle, shell logout, notification private responses dan availability server-authoritative. Hasil aktual milik log eksekusi main.

## Findings

1. Existing `operations_booking_test.dart` unknown-claim test memakai key role1 lama `claim-booking`; implementasi role1 kini memakai sticky `booking-primary-action`. Ini ekspektasi usang, bukan bukti idempotency defect. Parent diberi lokasi dan tetap memegang file existing.
2. Existing dashboard/report tests masih mengasumsikan segmen lama, explicit refresh role1, dropdown yang dimuat otomatis dan label apply lama. Parent menangani rekonsiliasi dengan approved V1; subagent tidak menghapus assertion.
3. **TERBUKTI S2 / unresolved: scanner stale scope/preview setelah revalidasi akses (QA-032, QA-040/041 partial).** File `lib/data/ticket_scanner_state.dart:24` dan `:45`. Repro sepenuhnya MockClient: login role2 (atau role1 assigned), load scope, capture QR fixture → preview can_confirm=true; mock backend mengganti role menjadi1/assignment menjadi kosong; panggil `AuthSession.me()`; assert generation sama; actual `scanner.canConfirm` masih true, expected false dan preview/scope harus dibuang. Dua executable regressions gagal di `test/operations_scanner_scope_regression_test.dart:75`; `logs/tests-functional-agent-final.log`. Tidak ada confirm POST yang dikirim. Root cause: `valid` hanya mengecek generation/auth/role in[1,2]; `_sessionChanged` mempertahankan scope/preview saat validity masih true. Ini tidak membuktikan backend authorization bypass. Main diberi informasi; tidak diubah karena user melarang perubahan QR invariants hanya demi tests.
4. Role2 native picker overflow 62dp terbukti **harness Ahem false-positive**, bukan defect produk: dengan 5 font Plus Jakarta Sans yang sudah tracked di `artifacts/phase1a-visual/` dan `AppColors.visitorTheme`, focused test dan final batch PASS tanpa menghapus assertion. Font loader disalin dari pola existing `operations_dashboard_layout_test.dart`; tidak ada dependency atau binary baru.

## Skills yang benar-benar dibaca/dipakai

- `C:/Users/itsba/.codex/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`: reuse fake HTTP harness, scoped test file, tanpa dependency atau perubahan produk.
- `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/SKILL.md` dan `references/recipes.md`: MediaQuery/TextScaler dan simulated keyboard inset; tidak mengklaim guideline checks/TalkBack/VoiceOver/device PASS.

Tidak menjalankan live API mutation, pembayaran, kamera, broad suite, atau screenshot device. Risiko yang masih memerlukan bukti: safe backend dataset, actual Android layout dan TTL/QR hardware behavior.

## Bounded follow-up: hidden tab animation dan auth baseline

Parent meminta diagnosis read-only setelah test shell lama timeout saat menutup scanner. Menambahkan satu test pada file owned (sekarang 16 widget cases), tanpa mengubah produk atau existing tests.

- Command: `flutter test --no-pub --reporter expanded test/operations_post_relayout_test.dart --plain-name 'hidden operations pages mute tickers'`.
- Hasil: **exit 1, 0 PASS / 1 FAIL**, `logs/tests-hidden-ticker-diagnostic.log`; assertion `TickerMode.of(element)` expected false, actual true.
- Repro: mount shell role1 → pilih Profil → buka scanner fixture full-screen → tutup scanner → pump 2×500ms. Profil terlihat, tidak ada `LinearProgressIndicator` visible, tetapi indicator tersembunyi ditemukan dengan `skipOffstage:false` dan ticker-nya masih enabled. Font produk sudah dimuat, jadi ini bukan Ahem overflow.
- Root cause: scanner return memicu `operationsDataChanges`; dashboard inactive memanggil `_sessionChanged`, membersihkan data dan membentuk finance preview baru ber-key `finance-$_request`; preview `active:false` punya `_loading=true`, `_load()` langsung return; `IndexedStack` mempertahankan subtree tersembunyi tanpa `TickerMode`, sehingga indeterminate indicator terus menjadwalkan frame. Timeout `pumpAndSettle` adalah gejala animasi tersembunyi aktual.
- Minimal fix yang disarankan ke main: `TickerMode(enabled: _index == i, child: ...)` untuk tiap page shell; mempertahankan state/navigation, tidak mengubah API/business. Main tetap owner produk/retest.
- Auth failure `auth_prd_redesign_test.dart:189` **ekspektasi usang terhadap approved full-bleed**: mengharapkan `CustomScrollView.top==44`, padahal approved `docs/prd/PRD-Auth-Dynamic-Header-Full-Bleed-Edge-to-Edge-Wisata-Daerahku.md` §2 meminta background top0 dan safe inset hanya pada foreground. `AuthScenicShell` sudah mengikuti itu. Parent diberi saran verifikasi top0 + chip/title aman dan CTA keyboard reachable; tidak mengembalikan outer top SafeArea. Temuan ini inspeksi dokumen/kode, belum retest oleh subagent.
