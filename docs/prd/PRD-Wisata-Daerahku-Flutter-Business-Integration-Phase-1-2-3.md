# PRD — Wisata Daerahku: Flutter Business Integration Phase 1–3

**Tanggal:** 2 November 2026  
**Status:** Implementation-ready specification — implementasi Flutter belum dilakukan dalam dokumen ini  
**Target repository:** `C:\laragon\www\pami-mobile\pami-wisata-daearahku` (pastikan path checkout aktual)  
**Source repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Backend:** Laravel 13 REST API + MySQL, prefix `/api/v1`  
**Basis kontrak backend:** `docs/backend-business-adjustment.md`, bertanggal 2 November 2026, Phase 1–3 PASS  
**Scope:** Flutter Android client untuk Role 2 (Superadmin), Role 1 (Admin), Role 0 (User). Kerjakan seluruh tiga fase dalam **satu batch eksekusi**.  
**Keputusan:** User melakukan **manual testing** sendiri; agent tetap harus menjalankan automated testing.

---

## 1. Objective dan keputusan final

Integrasikan tiga perubahan backend yang sudah selesai dengan aplikasi Flutter, tanpa membangun ulang modul lama:

1. **Phase 1 — Fasilitas dinamis lintas role:** Superadmin kelola master fasilitas; Admin hanya memilih fasilitas aktif untuk sebuah destinasi; User melihat fasilitas aktual destinasi (tanpa default hardcoded).
2. **Phase 2 — Nomor telepon internasional:** Form booking mendukung country code dan format baca yang sesuai negara, mengirim nomor internasional berawalan `+`, mempertahankan snapshot nomor booking dan tidak menimpa nomor profil yang sudah ada.
3. **Phase 3 — Kalender kuota bulanan:** Tanggal ditandai menurut kapasitas dan sisa tiket dari API Laravel, mempertimbangkan jumlah tiket, status `bookable`, serta ketentuan tanggal/zona waktu destinasi.

**Out of scope:** Payment gateway, perubahan urutan approval/payment, perubahan backend, migrasi database, auth/OTP/JWT/Google, redesign menyeluruh, rekonstruksi histori data Firebase, deploy, push, commit, build Play Store/AAB, screenshot/mockup, dan manual-device testing oleh agent (kecuali user nanti meminta).

**Penting:** Handoff backend melaporkan 126 tes Laravel (1.075 assertion), 21 tes MySQL (334 assertion), dan 5 skenario HTTP E2E (176 assertion), namun itu **bukan bukti Flutter sudah terintegrasi**. Jangan mengklaim implementasi Flutter telah selesai sebelum source lokal berubah dan tes lulus.

## 2. Mandatory source-of-truth & repo audit

Sebelum coding, agent **wajib**:

1. Baca `AGENTS.md`, `README.md`, `docs/DESIGN.md`, `pubspec.yaml`, `docs/api_contract_phase4_5.md`, dokumentasi migrasi yang masih relevan, dan `git status` pada checkout Flutter aktual.
2. Baca dokumen handoff Laravel `docs/backend-business-adjustment.md` dari checkout backend (`C:\laragon\www\pami-wisata-daerahku-api`, jika sesuai; verifikasi lokasi) atau lampiran handoff. Dokumen handoff adalah otoritas kontrak terbaru untuk ketiga fase ini.
3. Inspeksi source Flutter aktual dan seluruh referensi `facilities`, `availability`, `visitor_phone`, `booking_intent`, `Idempotency-Key`, `sessionGeneration`, serta role gate. **Jangan menganggap file GitHub yang terindeks merepresentasikan working tree lokal terkini.** README publik memuat arsitektur Laravel/Flutter terbaru, tetapi beberapa raw source publik yang terbaca masih menampilkan kode Firestore lama. Laporkan perbedaan apabila ada; **source lokal aktual + kontrak backend handoff menang**.
4. `docs/DESIGN.md` adalah inventaris/audit desain historis, bukan alasan mengganti desain global. Selaraskan komponen tambahan dengan UI/tema Flutter **yang benar-benar aktif pada checkout**; desain auth dan edge-to-edge existing tidak disentuh.
5. Baseline `flutter test`, `flutter analyze`, dependency versions dan test coverage; pisahkan lint lama dengan regresi baru. Jangan klaim seluruh repo bersih dari lint jika baseline memang mengandung lint historis.
6. Jika dokumen handoff belum ada di repo Flutter, gunakan salinannya **sebagai read-only reference**; jangan mengedit source Laravel atau berpura-pura backend sudah berubah.

### Kandidat file Flutter untuk audit, bukan daftar final/izin menulis membabi buta

