# PRD IMPLEMENTASI — WISATA DAERAHKU
## Admin Role 1 · Kelola Destinasi Terpadu + Preview Pengunjung Read-Only (Interactive Wireframe V3)

**Status:** APPROVED FOR IMPLEMENTATION · berdasarkan keputusan pengguna, belum dijalankan pada kode Flutter oleh dokumen ini  
**Tanggal acuan:** 7 November 2026  
**Repo Flutter:** https://github.com/koyotot/pami-wisata-daearahku  
**Remote `main` HEAD diverifikasi:** `bbab5069fcc01c2e2ce6397d453d9ff000b68d6d`  
**Judul commit:** `fix(admin): refine role 1 workflows and add regression coverage` (6 November 2026, 17:32:26 UTC)  
**Baseline sebelum V3:** `48ab11c0a14fafa9d60383ee0c27530d675358de`  
**Repo Laravel:** https://github.com/joytimess/pami-wisata-daerahku-api — **read-only**, tidak mengubah schema/API.  
**User scope:** `users.role == 1` (disebut `user_type 1` dalam brief). **Bukan** relayout role 0 atau role 2.  
**UX yang disetujui:** `docs/references/wisata_admin_interactive_wireframe_v3_preview_pengunjung.html` (disertakan dalam paket).  
**Referensi tambahan:** V1 di `docs/references/wisata_admin_interactive_wireframe_v1.html`, 29 screenshot lama di `docs/references/screenshots/`, serta hasil QA sebelumnya di `qa/admin-role1-post-relayout/results/`.

---

## 1. Tujuan dan hasil akhir

Dari tab bawah Admin **Destinasi** → layar **Kinerja Destinasi** → segmen **Kelola**:

1. **Satu management hub** menggantikan empat daftar yang berulang (`Daftar Wisata`, `Ubah Data Wisata`, `Hapus Data Wisata`, `Kelola Kuota`) sebagai jalur utama role 1.
2. Setiap destinasi tampil sebagai **compact destination card** dengan thumbnail, nama, lokasi, harga, status, serta **dua tombol eksplisit**: `Preview` dan `Kelola`.
3. **Tidak ada tap seluruh kartu ataupun ikon `>` ambigu** yang membuka `DetailWisataScreen` publik. Hanya `Preview` membuka preview user; hanya `Kelola` membuka sheet tindakan admin.
4. `Preview` menampilkan **pengalaman visual detail destinasi seperti pengunjung** (galeri/carousel, nama, harga, deskripsi, fasilitas, lokasi/peta, ulasan) menggunakan **data API Laravel** dan komponen Flutter user yang sudah ada, tetapi **read-only secara fungsional**.
5. `Kelola` membuka bottom sheet tindakan: **Preview Pengunjung**, **Ubah Informasi**, **Kelola Galeri**, **Kelola Kuota**, dan tindakan destruktif **Nonaktifkan/Hapus** atau **Aktifkan Kembali** sesuai kontrak backend yang sebenarnya. **Tidak mengarang hard delete.**
6. Kontrol pencarian, filter status, kategori bila relevan, dan scroll state tetap terjaga setelah preview/editor ditutup. Data disinkronkan setelah mutasi berhasil dengan mekanisme existing; tidak ada tombol refresh manual pada role 1 (tarik ke bawah untuk refresh).
7. Integrasi **tanpa perubahan backend**, tanpa mengulang implementasi autentikasi, kuota, galeri, booking, approval, atau scanner. Ketentuan keselamatan mutasi dan permission tetap berlaku.

**Success metric:** Admin yang hendak melihat representasi sisi Pengunjung dapat memilih `Preview` tanpa pernah mendapatkan kemampuan membuat booking/review/favorit; Admin yang ingin edit/kuota/galeri dapat memilih `Kelola` tanpa mencari ulang destinasi di daftar lain.

## 2. Source of truth / prioritas apabila bertentangan

1. **Kontrak Laravel aktual, `AuthSession`, `BusinessRepository`, scope assignment, optimistik locking, dan keamanan mutasi** paling tinggi. Nilai API/null/error wajib jujur.
2. **Keputusan UX V3 pengguna:** management hub tunggal; dua CTA card terpisah; preview read-only; bottom sheet tindakan.
3. **Wireframe HTML V3** yang disertakan: tata letak/urutan/alur visual. Semua data, lokasi peta, gambar/galeri dan hasil edit pada HTML adalah **simulasi lokal**, bukan basis data.
4. **Flutter saat commit terbaru**: reuse komponen dan state. V1 dan 29 screenshot lama hanya referensi cakupan masalah, bukan gaya visual target V3.

