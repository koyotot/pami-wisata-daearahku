# Phase 4: booking dan kuota — penyelesaian fungsional

Kontrak lengkap: `docs/api_contract_phase4_5.md`. Backend: `pami-wisata-daerahku-api/docs/handoff/PHASE-4-5-COMPLETION.md`.

## Status akhir: FUNCTIONALLY COMPLETE (batas operasional di bawah)

Booking berjalan end-to-end terhadap Laravel/MySQL: ketersediaan → buat booking → riwayat/detail → pembatalan → dokumen → keputusan admin → status terbaru di sisi pengguna. Tidak ada operasi booking aktif yang membaca atau menulis Firestore.

## Yang diselesaikan

| Butir PRD | Implementasi |
| --- | --- |
| Ketersediaan & kuota (3.2) | `GET destinations/{guid}/availability`: kapasitas total, alokasi, sisa, status, jendela booking, dihitung server dari alokasi nyata, tanpa data pemesan. Formulir menampilkannya dan menonaktifkan kirim bila tidak `open` atau jumlah > sisa; POST tetap memeriksa ulang di dalam transaksi. |
| Pembatalan (3.3) | `POST bookings/{guid}/cancel`: hanya pemilik, hanya `pending_approval`; kapasitas dilepas atomic sekali; pembatalan ganda 409 `booking_already_cancelled`; booking terproses 409 `booking_not_cancellable`. Tanpa refund/pembatalan pembayaran. |
| Idempotensi & rekonsiliasi (3.4) | Key dan payload dipertahankan; tidak ada retry POST otomatis; `GET booking-intents/{key}` (terikat pengguna+key) → `completed` / `not_found` (kirim ulang aman) / `abandoned`; `POST booking-intents/{key}/abandon` sebagai jalur keluar aman (key ditombstone, create terlambat ditolak). Replay membaca status terkini. Key > 7 hari ditolak `idempotency_key_expired`, tidak dibuka kembali. |
| Error handling (3.5) | 409 membawa `code` terstruktur; Flutter memetakan tiap kode ke pesan spesifik (`lib/data/booking_errors.dart`). |
| Dokumen (3.6) | Metadata dan unduhan PDF lewat Bearer Laravel; hanya pemilik/admin. Invoice = konfirmasi booking, bukan bukti pembayaran. Tidak ada QR legacy. |

Sisi Flutter: `lib/data/booking_intent.dart` (mesin intent), `booking_state.dart` (riwayat semua halaman + dedupe, detail, pembatalan, dokumen, penolakan respons sesi lama), `booking_errors.dart`, layar `daftar_kunjungan`, `bukti_pendaftaran`, `detail_wisata`, penghitung beranda/profil dari `meta.total`.

## Perubahan perilaku yang disengaja

- Email pengunjung kini wajib di formulir (backend memang mewajibkannya; sebelumnya berlabel opsional).
- QR lokal tidak dibuat untuk booking Laravel; review/ulasan Firestore tidak dapat dicapai untuk booking Laravel.
- `image_path` tidak lagi dipakai sebagai URL; gambar lewat `image_url` + `ApiImage`.
- Riwayat masih difilter di klien oleh tiga ubin lama; status lain tampil di "Semua". Filter status server sudah ada di loader dan teruji, belum ada kontrol UI.

## Inventaris historis Firestore (tidak berubah, tidak dihapus)

`pendaftar` (UID Firebase, nama wisata, status `menunggu/disetujui/ditolak`) dan `ulasan` tetap ada sebagai data historis; tidak ada pemetaan terverifikasi ke GUID pengguna/destinasi Laravel sehingga tidak diimpor. Kode Firestore yang tersisa (ulasan, hapus akun, riwayat ulasan) hanya dapat dicapai akun non-Laravel.

## Hasil verifikasi

| Pemeriksaan | Hasil |
| --- | --- |
| `php artisan test` (SQLite) | PASS — 50 tes, 368 assertion |
| `php artisan test -c phpunit.mysql.xml` (MySQL 8.4 nyata, proses PHP paralel) | PASS — 7 tes: tanpa overselling (24 pemesan, kapasitas 10 → tepat 10), kuantitas campuran, key identik serentak → 1 booking, cancel serentak → rilis sekali, approve/reject/cancel balapan → tepat satu menang, penurunan kuota vs booking, kursi bebas setelah cancel. Lulus 3× berturut-turut. |
| `php artisan test -c phpunit.e2e.xml` (server HTTP nyata + MySQL) | PASS — Skenario A, B, C, D (132 assertion), termasuk dokumen PDF terbit lewat queue + scheduler command nyata |
| `flutter test --no-pub` | PASS — 185 tes (59 lama + 126 baru) |
| `flutter analyze --no-pub` | 0 error; 4 warning + 233 info = 237 (baseline 263: 0 error). Tidak ada isu baru pada file yang disentuh; file baru bersih. Semua sisa adalah lint lama (mis. `prefer_const_constructors` di `profil_user_screen`, field tak terpakai) |
| `git diff --check` | PASS (Flutter dan Laravel) |
| Android Emulator / perangkat | NOT VERIFIED — `adb`/emulator tidak tersedia di mesin ini |
| Google Login admin → 403 | PASS dengan verifier Firebase yang di-mock (`AuthSecurityTest`); NOT VERIFIED dengan ID token Firebase nyata |
| FCM/SMTP nyata, secure storage di perangkat | NOT VERIFIED |

## Risiko yang belum selesai

1. **Pembayaran**: tidak ada integrasi; `awaiting_payment` berarti menunggu pembayaran, bukan lunas. Booking terproses tidak dapat dibatalkan pengguna (butuh kebijakan refund/pembayaran).
2. **Unduhan PDF**: hanya disimpan ke direktori sementara aplikasi dan jalurnya ditampilkan; tidak ada penampil/berbagi karena tidak ada dependency baru. Perlu keputusan (mis. `open_filex`/`share_plus`) sebelum rilis.
3. **Cutoff kunjungan** (25 j 15 m create, 1 j 15 m approve) masih sementara.
4. **Pembersihan record idempotensi** tidak ada (record tetap sebagai penanda).
5. Metadata dokumen dapat menampilkan dokumen yang file PDF-nya belum siap (unduh → 404; UI menyatakan "belum siap").
6. Server pengujian satu-thread: konkurensi dibuktikan lintas proses di level service, bukan lewat banyak koneksi HTTP simultan.
7. Tampilan visual panel baru, picker, dan perilaku di perangkat belum diverifikasi.