| Area | Kandidat source yang telah tercantum dalam README / source publik | Keputusan implementasi |
|---|---|---|
| Model/HTTP | `lib/data/business_repository.dart`, `lib/services/api_client.dart`, `lib/services/auth_session.dart` | Tambah model dan method API, pertahankan envelope, auth dan transport |
| State Admin | `lib/data/admin_state.dart` | Gunakan paginated state, stale-response guard, role gate existing |
| Navigasi Admin | `lib/screens/admin_dashboard.dart`, `lib/screens/admin_common.dart` | Tambah menu Superadmin master fasilitas, tanpa ekspos role 1 |
| Master fasilitas baru | `lib/screens/kelola_fasilitas_screen.dart` (baru hanya jika belum ada) | CRUD role 2, pola Kelola Kategori existing |
| Form Admin destinasi | `lib/screens/tambah_wisata_screen.dart`, `lib/screens/daftar_wisata_screen.dart` | Selector multi pilihan fasilitas dan assignment pada edit/create |
| Detail User | `lib/screens/detail_wisata_screen.dart` | Gunakan `destination.facilities` dari API |
| Booking User | `lib/screens/daftar_kunjungan_screen.dart` | International phone, kalender warna, jumlah tiket, request booking aman |
| Idempotency & booking | `lib/data/booking_intent.dart`, `lib/data/booking_state.dart`, `lib/data/booking_errors.dart` | Jangan merusak implementasi intent yang ada |
| Profil/identity | `lib/screens/profil_user_screen.dart`, `lib/data/app_data.dart` | Prefill nomor bila ada, refresh profile setelah booking sukses jika relevan |
| Tests | `test/` | Tambah test unit/widget/contract untuk fitur terkait; pertahankan yang sudah ada |

Tidak perlu menambahkan package state management baru (BLoC/Riverpod/Provider) untuk scope ini. Pertahankan repository/state/UI yang ada. Tambah dependency phone input yang aktif dipelihara **hanya bila perlu**, catat alasan dan risiko/versi yang kompatibel. Tidak menambah Firebase Firestore/Storage/QR.

## 3. Mandatory agent orchestration (Codex)

Delegasi sungguhan menggunakan mekanisme subagent Codex jika tersedia. Agent konfigurasi global Windows **wajib dicari dan dibaca dari path aktual**, contohnya:

- `C:\Users\itsba\.codex\agents\master_orchestrator.toml` — lead integrator, assignment tugas, kontrak, conflict resolution, final report.
- `C:\Users\itsba\.codex\agents\system_architect.toml` — audit kontrak Laravel/Flutter, state model, idempotency, status & error invariants.
- `C:\Users\itsba\.codex\agents\flutter_engineer.toml` — primary implementer Flutter repository/state/screens/widgets.
- `C:\Users\itsba\.codex\agents\qa_engineer.toml` — unit/widget/contract/regression, fake HTTP, async/stale-response tests.
- `C:\Users\itsba\.codex\agents\security_auditor.toml` — role isolation, session leakage, PII, client authorization boundary, no secrets.

Temukan dan gunakan **skill taste/design untuk mobile** bila memang terpasang (mis. `design-taste-frontend`/Taste Skills), terbatas pada konsistensi UI tambahan; jangan melakukan redesign. Gunakan pendekatan Ponytails bila tersedia tanpa mewajibkan instalasi skill/plugin baru.

**Urutan orkestrasi:** Master Orchestrator menginventaris status → System Architect membekukan kontrak → Flutter Engineer mengimplementasikan Phase 1/2/3 dengan ownership file jelas → QA dan Security mengaudit → Master Orchestrator menyelesaikan blocking findings dan menjalankan regression suite akhir. Parallelize tugas independen, **jangan menugaskan dua agent mengedit file yang sama**. Bila agent tidak bisa dipanggil, nyatakan eksplisit, jalankan tanggung jawabnya pada main thread; jangan mengklaim subagent berjalan jika tidak.

## 4. Invariants dan role matrix

| Fitur | User `0` | Admin `1` | Superadmin `2` |
|---|---|---|---|
| Master facilities GET all/CRUD | Tidak | Tidak | Ya |
| Active facilities selector `GET /facilities` | Tidak | Ya | Ya |
| Assignment fasilitas destinasi | Tidak | Ya | Ya |
| Lihat fasilitas aktif destinasi | Ya | Ya | Ya |
| Booking + phone | Ya sesuai hak booking existing | Tidak ditambah scope baru | Tidak ditambah scope baru |
| Kalender availability user | Ya setelah login | Hanya jika API existing mengizinkan | Hanya jika API existing mengizinkan |

