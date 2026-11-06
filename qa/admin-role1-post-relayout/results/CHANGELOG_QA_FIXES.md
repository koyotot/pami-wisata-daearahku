# Perubahan QA

## Produk

1. `lib/widgets/floating_bottom_nav.dart`: D-001, satu aksi tap pada node semantics navbar untuk role0/1/2.
2. `lib/screens/operations_navigation_shell.dart`: D-002, mute ticker tab tidak aktif dengan TickerMode; state dan navigasi dipertahankan.

Tidak mengubah backend, schema, pembayaran, JWT, RBAC, TTL, ApprovalDetailState, QR validation, idempotency, atau status bisnis.

## Tes existing yang diselaraskan

- `test/operations_dashboard_layout_test.dart`: summary + empat KPI, null values, icon/metadata role1/2, pull-to-refresh empty, label/chart/nav clearance; memakai font produk tracked untuk layout. Capture fixture sekarang ke `results/widget-renders/`, sehingga artifact lama tidak ditimpa.
- `test/operations_booking_test.dart`: key sticky CTA role1; menunggu snackbar sementara sebelum recovery; tetap memeriksa back guard, jumlah POST dan same-key headers.
- `test/operations_shell_test.dart`: label approved dan pull-to-refresh saat akses diperbarui; assertion lifecycle/logout/nav tetap ada.
- `test/operations_reports_test.dart`: copy empty/audit/null occupancy approved, tombol pagination benar-benar terlihat sebelum tap, refresh gesture, invalidasi picker dan hasil filter kosong setelah revalidasi.
- `test/admin_widget_test.dart`: chip horizontal/GlobalKey ditemukan lewat label control; entry history menjalani explicit claim → review → approve, dengan exact request paths.
- `test/auth_prd_redesign_test.dart`: mengikuti PRD full-bleed disetujui; background top0, foreground aman di bawah inset44, CTA tetap reachable dengan keyboard.

## Tes baru

- `test/operations_accessibility_regression_test.dart`: empat tes; semantics tap dan empat guideline navbar pada tiga role, nested theme/snackbar Jakarta di atas root Georgia.
- `test/operations_post_relayout_test.dart`: 16 tes; custom picker/calendar, fallback role2, tanggal boundary/leap/reverse/reset, blank reject, release, changed owner/resume, legacy chips/detail, hidden tickers.
- `test/operations_queue_finance_regression_test.dart`: tujuh tes; urgency server/guarded route, Kinerja/Kelola/quota entry, profile logout, queue ownership/pagination/revalidation/refresh empty-error, finance DEMO dan foreign scope rejection.
- `test/operations_scanner_scope_regression_test.dart`: dua tes **tetap gagal**, mereproduksi D-003. Tidak menghapus assertion, skip, atau menyesuaikan guard agar hijau.

## Artefak

Matrix input disalin ke `qa/admin-role1-post-relayout/TEST_MATRIX.csv`; seluruh 45 case diisi pada `results/TEST_MATRIX_EXECUTED.csv`. Laporan, log, 10 PNG Android login nyata, dan 10 PNG render widget fixture tersimpan terpisah. Dua dokumen QA input pengguna yang semula untracked tetap dipertahankan.

Tidak ada commit, push, pull, checkout, reset, rebase, perubahan remote, atau mutasi API live.
