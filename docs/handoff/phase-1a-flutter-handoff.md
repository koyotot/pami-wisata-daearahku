# Flutter Admin/Superadmin Phase 1A — implementation handoff

Tanggal: 5 November 2026. Scope berhenti sebelum Phase 1B DOKU dan Phase 2.

## Baseline dan working tree

- Flutter branch `main`, HEAD `cba3d0b581c4ddc38c345380846f1a4de8e37847`.
- Sebelum implementasi: hanya PRD `docs/prd/PRD-Wisata-Daerahku-Flutter-Admin-Superadmin-Phase-1A-Integration.md` untracked. File tersebut dipertahankan.
- Sesudah: 10 tracked files modified, 16 file baru untracked (source/test/handoff), ditambah PRD untracked semula. Tidak ada file staged; HEAD tidak berubah.
- Laravel read-only: HEAD `c43a5d18183a660ccf45830c2c51e6e2698ff322`; working tree bersih sebelum/sesudah pekerjaan.
- Tidak ada commit, staging, push, perubahan environment/dependency, aktivasi DOKU, atau perubahan `APPROVAL_CLAIM_MODE`. Default Laravel tetap `compat`.
- Tepat dua subagent: Flutter engineer (UI) dan security auditor (read-only). Tidak menggunakan FigCraft.

## File dan perilaku

File produksi baru: `lib/data/operational_models.dart`, `lib/data/approval_queue_state.dart`, `lib/screens/operations_navigation_shell.dart`, `operations_dashboard.dart`, `operations_reports.dart`, `operations_filters.dart`, `operations_presentation.dart`, `operations_queue_screen.dart`, `operations_booking_screen.dart`.

File produksi diubah: `session_destination.dart`, `admin_dashboard.dart` (compatibility wrapper), `daftar_pendaftar_screen.dart` (history tanpa direct decision), `floating_bottom_nav.dart` (parameter opsional), `business_repository.dart`, `admin_state.dart` (pesan claim/409 reconciliation).

Test baru: `operations_contract_test.dart`, `approval_queue_state_test.dart`, `operations_booking_test.dart`, `operations_shell_test.dart`, `operations_reports_test.dart`, `operations_test_support.dart`. Test existing disesuaikan: `admin_widget_test.dart`, `admin_state_test.dart`, `unified_routing_test.dart`, `v4_navigation_notifications_test.dart`. Selector notification disesuaikan dengan label jumlah unread yang sudah ada; source role 0 tidak diubah.

Role 0 tetap memakai MainNavigationScreen dan default visitor painter/navbar. Role 1 memakai Beranda/Booking/**Scan QR**/Destinasi/Profil; center membuka scanner existing sebagai route fullscreen lalu kembali ke tab sebelumnya. Role 2 memakai Ringkasan/Operasi/**Analitik**/Kelola/Profil. Navbar icon-only, tooltip/semantics, blur, hit area 48dp, safe area dan hide saat keyboard. Tab berat dimuat saat dipilih. Back dari non-home menuju home; child route kembali ke parent.

## Inventaris layar (implementasi)

COMPLETE di tabel berarti representasi UI dan wiring tersedia; bukan bukti authenticated live E2E atau kecocokan screenshot perangkat.

