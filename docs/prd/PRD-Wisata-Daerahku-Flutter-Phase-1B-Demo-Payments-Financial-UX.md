# PRD — Wisata Daerahku · Flutter Phase 1B
## Checkout DEMO Role 0 + Financial Dashboard Admin/Superadmin

**Status:** Requirements frozen (15/15 keputusan); siap implementasi Flutter.  
**Tanggal:** 5 November 2026 · **Scope:** Flutter presentation + API integration only.  
**Basis UI:** Approved Phase 1A interactive wireframe A00–A09, E00–E08, X01–X08; ekstensi Phase 1B U00–U13 dalam HTML yang dilampirkan.  
**Backend pin:** `joytimess/pami-wisata-daerahku-api@0bf82ffd8b377fc736b20ee4abfdf58a1b11b7ba` — `feat(payments): add ledger, demo simulator, and financial analytics`.  
**Flutter public pin (referensi saja):** `koyotot/pami-wisata-daearahku@0566f7cf133b8a0918f2a94a11d2928f5b3d718a` — operasional Phase 1A. **Checkout lokal Codex dapat lebih mutakhir; periksa working tree dahulu, jangan reset.**

> **Tegas:** Ini kelanjutan Phase 1B; bukan rebuild Phase 1A, bukan DOKU real-money. HTML bersifat offline, interaktif, dan berisi **data contoh**, bukan API. Semua nilai live harus mengikuti Laravel. Seluruh keputusan UI yang disetujui pengguna di bawah tidak boleh dinegosiasikan ulang.

## 0. Dokumen sumber yang WAJIB benar-benar dibaca Codex

