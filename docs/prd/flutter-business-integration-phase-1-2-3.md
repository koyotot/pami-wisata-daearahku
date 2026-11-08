# Flutter Business Integration Phase 1–3

Tanggal: 2 November 2026. Scope: Flutter saja, Wisata Daerahku.

## Acuan dan batas implementasi

- PRD: `docs/prd/PRD-Wisata-Daerahku-Flutter-Business-Integration-Phase-1-2-3.md`.
- Kontrak terbaru dibaca langsung, read-only, dari `C:\laragon\www\pami-wisata-daerahku-api\docs\backend-business-adjustment.md` (2 November 2026).
- README, `docs/DESIGN.md`, kontrak API historis Phase 4/5, source aktual dan lima konfigurasi agen global dibaca. Tidak ditemukan AGENTS.md fisik pada checkout/ancestor yang diperiksa; instruksi AGENTS global dari user tetap diikuti.
- DESIGN adalah audit historis; beberapa catatan Firestore di sana sudah tidak cocok dengan implementasi Laravel lokal. Komponen baru mengikuti UI aktif dan `admin_common.dart`, tanpa mengganti tema/global auth.
- Auth, OTP, JWT, Google Sign-In, FCM, approval/payment dan `BookingIntent` tidak diubah. Tidak ada perubahan Laravel, seed, migrasi/hapus histori, Firestore/Storage bisnis, payment gateway, commit, push, atau deploy.

## Hasil implementasi

Status implementasi Phase 1: **DONE**; Phase 2: **DONE**; Phase 3: **DONE**. Automated regression baru lulus; full repository gate tetap tidak hijau karena kegagalan auth dan lint historis yang dirinci di bawah.

### Phase 1 — fasilitas dinamis

- Model `Facility` dan `Destination.facilities`, array kosong tetap kosong. Detail pengunjung menampilkan data server dan ikon netral `room_service_outlined`; fallback Parkir/Toilet/dll dihapus.
- Dashboard dan drawer menyediakan Kelola Fasilitas hanya role 2. Entry langsung layar dan mutation handler ikut memeriksa sesi aktif/role. Daftar memakai request pagination existing, filter semua/aktif/nonaktif, empty/loading/error/retry, create, edit, logical deactivate dan reactivate.
- Slug opsional saat create dan read-only saat edit. Repository membuang slug dari PATCH dan menetapkan `icon_key:null` sesuai kontrak. Error validasi backend ditampilkan; tidak ada seed fasilitas.
- Admin role 1/2 memuat seluruh selector aktif, dedupe GUID dan hydrate dari detail admin (termasuk destinasi nonaktif). Selector yang gagal/terpotong tidak dapat melakukan assignment. Loop dibatasi 200 halaman dan gagal bila masih ada halaman berikutnya.
- Checkbox memiliki batas 100 pilihan. PUT hanya dilakukan ketika pilihan berbeda dari hasil hydrate, termasuk `[]` saat semua pilihan sengaja dilepas. Save atribut destinasi biasa tidak melakukan PUT fasilitas.
- Create destinasi menyimpan GUID hasil server sebelum assignment. Jika assignment gagal, layar memberi pesan keberhasilan parsial dan retry menggunakan destinasi yang sudah tercipta. Tidak mengulang POST create.
- Setelah PUT sukses/gagal/timeout, detail admin dibaca ulang. Bila hasil server berbeda, pilihan user dipertahankan sebagai perubahan belum tersimpan; baseline assignment mengikuti server. Bila hasil sudah sama (termasuk response timeout setelah commit), rekonsiliasi dapat memastikan sukses. Jika detail tidak dapat dibaca, assignment diblokir sampai reload.

### Phase 2 — nomor internasional

- Country selector berbasis metadata, default ID +62. Input menerima nomor nasional menurut negara terpilih atau paste internasional. Preview format baca mengikuti metadata negara; transport percobaan baru menggunakan nomor internasional `+...`.
- Prefill dari profil existing; kontak booking tetap dapat berbeda. Error server 422 `visitor_phone` tampil inline dan tidak menghapus form.
- Payload final dibentuk sebelum `BookingIntent.submit`. Implementasi intent existing tetap menyimpan JSON/key di secure storage sebelum POST dan replay memakai payload/key tersimpan, termasuk format nomor asli. Perubahan form setelah timeout tidak membangun ulang replay.
- Tidak ada PATCH profil tambahan. First-fill `users.phone` tetap tanggung jawab transaksi backend. Snapshot `visitor_phone` pada booking/riwayat tetap independen dari nomor profil.
- Refresh profil setelah booking bersifat opsional dan tidak ditambahkan; perubahan first-fill terlihat ketika profil dimuat ulang oleh alur existing. Tidak ada klaim nomor telah diverifikasi SMS.

