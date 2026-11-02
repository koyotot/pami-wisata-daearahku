# PRD — Massive Flutter UI/UX Redesign Wisata Daerahku (Wireframe V4)

**Status:** FINAL APPROVED DESIGN / READY FOR FLUTTER IMPLEMENTATION (integration caveats below)  
**Tanggal:** 2 November 2026  
**Produk:** Wisata Daerahku — Flutter Android, user role `0`  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Acuan wajib:** `docs/DESIGN.md`, wireframe interaktif V4 yang telah disetujui pengguna, source Flutter paling mutakhir, dan handoff `docs/flutter-business-integration-phase-1-2-3.md`  
**Pemilik implementasi:** `flutter_engineer` (gunakan konfigurasi agent lokal/global yang benar-benar tersedia; verifikasi `.codex/agents/flutter_engineer.toml` bila ada)  
**Design review:** `design-taste-frontend` dan/atau mobile taste skill yang **benar-benar terpasang/tersedia**; jangan mengklaim skill dijalankan apabila tidak ditemukan.  
**Batas keras:** **Tidak mengubah repository, endpoint, skema, aturan bisnis atau source Laravel.** Tidak menghapus/mengulang fase integrasi Flutter yang sudah selesai. Tidak melakukan commit/push/deploy kecuali diminta secara terpisah.

---

## 1. Executive Summary

Redesign menyatukan pengalaman pengunjung menjadi aplikasi wisata modern dan konsisten, mengikuti estetika biru yang sudah dipakai user-facing Flutter dan **seluruh 7 poin approval wireframe V4**. Fokus: floating bottom navigation lima menu; Beranda dan Jelajah yang tidak redundan; Detail Wisata yang bebas flash hijau; Daftar Kunjungan dengan input telepon internasional berbendera dan kalender berwarna pada angka tanggal; Riwayat berbentuk kartu tiket expandable; tab Notifikasi; dan dashboard Profil yang baru.

Kriteria keberhasilan bukan hanya tampilan. Navigasi, state, API, business flows, validasi, format E.164, kuota bulanan, idempotensi, session guard, notifikasi, dokumen PDF, review/check-in, dan hak akses harus tetap berjalan. **Desain V4 adalah referensi visual, bukan sumber data atau kontrak backend.** Foto, nama demo, angka statistik, tanggal, kuota, progres tiket dan unread count pada prototype tidak boleh dibawa sebagai hardcode produksi.

### 1.1 Urutan otoritas
1. Aturan bisnis, security dan kontrak respons nyata dari Laravel dan source Flutter terkini.
2. Keputusan produk yang telah disetujui pada V4 dan koreksi terakhir pengguna.
3. `docs/DESIGN.md` sebagai audit historis palet, tipografi, komposisi, pola visual; **bukan** dokumentasi backend terkini atau token otomatis yang sudah aktif.
4. Komponen desain hasil inventarisasi saat implementasi. Jika bertentangan, dokumentasikan keputusan teknis dan jangan merusak alur lama.

### 1.2 Goals dan non-goals
**Goals:** hierarki informasi lebih jelas; navigasi ibu jari yang ergonomis; layar edge-to-edge yang konsisten; input booking lebih mudah; status booking mudah dipahami; reuse komponen; aksesibilitas dan regression safety.  
**Non-goals:** redesign autentikasi, Admin/Superadmin, migrasi data, pembuatan endpoint notifikasi baru, payment gateway, refund, QR tiket legacy, pergantian arsitektur state-management, rekonstruksi `BookingIntent`, perubahan Firebase/FCM integration, atau refactor total Flutter yang tidak perlu.

## 2. Design Foundation — wajib lintas layar

