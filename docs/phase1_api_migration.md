# Phase 1: migrasi Firestore ke Laravel

Fondasi ini belum mengganti layar atau sumber data legacy. `BusinessRepository` memakai `ApiClient` dan `AuthSession` yang sama. Model resource menyimpan JSON Laravel; `Booking` adalah representasi API untuk Pendaftar, bukan konversi otomatis ke model Firestore. GUID Laravel tidak boleh dianggap Firebase UID. Resource tidak menyediakan rating atau pemilik booking; jangan mengarang nilai atau status legacy. `image_path` adalah path storage, belum tentu URL publik.

| Fitur legacy | Laravel / tindak lanjut |
| --- | --- |
| Wisata | GET publik `destinations`, `destinations/{guid}`; CRUD admin tersedia. Kategori memakai GUID. |
| Kategori | GET publik `categories`; CRUD dibatasi role. |
| Favorit | GET `favorites`, PUT/DELETE `favorites/{destination}` dengan Bearer. |
| Pendaftar/booking | GET/POST `bookings`, GET `bookings/{guid}`; admin GET `admin/bookings` dan approve/reject. POST perlu `Idempotency-Key` yang sama saat retry serta `destination_guid`, `visit_date`, `quantity`, `visitor_name`, `visitor_email`, `visitor_phone`, `notes` opsional. Simpan key lintas retry. Status dan snapshot Laravel harus dipetakan secara eksplisit saat layar dimigrasikan. |
| Kuota | GET/PUT `destinations/{destination}/quotas` hanya role admin, bukan endpoint publik. |
| Review dan rating | Tidak ada endpoint review/rating. |
| Check-in | Tidak ada endpoint check-in. |
| Pembayaran | Tidak ada endpoint penyelesaian pembayaran; approval berbayar dapat menghasilkan `awaiting_payment`. |
| Dokumen | GET `bookings/{booking}/documents` dan download invoice/ticket tersedia, integrasi layar belum dibuat. |
| Profil/admin | `auth/me`, `profile`, `admin/accounts` tersedia; identitas Firebase dan Laravel berbeda. |

Pagination resource Laravel mengembalikan `data`, `links`, `meta`; repository mempertahankannya. `RequestState` menangani loading, error, retry, data kosong (koleksi kosong) dan mengabaikan respons lama/dispose; tidak membatalkan HTTP di jaringan. Jangan retry otomatis POST dengan key baru. Endpoint mungkin mengembalikan validasi 422 atau konflik 409.

## Inventaris legacy

- `lib/data/app_data.dart`: model mutable, daftar global, seed dan pembacaan Firestore wisata/pendaftar.
- Firestore langsung: `admin_login.dart`, `kelola_admin_screen.dart`, `daftar_wisata_screen.dart`, `tambah_wisata_screen.dart`, `daftar_kunjungan_screen.dart`, `daftar_pendaftar_screen.dart`, `bukti_pendaftaran_screen.dart`, `detail_wisata_screen.dart`, `profil_user_screen.dart`.
- Konsumen data global juga meliputi `beranda_user_screen.dart`, `cari_wisata_screen.dart`, `admin_dashboard.dart`, `bukti_konfirmasi_screen.dart`, `main_navigation_screen.dart`, `user_login_screen.dart`.
- `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage`, `firebase_messaging` tetap diperlukan. Google exchange dan FCM tetap menggunakan Firebase. Stream Firestore memerlukan kebijakan refresh tersendiri saat migrasi.
- Login admin legacy membandingkan password Firestore dan melakukan seed; perlu diganti melalui alur backend sebelum dianggap aman. Sebagian layar mencampurkan GUID Laravel dengan Firebase UID; integrasi end-to-end legacy belum terjamin.

## Urutan berikutnya

1. Sepakati migrasi data dan identitas, role, pemetaan status, gambar dan kebijakan refresh; jangan menyalin GUID menjadi Firebase UID.
2. Migrasikan katalog dan kategori baca, lalu favorit dengan loading/empty/error/retry di UI existing.
3. Migrasikan booking pengguna dan admin, persist idempotency key dan verifikasi status, kuota, dokumen dan concurrency di backend nyata.
4. Migrasikan profil/admin, selesaikan kontrak review/check-in/pembayaran, lalu pensiunkan koleksi dan dependency hanya setelah semua konsumen diuji.