| ID | Status | Implementasi / state |
|---|---|---|
| A00 | COMPLETE | operations_dashboard: overview KPI, segment Destinasi/Kinerja Saya, tren booking, Action Center |
| A01 | COMPLETE | dashboard personal + reports approvals personal; response/SLA null tetap —, claim aktif dari overview; series tim diberi label tersendiri |
| A02 | COMPLETE | operations_filters: pilihan admin/destinations terpaginasikan, pilih/reset/apply periode dan destinasi |
| A03 | COMPLETE | operations_queue_screen: antrean paginated, urgency server, filter tanggal/destinasi dan status claim pada halaman termuat |
| A04 | COMPLETE | operations_booking_screen + ApprovalDetailState: authoritative detail, explicit claim, approve/reject/release |
| A05 | COMPLETE | 409 ditampilkan, baca ulang booking dan claim; tidak auto-submit |
| A06 | COMPLETE | reports action-center, pagination dan drill-down booking |
| A07 | COMPLETE | reports destinations: kapasitas, alokasi, terkonfirmasi, sisa, okupansi terpisah; management existing tetap terjangkau |
| A08 | COMPLETE | reports visitors + entry fullscreen scanner existing |
| A09 | COMPLETE | financial unavailable: —, DOKU belum terhubung, tanpa gateway CTA |
| E00 | COMPLETE | dashboard global, KPI, tren keputusan tim dan tindakan operasional |
| E01 | COMPLETE | paginated destination comparisons dengan unit alokasi/konfirmasi/booking/permintaan berbeda |
| E02 | COMPLETE | staff/staff_workload, nama melalui accounts paginated; detail SLA lewat approvals?admin_guid, tanpa SLA buatan pada list |
| E03 | COMPLETE | shared queue global dan claim owner/deadline |
| E04 | COMPLETE | reassign: intersection assignment destinasi dan accounts aktif role 1, reason wajib max255, stable key dan 422 |
| E05 | COMPLETE | Kelola: destination view/edit/delete/create/quota, assignment, accounts, category, facilities existing |
| E06 | COMPLETE (unavailable sesuai PRD) | route audit ada; menjelaskan API timeline global belum tersedia. Tidak ada audit entry buatan |
| E07 | COMPLETE | financial unavailable global |
| E08 | COMPLETE | action-center global + queue/detail drill-down |
| X01 | COMPLETE | zero assignment diberi arahan hubungi Superadmin; query tetap assignment-scoped di Laravel |
| X02 | COMPLETE | antrean kosong, refresh dan navigasi kembali |
| X03 | COMPLETE | skeleton/indikator loading, tanpa dummy KPI 0 |
| X04 | COMPLETE | network error/retry; detail lama ditandai belum tersinkron, mutation disabled sampai reread |
| X05 | COMPLETE | no-result filter, reset/apply dan load pagination eksplisit |
| X06 | COMPLETE | 403/404 purge scoped data + me revalidation; cache retained tabs/filter dibersihkan; perubahan role/generation menghapus child routes |
| X07 | COMPLETE | null financial/attendance/no-show tetap unavailable |
| X08 | COMPLETE | claim_owned/not_owned/required, not_pending/deadline dan 409 generic: tampilkan konflik + authoritative reread |

## Kontrak API

Semua path relatif `/api/v1`; JWT memakai ApiClient/AuthSession existing. Tidak ada custom role header atau payment mutation.

| Method/path | Pemakaian |
|---|---|
| GET admin/dashboard/overview | metrics/personal/assigned_workload/booking_trend/scope/period/financial/generated_at |
| GET admin/dashboard/approvals | team_operational_totals/personal/series/staff/staff_workload; admin_guid hanya role 2 |
| GET admin/dashboard/destinations | ApiPage dengan root meta/links; quantity_requested/allocated/confirmed_quantity/capacity/remaining/occupancy |
| GET admin/dashboard/visitors | observed check-in metrics; attendance_rate/no_show_count null |
| GET admin/dashboard/action-center | paginated server action rows, booking GUID untuk detail |
| GET admin/approval-queue | paginated non-PII rows, claim owner/state/expiry |
| GET admin/bookings/{guid} | detail booking/PII/status/approval deadline yang berwenang |
| POST admin/bookings/{guid}/claim | Idempotency-Key, body kosong; explicit user action |
| POST admin/bookings/{guid}/release | Idempotency-Key; UI melepas own claim |
| POST admin/bookings/{guid}/approve atau reject | existing authoritative Booking response; own claim diperiksa ulang sebelum POST |
| POST superadmin/bookings/{guid}/reassign | Idempotency-Key + admin_guid + reason; target active assigned role 1 |
| GET admin/accounts | bounded pagination identitas staff/target reassign |
| GET admin/destinations/{guid}/admins | existing assignment IDs untuk target reassign |
| GET admin/destinations | assigned selector; tidak memakai public catalog untuk filter admin |
| GET/PUT admin/destinations/{guid}/admins dan CRUD management existing | dipertahankan melalui screen existing |

UI mengirim from/to berpasangan (`YYYY-MM-DD`, selisih <=366 hari), destination_guid/page/per_page sesuai kebutuhan, tanpa date_basis arbitrer. Overview/approvals adalah decision UTC; booking trend created UTC; destinations/visitors adalah visit calendar lokal. Pending/workload merupakan snapshot saat ini. Scope dan filter tidak diturunkan dari metrik lokal.

Contoh berikut **fixture test**, bukan data live atau akun sebenarnya:

```json
{
  "data": [{"booking_guid":"b1","destination_guid":"dest-1","destination_name_snapshot":"Pantai Indah","claim_state":"unclaimed","owner_user_guid":null,"expires_at":null}],
  "meta": {"current_page":1,"last_page":2,"generated_at":"2026-11-05T00:00:00Z","period":{"date_basis":"created"}},
  "links": {"next":"next-url"}
}
```

Null semantics diuji dengan `financial.gross_revenue=null`, `attendance_rate=null`, `no_show_count=null`, dan capacity-zero occupancy=null. Nilai null tidak dijadikan revenue atau persen nol.

## Claim, race dan session safety