| Token semantik | Arah V4 | Catatan |
|---|---|---|
| Primary Blue | `#1976D2` | Navigasi/CTA utama |
| Deep Blue | `#1558B0` | Gradien/hierarki |
| Navy | `#102D59` | Teks/heading |
| App Background | `#F5F8FD` | Scaffold, overlay transisi |
| Muted | `#728099` | Metadata/sekunder |
| Border | `#DCE4F0` | Divider/input/card |
| Orange | `#FF9800` | Accent, harga, notification badge |
| Green / Yellow / Red / Grey | Semantik status saja | Kalender/status transaksi, **bukan** scaffold atau page transition |
| Tipografi | Plus Jakarta Sans | Konsisten di user app; jangan kembali ke serif Georgia dari tema global historis |

**Komponen wajib:** token/ThemeExtension/ThemeData yang dipakai nyata, floating nav shared, `AppPageScaffold`/surface helper secukupnya, destination card, visual status badge, section heading, phone field, calendar day, ticket card, async content state, bottom CTA. Hindari duplikasi nilai manual antar layar. Tetap pertahankan role-based auth UI di area terpisah.

**Edge-to-edge / system UI:** status bar Android transparan dengan ikon yang memiliki kontras benar; background konten menggambar sampai belakang area status bar sesuai layout; navigasi sistem tidak memperlihatkan strip asing. Hormati `MediaQuery.padding`, `SafeArea`, gesture navigation, keyboard inset, orientation dan text scale. Floating nav punya clearance untuk gesture bar; bottom CTA menggunakan inset yang sama. **No green flash** saat masuk Horeg Mini/detail/booking ataupun pop: periksa `MaterialApp ThemeData`, `Scaffold` background, `PageRouteBuilder`/`MaterialPageRoute`, `Hero` flight, loading placeholder, statusBarColor dan layer transisi. Harus bertema biru/putih senada sejak frame pertama. Gunakan transisi ringkas, konsisten; reduced motion non-animasi.

**Mobile UX:** touch target disarankan minimal 44–48 logical px; kontrol dapat diakses screen reader; contrast teks/status memadai; warna tak menjadi satu-satunya penanda; widget scrollable saat keyboard terbuka; state loading/empty/error/retry disediakan, tidak boleh overflow di perangkat sempit 320–360dp maupun text scale besar.

## 3. Navigation & Information Architecture — APPROVED

**Bottom floating bar berurutan:** **Beranda — Riwayat — Jelajah — Notifikasi — Profil**.

- **Jelajah di tengah** adalah *primary hook*: ikon **kompas**, tombol elevated biru sedikit lebih tinggi, label tetap "Jelajah".
- Bell milik Notifikasi ada di posisi keempat. **Unread count berupa bubble oranye `#FF9800` menempel pada sudut kanan atas glyph Bell sendiri**: secara layout `Stack(clipBehavior: Clip.none)` pada container ikon Bell dan `Positioned(top: -5, right: -7)` sebagai titik awal yang boleh disesuaikan visual; badge **bukan** di sudut tab, atas label, tepi nav, atau di bawah Bell. Tampilkan `1`–`99`, `99+` untuk angka lebih besar; `0` = badge tidak dirender; accessibility label membaca jumlah unread. Warna teks badge putih. Angka harus berasal dari state yang tepercaya, tidak boleh ditulis `2` secara konstan.
- Dock float di atas konten, surface putih/translucent blur dan shadow lembut; hargai gesture inset perangkat dan keyboard. Tab aktif punya state jelas tanpa jump layout.
- Drawer/sidebar lama untuk User digantikan/diadaptasi, **bukan** membuat dua navigasi primer berulang. Kelola drawer admin tidak masuk scope.
- Lima tab hanya pada **root tab screens**. Detail Wisata: sticky CTA "Daftar Kunjungan" dan back. Booking: sticky CTA "Konfirmasi Pendaftaran" dan back. Layar konfirmasi, sheet, detail tiket serta dialog mengikuti hierarki konteks.
- Pindah tab mempertahankan state berharga (filter/pencarian/scroll sesuai kebutuhan); back Android dari tab bukan pertama kembali ke Beranda; tidak menyebabkan navigasi bertumpuk/duplikasi. Deep links/notifikasi hanya menuju target yang tervalidasi dan sesuai role/session.

