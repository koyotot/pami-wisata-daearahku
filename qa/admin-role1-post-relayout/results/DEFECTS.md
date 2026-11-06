# Defects

Tidak ditemukan S0/S1 yang terbukti dari pengujian lokal. S2 scanner masih terbuka, sehingga verdict **FAIL / NOT RELEASE READY**. Pengujian mock tidak membuktikan otorisasi backend live.

## D-001 — S2 — FIXED: navbar tidak dapat diaktifkan melalui semantics

- Case: QA-041, QA-043, QA-044; role0/1/2.
- Repro: render `FloatingBottomNav`, aktifkan semantics, baca node tab, lalu periksa `SemanticsAction.tap`.
- Expected: setiap tab berlabel memiliki aksi tap yang memanggil tab sesuai indeks.
- Actual sebelum fix: ketiga tes role gagal `Expected true / Actual false`.
- Root cause: `lib/widgets/floating_bottom_nav.dart` memakai `excludeSemantics: true`, tetapi outer `Semantics` tidak memiliki `onTap`; aksi InkWell anak ikut dibuang.
- Fix: menambahkan `onTap: () => onSelected(tab)` pada node semantics. Touch/visual/navigation tetap memakai jalur sama.
- Evidence sebelum: `logs/tests-batch-d-initial.log`; regression: `test/operations_accessibility_regression_test.dart`.
- Retest: tiga role dapat diaktifkan melalui semantics; android/iOS tap target, labeled target, dan contrast guideline navbar lulus. Bukti akhir `logs/tests-final.jsonl`, `logs/tests-final-cases.json`.
- TalkBack perangkat belum dijalankan.

## D-002 — S3 — FIXED: ticker tab tersembunyi tetap berjalan sesudah kembali dari scanner

- Case: QA-027, QA-040, QA-041, QA-044.
- Repro: buka Profil Admin → Scan QR fixture → tutup scanner. Cari loading indicator pada subtree offstage dan periksa mode ticker.
- Expected: tab yang tidak aktif menyimpan state dengan ticker dibisukan.
- Actual sebelum fix: `TickerMode` aktif pada indikator tersembunyi; `operations_shell_test.dart` timeout pada `pumpAndSettle` setelah scanner ditutup.
- Root cause: scanner return memicu `operationsDataChanges`; dashboard tersembunyi membuat finance preview `active:false` dengan `_loading:true`. `IndexedStack` mempertahankan animasi indeterminate karena tidak memakai `TickerMode` per halaman.
- Fix: `lib/screens/operations_navigation_shell.dart` membungkus tiap halaman dengan `TickerMode(enabled: _index == i)`.
- Evidence sebelum: `logs/tests-batch-b.log`, `logs/tests-hidden-ticker-diagnostic.log`.
- Regression: `hidden operations pages mute tickers after scanner returns` dalam `test/operations_post_relayout_test.dart`, termasuk zero transient callbacks; tes scanner-return existing juga lulus.
- Retest: `logs/tests-fixed-targeted.log` (49 PASS) dan run gabungan akhir.

## D-003 — S2 — OPEN: scanner menyimpan scope/preview lama setelah revalidasi akses

- Case: QA-032, QA-040; risiko privasi dan CTA stale.
- Dua repro: sesi role2 dengan scope global diturunkan menjadi role1, atau sesi role1 kehilangan assignment. Buka scope dan preview fixture `can_confirm:true`, panggil `session.me()` tanpa mengganti generation.
- Expected: scope/preview lama dibuang dan konfirmasi tidak lagi aktif sebelum akses terbaru tervalidasi.
- Actual: `scanner.canConfirm` tetap `true`; preview dan scope lama dipertahankan. Dua assertion akhir gagal. Tes tidak mengirim POST confirm.
- Root cause: `lib/data/ticket_scanner_state.dart:24` hanya memeriksa generation/auth dan keanggotaan role1/2. `_sessionChanged` pada baris 45 hanya menghapus data ketika `valid` menjadi false. Revalidasi generation sama tidak menginvalidasi snapshot.
- Repro executable: `test/operations_scanner_scope_regression_test.dart`, dua tes aktif tanpa skip; `logs/tests-functional-agent-final.log`, `logs/tests-final.jsonl` dan `logs/tests-final-summary.json`.
- **Tidak membuktikan bypass RBAC backend atau check-in yang berhasil tanpa izin.** Yang terbukti adalah state klien stale dan enabled confirm.
- Tidak mengubah QR validation/guard atau recovery key pada QA ini. Perbaikan perlu mencakup invalidasi akses serta hasil confirm yang belum diketahui, supaya revalidasi tidak membuang idempotency recovery dan memicu write baru.
- Required follow-up: perbaiki lifecycle scope scanner dalam scope keamanan tersendiri; pertahankan dua failing regression tests; ulangi QR sandbox dengan dataset terisolasi.

## D-004 — S3 — OPEN: kontras metadata legacy di bawah 4.5:1

- Case: QA-043.
- Repro terukur: luminance WCAG untuk `AdminColors.textMuted #728099` pada `#F5F8FD` menghasilkan **3.748:1**; pemakaian metadata 12/13sp pada `lib/screens/kelola_kuota_screen.dart` dan `admin_common.dart`.
- Expected: teks ukuran normal minimal 4.5:1.
- Evidence: kalkulasi dan lokasi pada `VISUAL_AGENT.md`. Navbar empat guideline lulus; itu tidak membuktikan seluruh layar lulus kontras.
- Tidak mengganti palette shared yang sudah disetujui tanpa verifikasi layar terkait. Tidak mengklaim visual perfection.

## Koreksi tes dan temuan yang dibatalkan

- Ekspektasi KPI/icon/metadata, label dashboard, key claim, dropdown/refresh/filter lama, chip status, dan auth safe-area lama disesuaikan dengan approved PRD. Assertion bisnis tetap memeriksa request, nilai API/null, pemisahan role, dan state.
- Picker role2 awalnya menunjukkan overflow dengan Ahem test font. Repro dengan **font produk tracked dan visitorTheme** lulus; bukan defect produk. Bukti `logs/tests-role2-calendar-font-diagnostic.log`.
- Dugaan refresh hilang pada “Akses diperbarui” dibatalkan: `OperationsPage.onRefresh` sudah ada; tes sekarang benar-benar melakukan pull.
- Recovery unknown-claim menunggu snackbar back-guard selesai sebelum menekan recovery; request kedua tetap harus memakai header/idempotency key yang sama.
- Analyzer memiliki lint debt baseline; tidak ada compile error/new diagnostic pada scope akhir. Detail pada QA_REPORT dan log analyzer.