Flutter menu hide/disable hanya UX: **server role policy sumber otoritas**. Jangan mengirim `role`, `user_guid`, `phone` profile field tambahan pada body create booking. Admin tetap katalog bersama sesuai schema backend existing; **jangan mengarang ownership admin per destinasi**.

Session change/logout/login akun lain harus menghapus state admin fasilitas, kalender, nomor telepon, booking sementara di memori menurut generation guard existing. Intent booking per-user yang persist harus tetap dipisahkan berdasarkan GUID sesuai flow existing.

## 5. Backend API contract — immutable untuk client Flutter

Semua path berawalan `/api/v1`. Gunakan repository `ApiClient/AuthSession` existing, bukan HTTP client paralel.

### 5.1 Master dan relasi fasilitas

| HTTP | Path | Akses | Body / respons penting |
|---|---|---|---|
| GET | `/superadmin/facilities?status=all&page=1&per_page=50` | Role 2 | Paginated all, status active/inactive/all |
| POST | `/superadmin/facilities` | Role 2 | `name`, optional `slug`, `icon_key:null`, `is_active` → 201 |
| PATCH | `/superadmin/facilities/{guid}` | Role 2 | `name`, `icon_key:null`, `is_active`; **tidak boleh kirim slug** |
| DELETE | `/superadmin/facilities/{guid}` | Role 2 | Logical deactivation, bukan hard-delete |
| GET | `/facilities?page=1&per_page=50` | Role 1/2 | Active selector; per_page 1–100, iterate pages |
| PUT | `/admin/destinations/{guid}/facilities` | Role 1/2 | `{ "facility_guids": ["<guid>"] }`; maksimal 100 |
| GET | `/destinations/{guid}` | Public catalog existing | `data.facilities: [{guid,name,slug,icon_key}]` atau `[]` |

Perilaku backend penting:

- `icon_key` **selalu null pada kontrak saat ini**. Jangan invent katalog icon server; gunakan fallback icon Flutter.
- `name` trim/collapse whitespace oleh backend. Slug dibuat saat create, immutable; tampilkan read-only jika perlu.
- `DELETE` menonaktifkan, pivot historis tetap utuh. Reaktivasi memunculkan kembali relasi historis yang masih ada. Dalam UI tampilkan status master dan konfirmasi konsekuensinya.
- PUT assignment **mengganti seluruh daftar** (atomic replace), bukan append. `[]` berarti lepas semua fasilitas. Jangan kirim PUT sebelum seluruh halaman selector selesai dimuat / pilihan existing telah terhidrasi.
- Invalid/inactive/duplicate GUID ditolak seluruh request; tidak ada partial commit. Kalau PUT gagal/timeout, **reload destination detail** untuk rekonsiliasi, jangan berasumsi berhasil atau rollback lokal sebagai kebenaran server.
- Update destinasi biasa tidak memutakhirkan fasilitas. Assignment adalah operasi terpisah.

**POST contoh**:
```json
{"name":"Parkir","icon_key":null,"is_active":true}
```
**response contoh**:
```json
{"data":{"guid":"<facility-guid>","name":"Parkir","slug":"parkir","icon_key":null,"is_active":true}}
```
**PUT assignment contoh**:
```json
{"facility_guids":["<guid-parkir>","<guid-toilet>"]}
```
**destination detail snippet**:
```json
{"data":{"guid":"<destination-guid>","facilities":[{"guid":"<facility-guid>","name":"Parkir","slug":"parkir","icon_key":null}]}}
```

### 5.2 Booking & phone

`POST /bookings` tetap authenticated, header `Idempotency-Key` existing. Format `visitor_phone` harus **internasional berawalan `+`**, validasi memakai metadata nomor negara di Laravel.

```json
{
  "destination_guid":"<destination-guid>",
  "visit_date":"2026-11-07",
  "quantity":1,
  "visitor_name":"Visitor",
  "visitor_email":"visitor@example.com",
  "visitor_phone":"+62 896-5586-2781"
}
```

Backend menyimpan snapshot ter-normalisasi seperti `+6289655862781` di `bookings.visitor_phone`. `users.phone` hanya diisi oleh backend jika sebelumnya `NULL`/blank; jika sudah punya nilai, tidak di-overwrite. Ini dilakukan **dalam transaksi backend**. Flutter **tidak boleh memanggil PATCH profile tambahan untuk meniru first-fill**; dapat refresh profil setelah booking commit terkonfirmasi. Gagal validation menghasilkan 422; nomor nasional semisal `0812...` tidak diterima.

