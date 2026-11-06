# PRD — Wisata Daerahku | Flutter Admin Role 1 UI/UX Relayout V1

**Status:** APPROVED FOR IMPLEMENTATION — keputusan desain final, belum diimplementasikan ke Flutter  
**Tanggal acuan:** 6 November 2026  
**Repositori Flutter:** https://github.com/koyotot/pami-wisata-daearahku  
**Branch terinspeksi:** `main` (`5096e3703f2e04abcac6aba0ecba5c3fd6dcc60b`, diperiksa 6 November 2026; cek HEAD lokal sebelum coding)  
**Repositori backend (read-only):** https://github.com/joytimess/pami-wisata-daerahku-api  
**Role:** Admin `users.role == 1` / `user_type = 1` dalam istilah brief. Bukan redesign role 0 atau role 2.

## 0. Source of truth, prioritas, dan batasan

Urutan otoritas implementasi:
1. **Kontrak keamanan, status, scope penugasan dan data aktual dari Laravel + existing Dart state/repository** — tidak boleh diubah oleh visual mockup.
2. **Sepuluh keputusan disetujui pengguna**, pada Bagian 1.
3. **`docs/design/wisata_admin_interactive_wireframe_v1.html`** — sumber visual/interaction utama untuk role Admin. Buka dan inspeksi interaksi; **jangan** mengintegrasikan HTML, CSS, atau JavaScript ke Flutter.
4. **`docs/design/references/screenshots/`** — 29 screenshot kondisi implementasi lama, bukti fitur dan pain points, **bukan** styling target. Screenshot terpotong bisa merepresentasikan segmen dari layar sama.
5. Implementasi Flutter saat ini (`lib/screens/`, `lib/widgets/`, `lib/theme/`) — reuse pattern valid dan endpoint yang sudah berjalan.

Konflik diselesaikan dengan menjaga keselamatan bisnis/API terlebih dulu; jika visual V1 bertentangan dengan backend, pertahankan backend dan adaptasi state UI. **Dilarang** menambahkan metrik, transaksi, booking, claim atau check-in palsu. Konten mock HTML adalah simulasi, bukan dataset prod.

**In scope:** UI/UX dan alur navigasi Admin role 1 untuk dashboard, personal performance, action center, approval queue/detail/claim, filter, destinations/performance/manage, visit/check-in, daftar pendaftar (booking history), financial demo preview bila terlihat, profile, dan state terkait. Semua dipertahankan di Flutter native + repository/API yang sama.  
**Out of scope:** perubahan schema/API Laravel, auth/session/JWT, backend rules, pembayaran DOKU production, permission/role baru, logic QR, redesign role 0 dan role 2, menjalankan QA/regresi/analyze/test/build APK, FigCraft/MCP baru, dan dependency UI tidak perlu.

## 1. Sepuluh keputusan UI final (LOCKED)

| ID | Keputusan | Pilihan | Hasil wajib |
|---|---|---|---|
| Q01 | Dashboard utama | A | Dua tab **Destinasi / Kinerja Saya**. |
| Q02 | KPI prioritas | A | Operasional: pending, assignment, approval, SLA. Finansial tidak menyaingi hero KPI. |
| Q03 | Komposisi KPI | B | Satu summary prioritas + empat KPI kecil (jangan menambah card dekoratif). |
| Q04 | Destinasi picker | A | Custom bottom sheet searchable, **single-select**, hanya destinasi scoped. |
| Q05 | Kalender range | B | Preset **7 hari / 30 hari / Bulan ini**, ditambah Start Date–End Date manual custom. |
| Q06 | Antrean approval | A | **Semua / Tersedia / Claim Saya** (state claim dari Laravel). |
| Q07 | Posisi aksi | A | **Sticky bottom contextual primary action** pada Detail Booking. |
| Q08 | Setelah claim | A | **Tinjau Keputusan** -> custom bottom sheet Setujui/Tolak; **Lepas Claim** di menu sekunder. |
| Q09 | Alasan penolakan | B | **Opsional** sepanjang backend saat ini mengizinkan; jangan buat wajib hanya oleh UI. |
| Q10 | Destinasi | A | Segmented **Kinerja / Kelola** di tab Destinasi. |

