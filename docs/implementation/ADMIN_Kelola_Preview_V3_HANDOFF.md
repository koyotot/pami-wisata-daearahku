# Handoff Kelola dan Preview Pengunjung V3

Tanggal: 7 November 2026. Baseline lokal `main`: `bbab5069fcc01c2e2ce6397d453d9ff000b68d6d`. Tidak ada reset, checkout, pull, commit, push, deploy, atau mutasi layanan live.

## Perubahan

Role 1 membuka Destinasi, Kinerja Destinasi, lalu Kelola untuk mengakses satu hub. Kinerja dan navigasi bawah existing dipertahankan. Hub memakai `DaftarWisataScreen(mode: 'manage', embedded: true)` beserta `PagedListController`, pencarian debounce, status server, dan mekanisme mutasi existing. Tidak ada daftar CRUD kedua atau dependency baru.

Card memuat thumbnail pertama menurut sequence, nama, lokasi, harga server, status, dan dua tombol Preview/Kelola. Area card tidak membuka route. Tambah berada di atas daftar. Sheet membawa GUID card terpilih ke Preview Pengunjung, Ubah Informasi, Kelola Galeri, Kelola Kuota, atau konfirmasi Nonaktifkan/Aktifkan Kembali.

Penyesuaian berikutnya mengikuti screenshot Kelola dari user: subtitle penugasan, pencarian ringkas, filter pill, penanda jumlah, lokasi dengan pin, harga Rp memakai `visitMoney`, divider, lalu status kiri dan tombol Preview/Kelola kanan pada footer yang sama. Footer dapat wrap saat ruang tidak cukup. Tap target48 tetap dipertahankan. `AppColors.textSecondary` dipakai untuk metadata yang lebih tenang tanpa mengubah token legacy. Fungsi route/API/read-only tetap sama. Bukti normal text scale ada di `fixture-reference-kelola-360-scale10.png`; tes terbaru22 PASS.

Filter, pencarian, dan subtree hub dipertahankan saat kembali dari route maupun berpindah segmen. Ticker hub dibisukan saat segmen Kinerja aktif. Pengambilan ulang server berjalan setelah editor mengembalikan sukses, setelah perubahan status, dan setelah kembali dari kuota. Controller existing mengambil seluruh halaman yang dilaporkan API, dengan batas existing 200 halaman. Jumlah menggunakan metadata API; bila tidak ada metadata, teks hanya menyebut jumlah dimuat. Scope change membuang dataset lama. Tidak ada klaim jumlah seluruh destinasi tanpa metadata.

## Preview dan batas akses

`DetailWisataScreen(adminPreview: true)` memakai `BusinessRepository.adminDestination(GUID)` dengan sesi Admin yang sama. Sesi harus authenticated, device ready, dan role 1. Mode default tetap visitor.

- Booking disabled secara semantik dan callback; `_book` juga menolak preview pada batas aksi.
- Favorit disembunyikan dan `_toggleSave` menolak preview. Preview tidak memasang listener atau menginisialisasi state favorit visitor.
- Embedded OSM, fasilitas, harga, deskripsi, rating, dan carousel tetap menggunakan UI detail existing. Map fullscreen dan launch directions tidak tersedia; kedua batas aksi memiliki guard.
- Carousel tetap bisa digeser. Fullscreen foto tidak dibuka dalam preview agar foto privat tidak bertahan di route terpisah setelah akses dicabut. Visitor tetap dapat membuka fullscreen.
- `ReviewsSheet` existing hanya membaca, tanpa form submit. Dalam preview, sheet memvalidasi admin detail terlebih dahulu. Perubahan sesi menghapus review lama dan memvalidasi ulang akses sebelum menampilkan hasil.
- Perubahan sesi dalam generation yang sama menghapus detail lama dan memicu validasi ulang. RequestState dan pemeriksaan revision menolak respons terlambat. Loading/error tidak memakai isi card sebagai detail fallback; header error preview juga tidak memuat nama lama.
- 403/404/409 dan GUID mismatch menampilkan error, tanpa bypass atau konten dummy. Destinasi nonaktif dapat dipreview jika endpoint Admin mengizinkan; error API tetap ditampilkan bila tidak tersedia.

## Route dan kontrak existing

