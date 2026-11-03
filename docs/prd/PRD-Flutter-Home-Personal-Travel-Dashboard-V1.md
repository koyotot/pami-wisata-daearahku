# Flutter Home Personal Travel Dashboard V1 — Implementasi

Beranda menjadi dashboard personal, terpisah dari pencarian, filter, dan katalog Jelajah. Implementasi mengikuti token V4 `AppColors`, tema Plus Jakarta Sans shell, radius existing, dan `TimeBasedScenicBackground` yang memenuhi lebar layar serta status bar. Konten mempunyai batas lebar 640 px dan ruang bawah untuk floating navigation.

| Section | Sumber data dan perilaku | Navigasi |
| --- | --- | --- |
| Dynamic Scenic Hero | Nama `currentUser` hasil AuthSession; greeting mengikuti batas scenic 05/11/15/19 waktu perangkat. | Tidak ada hero kedua. |
| Perjalanan Kamu | `UserBookingsState` / `loadAllBookings`, GET bookings seluruh halaman. Satu booking diprioritaskan: awaiting_payment, pending_approval/payment_verification/payment_review, lalu confirmed dengan tanggal kunjungan terdekat yang belum check-in. Terminal masuk riwayat. Status memakai `bookingStatusLabel/Note` existing; tanggal dan kuantitas berasal Laravel. | Riwayat ke tab 1; CTA status/detail kunjungan membuka `BookingTicketScreen` memakai booking GUID. |
| Favorit Kamu | Singleton `FavoriteState`, Laravel Favorites API; maksimal 5 destinasi. Section disembunyikan jika kosong, state loading/error tetap eksplisit. | Card ke DetailWisataScreen; Lihat Semua memakai SavedDestinationsSheet existing dari profil. |
| Inspirasi Wisata | BusinessRepository.destinations dengan `per_page=4`, `sort=-created_at`, didukung CatalogRequest/CatalogService backend. Endpoint publik memfilter destinasi dan kategori aktif; Flutter mempertahankan filter isActive. Tidak ada field featured pada kontrak saat ini. | Card ke detail destinasi; Lihat Semua ke tab Jelajah (2). |
| Explore CTA | Copy tetap: Masih mencari destinasi impian? | Jelajahi Destinasi ke tab 2. |

Refresh dilakukan saat tab kembali aktif, aplikasi resume pada Beranda, pull-to-refresh, perubahan booking saat aktif, dan kembali dari detail. Request yang sedang loading tidak dikirim ulang oleh Beranda; favorit menggunakan state bersama. UserBookingsState/API existing menjaga session generation dan membuang respons account lama. Loading, error dengan retry, dan empty state ditampilkan per section. CTA shell menggunakan callback tanpa mengubah IndexedStack atau floating navigation.

Search bar, category chips, destination count dan grid katalog dihapus hanya dari Beranda. Tidak ada dependency baru, data dummy produksi, perubahan auth, booking mutation, atau kontrak Laravel.

Keterbatasan: belum ada checkout/pembayaran yang dapat dipakai; tidak ada tombol bayar, status pembayaran terpisah, deadline, atau klaim tiket terbit buatan client. BookingTicketScreen memeriksa dokumen Laravel untuk otoritas tiket. Seleksi future confirmed memakai tanggal perangkat sebagai pengurutan presentasi, bukan otorisasi atau expiry. Semua booking dipaginasi melalui helper existing untuk memastikan booking relevan tidak terlewat.