Keputusan tambahan yang sudah eksplisit: **tidak boleh ada tombol refresh manual di layar mana pun**; refresh dengan pull-down di posisi scroll paling atas, ditambah re-fetch otomatis pascaperubahan/focus sesuai existing state; font standar project **Plus Jakarta Sans**, bukan Georgia/Flutter fallback serif; header **time-based scenic** dari role 0; tidak boleh dropdown Material mentah; seluruh kalender adalah custom native Flutter mengikuti visual user-side, bukan `showDateRangePicker` Android; actions harus minimal dan status-driven.

## 2. Design system & komponen reusable

### 2.1 Identitas visual

- Typography: `GoogleFonts.plusJakartaSansTextTheme()` dari `lib/theme/app_colors.dart` atau theme operation-specific yang mewarisinya. Tidak boleh `Georgia` untuk role 1, termasuk page legacy, date picker, modal, dialog, badge, snackbars dan bottom sheets. `lib/main.dart` masih punya ThemeData global Georgia; **jangan ubah theme global tanpa alasan**; bungkus seluruh entry point dan routes operasional dengan `AppColors.visitorTheme` atau operasi theme reusable yang identik secara typography.
- Existing tokens: blue `#1976D2`, blueDeep `#1558B0`, navy `#102D59`, bg `#F5F8FD`, surface `#FFFFFF`, border `#DCE4F0`, muted `#728099`. Warna status green/amber/red hanya untuk makna, bukan menghias semua card.
- Grid layar: padding 16–20dp, spacing konsisten 8/12/16/24dp, border radius 14–20dp, surface putih; utamakan tinggi konten yang ringkas (360×800 dan 393×852 target umum) tanpa clipping atau minHeight kosong besar. Ukuran tap target minimal ~48dp, SafeArea status bar dan gesture nav dijaga.
- Tipografi: page title ~22–26sp; section title ~16–18sp; body ~13–15sp; metadata ~11–12sp; monospaced hanya jika memang untuk kode/token. `TextOverflow.ellipsis` dan `SelectableText`/copy menu untuk GUID panjang, jangan render identifier sebagai judul 3+ baris tanpa opsi.
- Kartu KPI: summary tunggal dengan CTA jelas; empat metrik kecil grid 2×2. `0` hanya untuk angka nyata, `—/belum tersedia` saat data null/tidak terverifikasi. Indikator snapshot kecil di konten tanpa icon refresh.

### 2.2 Header scenic berbasis waktu

Reuse **`TimeBasedScenicBackground`** di `lib/screens/auth_presentation.dart`, sama dengan sisi visitor `lib/screens/beranda_user_screen.dart`. Empat batas waktu device: **05:00, 11:00, 15:00, 19:00**; transitions dan app-resume menggunakan behavior existing. Header di dashboard, queue, detail, action center, reports, data pendaftar, profile memakai scenic yang sama; tidak lagi `_DashboardScenery` statis untuk role 1. Konten teks tetap terbaca siang dan malam; jangan membawa manual scene picker dari HTML ke produk (hanya alat preview wireframe). Sertakan back/route label konsisten. Jaga ikon notch/gesture dalam SafeArea.

### 2.3 Refresh tanpa tombol

Hapus seluruh `Icons.refresh`, `IconButton` atau `TextButton` berlabel `Muat ulang/Perbarui/Coba lagi` yang berfungsi sebagai manual refresh **pada semua layar di scope role 1**. Gunakan `RefreshIndicator` / nested scroll yang benar: tarik turun ketika di puncak list, termasuk empty/error states, dan seluruh konten cukup scrollable (`AlwaysScrollableScrollPhysics`) meski kosong. Setelah claim/approve/reject/release/scope/filter/perubahan booking, state refetch secara otomatis; on-resume/on-focus sesuai existing lifecycle. Jangan menghilangkan tindakan bisnis `Reset filter` dan `Terapkan` karena ini bukan refresh. Error 409/unknown result harus otomatis reconcile, tidak membuka duplicate submit; jika sinkronisasi belum berhasil, tampilkan pesan dan biarkan pull-down melakukan re-fetch. Freshness metadata tetap ada, lebih ringkas.