**Kontrak idempotency krusial:** Fingerprint backend memakai **payload request asli**. Sebelum submit, bentuk 1 final JSON body (termasuk format phone), persist body + key dengan `BookingIntent`, lalu kirim body itu. **Retry/reconciliation harus replay key dan JSON asli byte/logical-field-equivalent, tanpa reformat nomor, perubahan tanggal/jumlah atau re-serialize dari input terbaru**. Untuk percobaan baru setelah intent terselesaikan, baru buat key/payload baru. Jangan auto-retry POST create booking secara membabi buta setelah timeout.

### 5.3 Availability kalender bulanan

`GET /destinations/{guid}/availability?month=2026-11&quantity=1` dengan Bearer; `month` harus `YYYY-MM`, `quantity` opsional default 1 (1–1000000 sesuai backend). Jangan campur `month` dengan mode legacy `visit_date/from/to`. Respons `data` **objek**, berbeda dari legacy mode yang merupakan array/list.

```json
{
  "data": {
    "destination_guid": "<destination-guid>",
    "month": "2026-11",
    "timezone": "Asia/Jakarta",
    "requested_quantity": 1,
    "dates": [
      {"date":"2026-11-06","capacity":0,"remaining":0,"remaining_percent":null,"level":"none","status":"unavailable","bookable":false},
      {"date":"2026-11-07","capacity":200,"remaining":200,"remaining_percent":100,"level":"high","status":"available","bookable":true},
      {"date":"2026-11-08","capacity":null,"remaining":null,"remaining_percent":null,"level":"none","status":"unconfigured","bookable":false}
    ]
  }
}
```

**Contoh di atas hanya snippet 3 tanggal.** API aktual mengembalikan seluruh 28–31 hari kalender berurutan.

| Backend kondisi | level | status | UI |
|---|---|---|---|
| remaining >60% | high | available jika bookable | hijau + label Banyak tersedia |
| 35% s.d. 60% inklusif | medium | available jika bookable | kuning + label Terbatas |
| >0 sampai <35% | low | available jika bookable | merah + label Hampir penuh; **masih boleh dipilih** |
| remaining=0, capacity>0 | none | sold_out | Disabled / Habis |
| capacity=0 | none | unavailable | Disabled / Tidak tersedia |
| quota tidak dikonfigurasi | none | unconfigured | Disabled / Belum dibuka |
| booking window/cutoff tutup | level berdasar remaining | closed | Disabled / Ditutup |
| remaining kurang dari quantity | level berdasar remaining | insufficient_quantity | Disabled / Tidak cukup untuk N orang |

**Aturan utama:** `bookable` dari server selalu menang atas warna. `level` mewakili persentase, tidak boleh dianggap permission. `remaining_percent` nullable; jangan melakukan `0/0`. Gunakan server response dan tanggal destinasi (`timezone` IANA) sebagai sumber data, bukan asumsi UTC/perangkat. Sistem cutoff saat ini berasal dari backend; Flutter tidak membuat aturan tanggal 365 hari/horizon baru secara sepihak. Kalender adalah snapshot, bukan reservasi.

## 6. Phase 1 — Flutter Superadmin & Admin & User fasilitas

### 6.1 Model/repository/state

- Tambahkan model `Facility` (`guid`, `name`, `slug`, `iconKey?`, `isActive?`) dengan null handling yang tepat; jangan menganggap fasilitas bisa dipakai jika tidak aktif di selector.
- Tambah `Destination.facilities` typed list (lebih baik array kosong untuk response `[]`; tidak ada hardcoded default). Jangan merusak response list/detail yang mungkin berbeda kelengkapan field; saat perlu selalu fetch detail sebelum render penting.
- Tambahkan typed methods: list superadmin paginated/status; create/update/deactivate; list active selector paginated; assign destination (PUT); parser API resource/collection.
- Gunakan state pattern `PagedListController`, `InFlightGuard`, session generation/stale-response guard existing. Jangan fetch all pages tanpa batas uncontrolled; selector boleh load seluruh halaman sampai habis dengan indikator loading dan kontrol request.

### 6.2 UI Superadmin Role 2

