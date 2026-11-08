# Icon Source Inventory — Baseline Remote 3fbf22b6a70c

Tanggal audit: 7 November 2026. Ini inventaris **pemakaian literal `Icons.*` Material** pada file UI yang dibaca dari remote GitHub. Angka dapat menghitung pemakaian di konstanta/map dan tidak sama dengan jumlah ikon unik atau widget yang terlihat. **Bukan daftar lengkap semua icon custom/SVG/dynamic**, jadi Codex wajib memindai seluruh `lib/**/*.dart` dari working tree lokal sebelum menyatakan migrasi total.

- Berkas UI yang ditinjau: **56**.
- Referensi literal `Icons.*` dalam sampel: **394**.
- Pengecualian penting di luar hitungan: `lib/widgets/floating_bottom_nav.dart` berisi **2 kelas ikon CustomPainter** yang wajib dihapus/diganti (`_NavIconPainter`, `_OperationsIconPainter`).
- File yang memiliki 0 literal `Icons.*` **tetap harus diaudit** jika menerima `IconData` dinamis atau icon custom.

| Area | File | Referensi `Icons.*` |
|---|---|---:|
| User/Auth | `lib/screens/auth_presentation.dart` | 2 |
| User/Auth | `lib/screens/user_login_screen.dart` | 5 |
| User/Auth | `lib/screens/user_register_screen.dart` | 7 |
| User/Auth | `lib/screens/forgot_password_screen.dart` | 1 |
| User/Auth | `lib/screens/verify_email_otp_screen.dart` | 1 |
| User/Auth | `lib/screens/verify_reset_otp_screen.dart` | 0 |
| User/Auth | `lib/screens/reset_password_screen.dart` | 7 |
| User/Auth | `lib/screens/admin_login.dart` | 0 |
| User/Visitor | `lib/screens/beranda_user_screen.dart` | 13 |
| User/Visitor | `lib/screens/home_screen.dart` | 2 |
| User/Visitor | `lib/screens/cari_wisata_screen.dart` | 27 |
| User/Visitor | `lib/screens/detail_wisata_screen.dart` | 18 |
| User/Visitor | `lib/screens/daftar_kunjungan_screen.dart` | 8 |
| User/Visitor | `lib/screens/bukti_pendaftaran_screen.dart` | 33 |
| User/Visitor | `lib/screens/permintaan_terkirim_screen.dart` | 2 |
| User/Visitor | `lib/screens/notifikasi_screen.dart` | 11 |
| User/Visitor | `lib/screens/profil_user_screen.dart` | 17 |
| User/Visitor | `lib/screens/main_navigation_screen.dart` | 0 |
| Admin/Operations | `lib/screens/admin_common.dart` | 1 |
| Admin/Operations | `lib/screens/admin_dashboard.dart` | 0 |
| Admin/Operations | `lib/screens/admin_ticket_scanner_screen.dart` | 5 |
| Admin/Operations | `lib/screens/daftar_pendaftar_screen.dart` | 4 |
| Admin/Operations | `lib/screens/daftar_wisata_screen.dart` | 43 |
| Admin/Operations | `lib/screens/kelola_kuota_screen.dart` | 5 |
| Admin/Operations | `lib/screens/tambah_wisata_screen.dart` | 18 |
| Admin/Operations | `lib/screens/operations_dashboard.dart` | 24 |
| Admin/Operations | `lib/screens/operations_home.dart` | 4 |
| Admin/Operations | `lib/screens/operations_navigation_shell.dart` | 4 |
| Admin/Operations | `lib/screens/operations_presentation.dart` | 18 |
| Admin/Operations | `lib/screens/operations_reports.dart` | 14 |
| Admin/Operations | `lib/screens/operations_queue_screen.dart` | 5 |
| Admin/Operations | `lib/screens/operations_filters.dart` | 18 |
| Admin/Operations | `lib/screens/operations_financial.dart` | 7 |
| Admin/Operations | `lib/screens/operations_booking_screen.dart` | 8 |
| Admin/Operations | `lib/screens/destination_admin_assignments_screen.dart` | 0 |
| Admin/Operations | `lib/screens/kelola_admin_screen.dart` | 9 |
| Admin/Operations | `lib/screens/kelola_fasilitas_screen.dart` | 7 |
| Admin/Operations | `lib/screens/kelola_kategori_screen.dart` | 7 |
| Admin/Operations | `lib/screens/demo_checkout_screen.dart` | 6 |
| Map | `lib/screens/destination_location_picker_screen.dart` | 1 |
| Map | `lib/screens/destination_map_screen.dart` | 2 |
| Shared widgets | `lib/widgets/floating_bottom_nav.dart` | 0 |
| Shared widgets | `lib/widgets/operations_tabs.dart` | 0 |
| Shared widgets | `lib/widgets/operations_chrome.dart` | 4 |
| Shared widgets | `lib/widgets/availability_calendar.dart` | 3 |
| Shared widgets | `lib/widgets/admin_destination_gallery_editor.dart` | 4 |
| Shared widgets | `lib/widgets/booking_payment_section.dart` | 0 |
| Shared widgets | `lib/widgets/booking_ticket_qr_section.dart` | 1 |
| Shared widgets | `lib/widgets/destination_hero_gallery.dart` | 2 |
| Shared widgets | `lib/widgets/destination_location_map_preview.dart` | 1 |
| Shared widgets | `lib/widgets/profile_avatar.dart` | 9 |
| Shared widgets | `lib/widgets/reviews_sheet.dart` | 2 |
| Shared widgets | `lib/widgets/international_phone_field.dart` | 3 |
| Shared widgets | `lib/widgets/api_image.dart` | 1 |
| Config | `lib/theme/app_colors.dart` | 0 |
| Config | `lib/main.dart` | 0 |

## Audit rules ketika Codex implementasi

1. Cek `Icons.`, `CupertinoIcons.`, `IconData`, `SvgPicture`, `ImageIcon`, `CustomPainter`, dan icon asset buatan sendiri pada **seluruh lib**, bukan hanya tabel ini.
2. Untuk setiap satu referensi lama, pilih semantik Phosphor yang benar dengan style Regular/Fill (bukan search-replace identifier secara mentah).
3. Jaga `onTap`, `onPressed`, semantics, tooltip, idempotency, auth/permission, dan state semua role.
4. Abaikan ilustrasi scenic, logo, foto, QR bitmap, chart path, dan crop guide sebagai non-icon assets.
5. Catat residual Material/Cupertino/ikon non-Phosphor yang benar-benar tidak dapat diganti beserta alasan.

## Mapping contoh (nama properti harus diverifikasi dari package lokal)

| Konsep lama | Phosphor intent |
|---|---|
| `Icons.arrow_back_rounded` | arrowLeft (Regular) |
| `Icons.close_rounded` | x (Regular) |
| `Icons.search_rounded` | magnifyingGlass (Regular) |
| `Icons.favorite_border` | heart (Regular) |
| `Icons.favorite` | heart (Fill) |
| `Icons.star_border` | star (Regular) |
| `Icons.star_rounded` | star (Fill) |
| `Icons.check_circle_rounded` | checkCircle (Fill) |
| `Icons.edit_rounded` | pencil (Regular) |
| `Icons.calendar_today_outlined` | calendarBlank (Regular) |
| `Icons.qr_code_scanner_rounded` | qrCode / scan concept (Regular) |
| icon painter navbar User | house/ticket/compass/bell/userCircle (Regular/Fill) |

> Inventaris merupakan dasar migrasi statis, **bukan hasil QA/regression/testing**.