### 2.4 Filters, search, chips dan calendar

- Global `OperationsFilterSheet`: custom destination field -> `DestinationPickerSheet` searchable + single select. Daftar hanya destination assigned Admin, pagination mengikuti repository; no native dropdown overlay. Item terpilih punya check state; `Semua destinasi saya` jelas.
- Date control memakai `OperationsDateRangeCalendar`: custom month header (prev/next), weekday lokal, grid numerik 7 kolom, inclusive range shading dari tanggal awal sampai akhir, start/end emphasis, manual pilihan ulang, scroll/switch bulan, safe bottom CTA `Terapkan periode`; marker hari ini halus. Preset 7 hari, 30 hari, bulan ini; preview terpilih.
- Validasi jangan menyalahi batas backend (`operations_filters.dart` saat ini punya perbedaan kondisi `financial` vs nonfinancial sekitar 366 hari); pertahankan kontrak masing-masing, jelaskan error inline; `from <= to`. Calendar admin **tidak** mewarisi availability/bookability visit-only dari `AvailabilityCalendar`; reuse visual language, bukan disabled date logic.
- Sediakan `Terapkan filter`, `Reset filter`, close/cancel yang tidak mengubah applied filters. Filter antara tab konteks tetap konsisten tanpa memperluas hak akses. Backend data attribution harus dipertahankan: approval dan booking creation UTC; destinasi/visits kalender lokal destinasi; finance mengikuti basis API masing-masing. Jangan ubah tanggal menjadi device-local secara sembarangan.
- Status filter pendaftar (9 status) dibuat **horizontal scroll chip rail** dengan selected chip yang otomatis masuk viewport; tanpa clipping kiri/kanan, overscroll horizontal tidak menyebabkan scroll vertical lompat. Jangan overload semuanya pada satu baris yang dipaksa muat.

### 2.5 Aksi & sheet

Satu sticky action dock pada Detail Booking, di atas gesture bottom nav. State matrix:

| Booking/claim authoritative | Primary action | Secondary/UI |
|---|---|---|
| `pending_approval`, claim bebas, berhak approve | **Ambil Claim** | Detail info; belum boleh Setujui/Tolak. |
| `pending_approval`, claim aktif milik saya, masih valid | **Tinjau Keputusan** | Menu `···` -> `Lepas Claim`; countdown claim kecil. |
| Claimed admin lain | Tidak ada primary | Info penugasan/scope, bukan owner GUID PII mentah. |
| Booking disetujui/ditolak/expired | Tidak ada primary | Outcome badge + riwayat, status terminal. |
| Tindakan sedang pending/reconcile | Disabled/skeleton sesuai status | Double tap/duplicate submit diblokir; jangan optimistically set status. |
| 403/404/409/session berubah | Tidak ada tindakan | Clear stale data sesuai existing guards, re-read authoritative. |

`Tinjau Keputusan` membuka bottom sheet ringkas: identitas booking, tujuan, tanggal, jumlah tiket, status pembayaran jika backend tersedia; dua pilihan **Setujui** dan **Tolak**. Untuk `Tolak`, input alasan opsional hingga batas API existing; final submit tetap perlu konfirmasi yang jelas dan server validation. `Lepas Claim` hidden di overflow/secondary sheet; bukan 4 disabled buttons. Preserve idempotency key, claim ttl 15 menit, SLA approval asli, race/unknown outcome/409 behavior dari `ApprovalDetailState`/`AdminBookingDecider`. Dilarang auto-claim dan auto-approve. Tidak boleh mengubah status payment dari UI keputusan booking.

## 3. Screen-to-code mapping