**Flow utama:** `Beranda / Jelajah → Detail Wisata → Daftar Kunjungan → Konfirmasi → Riwayat → Detail Tiket` dengan `Notifikasi → tiket spesifik` saat tersedia. Profil adalah tab mandiri (fav, review, setting). Tidak ada keharusan menjalankan flow secara linear.

## 4. Functional Requirements & Acceptance Criteria

### FR-01 — Beranda
- Pertahankan branding, greeting sesuai user sebenarnya, statistik dari server, search, kategori dinamis, destinasi populer dari state katalog.
- Kartu wisata responsive: gambar `ApiImage`/placeholder, nama, lokasi, kategori, harga jika ada, CTA tap untuk detail. Jangan seed/hardcode Horeg Mini/Kuliner demo.
- Search/kategori reuse `CatalogState`/API server; loading, network error, empty query dan filtered-empty dibedakan.
- **AC:** tapping card membuka ID/GUID destinasi yang benar; rerender tidak menduplikasi request atau kehilangan pencarian tanpa alasan.

### FR-02 — Jelajah
- Halaman utama dari tombol kompas; eksplorasi semua destinasi dengan pencarian/filter kategori yang disediakan server, bukan salinan statis Beranda.
- Pilihan grid/list jika tersedia dapat dipertahankan; lazy load/pagination/dedupe; empty/search reset; kembali ke tab mempertahankan query secara wajar.
- **AC:** tombol tengah selalu menuju Jelajah dan tetap tampil elevated; hasil filter sesuai data API.

### FR-03 — Detail Wisata dan transisi bebas flash hijau
- Hero image, nama, lokasi, jam operasional, kategori, deskripsi, harga, favorit, **fasilitas dinamis persis dari API**. Daftar fasilitas kosong ditampilkan sebagai empty state jujur, **tanpa fallback Parkir/Toilet hardcoded**.
- Sticky CTA `Daftar Kunjungan`, safe-area-aware; favorit tetap memakai API/favorite state; loading/gagal gambar dan fetch tidak memunculkan overlay hijau.
- **AC:** Home/Jelajah → Horeg Mini → Detail terlihat kontinu pada rekaman frame-by-frame; tidak ada frame hijau/warna tema lama; back ke source tab yang sesuai.

### FR-04 — Daftar Kunjungan: Form identitas dan country picker
- Satu **combined phone field**: **`🇮🇩 +62 ▾ | 896-5586-2781`** (contoh Indonesia), bukan dua input terpisah. Flag nasional harus sesuai negara masing-masing dan tampil **di prefiks terpilih dan pada tiap opsi country picker**; jangan gunakan ikon globe generik. Untuk negara/locale yang tidak mendukung emoji flag secara konsisten, gunakan fallback aset bendera valid dengan ISO country code yang benar.
- Country picker berupa searchable modal bottom sheet dengan daftar negara, bendera, nama, dial code, selected state, keyboard management. Default negara masuk akal (Indonesia), tetapi dapat diganti.
- Placeholder hanya nomor lokal menurut metadata negara. Pemisah/divider vertikal memisahkan prefiks dan teks yang diinput. Format saat mengetik berdasarkan metadata negara, tidak hardcode `3-4-4` lintas negara.
- **Reuse** `lib/widgets/international_phone_field.dart` dan `phone_numbers_parser`; lakukan validasi/normalisasi ke **E.164** sebelum submit (`+6289655862781`). Jangan merusak pemetaan `422 fieldErrors.visitor_phone`, fokus/inline error, atau kehilangan data saat validation failure. Country change mesti menyelaraskan parser/nomor tanpa menghasilkan prefix ganda atau diam-diam mengirim nomor salah.
- Nama/email sesuai session dari backend; pesan validasi dekat field; jangan mencatat nomor lengkap/email/token di log.
- **AC:** 🇮🇩/+62 dan 🇯🇵/+81 menunjukkan flag yang berbeda; dropdown searchable; nomor tersimpan tepat E.164; 422 menempel pada input telepon tanpa menghilangkan state draft.