- Menu **Kelola Fasilitas** muncul di dashboard/drawer hanya Role 2; gaya dan pola state mengikuti `KelolaKategoriScreen` / `admin_common.dart` di checkout lokal.
- List paginated: nama, status aktif/nonaktif, indikator jumlah opsional **hanya bila backend menyediakan** (jangan hitung fiktif); loading, empty, error, retry, status filters.
- Tambah nama; validasi nama kosong; edit nama; toggle aktif/nonaktif via PATCH; deactivation via DELETE dengan konfirmasi; aktifkan kembali dengan PATCH `is_active:true`.
- Slug readonly/optional saat create sesuai kontrak; **tidak** ada edit slug. `icon_key` diset `null`, fallback icon UI. Error 422 duplicate name/slug tampil spesifik, 403/401 diperlakukan sebagai masalah akses/session.
- Master kosong pertama kali = empty state dengan CTA tambah, **jangan seed otomatis** atau hardcode fasilitas default.
- Jangan membuka kelola master untuk Admin 1/User 0 walau mereka tahu URL/nama route.

### 6.3 UI Admin Role 1 & Superadmin Role 2

- Pada form tambah/edit destinasi, tampilkan **Pilihan Fasilitas** berbasis `GET /facilities` (only active), multi-select checkbox/chips, search lokal opsional jika list besar; tampilkan state loading/empty/error.
- Pada edit: fetch destination detail → preselect GUID dari `facilities` yang aktif; nilai historis inactive tidak ditampilkan dalam public field sesuai handoff. **Jangan tanpa sengaja melepaskan pivot inactive:** backend menyimpan pivot historis dan hanya detail aktif yang diekspos. Karena kontrak PUT replace tidak memberi daftar hidden inactive untuk preserving, lakukan PUT **hanya saat user secara eksplisit menyimpan perubahan fasilitas**, dan dokumentasikan bahwa replacement dapat melepaskan pilihan inactive yang tidak terlihat jika disengaja. Jangan kirim PUT otomatis ketika user hanya mengedit atribut destinasi umum.
- Pada create: simpan destinasi existing lebih dulu sampai GUID tersedia → lalu PUT facilities terpisah. Tampilkan keberhasilan parsial dengan jelas jika create berhasil tetapi assignment gagal; jangan mengulang create destinasi dan membuat duplikat.
- PUT `facility_guids` dedupe secara client, max100. `[]` dikirim **hanya jika user memang memilih untuk mengosongkan**.
- Setelah save, refetch detail dan update state agar pilihan yang tersimpan nyata. Hindari menampilkan data baru seolah committed sebelum backend sukses. Jika timeout, refetch untuk mengetahui commit sebenarnya.

### 6.4 UI User Role 0

- Detail wisata menggunakan data `facilities` yang dikirim API; urutkan sebagaimana server jika sudah stabil.
- `facilities: []`: tampilkan empty state singkat (mis. "Fasilitas belum dicantumkan") atau sembunyikan bagian sesuai pola UI existing, **jangan fallback default Parkir/Toilet/Kuliner/Keamanan**.
- `icon_key:null`: gunakan satu ikon netral; jangan mengarang mapping server sebagai fakta.
- Perubahan active/inactive terlihat saat detail di-refresh; jangan cache fasilitas global lintas akun/destinasi tanpa invalidasi.

## 7. Phase 2 — International phone & profil first-fill

### 7.1 Input/format visual

- Pada `DaftarKunjunganScreen`, country-code selector harus jelas (default `+62`, user dapat memilih negara lain bila library metadata mendukung). Tampilan contoh: `+62 896-5586-2781` (pengelompokan **berdasarkan negara**, bukan aturan potong 3-4-3 universal).
- Field menerima edit/paste nomor nasional untuk country code terpilih dan menormalisasikannya ke format internasional `+...` sebelum **percobaan baru**. Jika paste sudah `+`, gunakan country code sebenarnya untuk menghindari `+62+62`.
- UX memisahkan raw keystrokes, formatted display, dan nomor internasional untuk API. Hilangkan spasi/dash untuk transport jika metadata mendukung, atau gunakan presentational separators yang backend memang terima; hasil harus valid dan diawali `+`.
- Validasi country-specific panjang/validitas menggunakan metadata yang memadai, bukan hanya `digitsOnly` atau hardcoded panjang nasional. Tidak ada verifikasi SMS; jangan tampilkan "nomor terverifikasi".
- Error 422 pada `visitor_phone` tampil inline pada field; data user dan tanggal tidak hilang, tidak ada `BookingIntent` yang terjebak untuk local validation failure.

### 7.2 Data akun & invariant backend

- Prefill dari `users.phone` bila ada; jika kosong tampilkan form kosong dengan +62 default. Form tetap bisa memakai kontak booking berbeda walau profile punya nomor.
- Setelah booking sukses/hasil intent rekonsiliasi `completed`, opsional refresh profil atau `auth/me` (jika mendukung) agar first-fill backend tercermin di tampilan selanjutnya. **Jangan** PATCH `users.phone` dari Flutter pada flow booking. Jangan klaim profil berhasil diisi hanya karena submit loading selesai.
- Nomor hasil booking adalah snapshot `visitor_phone`; tampilan riwayat/bukti memakai snapshot, bukan nomor profil terbaru.
- Sesi berganti/logout ketika request in-flight: input/response profil lama tidak bocor ke sesi user baru.