| Screen / journey | Existing implementation | Target relayout |
|---|---|---|
| A00 Beranda Admin, Destinasi | `operations_dashboard.dart`, `operations_presentation.dart` | Scenic, summary + 4 KPI, tab Destinasi, Action Center teaser, finance demo subordinate, recent bookings/trend bila punya data. |
| A01 Kinerja Saya | `operations_dashboard.dart`, `operations_reports.dart` | Tab terpisah, KPI approval pribadi/SLA, unit dan source benar. |
| A02 Scope/date filters | `operations_filters.dart` | One bottom sheet + custom searchable picker + custom range calendar. |
| A03 Antrean Approval | `operations_queue_screen.dart` | Segmented Semua/Tersedia/Claim Saya, compact queue cards, proper empty/claim states, no refresh button. |
| A04 Detail & Claim | `operations_booking_screen.dart`, `approval_queue_state.dart` | Concise booking & visitor card, claim status inline, sticky action, decision sheet. |
| A05 Claim conflict | `approval_queue_state.dart`, `operations_booking_screen.dart` | 409 / expiry / stolen claim / unknown submit states, automatic re-fetch, guarded actions. |
| A06 Pusat Tindakan | `operations_dashboard.dart`, `operations_presentation.dart`, `operations_reports.dart` | Urgency-based concise action cards, source Laravel, destination filter. |
| A07 Tab Destinasi | `operations_navigation_shell.dart`, `operations_reports.dart` | Segmented Kinerja/Kelola; capacity/allocated/confirmed/remain, empty-not-zero, CRUD entry points role 1 scoped. |
| A08 Kunjungan & QR | `operations_reports.dart`, `admin_ticket_scanner_screen.dart` | Better attendance summary + entry to existing Scan → Preview → Confirm, do **not** rewrite QR validation or scanner. |
| A09 Data Pendaftar | `daftar_pendaftar_screen.dart` | 9 status chips, clean visitor booking cards, tap routes to guarded `OperationsBookingScreen`. |
| A10 Keuangan demo | `operations_financial.dart` | Demo/test-only finance summary, explicit source/status, preserve calculations, no DOKU production actions. |
| A11 Profil Admin | `operations_navigation_shell.dart` `_OperationsProfile` | Card modern konsisten, role/scope, existing logout, avoid PII beyond allowed. |
| Nav role 1 | `floating_bottom_nav.dart`, `operations_navigation_shell.dart` | **Beranda / Booking / Scan QR / Destinasi / Profil**, center elevated icon-only, blur, no labels; keep existing role 0 and 2 behavior untouched. |

Reuse component extraction hanya bila benar-benar mengurangi duplikasi: `OperationsScenicHeader`, `OperationsFilterSheet`, `DestinationPickerSheet`, `OperationsDateRangeCalendar`, `OperationalKpiCard`, `BookingDecisionSheet`, `OperationsEmptyState`; gunakan lokasi `lib/widgets/operations/` atau dekat file pemanggil sesuai architecture existing. Jangan membuat package UI/architecture baru.

## 4. Functional acceptance criteria per modul

**A00/A01 — Dashboard**
- Beranda operasional memprioritaskan peringatan approval/SLA dan empat angka kecil; dua tab toggle tidak mengubah authorization. Nilai dari Laravel dengan currency, unit, dan source jujur. Finance demo status bukan uang nyata.
- `Pusat Tindakan`, `Antrean Approval`, `Riwayat booking`, `Kinerja Destinasi`, `Kunjungan` adalah route yang menuju screen sebenarnya, bukan dummy button. Charts tidak boleh memalsukan titik data; tampilkan empty state atau `—` bila data tidak ada.

**A02 — Filter**
- Semua destination disaring assignment user role1; search, single select, apply/cancel/reset, prev/next month, preview start/end, preset 7/30/month, validation range, scrolling aman, no Material showDateRangePicker/DropdownButtonFormField untuk filter di scope.
- Di halaman keuangan, filter date mengikuti basis UTC/kontrak financial. Semua dialog menginherit Plus Jakarta Sans.

**A03/A04/A05 — Approval**
- User dapat berpindah queue tab, membuka detail, claim bila tersedia, membaca TTL, tinjau keputusan, approve/reject, release lewat overflow; disabled controls tidak menumpuk ketika booking terminal.
- No auto claim; server rechecks before decisions; 409 conflict, expiry, unknown submit and session/scope revocation block further unsafe action; changing booking re-fetches list/detail. Existing claim idempotency remains.
- Current approve reject `AlertDialog` / reassign dropdown only role2: role1 gunakan custom sheet; jangan mengubah logika role2 lebih luas.