### FR-05 — Kalender Kunjungan dan kuota
- **Reuse** `lib/widgets/availability_calendar.dart` dan kontrak existing `GET /destinations/{guid}/availability?month=YYYY-MM&quantity=N`; server memutuskan `status`/`bookable`, tanggal dan kapasitas. Jangan menghitung status berdasarkan `date % n` seperti prototype.
- **Warna diterapkan langsung pada angka/tile tanggal** dan ada legenda teks: hijau = Banyak tersedia, kuning = Terbatas, merah = Hampir penuh, abu-abu = Tidak tersedia. Selected day memiliki outline/kontras jelas **tanpa menghapus semantik kuotanya**. Legenda harus selalu terlihat dan tidak hanya mengandalkan warna.
- Hari non-bookable disabled dan bisa menjelaskan alasan jika API menyediakannya; tanggal dipilih dan kuantitas harus valid sebelum submit. Waktu/jam kalender ditentukan timezone destinasi, bukan UTC atau timezone device secara buta.
- Request stale guard saat bulan, destination, quantity, atau session berubah; loading/error/retry state eksplisit; refresh setelah konflik kuota.
- **AC:** perubahan jumlah mengirim permintaan availability terbaru, hasil respons bulan lama tak mengganti bulan sekarang; tanggal tidak bookable tidak bisa di-submit; 409 menginvalidasi pilihan dan mengikuti reconciliation yang ada.

### FR-06 — Submit dan konfirmasi booking (non-regression)
- Menampilkan summary destinasi, data pengunjung, catatan, jumlah tiket, estimasi total sesuai sumber server/model yang ada, CTA disabled/loading tepat.
- Tetap menggunakan `BookingIntent` existing yang menyimpan **payload asli + `Idempotency-Key` asli** untuk retry/reconcile, termasuk error uncertain outcome. Jangan membuat request booking ganda dari double tap/navigation/rebuild dan jangan mengubah backend/kontrak.
- Sesudah booking confirmed via server/reconciliation, buka layar hasil yang benar dan Riwayat dengan GUID sesungguhnya. Jangan menyatakan “berhasil” hanya karena animasi selesai. Pertahankan 409/422 dan kegagalan jaringan.
- **AC:** retry unknown outcome memakai key/payload sama; tidak ada duplicate POST dengan key baru; race condition/409 tetap terlindungi.

### FR-07 — Riwayat Pendaftaran (redesign tiket)
- Header baru, statistik Diproses/Disetujui/Ditolak dari data sebenarnya dan filter Semua/Diproses/Disetujui/Ditolak (opsional Dibatalkan). Statistik **tidak hardcoded**.
- Kartu tiket berbentuk visual tiket dengan identitas tempat, **kode booking yang dapat disalin**, status badge + teks, tanggal, nama, telepon, jumlah; tombol **Lihat detail tiket** expandable.
- Detail mengandung langkah status aktual (jangan membuat progress fiktif), email, catatan, total yang valid, dokumen invoice/ticket PDF **hanya apabila benar-benar tersedia**, check-in/review bila diizinkan server. **Invoice bukan bukti pembayaran**; QR lokal lama tidak boleh dibangkitkan lagi.
- Status sumber: gunakan enum/status aktual API, termasuk `pending_approval`, `awaiting_payment`, `payment_review`, `approved`, `rejected`, `cancelled` bila ada; UI label dipetakan secara aman (unknown status fallback netral dengan teks yang tidak menyesatkan). **Pembatalan hanya apabila `pending_approval` dan backend mengizinkan**, bukan semua status "diproses". Konfirmasi aksi sebelum mutation dan handle errors.
- API `BookingState`/repository dipertahankan; detail tiket tertentu bisa dibuka dari notifikasi yang memuat GUID yang valid; paginasi/refresh, session guard dan retry harus tetap berjalan.
- **AC:** membuka/menutup satu kartu tidak memengaruhi kartu lain; pembatalan tidak ditampilkan pada `payment_review`; dokumen yang belum ada tidak dipalsukan.