- Queue tidak mendukung booking_guid filter dan BookingResource tidak memuat claim. Detail membaca booking lalu menelusuri halaman queue scoped destinasi sampai GUID cocok; tidak menganggap claim ada pada halaman pertama.
- Decision disabled sampai own active claim terkonfirmasi dan booking pending/deadline valid. Tepat sebelum keputusan, booking dan claim dibaca ulang. Server tetap otoritas akhir.
- Claim/release/reassign memakai satu UUID untuk satu tindakan. Unknown outcome menyimpan key/action/payload asli, melakukan GET reconciliation, dan hanya mengulang lewat tombol recovery eksplisit dengan key sama. Tidak ada retry otomatis dengan key baru.
- Back sementara mutasi berjalan/unknown ditahan dengan penjelasan agar key tidak hilang saat route disposed. Pencabutan akses tetap mengizinkan keluar; key dibersihkan. Key hidup di controller selama proses aplikasi; process-death recovery tidak diuji.
- POST sukses yang diikuti GET gagal tetap menjadi POST terkonfirmasi; tombol mutation menunggu manual refresh. Malformed claim response dianggap unknown, bukan sukses.
- 409 membaca ulang; 422 tetap definite failure; 403/404 membersihkan detail/queue, me memicu purge sibling tabs dan filter. Tidak ada fallback global otomatis setelah access error.
- Resume memeriksa session/role dan membaca ulang data; timer perangkat hanya dekorasi, tidak memberi otorisasi.
- Security auditor melakukan source review terbatas; temuan yang dilaporkan telah diperbaiki. Ini bukan security clearance produksi.

## Verifikasi dan batas bukti

**PASS:** 86 tests pada 10 file targeted, analyzer pada 25 file source/test yang berubah tanpa issues, `dart format`, dan `git diff --check`. Tidak ada full suite, full analyze, APK build, ataupun deployment.

Command test final (PowerShell, seluruh argumen dalam satu command):

```powershell
flutter test test/operations_contract_test.dart test/approval_queue_state_test.dart test/operations_booking_test.dart test/operations_shell_test.dart test/operations_reports_test.dart test/admin_widget_test.dart test/admin_state_test.dart test/admin_repository_contract_test.dart test/unified_routing_test.dart test/v4_navigation_notifications_test.dart
```

Command analyzer final:

```powershell
flutter analyze lib/data/operational_models.dart lib/data/approval_queue_state.dart lib/data/business_repository.dart lib/data/admin_state.dart lib/screens/operations_booking_screen.dart lib/screens/operations_queue_screen.dart lib/screens/operations_navigation_shell.dart lib/screens/operations_dashboard.dart lib/screens/operations_reports.dart lib/screens/operations_filters.dart lib/screens/operations_presentation.dart lib/screens/admin_dashboard.dart lib/screens/daftar_pendaftar_screen.dart lib/widgets/floating_bottom_nav.dart lib/screens/session_destination.dart test/operations_contract_test.dart test/approval_queue_state_test.dart test/operations_booking_test.dart test/operations_shell_test.dart test/operations_reports_test.dart test/operations_test_support.dart test/admin_widget_test.dart test/admin_state_test.dart test/unified_routing_test.dart test/v4_navigation_notifications_test.dart
```

Temuan pada run awal diperbaiki: guard compatibility route, timer disposal dialog, expectation routing/409, selector unread existing, invalid claim response, dan pagination overflow pada text scale2. Quality gate di atas adalah hasil sesudah perbaikan. Tidak ada failing test yang sengaja diabaikan.

- Backend lokal merespons GET dashboard tanpa token dengan HTTP 401. Ini hanya membuktikan reachability/auth gate, bukan report live atau readiness mutasi.
- `adb devices`: tidak ada perangkat/emulator terhubung. Android manual smoke/camera/permission dan visual screenshot fidelity **NOT VERIFIED**.
- Authenticated Laravel read/mutation E2E **NOT VERIFIED**; deterministic HTTP mocks hanya di test. Tidak menggunakan akun/credentials buatan di runtime UI.
- UI/render tests mencakup navbar safe area/icon-only/keyboard, center role1/role2, back/retained tabs, 360×800 dan 393×852 dengan text scale2, explicit claim/reassign, logout nested-route purge, dan scope/session changes.

## Gap backend dan tindak lanjut terpisah

E06: perlu API audit timeline global berotorisasi jika fitur tersebut kelak diaktifkan. Sekarang route unavailable sesuai PRD. E02 detail individual tersedia melalui filtered approvals; aggregate SLA per staff tidak diinventarisasi dari staff list.

Phase 1B membutuhkan authoritative gateway/payment ledger serta kontrak eligibility, callback/idempotency/reconciliation dan deployment readiness tersendiri. Tidak ada payment-preview admin, gateway CTA aktif, fake paid, atau perubahan scanner/QR rules pada pekerjaan ini. Phase 2 tidak dimulai.