Jika layar user detail sekarang memungkinkan aksi yang tidak pantas dalam preview Admin, **perlu guard aksi yang nyata**, bukan menaruh overlay transparan atau mematikan tombol lewat CSS/warna saja.

## 3. Batasan perubahan

**Dalam scope:** tab `Kelola` role 1 pada `OperationsReportScreen(section:'destinations')`, widget list/card dengan tindakan eksplisit, bottom sheet tindakan, route Preview user read-only, state kembali/filter/pagination, mutasi create/edit/galeri/kuota/status melalui layar lama, test dan visual QA terarah.

**Di luar scope:** redesain total halaman user detail, redesign role 0 atau 2, pembuatan API Laravel baru, hard delete yang tidak didukung, pembayaran/DOKU, mengubah QR check-in atau approval, modifikasi schema, instal dependency/skill tanpa izin, dan memasukkan mock HTML sebagai runtime.

**Kondisi QA warisan:** commit `bbab506` sudah menyertakan laporan QA dan beberapa fix. File `qa/admin-role1-post-relayout/results/DEFECTS.md` masih mencatat **D-003 scanner stale scope S2** dan **D-004 kontras legacy S3** sebagai OPEN. Dokumentasi tersebut *merekam hasil QA saat itu*, bukan bukti defect sudah ditutup oleh commit. **Jangan menghapus, skip, melemahkan, atau mengklaim lulus tes scanner yang gagal.** Perbaikan scanner merupakan workstream keamanan terpisah, kecuali pengguna secara eksplisit menambahkan scope; regression hasilnya tetap harus dilaporkan.

## 4. Peta kode yang telah diperiksa dari GitHub terbaru

| File / fungsi | Kondisi saat audit | Target V3 |
|---|---|---|
| `lib/screens/operations_navigation_shell.dart` | Role1 nav index 3 → `OperationsReportScreen(section: 'destinations')`; pakai `IndexedStack` + `TickerMode`. | **Pertahankan** 5 tab, state preservation dan ticker fix. |
| `lib/screens/operations_reports.dart` | Menampilkan `Kinerja / Kelola`; bagian Kelola masih route-link ke daftar CRUD terpisah. | Ganti konten segmen Kelola dengan management hub terpadu / composable widget. Kinerja tetap utuh. |
| `lib/screens/daftar_wisata_screen.dart` | Mode `view/edit/hapus/kuota` dan `_WisataCard` besar; onTap view dapat membuka `DetailWisataScreen`; FAB Tambah. | Reuse repository, pagination, search dan mutasi, tetapi role1 hub gunakan compact card + `Preview`/`Kelola`, tanpa area-card navigation ambigu dan FAB overlay. Jangan otomatis menghapus legacy yang dipakai role2. |
| `lib/screens/detail_wisata_screen.dart` | Detail destinasi menggunakan gallery, fasilitas, map, ulasan; `_bookingBar` dapat membuka `DaftarKunjunganScreen` dan top action favorit. | Tambah parameter eksplisit (`adminPreview` atau enum mode) dengan **read-only guard** di semua action. Pertahankan default visitor behavior role0. |
| `lib/screens/tambah_wisata_screen.dart` | Existing create/edit, gallery editor, optimistic/version guard. | Reuse untuk Tambah, Ubah Informasi, dan Kelola Galeri (langsung section/anchor jika feasible). |
| `lib/screens/kelola_kuota_screen.dart` | Existing kuota. | Reuse via destination GUID; jangan membuat kuota editor baru. |
| `lib/data/business_repository.dart` | `Destination` punya `images` dengan `sequence`, harga, fasilitas, rating, lokasi/koordinat, category, status. | Data utama dari API. Gunakan sorted gallery cover pertama; fallback image ketika tidak tersedia. Tidak hardcode Horeg Mini/Pantai. |
| `lib/widgets/operations_chrome.dart`, `lib/theme/app_colors.dart` | Scenic/theme role1 terkini. | Reuse Plus Jakarta Sans, dynamic 4-period scenic; jaga card compact dan aksesibilitas. |
| `test/operations_*`, `test/admin_*` | Baseline existing, termasuk regression. | Tambah tests V3 terarah; jangan rusak scope scanner/role0/role2. |