### FR-08 — Notifikasi (tab keempat, bukan FAB tengah)
- Halaman UI khusus dengan judul, daftar aktivitas, filter `Semua` / `Belum dibaca`, empty/error/loading, dan opsi `Tandai semua dibaca` **hanya jika data source dan mutation nyata mendukungnya**.
- Saat notifikasi terkait booking ditekan, navigasi menuju detail tiket berdasarkan **booking GUID yang benar** dan setelah verifikasi session/role. Hindari navigasi langsung menggunakan payload FCM tanpa validasi.
- **Critical integration gate:** README repository masih menyatakan belum ada inbox notifikasi aktif; FCM saat ini mendaftarkan perangkat dan menampilkan SnackBar foreground. Sebelum implementasi real badge/inbox, **audit kontrak Laravel yang sudah tersedia** (misalnya endpoint inbox, unread count, mark-read) dan implementasi Flutter yang sudah ada. **Tidak boleh mengarang endpoint, count, atau status baca**, dan **tidak mengubah Laravel**.
- Bila API inbox yang kompatibel **sudah ada**, gunakan via repository/state dan implementasikan penuh; jika **belum ada**, buat navigasi/screen shell dengan pesan empty/availability yang jujur, tidak menampilkan jumlah unread palsu, tidak menandai read secara fake, catat dependency sebagai **OPEN/BLOCKED untuk integrasi notifikasi nyata**. FCM push tetap berjalan seperti sebelumnya, jangan simpan PII/sinkronisasi inbox hanya di device yang tampak seperti data server permanen.
- **AC:** posisi badge melekat pada sudut kanan-atas ikon Bell pada semua ukuran/scale; count = 0 hilang; tab bukan elevated; tidak ada angka demo di produksi; tidak ada API baru diam-diam.

### FR-09 — Profil Saya
- Kartu identitas user dengan avatar/inisial, **nama asli** (bukan email dipakai sebagai nama kecuali benar-benar nilai user), email, CTA Edit Profil; statistik Pendaftaran, Dikunjungi, Ulasan, Tahun Bergabung dari `GET profile/statistics`/data akun tersedia; graceful placeholder `—` saat belum tersedia, bukan angka palsu.
- Wisata Tersimpan memakai `FavoriteState`; menu Riwayat Ulasan, Notifikasi (membuka tab), Bahasa (sesuai capability yang ada), Ubah Password, Tentang Aplikasi, Hapus Akun, Keluar. Reuse aksi otentikasi dan sheet yang sudah berfungsi.
- **Ubah Password dan Hapus Akun belum tersedia menurut README**. Jangan membuat flow sukses palsu: tampilkan disabled/"Belum tersedia" atau informasi fitur, tanpa mutasi fiktif. Bahasa/notifikasi preference lokal tidak boleh diklaim tersinkron ke backend.
- Logout harus membersihkan sesi dengan flow existing, tidak hanya pindah layar; handling error & session-generation tetap berlaku.
- **AC:** profil user A tidak sempat muncul pada user B setelah logout-login; favorit dan statistik update dari server; actions unsupported transparan.

## 5. UX States, Motion, A11y & Security

Setiap screen/komponen async memiliki loading, content, empty, failed/retry dan session-expired behavior. Error disampaikan dekat aksi dan dapat dipulihkan; tidak menutup form yang sedang diisi tanpa alasan. Tidak ada double submit, auto-scrolling yang agresif, animasi berlebihan, ataupun overlay menutupi status/gesture bar. Hindari `mounted` violations dan refresh lama overwrite request baru. Hormati high text scale, TalkBack, minimum tap area, keyboard, contrast, reduced motion, dan view 320–430 logical dp. Jangan memasang `Hero` tag yang konflik pada grid/list.

**Security invariant:** data/akses selalu dari sesi role 0, bukan state tab; profile/contact PII tidak dicatat ke analytics/debug; session generation guard di callback async; Firebase hanya Google Sign-In + FCM; tidak menambah Firestore/Storage sebagai business source; HTTP API menggunakan `AuthSession`/`ApiClient` existing.