| Tindakan | Implementasi |
|---|---|
| Tambah / Ubah Informasi | `TambahWisataScreen` existing dengan repository/session sama |
| Kelola Galeri | `TambahWisataScreen(initialGallery: true)` mengarah ke section galeri existing |
| Kelola Kuota | `KelolaKuotaScreen(destinationGuid: selectedGuid)` existing |
| Nonaktifkan | `deactivateDestination`: DELETE `destinations/{guid}` |
| Aktifkan kembali | `reactivateDestination`: PATCH `is_active: true` |

Semantik DELETE diperiksa read-only pada checkout Laravel lokal: `DestinationController::destroy` memanggil `adminSave(..., ['is_active' => false])`, bukan hard delete. `CatalogRequest::authorize` memeriksa assignment untuk detail Admin; `CatalogService::adminDestinations` menerapkan AdminDestinationScopeService. Ini verifikasi source lokal, bukan pengujian backend live.

Gallery manifest, gallery_version, upload, reorder, validasi, optimistic locking 409, dan idempotency existing tetap dipakai. Tidak ada perubahan booking/QR/claim/payment/schema/backend. Tidak ada bukti media live untuk menelusuri gambar yang berisi tulisan "Galeri telah berubah"; konflik API tidak disembunyikan.

## File utama

- `lib/screens/operations_reports.dart`: segmen Kelola inline, state hub dan pull-refresh.
- `lib/screens/daftar_wisata_screen.dart`: mode hub, compact card, action sheet, konfirmasi scope-safe.
- `lib/screens/detail_wisata_screen.dart`: mode preview eksplisit, endpoint Admin, invalidasi dan guard aksi.
- `lib/screens/tambah_wisata_screen.dart`: anchor galeri existing; pembenahan overflow rating/save pada text scale besar yang ditemukan lewat V3.
- `lib/widgets/reviews_sheet.dart`: validasi dan invalidasi ulasan preview.
- `lib/widgets/destination_hero_gallery.dart`: opsi fullscreen default tetap aktif untuk visitor.
- `lib/screens/operations_dashboard.dart`: menghapus import editor yang tidak digunakan.
- `test/admin_kelola_preview_v3_test.dart`: regresi V3 dan capture fixture native Flutter.

## Referensi dan desain

PRD user dibaca di `docs/prd/PRD_Flutter_Admin_Role1_Kelola_Preview_V3.md`. HTML yang tersedia bernama `docs/references/wisata_admin_interactive_wireframe_v3_preview_pengunjung (1).html`; file user dipertahankan. V3 adalah source arah flow/layout, bukan sumber data runtime. HTML tidak dimasukkan sebagai runtime Flutter.

ZIP, empat PNG kanonik, dan `README_Wireframe_Admin_V3_Preview.md` tidak ditemukan. Paket tambahan, bila disediakan, perlu diekstrak ke root repo agar file berada di `docs/previews/admin_kelola_v3_*.png` dan `docs/references/README_Wireframe_Admin_V3_Preview.md`. Pemeriksaan saat ini membandingkan source/flow dengan PRD dan HTML yang tersedia, tanpa mengklaim perbandingan PNG yang tidak ada.

`docs/DESIGN.md` adalah audit lama dengan deskripsi Firebase/tema yang sudah berbeda dari source terkini. Tema, font, komponen, warna, serta scenic 05/11/15/19 mengikuti source terkini `AppColors.operationsTheme` dan operations chrome. Tidak ada migrasi theme atau redesign role 0/2.

## Validasi dan batas serah terima

Hasil aktual, daftar command, baseline failures, dan screenshot ada di `qa/admin-role1-kelola-preview-v3/QA_REPORT.md`. Screenshot adalah render fixture widget Flutter, bukan Android Admin E2E. Foto fixture/placeholder tidak membuktikan media Laravel live.

Emulator `emulator-5554` tersedia. `.env.development` menunjukkan APP_ENV development dan host loopback; ini tidak membuktikan isolasi dataset. Sesi Admin test dan isolasi belum diverifikasi, sehingga tidak menjalankan login/mutasi live. Android Admin E2E, TalkBack/VoiceOver, dan jaringan/media aktual tetap belum diverifikasi.

Release global tetap BLOCKED oleh D-003 scanner S2 dan QA Admin perangkat. D-004 kontras legacy tetap OPEN di laporan sebelumnya. Dua kegagalan tambahan pada tes shell scanner-return dan description wrapping juga direproduksi pada HEAD baseline terpisah. Tidak ada assertion dihapus atau dilemahkan.