**A06 — Action Center**
- Visually rank urgent items, include destination and visit date, action destination, no fabricated urgency. Empty state informative; pull-to-refresh works with zero items.

**A07 — Destinasi**
- Kinerja / Kelola segmented selector; performance capacity and occupancy correct. Avoid showing occupancy `0%` when denominator is zero; show `— / Belum tersedia` instead. CRUD links remain scoped, existing add/edit/disable/gallery/picker/quota workflows unchanged. No destructive direct tap without current confirmation.

**A08 — Kunjungan**
- QR scanner uses existing full-screen screen; **scan → backend validate → preview → petugas confirm**, authorized assigned destination only. Attendance/no-show null must show `Belum tersedia` unless backend confirms eligibility.

**A09 — Data Pendaftar**
- Preserve exact status enum + human labels from backend/`kBookingStatuses` (`Semua`, `Menunggu`, `Menunggu pembayaran`, `Verifikasi pembayaran`, `Peninjauan pembayaran`, `Disetujui`, `Ditolak`, `Kedaluwarsa`, `Dibatalkan`); inspect runtime source and never assume labels imply role1 can approve payment. Cards present name, destination, visit day, quantity, status, and detail route; no direct legacy approval bypass.

**A10/A11 — Keuangan dan profil**
- Keep DEMO/TEST_ONLY disclosure, source provenance (e.g. simulated demo events partial), no real transaction claim, avoid calculating revenue from fake mock HTML. Finance screen UI restyle only. Profile session and logout unchanged.

**Cross-cutting edge states:** loading skeleton, no assigned destinations, empty queue vs filtered-empty, no booking for status, no capacity data, network error, role revoked, expired claim, 409 collision, stale snapshot, unknown mutation result, accessibility scale, 360dp narrow viewport. No `Muat ulang/refresh` action button; support pulling the empty/error content. Ensure all route contexts inherit Plus Jakarta Sans and dynamic header.

## 5. Data/backend invariants (HARD STOP if violated)

- Only `role=1`, only assigned destinations. Preserve `AuthSession.sessionGeneration`, JWT handling, existing 403/404/409 responses, version/idempotency, and per-destination timezone semantics.
- Claim TTL ~15 minutes and original booking approval deadline remain server-truth; client countdown is informative only. Approval remains restricted to proper booking and permitted payment state.
- Any request outcome unknown is reconciled using existing guard before another mutate. Never invoke new payment settlement or refund endpoints from redesign.
- Role 0 experience, visitor calendar/bookability, ticket QR ownership/check-in rules, and role 2 executive/admin management behavior are protected.
- No API/database/schema changes, endpoint invention, seeded test data in production UI, or unofficial backend totals.

## 6. Implementation sequence, optimized to avoid rework

1. **Read only preflight:** open `C:\Users\itsba\.codex\Agents.md`, agents directory, local skill manifests, repository `git status`/HEAD, actual V1 HTML, existing Flutter UI files; map visual components to source and output 6–10 concise baseline facts. No shotgun repository audit.
2. **Design-system bridge:** ensure Role1 routes/theme, typography (including overlays), shared scenic header and pull-refresh wrapper; don't patch global visitor theme unnecessarily.
3. **Shared filters:** replace default selects/date picker with custom sheets and ranged calendar, preserve contract; unify filter states only where required.
4. **Dashboard, queue and detail:** implement visual hierarchy, claim dock/decision sheet, errors; preserve `ApprovalDetailState` guards.
5. **Destinasi, visit, registrants, finance/demo, profile:** integrate the remaining 9 screenshots' component coverage and role1 routes without rewiring APIs.
6. **Final lightweight static self-review:** inspect changed files and `git diff` for unrelated changes; no formal QA, regression, `flutter analyze`, `flutter test`, `flutter run`, screenshots, or APK builds. Report untouched backend and limitations.

