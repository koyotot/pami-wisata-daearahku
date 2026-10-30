# Kontrak API final — Phase 4 & 5

Semua path relatif terhadap `/api/v1`. Respons sukses dibungkus `{"data": …}`; koleksi berpaginasi menambah `links` dan `meta` (`current_page`, `last_page`, `total`, `per_page`). Autentikasi: `Authorization: Bearer <access_token>` dari `AuthSession`. Role dan status akun dibaca server dari database pada setiap request, sehingga perubahan role/status berlaku segera (token sesi lama ditolak 401).

## Error terstruktur

HTTP 409 untuk konflik domain selalu berbentuk `{"message": "...", "code": "<kode>", "context": {…}?}`. Klien harus membedakan berdasarkan `code`, bukan hanya status.

| `code` | Arti | Konteks |
| --- | --- | --- |
| `quota_unavailable` | Tidak ada kuota untuk tanggal itu, atau destinasi/kategori nonaktif | |
| `insufficient_capacity` | Sisa kapasitas lebih kecil dari jumlah diminta | `remaining` |
| `booking_window_closed` | Di luar jendela buka/tutup booking | |
| `visit_date_too_close` | Terlalu dekat dengan tanggal kunjungan (create > 25 j 15 m, approve > 1 j 15 m) | |
| `idempotency_conflict` | Key sama dipakai dengan payload berbeda | |
| `idempotency_key_expired` | Key melewati retensi 7 hari; tidak dibuka kembali | `booking_guid` |
| `idempotency_key_abandoned` | Intent sudah ditinggalkan lewat `abandon` | |
| `intent_already_completed` | `abandon` ditolak karena booking sudah terbentuk | `booking_guid` |
| `booking_not_pending` | Keputusan admin pada booking yang sudah diproses | `status` |
| `approval_deadline_passed` | Batas persetujuan lewat | `status` |
| `booking_already_cancelled` | Pembatalan ganda | |
| `booking_not_cancellable` | Booking sudah diproses; kebijakan pembayaran/refund belum tersedia | |
| `category_in_use` | Kategori masih dipakai destinasi aktif | |
| `category_inactive` | Destinasi tidak dapat aktif saat kategorinya nonaktif | |
| `invalid_price` | Harga tidak valid | |

422 = validasi (`errors`), 403 = role tidak cukup, 404 = tidak ada atau bukan milik pemanggil, 401 = sesi tidak valid, 429 = throttle. Kegagalan lokal klien: `timeout`, `network`, `invalid_response` (hasil mutasi **tidak diketahui**, lihat `ApiException.outcomeUnknown`).

## Booking pengguna (role ≥ 0)

| Endpoint | Keterangan |
| --- | --- |
| `GET destinations/{guid}/availability` | Query `visit_date` (satu hari) atau `from`/`to` (default 60 hari). Item: `visit_date`, `capacity`, `allocated`, `remaining`, `status` (`open`, `full`, `closed`, `not_open_yet`, `too_close`, `unavailable`), `booking_opens_at`, `booking_closes_at`, `timezone`. Dihitung server dari alokasi nyata; tidak memuat data pemesan. |
| `POST bookings` | Header `Idempotency-Key` (`[A-Za-z0-9._~-]`, ≤128). Body: `destination_guid`, `visit_date`, `quantity`, `visitor_name`, `visitor_email`, `visitor_phone`, `notes?`. Replay identik mengembalikan booking dengan **status terkini**. |
| `GET bookings` | Milik pemilik token. Query `status`, `per_page` (≤100), `page`. |
| `GET bookings/{guid}` | Hanya pemilik (404 untuk lainnya). Menyertakan `cancellable`. |
| `POST bookings/{guid}/cancel` | Hanya pemilik, hanya `pending_approval` sebelum batas persetujuan. Status → `cancelled`, kapasitas dilepas sekali (atomic). Lainnya 409. |
| `GET booking-intents/{key}` | Rekonsiliasi berdasarkan (pengguna, key). `state`: `completed` (+`booking` terkini), `not_found`, `abandoned`; `replay_safe`, `key_expired`, `expires_at`. |
| `POST booking-intents/{key}/abandon` | Jalur keluar aman: menandai key ditinggalkan; create berikutnya dengan key itu ditolak. 409 `intent_already_completed` bila booking sudah ada. |
| `GET bookings/{guid}/documents` | `{invoice, ticket}`; `null` bila belum terbit. Invoice = konfirmasi booking, **bukan bukti pembayaran**. |
| `GET bookings/{guid}/documents/{invoice\|ticket}` | PDF; pemilik atau admin. Tidak ada QR resmi. |