### Phase 3 — availability bulanan

- `MonthlyAvailability` dan `AvailabilityDay` terpisah dari model/method legacy `Availability`. Response bulanan memakai objek `data`, bukan koleksi; capacity/remaining/percent nullable tetap nullable dan angka int/double diterima.
- Kalender menampilkan 28/29/30/31 tanggal Gregorian, navigasi bulan/tahun, loading/error/retry, legenda, tooltip/semantics, zona waktu serta ringkasan tanggal/jumlah. Tidak ada aturan cutoff/horizon 365 hari baru.
- `high` hijau, `medium` kuning, `low` merah, `none` netral. Level dipakai dari server tanpa menghitung threshold ulang. `bookable` server adalah izin utama; low + true tetap dapat dipilih. Status tak dikenal gagal aman sebagai nonbookable.
- Sold out, closed, unconfigured, unavailable, insufficient quantity dibedakan. Angka null tampil sebagai tanda pisah, bukan kuota nol.
- RequestState direset saat bulan/jumlah/destinasi/sesi berganti; respons lama tidak dapat mengganti request terbaru. Respons diperiksa identitas destinasi, bulan dan jumlahnya. Submit diblokir selama loading/error atau pilihan tidak lagi bookable.
- Tanggal `YYYY-MM-DD` digunakan sebagai tanggal kalender tanpa konversi UTC. Bulan awal dihitung menggunakan IANA timezone destinasi. Unknown IANA zone hanya fallback untuk viewport awal; keputusan bookable dan tanggal tetap berasal dari server.
- Setelah booking confirmed oleh response/reconciliation, kalender dimuat ulang. Konflik 409 pada submit maupun replay membatalkan pilihan tanggal, merekonsiliasi intent yang masih pending dan refresh bulan. Tidak ada retry create otomatis dengan key baru.

## Endpoint yang terintegrasi

Semua path relatif terhadap `/api/v1`, menggunakan ApiClient/AuthSession existing.

| Method | Path | Penggunaan |
| --- | --- | --- |
| GET | `/superadmin/facilities?status=...&page=...&per_page=50` | Master role 2, semua status |
| POST | `/superadmin/facilities` | Create master, optional slug |
| PATCH | `/superadmin/facilities/{guid}` | Edit nama/status, reactivate; tanpa slug |
| DELETE | `/superadmin/facilities/{guid}` | Logical deactivate |
| GET | `/facilities?page=...&per_page=100` | Seluruh selector aktif role 1/2 |
| PUT | `/admin/destinations/{guid}/facilities` | Atomic replace `facility_guids` |
| GET | `/admin/destinations/{guid}` | Hydrate dan rekonsiliasi assignment |
| GET | `/destinations/{guid}` | Fasilitas dinamis pada detail pengunjung |
| GET | `/destinations/{guid}/availability?month=YYYY-MM&quantity=N` | Kalender bulanan authenticated |
| POST | `/bookings` | Nomor internasional; original payload + Idempotency-Key |
| GET / POST | `/booking-intents/{key}` / `/booking-intents/{key}/abandon` | Protokol rekonsiliasi existing tetap dipakai |

GET availability legacy dengan visit_date/from/to serta create/update destinasi existing tetap kompatibel.

## File perubahan

Produk/API/state:

- `lib/data/business_repository.dart`
- `lib/data/booking_state.dart`
- `lib/data/facility_state.dart` (baru)
- `lib/screens/admin_dashboard.dart`
- `lib/screens/kelola_fasilitas_screen.dart` (baru)
- `lib/screens/tambah_wisata_screen.dart`
- `lib/screens/detail_wisata_screen.dart`
- `lib/screens/daftar_kunjungan_screen.dart`
- `lib/widgets/availability_calendar.dart` (baru)
- `lib/widgets/international_phone_field.dart` (baru)
- `pubspec.yaml`, `pubspec.lock`

