# Phase 5: migrasi administrasi Laravel

## Kontrak yang diaudit

Seluruh path di bawah relatif terhadap `/api/v1`. Operasi admin memakai Bearer Laravel; role dan status akun diverifikasi server. `auth/me` mengembalikan `guid`, `role` integer dan `status`. Role minimal 1 untuk booking, destinasi, dan kuota; kategori dan akun admin memerlukan role 2.

| Operasi | Kontrak backend |
| --- | --- |
| Dashboard | Tidak ada endpoint statistik admin. |
| Booking | `GET admin/bookings`, halaman 15 item dengan `data`, `links`, `meta`; `POST admin/bookings/{guid}/approve` atau `reject`, body `reason` opsional maksimal 255 karakter. Resource berisi identitas, snapshot destinasi, tanggal, jumlah, kontak, harga, status dan waktu. |
| Detail booking | `GET bookings/{guid}` hanya untuk pemilik, bahkan jika pemanggil admin. Data detail admin terbatas pada resource daftar; tidak ada endpoint refresh detail individual admin. |
| Katalog | `GET categories`, `GET destinations`, `GET destinations/{guid}` publik; `POST`, `PATCH`, `DELETE categories/{guid}` dan `destinations/{guid}` dilindungi role. Daftar hanya resource aktif; DELETE menonaktifkan. POST kategori memerlukan `name`, `slug`; destinasi memerlukan `destination_category_guid`, `name`, `location`, `description`, `ticket_price`, `opening_hours`, `timezone`. |
| Kuota | `GET destinations/{guid}/quotas` berpaginasi dan `PUT` dengan `visit_date`, `capacity`, `booking_opens_at`, `booking_closes_at`. `capacity` adalah total, bukan sisa. Kapasitas di bawah alokasi menghasilkan 422. |
| Dokumen | `GET bookings/{guid}/documents` dan download `documents/{invoice|ticket}` tersedia untuk pemilik atau admin sesuai kondisi backend; bukan bukti pembayaran. Tidak ada kontrak QR legacy. |
| Akun admin | `POST admin/accounts` dan `PATCH admin/accounts/{guid}` tersedia untuk role 2; endpoint daftar dan hapus tidak tersedia. |

Approval gratis menghasilkan `confirmed`, berbayar `awaiting_payment`; penolakan menghasilkan `rejected`. Aksi pada booking yang tidak lagi `pending_approval` atau kedaluwarsa menghasilkan 409. Backend juga menggunakan 409 untuk alasan lain, termasuk kapasitas, jendela booking dan konflik idempotensi; kode itu sendiri bukan bukti satu penyebab. Keputusan admin tidak mempunyai kontrak idempotensi: hasil timeout tidak boleh dianggap gagal atau berhasil dan tidak boleh diulang otomatis; muat ulang daftar untuk memeriksa status.

Gambar memakai multipart `image` JPEG/PNG/WebP maksimum 5 MB. Backend menyimpan path pada disk default; konfigurasi default tidak menjamin URL publik. Pembacaan katalog aktif oleh pengguna dan admin menggunakan sumber Laravel yang sama. Server memvalidasi perubahan dan menyerialkan update kuota terhadap alokasi; hal ini belum membuktikan perilaku MySQL bersamaan di lingkungan nyata.

## Rekonsiliasi Phase 4

Intent booking yang hasilnya tidak pasti tetap disimpan per akun. Replay yang diizinkan memakai payload dan `Idempotency-Key` yang sama dan dapat membuat booking jika request awal belum tiba; hasil replay adalah snapshot awal dan detail pengguna perlu diambil lagi. Tidak ada endpoint pencarian berdasarkan key. Jangan membuka intent yang belum terpecahkan untuk membuat booking baru. Retensi dan pembersihan key, concurrency MySQL, scheduler, dan alur pengguna → admin → pengguna perlu verifikasi nyata. Lihat `phase4_booking_migration.md` untuk batas lebih lanjut.

## Blocker dan dependensi legacy

- Endpoint admin untuk detail individual, daftar resource nonaktif/reakivasi, statistik, sisa kuota, serta daftar/hapus akun admin belum tersedia. Jangan menyimpulkan kuota tersisa dari data lokal.
- Akses gambar publik dan upload perlu kontrak penyimpanan/deployment yang terverifikasi.
- Review, check-in, pembayaran, FCM, dan data Firebase historis berada di luar migrasi. Tidak ada pemetaan identitas Firebase atau ID wisata historis ke GUID Laravel yang terverifikasi.
- `app_data.dart` masih memuat helper Firestore historis; layar bukti/review/profil legacy masih mempunyai dependensi Firestore. Aturan Firestore terpasang belum diaudit; tidak ada data historis yang dihapus.

## Verifikasi

- PASS: `flutter test --no-pub`, 43 tes. Tes admin baru memeriksa kontrak HTTP mock; tes lain mencakup sesi, katalog, favorit, intent booking dan widget smoke. Ini tidak membuktikan backend nyata.
- PASS: `git diff --check` untuk perubahan terlacak; file baru ditinjau bersama perubahan.
- FAIL: `flutter analyze --no-pub`, 257 warning/info di seluruh proyek; tidak ada error kompilasi yang dilaporkan.
- NOT VERIFIED: admin double submit, konflik 409, pagination/deduplikasi dan respons terlambat pada widget admin; otorisasi non-admin terhadap server nyata; alur pengguna ? admin ? pengguna, MySQL bersamaan, FCM di perangkat, dan tampilan aktual.

## Status implementasi lokal

Login admin lama memakai AuthSession dan `auth/me`; seed dan login Firestore dihapus. Dashboard memakai total resource daftar dan booking terbaru Laravel; rating tidak tersedia. Daftar booking admin memakai seluruh halaman, GUID, keputusan server dan refresh tanpa perubahan status optimistis. Detail ditampilkan dari resource daftar, bukan endpoint detail admin. Daftar/edit/penonaktifan destinasi memakai Laravel. Repository menyediakan metode create destinasi, CRUD kategori dan GET/PUT kuota, namun metode tersebut belum terhubung ke layar operasional kategori/kuota. Form tambah destinasi diblokir karena tidak memiliki input timezone wajib; perubahan gambar juga diblokir. Layar kelola admin Firestore dinonaktifkan; create/update akun Laravel belum tersambung. Dengan batas ini acceptance criteria Phase 5 belum terpenuhi.

Belum siap produksi. Diperlukan penyelesaian input/UI dalam ruang lingkup yang disepakati, kontrak yang kurang, serta verifikasi end-to-end backend nyata sebelum penggunaan operasional.