### 7.3 Idempotency dan retry

- Bentuk payload final **sekali** sebelum `BookingIntent.submit()`. Pastikan `Idempotency-Key` ditetapkan/disimpan bersama body sebelum POST.
- Ketika `IntentNotFound(replaySafe:true)` atau timeout tak pasti, gunakan rekonsiliasi existing; kirim payload tersimpan persis dengan key sama hanya jika safe. **Jangan** membangun ulang phone dari controller, formatter, selection terkini, atau `currentUser`.
- Bila attempt definitif 422/409 / abandoned / expired, ikuti error/resolution existing; jangan auto membuat booking kedua tanpa interaksi user yang jelas.
- Saat revisi input (phone/quantity/tanggal) setelah percobaan ambigu, selesaikan/abandon intent dengan protokol backend terlebih dahulu sebelum membuat key baru.

## 8. Phase 3 — Monthly availability calendar

### 8.1 Models/repository

- Tambah model untuk `MonthlyAvailability` (`destinationGuid`, `month`, `timezone`, `requestedQuantity`, `dates`) dan `AvailabilityDay` (`date`, `capacity?`, `remaining?`, `remainingPercent?`, `level`, `status`, `bookable`).
- `BusinessRepository.monthlyAvailability(destinationGuid, month, quantity)` harus mem-parse **object `data`**, bukan memakai `api.collection()` legacy. Pertahankan method `availability(visitDate/from/to)` existing **tanpa breaking change**.
- Model parser robust untuk `null`, `int`/`double`, dan unknown status: fallback aman sebagai nonbookable jika tidak dapat divalidasi. Jangan mengarang remaining saat `null`.

### 8.2 Kalender UX pada booking

- Saat masuk form booking: fetch bulan terlihat **sekali** per month + quantity + destination + session. Saat pindah bulan, fetch bulan yang relevan. Saat quantity berubah, request data sesuai quantity (debounce opsional); jangan re-hit network pada setiap cell tanggal.
- Marker tanggal: `high` hijau; `medium` kuning; `low` merah/oranye kontras; `none` netral/disabled. Selalu tambah teks/legend/status dan accessible semantics; warna saja tidak cukup.
- tanggal `bookable=false` tidak bisa dipilih. Status `sold_out`, `unconfigured`, `closed`, `insufficient_quantity`, `unavailable` dibedakan melalui pesan; `level:low` dan `bookable:true` tetap selectable.
- Setelah memilih: tampilkan `capacity`, `remaining` dan jumlah pengunjung secara konsisten dengan server. Jika `quantity` dinaikkan di atas sisa, hapus/pending-invalid selection dan tampilkan alasan, jangan submit.
- Loading bulan, error (termasuk offline), retry, dan empty/error UI; jangan menggambarkan data belum termuat sebagai kuota 0. Jangan mengizinkan submit ketika ketersediaan belum terverifikasi untuk kombinasi selection/quantity terbaru.
- Kalender tetap mematuhi jumlah hari Gregorian (28/29/30/31), pergantian tahun, tanggal hari ini dan zona waktu dari response. Jangan mengonversi `YYYY-MM-DD` menjadi hari UTC yang bergeser; treat as **calendar-only date**.
- Race: response bulan/quantity/destination lama tidak boleh overwrite response terbaru. Pakai request generation/token atau stale guard; cache boleh hanya per active session + key lengkap, invalidate setelah booking/assignment changes/refresh.
- Sebelum POST create booking, lakukan cek lokal `bookable` terkini, **tetapi server tetap penentu akhir**. Jika create mengembalikan 409 akibat sold out/window berubah, tampilkan pesan server, refresh bulan, dan minta user memilih ulang; jangan auto retry dengan key baru.
- Jangan mendefinisikan `365 days` limit atau maximum advance horizon baru jika backend tidak menerapkannya. Gunakan validasi server untuk cutoff.

### 8.3 Kalender dan UI implementasi

`showDatePicker` bawaan tidak otomatis mendukung colored cell markers sesuai requirement; implementasikan calendar day builder/wrapper yang bisa memberi marker per tanggal, atau gunakan komponen/dep yang sudah ada bila sesuai. Tidak perlu redesign keseluruhan form. Kembangkan widget reusable jika memberi manfaat, misalnya `lib/widgets/availability_calendar.dart`, dengan state/semantics teruji.