Tests dan dokumentasi:

- `test/facility_state_test.dart` (baru)
- `test/facility_widget_test.dart` (baru)
- `test/business_booking_widgets_test.dart` (baru)
- `test/business_integration_contract_test.dart` (baru)
- `test/business_integration_calendar_test.dart` (baru)
- `test/business_integration_regression_test.dart` (baru)
- `test/business_integration_destination_test.dart` (baru)
- `test/business_integration_detail_test.dart` (baru)
- `test/admin_destination_form_test.dart` (fixture kontrak baru)
- `test/user_booking_form_test.dart` (fixture bulanan dan regresi form)
- `docs/flutter-business-integration-phase-1-2-3.md` (dokumen ini)

PRD sudah ada sebagai file untracked pada awal execution, tidak dibuat atau diubah oleh implementasi ini.

## Dependency

| Dependency | Versi locked | Alasan |
| --- | --- | --- |
| `phone_numbers_parser` | 9.0.29 | Validasi/format berdasarkan metadata negara, bukan regex panjang nomor |
| `timezone` | 0.11.2 | Bulan kalender awal menurut IANA timezone destinasi, tanpa offset hardcoded |

Referensi primary: https://pub.dev/packages/phone_numbers_parser dan https://pub.dev/packages/timezone. Keduanya pure Dart, tanpa konfigurasi platform baru atau dependency transitif baru pada lockfile. Metadata nomor dan zona waktu perlu pembaruan berkala; validator backend tetap otoritatif.

## Orkestrasi, QA dan security

Delegasi nyata melalui subagents: master_orchestrator (lead acceptance), system_architect (freeze kontrak), dua flutter_engineer dengan ownership terpisah (Phase 1 dan Phase 2/3), qa_engineer (tes dan gate), security_auditor (review read-only). Batas empat slot dipenuhi dengan menjalankan peran bergiliran. Main thread memiliki shared repository, integrasi, perbaikan dan handoff.

Lingkungan: Windows PowerShell, Flutter 3.44.4 stable, Dart 3.12.2.

Baseline sebelum perubahan: flutter test 258 PASS, 1 SKIP, 1 FAIL. Failure existing `auth_prd_redesign_test.dart`, test `scrolled header stays below status bar on narrow scaled viewport`: expected 44, actual 0.0. QA mereproduksi failure secara terpisah. Baseline flutter analyze: 181 temuan (0 error, 3 warning, 178 info).

Review security independen: tidak ditemukan temuan Critical/High atau blocker baru pada diff yang diperiksa. Bukti mencakup gate role pada entry/mutasi, generation reset, secure-storage intent, replay JSON/key, tidak ada profile PATCH/identity injection/PII logging/client paralel. Ini review source, bukan penetration test, advisory scan dependency, atau audit server live.

Review lead menemukan dua gap yang ditutup sebelum gate akhir: pilihan user hilang ketika assignment ditolak (kini dipertahankan dan diberi status belum tersimpan), serta teks kuota nullable yang semula menampilkan literal null (kini tanda pisah). Regression tests mencakup kedua perbaikan.

| Pemeriksaan aktual | Hasil akhir |
| --- | --- |
| `flutter pub get` | **PASS**, exit 0; dependency resolved, 39 package mempunyai versi lebih baru di luar constraint existing (info resolver) |
| `flutter test --reporter expanded` | **FAIL**, exit 1: **312 PASS, 1 SKIP, 1 existing FAIL**; naik 54 test PASS dari baseline; tidak ada kegagalan baru |
| `flutter analyze` | **FAIL karena lint existing**, exit 1: **175 temuan = 0 error, 3 warning, 172 info**; baseline 181; perbandingan path/pesan/rule: **0 baru, 6 berkurang** |
| `git diff --check` | **PASS**, exit 0; Git hanya memberi notice normalisasi LF/CRLF pada dua fixture existing |
| Review source security independen | Tidak ada Critical/High atau blocker baru ditemukan pada scope yang diperiksa |
| Android Emulator / device / live Laravel E2E / build APK-AAB | **NOT RUN**, manual Android ditangani user |