## 6. Kandidat File Flutter (berdasarkan struktur repository)

> Ini adalah **candidate impact map**, bukan instruksi mengubah semuanya tanpa kebutuhan. `git status`, isi file aktual, dan konfigurasi agent lokal diperiksa kembali sebelum edit. Path baru di bawah bersifat usulan.

| Area | File eksisting utama | Kemungkinan komponen baru / tindakan |
|---|---|---|
| Root navigation | `lib/screens/main_navigation_screen.dart` | `lib/widgets/floating_bottom_nav.dart` (baru); kurangi drawer user, jaga route/back/tab state |
| Beranda | `lib/screens/beranda_user_screen.dart` | destination card/shared section components bila layak |
| Jelajah | `lib/screens/cari_wisata_screen.dart` | reuse catalog filters/pagination |
| Detail | `lib/screens/detail_wisata_screen.dart` | dynamic facility badges, transition fix |
| Booking | `lib/screens/daftar_kunjungan_screen.dart` | reuse phone field/calendar, sticky CTA |
| Phone | `lib/widgets/international_phone_field.dart` | **redesign existing**, flag + search picker; preserve metadata/parser |
| Calendar | `lib/widgets/availability_calendar.dart` | **redesign existing**, semantic day styling; preserve API guards |
| Riwayat | `lib/screens/bukti_pendaftaran_screen.dart` | `lib/widgets/booking_ticket_card.dart` (opsional), detail/expand UI |
| Konfirmasi | `lib/screens/bukti_konfirmasi_screen.dart` (jika masih dipakai) | UI polish only; no legacy QR |
| Profil | `lib/screens/profil_user_screen.dart` | compose identity/metrics/settings, preserve actions |
| Notifikasi | `lib/screens/notifikasi_screen.dart` (usulan) | `lib/data/notification_state.dart` **hanya jika kontrak inbox ada** |
| Global theme | `lib/main.dart`, `lib/theme/app_colors.dart` | ubah user scheme/transitions secara terukur, **jangan regresi auth/admin** |
| Shared | `lib/widgets/`, `lib/data/{catalog_state,favorite_state,booking_state}.dart` | minimalkan perubahan data; no rewrite kontrak |
| Session, FCM | `lib/screens/session_destination.dart`, `lib/services/fcm_device_manager.dart`, `lib/services/auth_session.dart` | audit/integration only, ubah bila benar-benar perlu dan no behavior regression |
| Tests | `test/` | widget golden/layout/navigation/booking tests baru sesuai cakupan |
| Dokumentasi | `docs/prd/PRD-Wisata-Daerahku-Massive-Flutter-UIUX-Redesign-V4.md` | PRD ini dan handoff implementasi |

**Catatan:** Handoff Phase 1–3 telah menambahkan `lib/widgets/international_phone_field.dart`, `lib/widgets/availability_calendar.dart`, serta `phone_numbers_parser` dan `timezone`. Jangan kembali ke versi pre-Phase-1–3 dari `docs/DESIGN.md` yang masih mencatat Firestore. Path agent `.codex/agents/flutter_engineer.toml` kemungkinan berasal dari workspace lokal, bukan direktori yang berhasil diverifikasi pada publik GitHub; verifikasi sebelum menjalankan agent.

## 7. Design Workflow & Agent Instructions

1. **`flutter_engineer` adalah pelaksana utama.** Sebelum edit baca `docs/DESIGN.md`, README, `docs/flutter-business-integration-phase-1-2-3.md`, seluruh screen utama, widget, state, model dan tes relevan.
2. **Gunakan `design-taste-frontend` / mobile taste skills yang tersedia** untuk visual hierarchy, spacing, typography, compositional consistency, interaction/keyboard/safe-area review. Jika skill tidak ditemukan, tulis "not available" di handoff dan pakai prinsip yang dijabarkan PRD; jangan mengarang output skill.
3. Gunakan agent pengujian/review (`qa_engineer`, `security_auditor`, `system_architect`) bila tersedia dan relevan, terutama untuk kontrak API, session, idempotency dan batas backend. Tidak wajib menambah framework baru.
4. Perubahan UI melalui reusable components dan ThemeData yang memang digunakan; tidak mengubah seluruh proyek demi satu halaman. Setiap phase punya checkpoint dan review diff.
5. **Dilarang:** menyentuh repository Laravel, migrasi/seed database, mengubah endpoint/response contract, menonaktifkan session guard, mengubah `BookingIntent`, memaksa unread count dari simulasi, membuat QR legacy, mengubah layar auth yang sudah di-approve tanpa bug yang relevan.