## 9. Error and edge-case matrix

| Kasus | Expected Flutter behavior |
|---|---|
| 401 expired access token | Gunakan refresh/session existing, bukan auth baru |
| 403 fasilitas role rendah | Tidak eskalasi atau fallback master palsu; kembali ke dashboard sesuai role |
| 404 inactive destination/category | Informasikan destinasi tidak tersedia; hindari booking |
| 422 facility invalid / duplicate / inactive | Tampilkan error, pertahankan pilihan input; reload selector jika data berubah |
| 422 phone invalid | Inline di nomor telepon, `+` required; jangan hilangkan form |
| 422 month/quantity invalid | Validasi query dan refresh state, bukan infinite retry |
| 409 quota race / booking conflict | Rekonsiliasi booking intent sesuai status, refresh availability, tampilkan actionable message |
| PUT facility timeout | Refetch destination sebelum mencoba lagi; jangan menambah/mengosongkan pivot diam-diam |
| Booking POST unknown outcome | Resolve `BookingIntent`, jangan post otomatis dengan payload yang sudah berubah |
| Date status low+bookable | Tetap bisa dipilih dengan label hampir penuh |
| Date remaining>0 tapi insufficient_quantity | Nonbookable untuk quantity aktif, jelaskan jumlah tidak cukup |
| No facilities configured | User tidak lihat hardcoded default; admin melihat empty selector |
| Session switched mid-request | Drop stale response, hindari data PII akun lama |

## 10. Test plan — automated oleh agent, manual oleh user

### Unit/model/contract tests

1. `Facility` parsing, master pagination, active/inactive handling, `icon_key:null`, `facilities:[]`.
2. Superadmin CRUD request methods & paths; PATCH tidak mengirim slug; DELETE logical; POST validation errors.
3. Admin selector fetch semua halaman (dedupe, stale guard), preselection, PUT exact array, empty explicit, offline/timeout reconciliation, role 0/1/2.
4. Destination existing edit without facilities change tidak memanggil PUT; create destination sukses/assignment gagal tidak membuat destinasi duplikat.
5. Phone input: default +62, national conversion, E.164, paste international, non-ID country, invalid number/422; backend profile nonempty tidak diubah; empty phone first-fill hanya lewat backend.
6. Booking intent: payload dan key tidak berubah saat replay, termasuk phone punctuation/spacing; concurrent tap guard; session swap/cancel; ambiguous failure.
7. Month parse: response object vs legacy list, 28/29/30/31 hari, null capacity/remaining/percent, thresholds 60/35 boundaries, unknown status fallback, `requested_quantity`.
8. UI calendar: 6 Nov unavailable, 7 Nov available dari fixture; low+bookable selectable, sold_out/closed/unconfigured/insufficient disabled; quantity switch, month switch, stale network results, timezone-safe date.
9. HTTP error mapping and regression auth/login, profile, destinations, quota, favorites, booking, cancellation, existing receipts/reviews.
10. Widget tests screen master facilities, admin select, user details, booking form availability, accessibility labels (render/interaction).

### Execution commands

```powershell
flutter pub get
flutter test
flutter analyze
# Opsional: test file spesifik yang ditambah, lalu full suite ulang.
# Jangan jalankan live E2E yang memutasi database aplikasi kecuali isolated dan opt-in.
```

Agent mencatat total pass/fail terbaru; hasil lint lama dipisah dari lint baru. QA boleh menambahkan integration tests dengan fake/local stub API; jangan menjalankan write ke DB pengguna, staging, atau production. Tidak perlu screenshot atau emulator manual run untuk menandai automated phase done; user sendiri yang akan testing Android Emulator.

## 11. Acceptance criteria / Definition of Done