Failure full suite tetap test auth baseline di atas (file/test dan expected/actual sama); source auth tidak disentuh. Tiga warning existing adalah unused `textDim` dan `amber` di admin_dashboard serta `blueDeep` di daftar_wisata. Satu skip adalah test live Laravel/MySQL Phase 6 yang opt-in melalui fixture environment; tidak menjalankan mutation live DB pengguna.

Coverage automated meliputi unit/model, widget, fake HTTP API contract, master CRUD/immutable slug/null icon, selector pagination/dedupe/completeness, role isolation 0/1/2, session/stale response, explicit clear/no-op assignment, partial create retry dengan GUID sama tanpa POST kedua, pilihan gagal tetap pending, user detail dinamis/kosong, validasi negara/paste/E.164 dan inline422, payload/key/punctuation original tersimpan sebelum POST dan tidak berubah saat replay, nullable monthly fields dan seluruh panjang bulan, threshold level dari server, low+bookable, status disabled, race jumlah/bulan/logout, 409 reconciliation tanpa duplicate, timezone boundary, serta kalender viewport 320px dengan text scaling 1.4 dan semantics.

Log execution lokal (TEMP, bukan artefak permanen repository):

- `%TEMP%\pami-baseline-test.log`, `%TEMP%\pami-baseline-analyze.log`
- `%TEMP%\pami-qa-baseline-isolated.log`
- `%TEMP%\pami-qa-final2-test.log`, `%TEMP%\pami-qa-final2-analyze.log`
- `%TEMP%\pami-qa-pubget.log`

## Batas verifikasi dan risiko

- Automated contract tests memakai fake HTTP dan secure storage test. Ini tidak membuktikan integrasi live Laravel/MySQL, perangkat Android, staging atau production.
- PUT fasilitas memang mengganti seluruh assignment. Hidden inactive pivot tidak diekspos backend; perubahan fasilitas yang disengaja dapat melepas relasi inactive tersebut. Notice tersedia pada edit; save atribut biasa tidak melakukan PUT.
- Kalender adalah snapshot, bukan reservasi. Backend tetap memutuskan kuota/cutoff saat POST; 409 harus diterima sebagai perubahan ketersediaan.
- First-fill profil merupakan invariant backend handoff; tidak dimutasi atau dibuktikan melalui live DB dalam execution Flutter ini.
- Tidak menjalankan screenshot/mockup, manual emulator/device testing, build APK/AAB, commit/push/deploy. Manual Android ditangani user.

## Checklist manual Android untuk user

1. Superadmin: buka menu/drawer Kelola Fasilitas; empty state; create beberapa fasilitas; duplicate name/slug; edit nama; slug tetap; deactivate/reactivate; filter status.
2. Admin: pastikan menu master tidak ada; tambah destinasi dengan fasilitas; reopen edit dan periksa pilihan. Ubah atribut saja dan pastikan assignment tetap. Uji lepas semua secara sengaja dan notice relasi inactive.
3. Gangguan jaringan saat assignment setelah create: pesan parsial muncul; pulihkan koneksi dan retry/reload tanpa destinasi duplikat.
4. User: detail dengan fasilitas serta `facilities:[]`; tidak ada fasilitas default; perubahan active master muncul setelah detail dimuat ulang.
5. Phone: profil kosong default +62, nomor nasional Indonesia, paste `+62`, nomor negara lain, invalid/422 inline. Booking dengan nomor berbeda dari profil tidak mengubah profil existing; first-fill diverifikasi lewat profil yang dimuat ulang.
6. Booking timeout: ubah isian lalu Periksa hasil/Kirim ulang; pastikan original payload/key dipakai dan tidak ada booking duplikat. Selesaikan/abandon intent sebelum percobaan baru.
7. Kalender: gunakan fixture tanggal masa depan yang valid menurut backend. Periksa high/medium/low, low tetap selectable, sold_out/closed/unconfigured/unavailable/insufficient_quantity, null quota, pergantian tahun dan timezone destinasi.
8. Ubah jumlah atau pindah bulan cepat saat jaringan lambat; data lama tidak mengganti bulan/jumlah terbaru. Uji 409 dari kuota/window berubah, pilihan tanggal direset dan kalender refresh.
9. Logout/login akun lain saat loading/save: data master/selector/nomor/intent akun pertama tidak muncul pada akun kedua. Regresi login/OTP/Google/FCM, favorites, riwayat, check-in/review serta approval/payment existing tetap diuji manual sesuai akses.