## 8. Phasing — Implementation Plan

| Phase | Deliverables | Gate |
|---|---|---|
| P0 — Freeze & baseline | `git status`, inventory current repo/agents/skills, compile/test/analyze baseline, cek endpoint notifikasi tanpa mutasi | scope & dependency map tersimpan |
| P1 — Foundation | shared tokens/theme user-facing, edge-to-edge, flash green fix, common loading/error/CTA | transition + auth/admin no-regression |
| P2 — Navigation | floating 5-tab bar, compass center, Bell badge upper-right, back/tab state | widget/golden nav tests + a11y |
| P3 — Discovery | Home, Jelajah, Detail & facility API | catalog, favorites & facilities regression pass |
| P4 — Booking | phone country flags, searchable picker, kalender colored dates + legend, CTA | E.164, availability, 422/409/idempotency pass |
| P5 — History & Profile | tiket expandable, status, cancel guard, docs/review/check-in, identity/metrics/settings | auth/session/state tests pass |
| P6 — Notifications & polish | tab shell + real inbox integration **hanya jika existing backend contract tersedia**; no mock unread; final QA | feature graded PASS or explicitly BLOCKED by missing API |

## 9. Verification / Acceptance Gate

**Automated:** `flutter pub get`, `dart format` pada file tersentuh, `flutter analyze` (catat delta vs baseline, jangan menyamakan lint historis dengan bug baru), `flutter test`, targeted tests dan `git diff --check`. Test minimal:

1. Navbar lima tab berurutan, elevated Jelajah tengah, Bell badge anchored top-right glyph; 0/1/9/99/100 unread termasuk text scale, compact width.
2. Root/tab/detail/booking back navigation tidak duplicate, tidak menghilangkan form state.
3. Frame transition Home→Detail Horeg Mini→Booking tidak menunjukkan hijau; status/nav bars seamless.
4. Telepon: flag Indonesia/negara lain, country search, format, paste, edit, E.164, error 422 inline, keyboard/focus.
5. Kalender: empat status & legenda, selected semantics, destination timezone, month/quantity stale response, disabled dates, 409 refresh.
6. BookingIntent: uncertain response replay same payload+key; double tap = single mutation; 409 reconcile.
7. Riwayat: correct status mapping, copy code, expanded card, pending-only cancellation, PDF semantics, check-in/review eligibility.
8. Notifikasi: no fake data; unread source verified or gracefully absent; event to correct GUID and unauthorized guard.
9. Profil: stats/favorites/server data, unsupported actions honest, logout/session switching A→B no leak.
10. Screen readers, text scale 1.0/1.3/1.8, 320/360/390/430dp, keyboard, Android gesture navigation, slow network, empty/error states.

**Manual:** Android Studio emulator Pixel (API 37 tersedia), actual Android device if possible; compare screenshots against approved V4. Jangan mengklaim iOS device test jika tidak punya environment yang bisa menjalankannya. No overflow, clipped badge, keyboard-blocked CTA, non-contrast icons. Sematkan screenshot/video hasil pemeriksaan UI dan daftar selisih dari V4 pada handoff.

**Baseline caution:** dokumen handoff Phase 1–3 mencatat 54 tes tambahan pass dan satu test layout auth pre-existing gagal dalam full suite; jalankan ulang agar status aktual diverifikasi. Semua regresi baru pada file terdampak harus diselesaikan. Bedakan failure existing, skipped, warning dan error; jangan laporkan full-green bila tidak.