- [ ] Superadmin role 2 dapat melihat, membuat, mengubah, menonaktifkan, mengaktifkan master fasilitas via Laravel, tanpa seed default.
- [ ] Admin role 1 **tidak** memiliki menu/aksi CRUD master; hanya selector aktif dan assignment ke destinasi.
- [ ] Relasi fasilitas tersimpan dari PUT setelah save; user melihat daftar dinamis, kosong tidak diganti fasilitas hardcoded.
- [ ] Inactive master hilang dari selector/public detail, tetapi UI tidak melakukan penghapusan pivot secara implisit melalui save form biasa.
- [ ] Nomor telepon booking dengan selector kode negara menjadi format international `+...` valid; error422 ditampilkan pada field; snapshot booking tersimpan.
- [ ] Client tidak menimpa `users.phone` melalui booking; backend first-fill dipertahankan; profil existing tetap independen.
- [ ] Payload + Idempotency-Key tersimpan dan digunakan ulang secara identik saat replay; tidak duplicate booking dari double tap/timeout.
- [ ] Kalender menampilkan seluruh tanggal dari API month, marker semantik high/medium/low, status dan remaining; `bookable` menjadi keputusan seleksi.
- [ ] `unconfigured`, `closed`, `sold_out`, `insufficient_quantity` dan `unavailable` dibedakan; low+bookable tetap selectable.
- [ ] Quantity change/move month/session change tidak menampilkan state stale; 409 create booking ditangani dengan refresh dan tanpa oversell-client.
- [ ] Legacy availability method dan semua flow existing tidak regress; auth Google/OTP, JWT, FCM, booking approval/payment tetap tidak berubah.
- [ ] Automated test dan analyze dijalankan; tidak ada regression error/broken build baru, file touched dilaporkan.
- [ ] Handoff Flutter menjelaskan changed files, API map, tests, error cases, dependency, remaining limitations dan checklist manual untuk user.

## 12. Execution plan — one continuous delivery, three internal workstreams

1. **Contract freeze:** audit source dan backend handoff, pilih data classes dan widget strategy, role gates, session safety; baseline tests.
2. **Implement P1:** models + repository + Superadmin CRUD + Admin multi select/assignment + User facility render.
3. **Implement P2:** phone country input, parse/validate/serialize `+`, profile refresh behavior; booking intent regression.
4. **Implement P3:** month response parser, calendar UI states, quantity and request guards, booking 409/reconciliation.
5. **Quality gates:** QA+Security audit, fix defects, full tests, analyze, `git diff --check` jika tersedia; compile/build debug jika feasible tanpa memodifikasi signing/release config.
6. **Handoff:** write `docs/flutter-business-integration-phase-1-2-3.md` (jika folder ada, disesuaikan) plus ringkasan final, tanpa commit/push/deploy.

## 13. User manual test checklist (untuk handoff, **bukan** tugas agent menjalankan)

1. Login Superadmin → Kelola Fasilitas → buat Parkir, Toilet, Wi-Fi → disable/re-enable satu item; cek daftar.
2. Login Admin → tambah/edit destinasi → pilih dua fasilitas → save → buka lagi pastikan terpilih; coba ubah atribut destinasi tanpa menyentuh fasilitas.
3. Login User → detail destinasi berfasilitas dan tanpa fasilitas → tidak ada label default fiktif.
4. Booking dengan akun `users.phone` kosong → masukkan `+62` → booking sukses → profil terisi; booking kedua dengan nomor kontak berbeda → profil pertama tidak ditimpa.
5. Kalender November 2026: 6 Nov (quota0) nonselectable; 7 Nov (quota200/remaining200) hijau jika masih dalam jendela booking yang sah saat diuji; tanggal status backend tetap otoritatif. Karena waktu berjalan, gunakan **fixture tanggal masa depan** bila 6/7 November sudah melewati cutoff.
6. Quantity diubah → kalender menyesuaikan `bookable`; cek full/closed/unconfigured/low; refresh apabila terjadi 409.
7. Logout/login akun lain saat loading → tidak ada fasilitas privat/master/nomor profil/intent akun pertama yang bocor.

**Catatan tanggal:** contoh 6/7 Nov 2026 bersifat ilustrasi payload, bukan janji tanggal selalu masih bookable; cutoff dan zona waktu ditentukan backend.

## 14. Final reporting format

Laporkan: status tiap Phase (DONE/PARTIAL/BLOCKED), daftar file dibuat/diubah, implementasi endpoint/model/widget, dependency baru dan alasan, test command + angka asli, lint baseline vs baru, temuan security, risiko contract drift, hal yang sengaja tidak dikerjakan, dan panduan singkat untuk user menjalankan manual test. **Jangan mengklaim memanggil subagent yang tidak berhasil dijalankan.**

---

### Reference provenance

- Laravel handoff terlampir: `backend-business-adjustment.md` (2 Nov 2026), otoritas kontrak API, authorization, phone, availability, dan regression.
- Repository publik `koyotot/pami-wisata-daearahku`: README arsitektur Flutter/Laravel; `lib/data/business_repository.dart`, `lib/data/booking_intent.dart`, `lib/data/admin_state.dart`, dan layar sebagaimana terlihat pada source publik saat PRD ditulis. Source publik/raw sebagian tampak tidak sinkron antarfile: **working tree lokal harus diverifikasi**.
- `docs/DESIGN.md`: audit styling historis, harus dibaca ulang pada checkout lokal dan dipakai untuk menjaga konsistensi, bukan redesign.