1. `docs/design/Wisata-Daerahku-Interactive-Wireframe-Phase-1B-EXTENSION.html` — **spesifikasi visual/interaksi Phase 1B utama**. Buka di browser; ikuti kiri (pilih role/screen), tengah (ponsel), kanan (screen contract). Ini ekstensi HTML yang **mempertahankan approved Phase 1A**; jangan interpretasikan screenshot sebagai source Flutter.
2. `docs/design/Wisata-Daerahku-Admin-Superadmin-Interactive-Wireframe-APPROVED-Phase1A.html` — **baseline visual Phase 1A approved**; desain lama A/E/X tidak boleh diganti gaya secara arbitrer.
3. `docs/DESIGN.md` — pedoman dan inventaris visual Flutter; **sebagian catatan audit lama mungkin merujuk Firebase/arsitektur usang, jangan pakai sebagai kontrak backend**. Cocokkan dengan source Flutter terbaru.
4. **Skill lokal wajib:** cari `design-taste-frontend/SKILL.md` di instalasi Codex/agent pengguna, termasuk `C:\Users\itsba\.agents\skills\design-taste-frontend\SKILL.md`, `C:\Users\itsba\.codex\skills\design-taste-frontend\SKILL.md`, atau lokasi nyata lain. **BACA isi SKILL.md, lalu baca file references/checklists yang ditunjuk skill dan relevan dengan tugas ini.** Jangan mengarang isi skill. Bila tidak ditemukan, **STOP sebelum coding** dengan daftar path yang diperiksa.
5. **Agent instructions:** `C:\Users\itsba\.codex\Agents.md`; inventaris agent dalam `C:\Users\itsba\.codex\agents\`. Baca sebelum delegasi, gunakan **maksimum dua** agent hanya bila nyata membantu (mis. pembayaran role 0 dan dashboard A/E). **Jangan pakai QA/test/regression agents.** Agent opsional; satu agent juga sah.
6. Laravel terbaru: [`docs/phase-1b-handoff.md`](https://github.com/joytimess/pami-wisata-daerahku-api/blob/0bf82ffd8b377fc736b20ee4abfdf58a1b11b7ba/docs/phase-1b-handoff.md), `routes/api.php`, `PaymentController.php`, `PaymentService.php`, `PaymentGateway.php`, `DemoPaymentService.php`, `FinancialAnalyticsService.php`, `PaymentEligibility.php`, `BookingResource.php`, `TicketService.php` pada backend pin. **Baca kode dan handoff lebih dulu; kalau kontrak berbeda dari PRD, jangan mengarang; laporkan gap.**
7. Flutter existing minimum: `lib/data/business_repository.dart`, `lib/data/booking_state.dart`, `lib/data/ticket_models.dart`, `lib/screens/bukti_pendaftaran_screen.dart`, `lib/screens/daftar_kunjungan_screen.dart`, `lib/screens/operations_dashboard.dart`, `lib/screens/operations_reports.dart`, `lib/screens/operations_navigation_shell.dart`, `lib/widgets/floating_bottom_nav.dart`, komponen notifikasi dan tiket yang ditemukan pada working tree. Reuse pola API client, auth session, dan navigation existing.

## 1. Tujuan & batas implementasi

**Sasaran utama:** setelah booking berbayar disetujui Admin, role 0 dapat menyelesaikan **Demo Payment Simulator** melalui Flutter dan melihat status booking/tiket yang benar. Role 1/2 dapat melihat data **finansial DEMO** secara scoped dengan data-source provenance, filter, dan hierarchy yang approved.

**Harus dipertahankan:** role 0 floating navbar `Beranda – Riwayat – Jelajah (tengah) – Notifikasi – Profil`; Admin `Beranda – Booking – Scan QR (tengah) – Destinasi – Profil`; Superadmin `Ringkasan – Operasi – Analitik (tengah) – Kelola – Profil`. Kontrol icon-only, glass/blur, elevated center, safe-area mengikuti existing Flutter. Jangan mengganti shells yang telah bekerja.

**Non-goals keras:** implementasi DOKU Sandbox/Production, QRIS/VA/E-Wallet asli, real funds, refund workflow, settlement accounting, payout, audit E06, Phase 2/3, backend migrations/API changes/config `.env`, redesign semua layar role 0, rewrite operasional Phase 1A, dummy payment dalam production app, fake QR dan fake revenue.

**Aturan proses pengguna:** **TIDAK ADA Flutter analyze, dart analyze, unit/widget/integration tests, QA, visual regression testing, full regression, emulator test run, atau APK/build otomatis.** Tidak menjalankan perintah tersebut dan tidak menugaskan agent QA. Boleh membaca source dan mengedit kode, kemudian membuat handoff yang jujur: **NOT TESTED BY REQUEST**, jangan klaim PASS.

## 2. Keputusan 1–15 yang sudah final (semuanya pilihan yang dikunci)

| # | Keputusan final | Dampak implementasi |
|---|---|---|
| 01 | **A** — integrasi lengkap | Checkout DEMO role 0 + finansial role 1/2, bukan salah satunya. |
| 02 | **B** — E-Wallet-style DEMO | UX dompet digital, tetapi **kode metode API hanya `demo`**, bukan E-Wallet provider. DEMO terlihat jelas. |
| 03 | **B** — checkout + expandable scenario | Default **success**, panel `Skenario Simulasi` collapse/expand berisi success/failed/expired. |
| 04 | **B** — akses dari Riwayat + Notifikasi | Kedua entry membuka detail booking/checkout dengan booking GUID yang sama. |
| 05 | **B** — halaman hasil khusus | Hasil sukses, gagal, dan attempt kedaluwarsa punya halaman/state berbeda + recovery sesuai backend. |
| 06 | **B** — environment terpisah | A09/E07: DEMO, Sandbox, Production; jangan pernah gabung nominal. |
| 07 | **B** — Ringkasan + Analitik Pembayaran | Segmented control; tidak ada fake transaksi atau finance time-series. |
| 08 | **B** — Financial Preview Card | Tambahkan di A00/E00, tidak mengganti scenic hero/KPI operasional/action center. Tap ke A09/E07. |
| 09 | **B** — Adaptive Financial Preview | `unavailable` ≠ valid zero ≠ partial data. Financial preview tetap ada. |
| 10 | **B** — checkout unavailable adaptif | `can_pay=false`: CTA disabled dengan penjelasan. Flutter tidak menyetel flag/gateway. |
| 11 | **B** — Smart Payment Recovery | GET status authoritative saat kembali; reuse current pending attempt, cegah duplikasi idempotency. |
| 12 | **B** — countdown 3 tempat | Riwayat, Detail Booking, Checkout dari `payment_expires_at`; 0 detik → refresh Laravel, bukan set status lokal. |
| 13 | **B** — Inbox + context | Inbox sukses DEMO dari Laravel; update Riwayat/Detail/Tiket. Tidak tambah FCM/email/local notification. |
| 14 | **B** — tiket terlihat sebelum QR | Setelah confirmed, tiket per-unit bisa dilihat; QR hanya ketika API eligible H-5, check-in hanya hari kunjungan. |
| 15 | **B** — compact filter + bottom sheet | Environment selector inline; periode+destinasi lewat sheet, Apply/Reset, role scope. |

**Tidak ada pertanyaan ke-16.** Untuk detail minor yang tidak ditentukan, cocokkan dengan kode existing + approved HTML + design-taste skill; buat keputusan konservatif yang tidak menciptakan fitur backend baru.

## 3. Visual/interaction contract — referensi HTML wajib

### 3.1 Struktur screens

**Role 0 (ekstensi baru):** `U00` Riwayat (countdown), `U01` Detail Booking approved, `U02` Checkout E-Wallet-style DEMO, `U03` pending/processing, `U04` success result, `U05` failed result, `U06` expired attempt result, `U07` payment recovery, `U08` tiket per-unit + QR gate, `U09` inbox, `U10` payment unavailable. `U11/U12/U13` hanya placeholder navigasi Beranda/Jelajah/Profil existing; **jangan port placeholder ke Flutter sebagai redesign**.

**Role 1:** A00 financial preview (tanpa hilangkan KPI), A09 financial dashboard khusus; A01–A08 existing visual dan workflow **tetap**.

**Role 2:** E00 financial preview, E07 financial dashboard khusus; E01–E06 dan E08 existing **tetap**; E06 audit timeline unavailable karena tidak ada endpoint global audit baru.

**Shared:** X01–X08 dari baseline approved tetap ada, X07 harus dipahami sebagai DOKU/source production unavailable, **bukan berarti DEMO financial source tidak mungkin tersedia**.

### 3.2 Komposisi visual yang harus diconvert ke widget Flutter

- Gunakan scenic blue header compact, typography Plus Jakarta Sans existing, navy copy, white surfaces, single blue focus, semantic amber/green/error. **No gratuitous gradients** di semua kartu; header dan nominal DEMO menjadi fokus, bukan dekorasi seluruh halaman.
- Checkout: total amount paling dominan; context booking + deadline dekat CTA; satu metode aktif `Dompet Digital · DEMO`, bukan logo OVO/DANA/GoPay palsu. Accordion scenario sekunder agar checkout normal tetap fokus.
- Results: ikon state, headline kuat, nomor booking/amount dan langkah berikutnya; `DEMO / TEST_ONLY` selalu terlihat; CTA kontekstual.
- Financial: environment selector sebelum summary; compact filter dekat kontrol; tabs `Ringkasan / Analitik Pembayaran`; total gross DEMO kuat namun jelas tidak nyata; null metric represented `— / Belum Tersedia`; alert incomplete finance tidak diganti Rp0.
- A00/E00 preview: dua nilai saja (gross demo dan transaksi sukses) + badge `DEMO / TEST ONLY` + drill-down. Jangan campur nilai DEMO ke KPI Production.
- Mobile: safe area, no overlap navbar/fixed CTA; tombol konteks aman untuk tap; state readable tanpa hover; bottom sheet apply/reset; user checkout full-screen boleh menyembunyikan navbar sesuai pola navigator existing.
- Data yang muncul di HTML `WDA-2048`, Rp240.000, Rp2.450.000, 12 transaksi, dsb. hanya **illustrative examples**; **tidak boleh hardcode di Flutter production source**.

### 3.3 Urutan interaksi visual

`U00 Riwayat → U01 Detail Booking → U02 Checkout DEMO → U03 Pending → U04 Success / U05 Failed / U06 Expired → U08 Tiket`; `U09 Notifikasi → U01`; `U07 Recovery` dapat dicapai dari U02/U03/U05/U06 atau ketika app dibuka ulang. Pada A00/E00 tap preview → A09/E07, tab/filters/environment memperbarui request ke finance API tanpa mengubah role scope.

## 4. Kontrak Laravel Phase 1B yang sudah dicek di source

**API base:** `/api/v1`. Semua endpoint auth JWT existing. Owner pembayaran: **role 0 aktif, hanya booking sendiri**. Admin/Superadmin **tidak** boleh POST pembayaran. API tidak menggunakan external payment gateway pada fase ini.

| API | Siapa | Kontrak dan pemakaian |
|---|---|---|
| `GET /payments/methods?booking_guid={uuid}` | Owner role 0 | Kembalikan booking snapshot & capabilities: `can_pay`, `reason`, `methods`, `amount`, `currency`, `expires_at`, `booking_status`, `payment_status`, `provider`, `environment`, `integration_status`. Saat DEMO aktif, **metode terdaftar `code=demo`**. Saat belum aktif, QRIS/VA/E-Wallet berstatus unavailable. |
| `GET /bookings/{booking_guid}/payment-intent` | Owner role 0 | Sumber recovery, `status` intent (mis. `processing/paid/not_created`), `last_attempt.status` (`pending/paid/failed/expired`), safe metadata, `instruction.presentation_type`, eligibility. Ini berbeda dari status booking. |
| `POST /bookings/{booking_guid}/demo-payment` | Owner role 0 | `Idempotency-Key` **wajib**, body `{}`; initiate/reuse pending atau retry aman setelah failed/expired jika masih eligible. Return `attempt_guid`, `intent_guid`, `status` attempt, payment/booking snapshot. |
| `POST /bookings/{booking_guid}/demo-payment/simulate` | Owner role 0 | `Idempotency-Key` **wajib dan terpisah** dari initiate; JSON `{ "attempt_guid": "<uuid dari initiate>", "outcome": "success|failed|expired" }`. Response `status=paid|failed|expired`, `booking_status`, `payment_status`. |
| `GET /bookings/{booking_guid}` | Owner role 0 | Refresh status booking after mutation; `payment_status`, `payment_provider`, `payment_environment`, `payment_test_only`, `payment_label`, `payment_expires_at`. |
| `GET /bookings/{booking_guid}/tickets` | Owner role 0 | Tiket per-unit dan `ticket_state`; QR gate authoritative. |
| `GET /bookings/{booking_guid}/tickets/{ticket_guid}/qr` | Owner role 0 | SVG QR dari server hanya jika eligible; jangan generate sendiri. |
| Existing notifications endpoint/inbox | Owner role 0 | Inbox `demo_paid` dari backend, tanpa email atau FCM push untuk success simulator. Reuse navigasi notifikasi existing. |
| `GET /admin/dashboard/financial?environment=demo` | Role 1/2 | Baca `data.financial` (OperationalResource); role 1 current assigned destinations, role 2 global. Boleh `environment=sandbox|production` tetapi sumber DOKU belum ada. |

**Activation gate:** `DEMO_PAYMENTS_ENABLED=false` by default; backend hanya mengizinkan `APP_ENV=local|testing|demo` **dan** flag true. Default inactive bukan error Flutter. UI harus mengikuti `can_pay`, `availability`, `reason`. DOKU selalu hard-disabled pada commit ini. Tidak ada Flutter-side toggle yang menyalakan gateway. Bila gate OFF, bisa tetap ada label pembayaran DEMO historis, tapi `PaymentEligibility` fail-closed untuk check-in baru.

**Do not invent routes:** tidak ada generic `POST /payment-intent` atau `POST /payment-attempts`, tidak ada DOKU webhook/check-out/QRIS payload yang bisa digunakan. `GET /payment-preview` read-only dan default OFF, bukan tombol bayar.

### 4.1 State machine role 0 (sumber backend, bukan UI)

1. Booking dibuat → `pending_approval` (belum eligible bayar).
2. Admin approve booking berbayar → `awaiting_payment` (approval **bukan paid**).
3. Jika `can_pay=true`, initiate menghasilkan `attempt.status=pending`, `intent.status=processing`, booking masih `awaiting_payment`.
4. Simulate `success` membuat attempt `paid`, verified **DEMO simulator capture** pada ledger, booking `confirmed`, `payment_status=paid` jika gate tetap sah; satu notifikasi inbox DEMO dari server. Ini **bukan signature DOKU**.
5. Simulate `failed`/`expired`: attempt terminal, intent dapat kembali `requires_payment`, booking tetap `awaiting_payment`; retry hanya sebelum payment deadline & visit constraints.
6. Unknown/timeout/restart: **GET payment-intent + GET booking**, tentukan safe path; jangan otomatis POST lagi saat response tidak pasti.
7. Countdown memakai server `payment_expires_at` UTC. Tidak ada perpanjangan otomatis. Grace verifikasi bukan tambahan waktu bayar.
8. Jika sudah `confirmed`, tiket per-unit tersedia untuk dilihat. QR mengikuti H-5 (destination-local timezone), **check-in tetap hanya pada visit day**. Jika gate nonaktif kemudian, backend dapat kembali `unverified` untuk eligibility; jangan mempertahankan cache QR sebagai tiket baru yang valid.

### 4.2 Idempotency dan recovery: ketentuan wajib

- Generate idempotency key unik **per operasi dan payload**. Initiate dan Simulate tidak memakai key yang sama. Same operation + same key + same payload aman direplay; same key different payload → 409.
- Jangan generate key baru untuk suatu mutasi dengan hasil ambigu (network lost), terutama jika aplikasi resume. Lakukan GET recovery dulu. Pertahankan pending operation state sesuai pola session/repository existing dan hindari double-tap.
- Panggilan simulate memakai `attempt_guid` **hasil initiate/backend current pending**, bukan UUID rekaan. Outcome diambil dari pilihan demo UI, server tetap authoritative untuk amount/currency/paid_at.
- No `amount`, `currency`, `status`, `paid_at`, `provider` dikirim pada POST simulator. Nilai berasal dari server booking snapshot.
- 401 → session flow existing; 403/404 → no permission/gate closed dan safe explanation; 409 → refresh state + show conflict/recovery; 422 → validation/eligibility; 429 → polite throttle; network/5xx → ambiguous outcome, **GET first**, no false success.

## 5. Kontrak Financial API, state, dan filter

**Endpoint tunggal:** `GET /api/v1/admin/dashboard/financial`. Query yang valid: `environment=demo|sandbox|production` (default backend `production`), `from`, `to` (YYYY-MM-DD **harus berpasangan**, UTC; rentang maksimal **366 hari inklusif**), `destination_guid` (UUID authorized). `date_basis` hanya `paid_utc`; `admin_guid` **prohibited**. Jangan create filter staf palsu.

**Scope:** role 1: `assigned_destinations` saat ini, role 2: global. UI filter destinasi harus mengikuti daftar yang diizinkan; backend tetap mengecek scope. Assignment multiple tidak boleh menggandakan revenue.

**Mapping UI ↔ response `data.financial`:**

| UI | Key API | Ketentuan |
|---|---|---|
| Data environment & source | `environment`, `provider`, `test_only`, `label`, `source`, `availability`, `reason` | Validasi provenance. DEMO label selalu terlihat, tidak sebagai pendapatan nyata. |
| Gross revenue | `gross_revenue` | Nilai demo recognized jika `partial`, `null` berarti unavailable. |
| Gross collected | `gross_collected` | Beda dari recognized revenue; jangan otomatis samakan. |
| Unapplied collected | `unapplied_collected` | Jangan disamakan dengan `net_revenue`. |
| Transaksi sukses | `successful_transactions` | Unique recognized paid transaction count. |
| Tiket terjual | `tickets_sold` | Quantity, bukan jumlah booking. |
| Attempts | `payment_attempts`, `successful_payment_attempts`, `failed_attempts`, `expired_attempts`, `unknown_attempts` | Pembilang dan penyebut harus sesuai kontrak. |
| Konversi | `attempt_conversion.percent`, `booking_conversion.percent` | Dua metric **berbeda**, label dan date_basis masing-masing. Jangan buat konversi sendiri. |
| Rata-rata durasi | `avg_payment_seconds` | Null → belum tersedia. |
| Method mix | `method_mix[]` | Agregat `method/channel`, bukan daftar transaksi, dengan limit/truncated metadata. |
| Unavailable financial | `gateway_fees`, `net_revenue`, `settlement`, `refunds_complete`, `missing_fields` | Null → “Belum Tersedia”; jangan klaim estimasi. Refund mungkin tidak complete. |

Backend bisa mengembalikan `availability=unavailable` (source tak ada) atau `partial` (data available tapi fees/net/settlement incomplete). Saat DEMO aktif tanpa capture, agregat nol valid bisa muncul. DEMO historis dapat dibaca dengan label setelah execution gate OFF jika memiliki event, tetapi **tidak berarti checkout diaktifkan**.

**Filter UX (15/B):** pilih environment di halaman; `Filter` membuka bottom sheet periode/destinasi dengan Apply/Reset. Perubahan kontrol hanya mempengaruhi GET request; nilai ilustratif HTML tidak menyimulasikan hitungan backend. Saat kembali ke screen, pertahankan pilihan bila data role/scope sah, tapi reset/purge saat role/assignment berubah.

**Home preview (08/B & 09/B):** di A00/E00, tampilkan gross DEMO + success transaksi dari endpoint yang sama, diberi provenance. Kalau unknown → adaptive unavailable, kalau valid zero → Rp0, kalau valid partial → sample amount sebenarnya. Tetap bisa tap A09/E07; jangan menimpa operational KPIs dan jangan buat second fake backend aggregator.

## 6. State khusus, loading dan akses

- Checkout payment OFF / can_pay false: screen U10 disabled CTA dengan reason mapping, bukan silent button atau checkout DOKU.
- `booking_not_awaiting_payment`, `payment_window_closed`, `visit_window_closed`, `doku_not_configured`, `payment_provider_conflict`: tampilkan reason yang jujur; tidak ada override client.
- `pending`: screen U03 (atau recovery U07), **jangan** tampilkan success sebelum backend confirm.
- `paid`: screen U04, refresh booking & tickets/inbox. Ticket QR mungkin `scheduled` walau paid.
- `failed`/`expired` attempts: screen U05/U06, query eligibility ulang sebelum tampilkan retry.
- `unknown`: U07, tampilkan “Periksa status” tanpa duplicate POST.
- Financial: `loading` skeleton, `unavailable` reason text + em dash, `partial` actual counters plus unverified fields as em dash, valid zero → true zero, stale/offline → freshness caveat. Jangan default nilai 0 ketika request gagal.
- Role 1 tanpa assignment tetap X01; tidak boleh melihat data Superadmin/global. E06 audit tetap unavailable.

## 7. Strategi edit Flutter (ringkas dan minim diff)

1. **Read phase:** cek working tree dan source lokal. Baca mandatory skill + references, agent instructions, HTML lama/baru, backend contracts. Identifikasi navigator, `BusinessRepository`, `ApiClient`, booking/ticket/notif state dan dashboard; jangan membuat duplicate infrastructure.
2. **User path:** tambah model/adapter pembayaran minimal yang membaca fields authoritative. Hubungkan CTA dari Riwayat & Inbox → detail → checkout. Buat states U02–U10, idempotent initiate/simulate, recovery, countdown. Pertahankan existing user booking, tickets, QR widget.
3. **Finance path:** tambah satu finance repository call dan domain-state yang membedakan null/zero/partial/unavailable; A09/E07 dengan sharing component jika masuk akal. Tambah A00/E00 adaptive preview tanpa merusak operational dashboard.
4. **Cross-cutting:** gunakan existing theme, header, nav, sessions, error mapper dan scoped reload. Tampilkan DEMO provenance di booking/ticket/inbox/financial sesuai backend.
5. **Handoff:** rangkum file changed, endpoint wired, screens implemented, permission/errors accounted, known blockers, dan status **NOT TESTED BY REQUEST**.

**Tidak membuat package baru tanpa kebutuhan keras.** HTML source adalah desain/behavior reference, **bukan** kode untuk di-embed ke Flutter WebView.

## 8. Definition of Done (implementasi, TANPA QA/testing)

- Semua 15 pilihan telah diterjemahkan ke navigasi + implementasi UI/API Flutter tanpa menambah route backend.
- Checkout role 0 hanya memakai metode `demo` saat capabilities mendukung. Skenario success default, failed/expired tersembunyi di accordion.
- Recovery tidak mengulang POST saat outcome ambigu. Countdown three surfaces terhubung ke deadline server.
- Role 0 menampilkan hasil pembayaran terpisah dan tiket per-unit dari backend; tidak membuat QR sebelum waktunya.
- A00/E00 preview tampil, adaptive. A09/E07 punya environment segregation, summary/analytics tabs, compact filter + bottom sheet.
- Semua angka finansial dari `data.financial`; null/zero/partial berbeda, fee/net/settlement tidak dipalsukan.
- Phase 1A (approval/claims/assignments/scanner/shell) dan role 0 existing tidak direwrite.
- Tidak ada `flutter analyze`, `flutter test`, `dart analyze`, widget/unit/integration/e2e tests, QA, regressions, APK build atau commit/push; **jangan mengklaim telah diverifikasi di runtime**.
- Final handoff menjelaskan perubahan dan batas validasi; user dapat melakukan review manual kemudian secara terpisah jika mau.

## 9. Risiko & blocker yang perlu dinyatakan, bukan disembunyikan

1. **Backend simulator gate OFF by default:** `DEMO_PAYMENTS_ENABLED` dan `APP_ENV` harus diaktifkan oleh pemilik backend pada instance/database demo terpisah. Codex Flutter **tidak boleh menyentuh `.env`, config, migration, ataupun deployment backend**. Saat OFF, UI unavailable adalah expected.
2. **DOKU Sandbox tidak siap:** jangan demo-kan provider real-money; semua nominal demo jelas TEST_ONLY.
3. **`docs/DESIGN.md` Flutter mungkin usang untuk Firebase/auth:** ikuti source terbaru, jangan memigrasikan auth mundur.
4. **API finance tidak memberi finance time-series atau individual transaction list:** jangan membuat grafik revenue palsu, tabel transaksi bohong, settlement or fee estimates.
5. **QR eligibility bergantung gate DEMO saat check-in:** terlihatnya booking `confirmed` historis bukan jaminan QR check-in aktif jika gate off.
6. **Baseline HTML A/E/X** adalah desain approved; ekstensi Phase1B diturunkan dari 15 keputusan. Jika ada perbedaan kecil antar-HTML, prinsipnya: backend authoritative untuk fakta, HTML Phase1B untuk baru, HTML Phase1A approved untuk layout lama.

## 10. Matriks layar ↔ API ↔ scope

| Layar | Fetch/action | Pengecualian penting |
|---|---|---|
| U00 Riwayat | `GET /bookings`; booking payment_expires_at | no fake zero timer; countdown display only |
| U01 Detail | `GET /bookings/{guid}`, methods, payment-intent | approval != paid |
| U02 Checkout | GET methods/payment-intent; POST initiate | demo only, optional scenario |
| U03 Processing | POST simulate (explicit) / GET reconcile | no premature success |
| U04 Sukses | GET booking + tickets + inbox | QR H-5 gate |
| U05/U06 Gagal/Expired | GET intent + methods before retry | attempt expiry != booking expiry |
| U07 Recovery | GET payment-intent, GET booking | no auto duplicate attempt |
| U08 Tiket | GET tickets, GET QR if eligible | per-unit; no local QR; visit day check-in |
| U09 Inbox | notifications existing + booking route | no new FCM/email |
| U10 Unavailable | methods reason & booking state | disabled checkout |
| A00/E00 | existing operational endpoints **plus** financial demo | financial badge DEMO; avoid mixing accounting |
| A09/E07 | GET admin/dashboard/financial with scoped filters | null ≠ zero; demo sandbox production separate |

---

**Penyusun PRD tidak mengubah repository.** Ini spesifikasi yang mengikat implementasi Codex berikutnya; tidak ada klaim Flutter sudah dijalankan/analyzed/tested setelah perubahan.