Status booking: `pending_approval`, `awaiting_payment`, `payment_verification`, `payment_review`, `confirmed`, `rejected`, `expired`, `cancelled`. Yang menahan kapasitas: lima status pertama.

### Aturan rekonsiliasi (klien)

1. Simpan intent (payload + key) sebelum POST. 2. Hasil tidak pasti (`outcomeUnknown`) → **jangan** buat key baru dan jangan kirim ulang otomatis. 3. `GET booking-intents/{key}`: `completed` → selesai (ambil booking); `not_found` → kirim ulang payload & key yang sama aman (idempotent); `abandoned`/`key_expired` → tidak boleh dikirim ulang. 4. Bila tidak bisa direkonsiliasi, pengguna memilih `abandon`, lalu intent lokal dihapus.

## Admin (role ≥ 1 kecuali dinyatakan lain)

| Endpoint | Keterangan |
| --- | --- |
| `GET admin/bookings` | Query `status`, `search`, `per_page`, `page`. |
| `GET admin/bookings/{guid}` | Detail booking siapa pun (role ≥ 1). Dipakai untuk refresh/rekonsiliasi setelah keputusan. |
| `POST admin/bookings/{guid}/approve\|reject` | Body `reason?` (≤255). Gratis → `confirmed`; berbayar → `awaiting_payment`; reject → `rejected`. Tidak idempotent: timeout → baca ulang detail, jangan ulangi otomatis. |
| `GET admin/destinations`, `GET admin/destinations/{guid}` | Termasuk nonaktif; query `status` (`active`/`inactive`/`all`), `search`, `category`, `per_page`. |
| `POST destinations` | Field: `destination_category_guid`, `name`, `location`, `description`, `ticket_price`, `opening_hours`, `timezone` (IANA, mis. `Asia/Jakarta`), `image?` (multipart). |
| `PATCH destinations/{guid}` | Sebagian field + `is_active` (reaktivasi). Multipart: `POST` + `_method=PATCH`. |
| `DELETE destinations/{guid}` | Menonaktifkan (soft). |
| `POST destinations/{guid}/image` | Multipart field `image`: JPEG/PNG/WebP ≤ 5 MB. File lama dihapus setelah referensi baru tersimpan. |
| `GET destinations/{guid}/image` | Gambar publik (destinasi aktif). `GET admin/destinations/{guid}/image` untuk semua (auth). |
| `GET destinations/{guid}/quotas`, `PUT …/quotas` | Resource: `visit_date`, `capacity` (total), `allocated`, `remaining`, `booking_opens_at`, `booking_closes_at`. PUT: timestamp wajib beserta offset (`…Z`/`+07:00`), `capacity` ≥ alokasi berlaku, jendela harus tutup sebelum hari kunjungan dimulai (zona waktu destinasi). |
| `GET/POST/PATCH/DELETE categories` (role 2), `GET admin/categories` (role 2, termasuk nonaktif) | `name`, `slug` (unik), `is_active`. DELETE menonaktifkan; 409 `category_in_use` bila masih dipakai destinasi aktif. |
| `GET admin/accounts` (role 2) | Query `role`, `status`, `search`, `per_page`. |
| `POST admin/accounts` (role 2) | Membuat akun role 1 (`name`, `email`, `password`, `password_confirmation`). |
| `PATCH admin/accounts/{guid}` (role 2) | `role` (0–2), `status` (`active`/`suspended`). Tidak boleh mengubah role/status sendiri; superadmin aktif terakhir dilindungi (422). Mencabut sesi target. |

### Gambar

`image_path` tidak lagi dikembalikan. Resource destinasi memuat `has_image` dan `image_url`, path **relatif terhadap base URL API** (mis. `destinations/{guid}/image?v=1730000000`; `v` berubah saat gambar diganti). Flutter memuatnya lewat `ApiImage` (memakai `ApiClient`, jadi header Host emulator ikut).

## Batas yang disengaja

- Pembayaran, refund, check-in, review: belum ada kontrak; `awaiting_payment` tidak berarti dibayar. Pembatalan hanya untuk `pending_approval`.
- Retensi `Idempotency-Key` 7 hari, setelah itu ditolak (`idempotency_key_expired`), tidak dibuka kembali. Belum ada job pembersihan record.
- Cutoff kunjungan masih sementara dan konservatif (lihat handoff backend).