**Arsitektur minimal yang disarankan:** widget `AdminDestinationManageHub` yang terpisah, bila perlu, menerima repository/session sebagai dependency dan membuka `DestinationAdminActionsSheet`; jangan menyalin ratusan baris `DaftarWisataScreen` ke `operations_reports.dart`. Bila refactor kecil dari existing lebih bersih, pilih diff paling sedikit yang aman.

## 5. UX contract rinci

### 5.1 Navigasi

`BottomNav Destinasi` → `Kinerja Destinasi` → segmented `Kinerja | Kelola` → **Kelola**.

- Segmen **Kinerja** tetap menampilkan metrik operasional, filter periode dan kapasitas yang bersumber dari Laravel, tak dibelokkan untuk CRUD.
- Segmen **Kelola** menampilkan: heading `Destinasi Saya`, jumlah destinasi *hanya bila berasal dari metadata dataset sesuai scope*; tombol `Tambah`, kolom pencarian, filter `Semua/Aktif/Nonaktif`, daftar destinasi ringkas.
- Tambahan kategori bisa menjadi filter opsional sesuai data; tidak perlu menambah chip dekoratif jika tidak diperlukan untuk daftar pendek.
- Buka `Preview` atau sheet `Kelola` tidak otomatis mengubah status/search/page, dan back mengembalikan ke posisi daftar yang masuk akal. Setelah mutasi berhasil, refresh data dari server; jika destinasi hilang dari filter, jelaskan state secara wajar.
- Perubahan scope/role melalui `sessionChanges` menghapus data privat yang tidak lagi berhak ditampilkan; jangan mempertahankan preview/private card stale. `403/404` harus diperlakukan sebagai perubahan akses ketika relevan.

### 5.2 Card destinasi compact

- Surface putih radius 14–20dp, border halus, padding 12–16dp, thumbnail sekitar 72–88dp kotak, informasi ditata maksimum dua-tiga baris, lalu area bawah status/tindakan.
- Teks: nama, lokasi terpotong wajar, harga IDR, status aktif/nonaktif; Plus Jakarta Sans, warna produk yang disetujui; contrast dan 44–48dp tap targets.
- Gambar cover dari **image pertama setelah `sequence` sorting**/thumbnail API; jika null/404 gunakan placeholder netral. Jangan menempel label konflik galeri ke thumbnail atau diam-diam menutup konflik; verifikasi apakah screenshot `Galeri telah berubah` memang konten gambar ter-upload, galeri stale overlay, atau media invalid.
- **CTA `Preview` (ikon mata + label) dan `Kelola` (ikon pengaturan + label)** harus berbeda secara semantik. Tidak ada `>` yang membuka detail publik, gesture card tersembunyi, atau tombol edit/hapus overlay di atas foto.
- Jika loading/busy, disable hanya aksi relevan dan berikan state. Tidak membuat loading tak berakhir di offstage.

### 5.3 Bottom sheet tindakan admin

- Header `Kelola {nama}`, subtitle `Pilih tindakan untuk destinasi ini` dan close/back yang jelas, safe area + keyboard + screen reader.
- Baris: `Preview Pengunjung`; `Ubah Informasi`; `Kelola Galeri`; `Kelola Kuota`; separator; `Nonaktifkan` atau `Aktifkan Kembali` (label jelas hasil sebenarnya). Jika backend memang melakukan delete, pastikan label+konsekuensi benar; repo saat audit memakai `deactivateDestination` / `reactivateDestination`.
- `Kelola Galeri` membuka/scroll ke editor galeri existing, **jangan** mengulang penyimpanan/upload/reorder/locking; preserve gallery_version, max 10, min 1, ukuran file dan atomic save sesuai current implementation.
- Konfirmasi destruktif wajib; saat denied/409/error tetap di state aman. Double-tap/idempotency, pending mutation, existing guard harus dihormati.
- Setelah aksi sukses, tutup sheet dan refresh list; jangan navigasi berlapis ke empat daftar mode lama.

### 5.4 Preview Pengunjung — aturan read-only NON-NEGOTIABLE