## 10. Definition of Done (DoD)

- [ ] 7/7 keputusan V4 terimplementasi pada User Android, tidak ada penyimpangan visual besar tanpa approval.
- [ ] Bell notification badge **tepat upper-right glyph**, label tidak bergeser, 0 disembunyikan, data tidak palsu.
- [ ] Jelajah elevated center; root tabs + detail/booking CTA sesuai arsitektur.
- [ ] Flag negara asli setiap dial code dan selector; combined field; E.164 tetap benar.
- [ ] Calendar day digits/tiles berwarna, legenda, server-bookable dan 409/race protection terjaga.
- [ ] Kartu tiket expandable, status real, pending-only cancel, docs/review/check-in tidak regresi.
- [ ] Profil menunjukkan identitas/data aktual; unsupported actions tidak disimulasikan sebagai berhasil.
- [ ] Green flash hilang di transisi; edge-to-edge, status bar, gesture safe area dan keyboard aman.
- [ ] Tidak ada modifikasi Laravel, tidak ada Firebase bisnis/QR legacy yang dihidupkan kembali.
- [ ] Full/targeted tests, analyzer delta, manual visual QA dilaporkan jujur.
- [ ] Notifikasi nyata diberi status **PASS jika existing contract tersedia**, atau **BLOCKED/DEPENDENCY jika belum**, tanpa mengarang backend.
- [ ] Dokumentasi hasil implementasi dan file tersentuh diserahkan; tidak melakukan commit/push/deploy tanpa instruksi.

## 11. Open Dependencies & Implementation Notes

1. **Notification inbox contract:** perlu audit backend read-only untuk memastikan list/unread/mark-read; README publik saat ini menyebut belum ada inbox. Frontend shell boleh dibangun, tetapi notifikasi persisten dan badge real **tidak dapat dinyatakan selesai** jika tidak ada sumber data otoritatif. Tidak ada izin untuk membuat endpoint baru.
2. **DESIGN.md is historic:** warna/hierarchy digunakan sebagai acuan; audit lama masih menyebut Firestore dan Georgia. Data aktual tetap Laravel + state/repository terkini.
3. **Agent/skill availability:** `flutter_engineer` dan mobile taste skill dipanggil dari lingkungan eksekusi yang tersedia; path TOML lokal harus diverifikasi, tidak dijamin ada pada GitHub publik.
4. **Existing feature scope:** autentikasi Android telah didesain ulang sebelumnya; global theme changes tidak boleh mengembalikan masalah auth status bar/layout. Admin/Superadmin harus tidak terpengaruh.
5. **UI prototype vs data:** tanggal, sisa kuota, statistik, harga, user identifier, status tiket dan notifikasi demo bukan fakta produksi. Semua harus mematuhi response Laravel.

## 12. References

- Repository: https://github.com/koyotot/pami-wisata-daearahku
- UI audit: https://github.com/koyotot/pami-wisata-daearahku/blob/main/docs/DESIGN.md
- Phase 1–3 handoff: https://github.com/koyotot/pami-wisata-daearahku/blob/main/docs/flutter-business-integration-phase-1-2-3.md
- Core nav: https://github.com/koyotot/pami-wisata-daearahku/blob/main/lib/screens/main_navigation_screen.dart
- Phone field: https://github.com/koyotot/pami-wisata-daearahku/blob/main/lib/widgets/international_phone_field.dart
- Calendar: https://github.com/koyotot/pami-wisata-daearahku/blob/main/lib/widgets/availability_calendar.dart
- UI approval: user-approved interactive wireframe **V4**, including later corrections on phone flags and Bell badge upper-right.

---

**Final directive:** Implementasikan redesign **UI/UX Flutter** secara bertahap dan dapat diuji, dengan source Laravel tetap utuh. Jika kemampuan yang ditampilkan di prototype belum ditopang data/endpoint aktual, jangan memalsukan keberhasilan; tandai dependency, tampilkan state jujur, dan teruskan bagian yang independen.
