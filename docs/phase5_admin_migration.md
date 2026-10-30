# Phase 5: administrasi Laravel — penyelesaian fungsional

Kontrak lengkap: `docs/api_contract_phase4_5.md`. Autentikasi terpadu: `docs/phase5_unified_auth.md` (tidak diubah).

## Status akhir: FUNCTIONALLY COMPLETE (batas operasional di bawah)

Semua operasi administrasi memakai Laravel/MySQL dan AuthSession (Bearer). Tidak ada Firestore atau Firebase Storage pada layar admin aktif.

## Yang diselesaikan

| Butir PRD | Implementasi |
| --- | --- |
| Booking admin (4) | `daftar_pendaftar_screen`: filter status di server, semua halaman + dedupe, detail via `GET admin/bookings/{guid}` (tombol keputusan aktif setelah detail terbaca), approve / reject dengan alasan opsional, guard double submit per GUID, tanpa perubahan status optimistis. `booking_not_pending` / `approval_deadline_passed` → baca ulang detail; timeout → rekonsiliasi via detail, tidak ada pengulangan otomatis. Gratis → `confirmed`, berbayar → `awaiting_payment`, reject → `rejected`. |
| Destinasi (5) | Create, edit, nonaktifkan, daftar nonaktif (`admin/destinations?status=`), reaktivasi (`PATCH is_active`; 409 `category_inactive`). Form tambah tidak lagi diblokir: mengirim `destination_category_guid`, `name`, `location`, `description`, `ticket_price`, `opening_hours`, `timezone` (dropdown IANA `Asia/Jakarta`, `Asia/Makassar`, `Asia/Jayapura`). Daftar katalog segar setelah refresh. |
| Kategori (6, role 2) | `kelola_kategori_screen`: daftar termasuk nonaktif, buat, ubah, nonaktifkan/aktifkan; slug unik (422); kategori masih dipakai destinasi aktif → 409 `category_in_use`; relasi tidak dirusak. |
| Kuota (7, role ≥ 1) | `kelola_kuota_screen`: kapasitas total, alokasi, dan sisa sebagai tiga nilai berbeda; `visit_date`, `capacity`, `booking_opens_at`, `booking_closes_at` dikirim UTC `Z`; validasi server (kapasitas ≥ alokasi, jendela valid, serialisasi konkuren). |
| Gambar (8) | Multipart `image` (JPEG/PNG/WebP ≤ 5 MB) pada create/edit atau `POST destinations/{guid}/image`. Backend tidak lagi membocorkan `image_path`; menyajikan `image_url` relatif berversi + endpoint media. Flutter memuat lewat `ApiImage` (bekerja dengan header Host emulator). File lama dihapus setelah referensi baru tersimpan. |
| Akun admin (9, role 2) | `kelola_admin_screen`: daftar (`GET admin/accounts`), buat admin (role 1), suspend/aktifkan, ubah role. Tidak dapat mengubah role/status sendiri; superadmin aktif terakhir dilindungi; akun terdampak dicabut sesinya seketika. Tanpa Firebase sebagai sumber akun. |

Sisi Flutter: `lib/data/admin_state.dart` (`PagedListController`, `AdminBookingDecider`, guard, pemetaan error), `lib/screens/admin_common.dart`, layar di atas, entri dashboard (Kuota role ≥ 1; Kategori & Admin hanya role 2 — hanya UX, backend tetap otoritas).

## Keamanan (diverifikasi)

Semua dengan HTTP nyata + MySQL (E2E Skenario D) dan tes fitur:

- Role 0 → 403 pada seluruh endpoint admin (booking, destinasi, kategori, akun, kuota).
- Role 1 → 403 pada endpoint role 2 (kategori, daftar/buat/ubah akun).
- Tanpa token → 401. User A tidak dapat membaca/membatalkan/mengunduh dokumen/membaca intent milik User B (404 atau `not_found` tanpa data).
- Logout, perubahan role, dan suspend mencabut akses seketika (token lama 401); login akun suspended ditolak.
- Approve vs reject vs cancel serentak di MySQL: tepat satu menang, riwayat konsisten.
- Google Login role 1/2 → 403 di `AuthService` (tidak diubah; diuji dengan mock verifier).

## Hasil verifikasi

Sama dengan tabel di `phase4_booking_migration.md`: Laravel 50 tes PASS, MySQL konkurensi 7 PASS, E2E A–D 4 PASS, Flutter 185 PASS, analyzer 0 error / 237 warning+info (baseline 263), `git diff --check` PASS. Android Emulator/perangkat, ID token Google nyata, FCM/SMTP nyata: NOT VERIFIED.

## Risiko yang belum selesai

1. Flow `image_picker`, tiga pemilih tanggal/waktu, dan tampilan visual hanya diuji pada level kontrak HTTP dan widget; tidak pada perangkat.
2. Tidak ada endpoint hapus gambar; "Hapus Foto" diganti "Batalkan Foto Baru".
3. Jam kuota dipilih di zona waktu perangkat dan dikirim UTC; aturan "tutup sebelum hari kunjungan" dinilai server di zona waktu destinasi (pesan 422 ditampilkan).
4. Daftar terurut terbaru dapat melewatkan baris yang bergeser antar halaman saat paging; dedupe hanya menghapus duplikat, tarik-segarkan memulihkan.
5. `AdminDashboard` tidak diuji widget (dependensi GoogleFonts); gating role diuji pada level fungsi.
6. Dashboard tidak punya endpoint statistik; angka diambil dari total daftar. Rating tidak tersedia.
7. Pembayaran, review, check-in tetap di luar cakupan; lihat risiko di `phase4_booking_migration.md`.