- Entry `Preview` dari card dan dari sheet menggunakan route khusus Admin, dengan mode eksplisit `adminPreview: true` pada existing detail atau wrapper yang memaksa read-only di bawahnya. **Tidak** menggunakan nav publik tanpa flag.
- UI pengunjung yang dipertahankan secara visual: gallery/carousel swipe, detail nama/rating, lokasi, harga, deskripsi, fasilitas, OSM map preview bila data koordinat valid, ulasan **hanya membaca**, dan status nonaktif yang jujur.
- Tampilkan petunjuk nonintrusif `Mode Pratinjau · Tidak dapat melakukan pemesanan` (atau padanan jelas). CTA `Daftar Kunjungan` boleh **tampak disabled**, atau diganti label `Hanya pratinjau`; **jangan** ada callback yang memanggil `DaftarKunjunganScreen`.
- Nonaktifkan/hilangkan **semua mutation capabilities**: toggle favorit, booking, review submission, check-in, payment, upload, dan apa pun yang bisa menulis. Tidak cukup membuat tombol berwarna abu-abu sementara `onPressed` masih tersambung. Screen reader juga harus melaporkan disabled.
- `Lihat Semua` ulasan dapat membuka **read-only** viewer jika komponen mendukung pemisahan `canWrite`; bila tidak, tampilkan informasi tanpa route ke form. `Lihat Peta` dan Google Maps external CTA di preview default **tidak melakukan navigasi eksternal**, sesuai wireframe V3; konten peta embedded tetap dapat dipreview tanpa perubahan data.
- **Asal data:** gunakan `BusinessRepository` dengan session Admin dan GUID destinasi yang dipilih, cek assignment/scope di API. Jangan memaksa autentikasi visitor/role0 atau membuat sesi kedua. Jika endpoint detail publik menolak destinasi nonaktif, gunakan endpoint admin detail yang authorized **bila tersedia**; jika tidak, tampilkan state `Preview belum tersedia untuk destinasi nonaktif` tanpa fake data. Tidak menambah bypass backend.
- Respons error/loading/null, offline, stale-session dan destination mismatch: jangan render data lama dari destinasi sebelumnya. Back kembali ke kelola; filter tetap ada.

### 5.5 Create/Edit/Galeri/Kuota

- `Tambah` → `TambahWisataScreen` create (validasi existing). `Ubah Informasi` → existing edit mode. `Kelola Galeri` → reuse gallery section dari editor (jangan buat API upload baru). `Kelola Kuota` → `KelolaKuotaScreen` sesuai GUID.
- Perubahan cover, nama, harga dan fasilitas ditampilkan setelah **re-fetch** dari Laravel; Preview tidak menampilkan simulasi lokal sebagai committed data.
- Optimistic lock/409 gallery_version dan replay policy mutasi tetap sama. Konflik galeri jangan disembunyikan hanya untuk tampilan.

## 6. Visual, accessibility, dan navigasi

- Theme `AppColors.operationsTheme` / Plus Jakarta Sans; gunakan `OperationsScenicHeader` atau composable header 4-periode (`05/11/15/19`). Jangan mengubah global `main.dart` theme atau role2 theme tanpa bukti.
- Background `#F5F8FD`, navy `#102D59`, biru `#1976D2`; metadata normal target contrast WCAG >= 4.5:1 saat digunakan pada foreground/background final. Gunakan status color untuk arti, bukan dekorasi.
- 360×800 dan 393×852 minimum, text scale 1.0/1.3, keyboard open, long names/price, safe area, screen-reader semantics, hit target. Scroll dan bottom sheet tidak boleh tertutup floating nav.
- Refresh melalui swipe-down top; tanpa explicit refresh icon. Beri empty/error states sesuai API, bukan dummy `0` yang mengesankan data asli.

## 7. Test plan dan acceptance gates

**Izin QA terbaru:** targeted `flutter analyze`, `flutter test`, widget/functional tests, emulator render dan regression diizinkan. Tetap batasi pada risiko V3, dan backend production mutating E2E **tidak diizinkan**. MockClient/fixture sintetis digunakan untuk mutations; sandbox terisolasi boleh jika benar-benar dikonfirmasi.