Use a primary Codex orchestrator, **max 2 subagents**: `flutter_engineer` for implementation; `frontend_engineer` for bounded fidelity review if available. Do not spawn QA/testing, security, FigCraft or broad design explorations.

## 7. Skills invocation contract

Skill use must be **real local reading**, not merely name-dropping. Inspect actual locations under `C:\Users\itsba\.agents\skills\` and `C:\Users\itsba\.codex\skills\` (including repo-local `.agents\skills`), and follow each existing `SKILL.md` + relevant references. **Do not assume installation solely from conversation.**

| Skill | Applicability in this task | Operating rule |
|---|---|---|
| `design-taste-frontend` / `design-taste` | **Required UI design direction** | Read skill/reference, adapt spacing, hierarchy, density, anti-slop to Flutter, not CSS. |
| `ui-ux-pro-max` | **Required targeted UI guidance** | Read `SKILL.md`; use local `scripts/search.py` with `--stack flutter` and, if useful, `--domain ux` for mobile filter/decision patterns. Use returned guidance selectively; V1 remains source of truth. |
| `flutter-custom-design-system` | Use if installed | Native Flutter tokens/components and maintainable reuse; no new generic library. |
| `flutter-improving-accessibility` | Use if installed | Tap targets, focus/order/semantics, text scaling, contrast, scrolling. |
| `impeccable` | Use if installed and relevant | Focused design polish pass; do not create new aesthetics. |
| `humanizer` | Use if installed | Microcopy/help/empty states only; do **not** rewrite Dart source code, route names, API schema/contract. |
| `web-design-guidelines` | Use only to interpret **HTML V1** if beneficial | Do not port CSS/web-specific tech to Flutter. |
| `anatomy` | **Not applicable by default** | Interactive isometric explainers, not mobile screen layout. Do not generate illustrative assets. |
| `reverse-engineer-anything` | **Not applicable by default** | REA for binaries/runtime reverse engineering; full Flutter source exists. Skill-only, no MCP or engine/config setup. |

If either required skill is missing, do not claim it was invoked; report the exact missing path and proceed only with an explicitly stated limitation (do not auto-install without user authorization). Optional absent skills are simply noted. User's already-installed skill content and references take precedence over guessed syntax.

## 8. Completion contract / handoff

Deliver actual Flutter code changes for role1, not only a design file. At finish provide: (i) changed files and relevant screens, (ii) navigation/actions/filters delivered, (iii) skill inventory actually read/applied versus skipped, (iv) backend/other roles not changed, (v) unresolved blockers, (vi) list of omitted verification commands because user forbids Flutter QA/test/analyze/build. Keep one coherent implementation, no repeated requirement questionnaires or PRD regeneration.

## Appendix A — Screenshot grouping (29 images)

| Images in `docs/design/references/screenshots/` | Original functionality represented |
|---|---|
| 01–03 | Beranda Admin: snapshot, KPI, finance demo, booking trend, action center, navigation links. |
| 04 | Kinerja Saya. |
| 05–07 | Filter destinasi, native select overlay, native date-range picker (replace). |
| 08–10 | Antrean Approval: Semua, Tersedia, Claim aktif empty states. |
| 11 | Queue destination picker overlay. |
| 12–13 | Kinerja Destinasi cards, pagination and management links. |
| 14 | Profil Admin. |
| 15 | Pusat Tindakan. |
| 16–17 | Detail Booking, claim state, overcrowded action buttons. |
| 18–23 | Data Pendaftar and status chips (including verification, review, approved). |
| 24–25 | Kinerja Destinasi legacy serif, pagination and CRUD links. |
| 26–27 | Legacy dropdown and Material date-range picker (replace). |
| 28–29 | Kunjungan/QR verification and attendance/no-show cards. |

**Tanda penerimaan final:** layout baru terasa seperti keluarga visitor V4, tidak ada Georgia role1, tidak ada refresh button, semua aksi booking benar secara business state, pemilihan destinasi/date mudah dan custom, seluruh screen pada appendix dapat dijangkau dari role1, dan tidak ada regresi yang sengaja diperkenalkan pada role0/role2/backend.
