# Phase 4: booking dan kuota

## Kontrak Laravel yang diaudit

Semua endpoint berikut berada di `/api/v1` dan memerlukan Bearer Laravel. `GET bookings` mengembalikan booking pemilik token, 15 per halaman, dengan `links` dan `meta`; `GET bookings/{guid}` juga dibatasi pemilik dan mengembalikan 404 untuk booking yang tidak ditemukan atau bukan miliknya. `POST bookings` menerima `destination_guid`, `visit_date` (`YYYY-MM-DD`), `quantity`, `visitor_name`, `visitor_email`, `visitor_phone`, `notes` opsional, dan header `Idempotency-Key`. Identitas pemilik ditentukan server dari token, bukan input klien. Resource menyediakan nomor booking, snapshot destinasi, harga, status dan waktu; status bukan status Firestore.

`GET/PUT destinations/{guid}/quotas` hanya untuk admin; resource hanya memuat kapasitas total, bukan sisa. Tidak ada endpoint ketersediaan pengguna atau pembatalan. Backend memeriksa kuota dan alokasi dalam transaksi saat POST dan dapat mengembalikan 409 dengan pesan aktual, termasuk `Quota is unavailable.` atau `Insufficient capacity.`; 409 juga dipakai untuk konflik lain. Tidak ada endpoint pencarian berdasarkan key. Endpoint dokumen dan admin approve/reject tersedia, tetapi integrasinya di luar Phase 4. Pembayaran, review, dan check-in tidak dimigrasikan.

## Idempotensi dan batas operasional

Backend mengunci record berdasarkan pengguna, operasi dan key; payload berbeda dengan key yang sama menghasilkan 409. Replay POST dengan key dan payload identik mengembalikan hasil pembuatan yang tersimpan. Hasil replay merupakan snapshot awal: gunakan GET detail untuk status terbaru. Transaksi dan penguncian backend belum dibuktikan terhadap MySQL dan concurrency nyata dalam pekerjaan ini. Record memiliki `expires_at` tujuh hari; retensi efektif dan kebijakan pembersihan harus diverifikasi sebelum mengandalkan replay jangka panjang.

HTTP 401, 403, 404, 409, 422, 429, 5xx dan kegagalan jaringan tidak boleh ditafsirkan sebagai keberhasilan. Timeout atau respons server yang tidak pasti bukan bukti bahwa booking gagal. Jangan mengirim niat baru sampai transaksi tidak pasti direkonsiliasi secara aman.

Intent tersimpan di secure storage berdasarkan GUID pengguna sebelum POST. Jika hasil belum diketahui, pengguna diminta secara eksplisit untuk mengirim ulang payload dan key lama; replay dapat membuat booking jika permintaan pertama belum sampai. Respons yang masih tidak pasti mempertahankan intent. Respons detail dipakai setelah pembuatan; formulir dan respons lama dijaga saat sesi berubah. Intent yang tidak dapat direkonsiliasi tetap memblokir pembuatan baru untuk akun tersebut. `AuthSession` saat ini menampilkan pesan umum untuk 409, bukan pesan konflik aktual Laravel; pembedaan konflik kuota dari konflik lain belum tersedia di UI.

Riwayat memuat semua halaman dan mengambil detail terkini ketika dibuka. Filter lama hanya mencakup `pending_approval`, `confirmed`, dan `rejected`; status lain ditampilkan apa adanya. QR dan review Firestore tidak diaktifkan untuk booking Laravel. Konfirmasi lama yang membuat QR lokal tidak dibuka; setelah berhasil, layar formulir menampilkan nomor dan status server. Ini adalah perubahan perilaku yang diperlukan untuk menghindari bukti operasional palsu; kesetaraan penuh dengan UX lama belum tercapai. Penghitung beranda/profil tidak otomatis diperbarui pada setiap perubahan status saat layar tetap terbuka.

## Inventaris historis Firestore

`pendaftar` menyimpan `userId`, nama dan kontak pengunjung, nama wisata, tanggal, jumlah, nomor bukti, catatan, status `menunggu`/`disetujui`/`ditolak`, dan waktu pembuatan. Data historis memakai UID Firebase dan nama wisata, bukan GUID destinasi Laravel; versi campuran mungkin telah menyimpan GUID Laravel sebagai `userId`. Nama atau email tidak membuktikan pemetaan identitas maupun destinasi. Tidak ada impor otomatis atau penghapusan data historis. Migrasi memerlukan pemetaan pengguna dan destinasi terverifikasi serta proses terpisah.

Pembaca/penulis legacy meliputi `app_data.dart`, layar daftar kunjungan, riwayat/bukti, beranda, profil, dashboard dan daftar pendaftar admin. Admin Firebase membaca dan mengubah `pendaftar`; booking Laravel tidak muncul pada alur admin lama. Aturan Firestore yang terpasang belum diverifikasi. Review dan check-in masih terkait data legacy.

## Kesiapan Phase 5

Sebelum operasional, sediakan alur admin Laravel untuk melihat dan memutuskan booking, dan sepakati akses ketersediaan pengguna, pembatalan, rekonsiliasi transaksi serta retensi key. Verifikasi integrasi nyata, otorisasi, scheduler, concurrency MySQL dan perangkat. Jangan menganggap alur admin Firebase dapat menyetujui booking Laravel.

## Hasil verifikasi lokal

- PASS: `flutter test` (39 tes), termasuk mock repository intent untuk replay identik, konflik awal, 422 saat rekonsiliasi, double tap dan respons sesi lama; tes API mock memeriksa Bearer dan key. Tes katalog, favorit dan autentikasi yang ada juga lulus.
- FAIL: `flutter analyze` keluar dengan 252 temuan lint dan warning di seluruh proyek; bukan bukti keberhasilan analisis bersih.
- PASS: `git diff --check` pada perubahan terlacak. File baru juga perlu ditinjau bersama diff.
- NOT VERIFIED: integrasi Laravel dan MySQL nyata, kuota tersedia/habis dan concurrency nyata, device/secure storage, UI/widget riwayat dan pagination, isolasi lintas akun secara end-to-end, serta aturan Firestore terpasang. Pembatalan dan pratinjau ketersediaan tidak dapat diuji karena endpoint pengguna tidak tersedia.