| ID | Kasus pengujian | Bukti PASS |
|---|---|---|
| V3-01 | role1 tab Destinasi → Kinerja/Kelola | Switch bekerja, state retained, Kinerja lama tidak berubah |
| V3-02 | daftar role1 dengan 0/1/multiple destination + pagination | Assigned-only, tidak memotong data, count jujur |
| V3-03 | search, status, optional category, reset, back | Query API/filter benar dan state kembali utuh |
| V3-04 | tap blank area / formerly `>` | Tidak membuka Detail Wisata / route tak terduga |
| V3-05 | `Preview` CTA card | Membuka **read-only preview**, bukan route visitor biasa |
| V3-06 | `Kelola` CTA card | Bottom sheet membuka menu spesifik destination GUID |
| V3-07 | sheet `Preview`, `Ubah`, `Galeri`, `Kuota` | Route/action benar; layar editor lama direuse |
| V3-08 | status aktif/nonaktif + cancel/confirm | Backend semantics sesuai deactivate/reactivate, tidak hard delete sembarang |
| V3-09 | preview gallery swipe, info, fasilitas, peta, ulasan, price | Bind data Laravel; null/empty/error tidak crash atau fake |
| V3-10 | mutation di Preview | 0 calls untuk booking/favorite/review/check-in/payment/external launch; disabled semantics benar |
| V3-11 | session role/assignment revoke while Preview open | Private state invalidated, aksi disabled/route keluar aman |
| V3-12 | image missing/conflict gallery | Fallback masuk akal; optimistic lock dan conflict tetap tampak semestinya |
| V3-13 | edit/gallery/quota success then back | Server re-fetch & list sync, tidak mengandalkan local mock |
| V3-14 | viewport & accessibility | 360/393, text scale 1.3, contrast/overflow, modal safe-area, keyboard/back |
| V3-15 | regressions role0/role2 | Role0 detail booking/favorite normal; role2 management/scanner tidak berubah |
| V3-16 | scanner D-003 existing failures | Dilaporkan sesuai kenyataan, tidak dihapus/skip; jangan otomatis menyatakan release ready |

**Suggested existing tests:** `test/operations_reports_test.dart`, `test/operations_shell_test.dart`, `test/operations_post_relayout_test.dart`, `test/admin_widget_test.dart`, `test/admin_destination_form_test.dart`, `test/smart_ticket_test.dart`, `test/operations_scanner_scope_regression_test.dart`, `test/unified_routing_test.dart`, ditambah file V3 targeted baru bila diperlukan. Pilih test entrypoint aktual, bukan helper.

**Release judgment:** Pengujian V3 bisa PASS sementara release global tetap **BLOCKED** bila scanner D-003 masih gagal atau Android Admin E2E belum diuji. Pisahkan implementasi V3 dari penandatanganan release global. Jangan melemahkan test untuk membuat hasil hijau.

## 8. Strategi implementasi yang minim risiko

1. `git status --short`, `git rev-parse HEAD`, inspect diff. **Jangan** reset/rebase/force-pull. Jika HEAD lokal sudah melampaui baseline remote, audit delta dan implementasi pada source aktual; jangan menghapus commit/perubahan pengguna.
2. Read `AGENTS.md` hierarchy, `C:\Users\itsba\.codex\Agents.md`, agents configs dan skill SKILL.md yang ditemukan. Maksimal **dua subagent** plus main orchestrator.
3. Identifikasi jalur duplicate management dari `operations_reports.dart` dan `daftar_wisata_screen.dart`. Tentukan widget/shared repository reuse dengan diff minimum.
4. Implement tab Kelola + compact cards + searchable/filter lists + sheet. Tidak merusak kinerja metrics dan role2 view.
5. Implement Preview read-only di component boundary dan seluruh action points; uji deny paths dan session invalidation.
6. Hook existing editor/galeri/kuota/status, handle re-fetch and 409; conditional extras only if already supported.
7. Targeted format/analyze/tests, visual screenshot emulator bila tersedia, QA report dan defect list. Jangan claim PASS untuk coverage yang tidak dijalankan.
8. Tidak commit/push otomatis; laporkan touched files, command/result, screenshot path, leftover blockers, dan completion summary.

## 9. Paket hasil yang harus diserahkan Codex

- Source Flutter updated, tanpa HTML sebagai runtime.
- Test V3 baru/diperbarui yang gagal jika routing preview berubah jadi booking biasa.
- `docs/implementation/ADMIN_Kelola_Preview_V3_HANDOFF.md` (actual files, UI flows, validasi API/role, batasan).
- `qa/admin-role1-kelola-preview-v3/QA_REPORT.md` dan `DEFECTS.md`, bukti screenshot hanya jika device tersedia. Status test per gate harus factual.
- `SKILLS_USED.md` (skill terpasang, path, manifest dibaca dan hasil), subagent yang benar-benar dijalankan.
- Final `git status --short`, `git diff --check`, daftar file modifikasi. **Tanpa auto commit/push.**

---

**Ringkasan fixed design:** satu daftar, dua CTA, satu sheet tindakan, satu preview pengunjung read-only. Flutter nyata dari Laravel, reuse existing edit/galeri/kuota, tanpa memodifikasi bisnis role0, role2, atau scanner.
