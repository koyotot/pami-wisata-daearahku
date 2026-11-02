# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## Wisata Daerahku — Flutter UI/UX V4
### Dynamic Scenic Headers, Notification Experience & Booking Detail Redesign

**Status:** Approved Design Direction — Ready for Implementation  
**Platform:** Flutter Android  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Design Authority:** `DESIGN.md` (gunakan lokasi aktual dalam repository)  
**Primary Agent:** `flutter_engineer`  
**Supporting Agent:** `qa_engineer`  
**Design Skill:** Mobile UI/UX Taste Skills / `taste-skill-frontend` jika tersedia  
**Backend:** Laravel API existing, tanpa perubahan business logic secara default

---

# 1. Executive Summary

PRD ini menetapkan penyempurnaan UI/UX Wisata Daerahku V4 pada empat halaman navigasi utama serta satu halaman detail pendaftaran/tiket.

Tujuannya menciptakan pengalaman visual yang konsisten dengan Dynamic Time-Based Scenic Background yang telah digunakan pada halaman Beranda dan autentikasi, sambil mempertahankan business logic, kontrak API, navigasi, dan data aktual pengguna.

Modul utama:

1. Riwayat Pendaftaran — Dynamic Scenic Header.
2. Jelajah — Dynamic Scenic Header.
3. Profil — Dynamic Scenic Header dengan Floating Profile Card.
4. Notifikasi — Dynamic Scenic Header dengan pembaruan tampilan inbox.
5. Detail Pendaftaran/Tiket — Soft Redesign dengan informasi status kontekstual.
6. Shared Scenic System — Pemakaian ulang aset, periode waktu, dan transisi.
7. Konsistensi Full-Bleed Edge-to-Edge pada halaman terkait.

Implementasi harus bersifat incremental, meminimalkan perubahan kode yang tidak relevan, dan mempertahankan kompatibilitas dengan arsitektur Flutter yang sudah ada.

# 2. Tujuan Produk

## 2.1 Goals

- Menerapkan identitas visual empat suasana waktu secara konsisten.
- Menciptakan header yang immersive tanpa mengurangi keterbacaan.
- Memperbaiki hierarki visual informasi pendaftaran dan notifikasi.
- Menghubungkan Notifikasi langsung ke detail booking yang sudah tersedia.
- Memperjelas perbedaan antara pendaftaran, pembayaran yang sedang ditinjau, persetujuan booking, dan penerbitan tiket.
- Mempertahankan posisi scroll dan filter ketika kembali dari halaman detail.
- Mengutamakan reusable components dan menghindari implementasi berulang.
- Memastikan layout tetap stabil pada berbagai ukuran perangkat Android.

## 2.2 Non-Goals

- Tidak melakukan redesign autentikasi.
- Tidak mengubah algoritma booking, kuota, pembayaran, atau idempotency.
- Tidak melakukan migrasi Firebase/Laravel.
- Tidak menambahkan status booking baru pada backend.
- Tidak membuat endpoint API baru kecuali terbukti benar-benar diperlukan dan disetujui secara terpisah.
- Tidak mengganti seluruh sistem navigasi.
- Tidak menambahkan scenic image pada halaman Detail Pendaftaran/Tiket.
- Tidak membuat ulang layar detail booking yang sudah ada.
- Tidak mengubah informasi status pembayaran secara optimistis.

# 3. Design System & Architecture

## 3.1 Design Authority

Sebelum implementasi, agent wajib membaca:

- `DESIGN.md` dari lokasi aktual repository.
- Implementasi existing dynamic scenic background.
- Implementasi auth dynamic background pada `auth_presentation.dart`.
- Komponen navigasi dan theme Flutter.
- Model, repository, dan screen yang saat ini mengelola booking serta notifikasi.

Apabila terjadi perbedaan antara contoh wireframe dan token desain yang berlaku, gunakan `DESIGN.md` sebagai acuan utama, kemudian dokumentasikan keputusan adaptasinya.

Tidak diperbolehkan memperkenalkan typography, spacing, radius, warna, atau komponen yang bertentangan dengan desain utama tanpa alasan yang jelas.

## 3.2 Shared Dynamic Scenic System

Gunakan satu shared component/service untuk menyediakan empat periode waktu:

| Periode | Jam perangkat | Suasana |
|---|---|---|
| Morning | 05.00–10.59 | Golden sunrise, morning blue |
| Day | 11.00–14.59 | Bright daylight, blue sky |
| Evening | 15.00–18.59 | Warm sunset, soft purple |
| Night | 19.00–04.59 | Deep navy, moonlight |

Sumber waktu adalah `DateTime.now()` pada perangkat, konsisten dengan implementasi dynamic auth sebelumnya.

Ketentuan:

- Reuse aset scenic existing yang sesuai.
- Jangan membuat asset duplikat per screen.
- Pertahankan transisi 800 ms menggunakan `Curves.easeInOut`.
- Update ketika batas periode terlewati.
- Sinkronkan kembali ketika aplikasi `resumed`.
- Lakukan pemeriksaan ulang periodik sebagai fallback.
- Hindari pemanggilan timer yang berlipat akibat rebuild.
- Gunakan `AnimatedSwitcher`, `AnimatedContainer`, atau pendekatan existing yang sudah terbukti sesuai.
- Hormati pengaturan reduced motion dari perangkat.
- Hindari decoding gambar berulang setiap perpindahan tab.

Kontrak shared component yang disarankan:

`TimeBasedScenicHeader`

Tanggung jawab komponen:

- Menentukan scene aktif.
- Menyediakan background image/scene yang sesuai.
- Mengelola gradient overlay dan transisi.
- Mendukung konfigurasi tinggi dan area overlay.
- Mendukung status bar yang menyatu dengan background.
- Menerima konten header melalui composition/child.
- Tidak memiliki ketergantungan terhadap business repository.

Pemilihan nama kelas final mengikuti konvensi repository. Jika komponen existing sudah mendukung kebutuhan ini, extend komponen tersebut daripada membuat komponen baru.

## 3.3 Edge-to-Edge

Seluruh scenic header harus full-bleed sampai bagian atas layar, termasuk area di belakang Android status bar.

Persyaratan:

- Tidak terdapat celah putih/abu-abu di bagian paling atas.
- Background hero meluas ke area status bar.
- Konten teks tetap menghormati safe inset.
- Warna ikon status bar adaptif agar kontras.
- Tidak terdapat benturan dengan kamera punch-hole.
- Navigation bar Android tetap konsisten dengan desain aplikasi.
- Tidak ada konten tertutup floating bottom navigation.
- Keyboard dan scroll behavior tidak rusak.

Jangan menyelesaikan edge-to-edge dengan `SafeArea` yang memotong background hero; safe area hanya diterapkan pada konten yang membutuhkannya.

# 4. Module A — Riwayat Pendaftaran

## 4.1 Existing State

Halaman memiliki:

- Header gradient biru.
- Badge total pendaftaran.
- Judul Riwayat Pendaftaran.
- Subtitle.
- Statistik Menunggu, Disetujui, Ditolak.
- Daftar riwayat pendaftaran.

## 4.2 Target Experience

Ganti background gradient statis dengan dynamic scenic background yang sesuai waktu.

Pertahankan hierarki:

1. Status bar edge-to-edge.
2. Badge jumlah pendaftaran.
3. Judul Riwayat Pendaftaran.
4. Subtitle.
5. Tiga kartu statistik.
6. Konten riwayat.

## 4.3 Statistik Glass Cards

Tiga kartu statistik tetap berada dalam hero dengan translucent glass styling.

Persyaratan:

- Teks dan nilai tetap terbaca pada semua scene.
- Tidak menggunakan blur berlebihan.
- Nilai berasal dari data aktual.
- Tidak memodifikasi definisi/status counting existing.
- Responsif pada lebar layar kecil.
- Tetap menggunakan status Menunggu, Disetujui, Ditolak sesuai semantik existing.

## 4.4 Acceptance Criteria

- Background berubah mengikuti periode waktu.
- Semua informasi existing tetap tersedia.
- Tidak ada perubahan pada perhitungan statistik.
- Navigasi ke detail booking tetap bekerja.
- Tidak terjadi overflow pada 320dp, 390dp, dan 430dp.

# 5. Module B — Jelajah

## 5.1 Existing State

Halaman memiliki:

- Tombol kembali.
- Badge jumlah destinasi tersedia.
- Judul Jelajah.
- Subtitle.
- Search bar.
- Filter kategori.
- Daftar destinasi.

Struktur visual existing sudah sesuai dengan konsep hero.

## 5.2 Target Experience

Gunakan dynamic scenic background pada area header sampai search bar.

Susunan:

1. Status bar.
2. Tombol navigasi existing.
3. Badge destinasi.
4. Judul Jelajah.
5. Subtitle.
6. Search bar.
7. Filter kategori pada area konten.
8. Daftar destinasi.

## 5.3 Visual Rules

- Search bar menggunakan surface terang dengan kontras tinggi.
- Scenic background tidak diteruskan ke seluruh daftar destinasi.
- Overlay menjaga keterbacaan title, badge, dan back button.
- Filter kategori mempertahankan behavior dan state existing.
- Kartu destinasi, image sequence, dan galeri tidak diubah oleh scope ini.

## 5.4 Functional Preservation

- Search tetap menggunakan data Laravel.
- Kategori tetap dinamis.
- Pagination dan deduplication tetap berjalan.
- Tidak mengubah data atau logika destinasi.
- Search query dan selected category tidak boleh hilang akibat perubahan scene.

# 6. Module C — Profil

## 6.1 Existing State

Halaman Profil memiliki:

- Background/header biru muda.
- Judul Profil Saya.
- Profile card berwarna putih.
- Avatar.
- Nama/email/telepon.
- Tombol Edit Profil.
- Statistik Pendaftaran, Dikunjungi, Ulasan, Tahun Bergabung.
- Wisata Tersimpan.
- Menu Akun.

## 6.2 Target Experience — Floating Profile Card

Gunakan dynamic scenic hero pada bagian atas halaman.

Profile card dibuat overlap secara visual pada batas bawah hero, menciptakan kesan floating card.

Struktur:

1. Scenic hero full-bleed.
2. Judul Profil Saya.
3. Floating profile card putih.
4. Informasi identitas.
5. Edit Profil.
6. Statistik akun.
7. Wisata Tersimpan.
8. Menu Akun.
9. Existing floating bottom navigation.

## 6.3 Floating Card Requirements

- Surface utama tetap putih.
- Border dan shadow lembut mengikuti `DESIGN.md`.
- Overlap hero menggunakan layout yang aman dari clipping.
- Identitas dan statistik tetap dalam satu kartu.
- Long email harus dapat dibungkus dengan benar.
- Tidak terdapat horizontal overflow.
- Avatar tetap menggunakan data existing.
- Statistik tidak menggunakan angka hardcoded.

## 6.4 Interaction Preservation

Pertahankan seluruh fungsi:

- Edit Profil.
- Wisata Tersimpan.
- Riwayat Ulasan.
- Notifikasi.
- Bahasa.
- Menu akun lainnya.
- Logout bila tersedia pada screen.

Tidak boleh terdapat perubahan route atau API akibat redesign visual.

# 7. Module D — Notifikasi

## 7.1 Existing State

Halaman Notifikasi menggunakan background polos, memiliki:

- Judul Notifikasi.
- Tombol refresh.
- Subtitle.
- Filter Semua dan Belum dibaca.
- Daftar kartu notifikasi.
- Floating bottom navigation.

## 7.2 Target Experience — Compact Immersive Hero

Gunakan scenic hero dengan tinggi lebih ringkas dibandingkan halaman Jelajah.

Struktur:

1. Status bar full-bleed.
2. Badge jumlah belum dibaca.
3. Judul Notifikasi.
4. Tombol refresh.
5. Subtitle.
6. Batas bawah scenic hero.
7. Filter Semua / Belum dibaca.
8. Label Aktivitas Terbaru.
9. Daftar notifikasi.
10. Floating bottom navigation.

## 7.3 Hero Behavior

- Scene mengikuti jam perangkat.
- Badge unread menampilkan jumlah aktual.
- Badge tidak boleh menyiratkan ada notifikasi baru jika semua sudah dibaca.
- Refresh icon tetap mudah diakses.
- Background tidak mengganggu konten.
- Filter berada di surface konten netral, bukan mengambang di atas scenic image.

## 7.4 Notification Cards

Setiap item mempertahankan:

- Ikon berdasarkan jenis notifikasi.
- Judul.
- Deskripsi.
- Waktu/tanggal.
- Status dibaca atau belum dibaca.
- Indikator navigasi jika applicable.

Unread state dibedakan melalui styling subtle, misalnya border atau unread dot.

Jangan menjadikan perbedaan status hanya bergantung pada warna.

## 7.5 Filter Interaction

Filter:

- Semua.
- Belum dibaca.

Persyaratan:

- Active state jelas.
- Perubahan filter menggunakan data existing.
- Tidak melakukan request tambahan yang tidak diperlukan.
- Filter tetap terpilih ketika kembali dari detail.
- Unread count konsisten setelah pembaruan server.
- Tidak menampilkan notifikasi yang baru ditandai dibaca pada filter Belum dibaca setelah state berhasil diperbarui.

## 7.6 Refresh Behavior

Tombol refresh harus:

- Memanggil mekanisme refresh existing.
- Menampilkan loading feedback seperlunya.
- Menghindari duplicate requests.
- Mengelola stale asynchronous responses.
- Mempertahankan list sebelumnya jika refresh gagal.
- Menampilkan retry feedback untuk kesalahan jaringan.
- Tidak secara otomatis mengubah read state.

## 7.7 Empty States

Sediakan tiga kondisi berbeda:

**Tidak ada notifikasi sama sekali:** Jelaskan bahwa aktivitas booking akan muncul di halaman ini.

**Semua notifikasi sudah dibaca:** Tampilkan informasi bahwa tidak ada item belum dibaca.

**Gagal memuat:** Tampilkan pesan error dan opsi retry, tanpa menyamakan error dengan empty state.

## 7.8 Notification Navigation

Keputusan final:

**Klik notifikasi booking membuka halaman Detail Pendaftaran/Tiket secara full-screen.**

Tidak menggunakan:

- Bottom sheet detail.
- Alert dialog berisi detail booking.
- Modal duplikat.
- Detail statis khusus notifikasi.

Navigasi harus menggunakan booking identifier/route existing.

Apabila notifikasi tertentu bukan notifikasi booking, jangan memaksanya menuju Detail Tiket. Ikuti target navigasi yang memang didukung oleh jenis notifikasi tersebut.

## 7.9 Read State

Saat membuka notifikasi:

- Gunakan mekanisme mark-as-read existing.
- Sinkronkan dengan backend.
- Jangan menyatakan update berhasil apabila request gagal.
- Cegah request ganda.
- Hindari hilangnya item secara prematur akibat optimistic state tanpa penanganan rollback.

## 7.10 Back Navigation

Ketika kembali dari detail:

- Kembali ke halaman Notifikasi.
- Pertahankan selected filter.
- Pertahankan scroll position bila daftar masih relevan.
- Pertahankan tab navigasi yang aktif.
- Hindari rebuild seluruh tab navigator secara tidak perlu.

# 8. Module E — Detail Pendaftaran/Tiket

## 8.1 Existing State

Screen existing memiliki:

- App bar Detail Tiket.
- Ticket card.
- Status badge.
- Nama destinasi.
- Booking code.
- Informasi pemesan, tanggal, jumlah dan telepon.
- Expand/collapse detail.
- Email.
- Total pembayaran.
- Deskripsi status.
- Informasi dokumen.

## 8.2 Target Experience

Implementasi **Soft Redesign V4**.

Tetap mempertahankan ticket metaphor, tetapi memperbaiki:

- Visual hierarchy.
- Status clarity.
- Content spacing.
- Format tanggal dan mata uang.
- Expand/collapse.
- Informasi tindakan berikutnya.
- Perbedaan booking dengan tiket resmi.

Halaman detail menggunakan background netral. Tidak menggunakan dynamic scenic hero.

## 8.3 Dynamic Page Title

Gunakan judul yang sesuai kondisi sumber data:

- **Detail Pendaftaran:** ketika booking masih dalam proses atau tiket belum diterbitkan.
- **Detail Tiket:** ketika dokumen tiket benar-benar telah diterbitkan.

Jangan mengganti judul hanya karena pembayaran disetujui apabila tiket belum tersedia.

Perhatikan juga apabila route detail digunakan oleh flow lain; perubahan judul tidak boleh merusak ekspektasi navigasi existing.

## 8.4 Ticket Card

Pertahankan:

- Rounded ticket card.
- Perforated/dashed divider.
- Side cutouts.
- Nama destinasi.
- Booking code.
- Detail kunjungan.
- Expandable information.

Perbaiki spacing dan proporsi agar informasi tidak terlalu rapat.

## 8.5 Booking Code

- Gunakan kode aktual backend.
- Dapat disalin melalui tombol copy jika belum tersedia.
- Berikan feedback setelah disalin.
- Tidak menggunakan kode contoh/hardcoded pada production.
- Tangani kode panjang agar tidak overflow.

## 8.6 Formatting

Gunakan locale Indonesia sesuai standar proyek.

Contoh:

- `2026-11-07` → `7 November 2026`.
- `100000` → `Rp100.000`.
- `1` → `1 orang`.

Nilai format tidak boleh mengubah raw value pada model atau request API.

Nama pemesan harus berasal dari field nama aktual. Jika backend hanya menyediakan email, jangan membuat nama palsu untuk menggantikannya.

## 8.7 Status Presentation

Desain harus memetakan status aktual backend ke representasi UI yang relevan.

Empat skenario visual yang harus dapat diuji:

| Skenario | Tampilan | Penjelasan |
|---|---|---|
| Menunggu pembayaran | Biru/informational | Pembayaran masih diperlukan atau belum tercatat |
| Peninjauan pembayaran | Oranye/warning | Pembayaran sedang diverifikasi |
| Disetujui | Hijau/success | Booking telah memperoleh persetujuan |
| Ditolak | Merah/error | Pendaftaran tidak disetujui |

**Penting:** tabel ini adalah skenario presentasi UI, bukan instruksi untuk membuat enum backend baru.

Agent wajib memeriksa status aktual Laravel dan mapping pada Flutter. Status tambahan existing tetap harus ditangani dengan benar.

## 8.8 Status Context & Next Steps

Tambahkan section **Apa Selanjutnya?** dengan pesan kontekstual.

### Scenario A — Menunggu Pembayaran

Jelaskan bahwa pembayaran masih perlu diselesaikan apabila alur backend mengharuskannya.

CTA pembayaran hanya boleh muncul jika memang ada route, instruksi, dan eligibility yang tersedia dari backend.

### Scenario B — Peninjauan Pembayaran

Jelaskan bahwa pembayaran sedang diverifikasi dan belum dipastikan diterima.

Tidak boleh menampilkan status "Pembayaran berhasil" sebelum verifikasi sesuai aturan backend.

### Scenario C — Disetujui

Jelaskan bahwa pendaftaran telah dikonfirmasi.

Jika tiket sudah diterbitkan dan URL/endpoint dokumen tersedia, munculkan action **Lihat Tiket** atau action dokumen existing.

Jika tiket belum diterbitkan, tampilkan informasi bahwa dokumen belum tersedia.

### Scenario D — Ditolak

Tampilkan informasi penolakan sesuai data aktual.

Alasan penolakan hanya ditampilkan bila tersedia dari backend.

Jangan mengarang alasan atau menjanjikan refund otomatis.

## 8.9 Expand/Collapse

Pertahankan konsep detail expandable.

Perbaikan:

- Animasi expand/collapse halus.
- Label berubah antara Tampilkan detail dan Sembunyikan detail.
- Icon chevron mengikuti state.
- Tidak terjadi layout jump yang tidak wajar.
- Fokus aksesibilitas tetap benar.
- Konten tidak hilang akibat rebuild yang tidak terkait.

## 8.10 Document Section

Status penerbitan dokumen harus terpisah dari status booking.

Jika dokumen belum ada:

> Dokumen belum diterbitkan.

Jika dokumen sudah tersedia, gunakan mekanisme akses dokumen existing.

Jangan membuat PDF baru di frontend, menyajikan mock document, atau menganggap dokumen tersedia hanya karena booking disetujui.

## 8.11 Navigation

Alur utama:

Notifikasi → Detail Pendaftaran/Tiket → Kembali ke Notifikasi.

Pertahankan sumber navigasi untuk flow lain, misalnya Riwayat Pendaftaran → Detail Pendaftaran/Tiket → Kembali ke Riwayat.

Back button serta system back gesture harus bekerja konsisten.

# 9. Shared Navigation Requirements

Bottom navigation existing tetap:

- Beranda.
- Riwayat.
- Jelajah.
- Notifikasi.
- Profil.

Persyaratan:

- Icon-only, tanpa label teks terlihat.
- Jelajah tetap menggunakan floating center treatment.
- Active state tetap mengikuti halaman aktif.
- Notification badge existing tidak bergeser.
- Tidak membuat instance navigator ganda.
- Tidak menyebabkan tab reset ketika pengguna kembali dari halaman detail.
- Detail full-screen tidak perlu menampilkan floating bottom navigation jika sesuai pola route existing.

# 10. Data & Backend Contract

Frontend harus tetap menggunakan Laravel sebagai sumber data bisnis.

Dilarang:

- Menambahkan hardcoded booking status.
- Menambahkan fake notification production.
- Mengubah payment lifecycle.
- Membypass authorization.
- Menggunakan user GUID atau booking GUID sembarangan.
- Menampilkan dokumen pengguna lain.
- Mengubah idempotency booking.
- Menyimpulkan status berdasarkan warna atau teks notification saja.

Model dan repository existing harus diperiksa terlebih dahulu.

Halaman detail harus mengambil data dari booking yang benar, bukan hanya menyalin title/description pada notifikasi.

Jika data tersedia secara parsial, tampilkan fallback yang aman dan jujur, bukan fabricated information.

# 11. Error Handling & Edge Cases

Wajib mencakup:

1. Tidak ada notifikasi.
2. Semua notifikasi sudah dibaca.
3. Server timeout.
4. Refresh gagal.
5. Notifikasi tidak memiliki booking reference valid.
6. Booking telah dihapus atau tidak lagi dapat diakses.
7. Session expired saat membuka detail.
8. Status booking berubah saat pengguna berada di halaman detail.
9. Dokumen belum tersedia walaupun booking disetujui.
10. Email atau booking code sangat panjang.
11. Data destinasi tidak memiliki gambar.
12. Pengguna mengganti jam perangkat.
13. Aplikasi resume setelah melewati batas periode scenic.
14. Pergantian tab cepat.
15. Repeated notification tap.
16. Rotasi/resize dan keyboard insets.
17. Internet terputus kemudian pulih.
18. Pengguna kembali dari detail saat filter Belum dibaca aktif.

Semua state harus memiliki UI yang masuk akal dan tidak menyebabkan crash.

# 12. Performance Requirements

- Reuse image assets.
- Prefetch atau precache scenic images sesuai kebutuhan existing.
- Tidak melakukan network fetch berulang hanya untuk pergantian scene.
- Hindari rebuild subtree besar setiap menit jika scene tidak berubah.
- Timer dan subscriptions harus dibersihkan saat dispose.
- Jangan menumpuk AnimationController.
- Hindari heavy blur pada terlalu banyak glass cards.
- Pertahankan scroll performance saat daftar destinasi/notifikasi panjang.

Perubahan UI tidak boleh menyebabkan regression yang signifikan pada startup atau navigasi.

# 13. Accessibility Requirements

- Semantik tombol dan icon.
- Touch target yang memadai.
- Kontras teks pada semua scenic scene.
- Screen reader dapat membaca status booking.
- Status tidak dikomunikasikan melalui warna saja.
- Support text scaling.
- Reduced motion.
- Long text wrapping.
- Focus order yang masuk akal.
- Loading, error, empty, dan success state dapat dipahami pengguna.

# 14. Candidate Files for Review

Daftar berikut adalah kandidat berdasarkan struktur proyek yang telah dibahas. Agent wajib memverifikasi path dan implementasi aktual sebelum mengedit.

### Flutter Screens

- `lib/screens/daftar_kunjungan_screen.dart`
- `lib/screens/cari_wisata_screen.dart`
- `lib/screens/profil_user_screen.dart`
- `lib/screens/notifikasi_screen.dart`
- `lib/screens/bukti_pendaftaran_screen.dart`
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/auth_presentation.dart`

### Shared UI & Services

- Komponen shared scenic background yang sudah tersedia.
- `lib/theme/app_colors.dart`
- `lib/data/business_repository.dart` — inspeksi model dan mapping, ubah hanya jika diperlukan.
- `lib/data/notification_state.dart` — inspeksi notification state.
- `lib/services/auth_session.dart` — inspeksi integrasi session, bukan target refactor default.

### Dokumentasi

- `DESIGN.md` pada lokasi sebenarnya.
- Dokumen handoff UI/UX V4 existing.
- Dokumen visual verification existing.

### Tests

Buat atau perbarui unit/widget tests sesuai nama dan konvensi test suite repository.

**Jangan membuat file duplikat hanya karena nama kandidat di PRD berbeda dari nama implementasi aktual.**

# 15. Agent & Skill Requirements

## Primary: flutter_engineer

Bertanggung jawab atas:

- Audit screen existing.
- Implementasi shared scenic system.
- UI redesign empat halaman.
- Detail ticket redesign.
- Navigation preservation.
- Widget lifecycle dan performance.

## Supporting: qa_engineer

Bertanggung jawab atas:

- Regression tests.
- Widget tests.
- Navigation tests.
- Status mapping.
- Responsive layout.
- Verification seluruh perubahan.

## Mobile Design Skill

Gunakan Taste Skills / taste-skill-frontend yang relevan untuk mobile apabila tersedia.

Tujuannya:

- Visual hierarchy.
- Spacing consistency.
- Responsive composition.
- Premium scenic experience.
- Component reuse.
- Android native visual ergonomics.

Skill tidak boleh menimpa token dari `DESIGN.md`.

## Delegation Limit

Gunakan **dua agent utama saja**, Flutter Engineer dan QA Engineer.

Tidak diperlukan delegasi berantai ke banyak subagent untuk perubahan presentasional ini.

Agent tambahan hanya jika ditemukan blocker spesifik yang benar-benar memerlukan spesialisasi lain.

# 16. Implementation Phases

## Phase 1 — Audit & Shared Foundation

- Audit `DESIGN.md`.
- Inspeksi scenic background existing.
- Inspeksi seluruh screen terkait.
- Identifikasi aset empat periode.
- Extract atau extend shared scenic component.
- Validasi lifecycle dan edge-to-edge.

## Phase 2 — Dynamic Scenic Tabs

Implementasi bertahap:

1. Riwayat Pendaftaran.
2. Jelajah.
3. Profil.
4. Notifikasi.

Pastikan setiap screen mengikuti komposisinya sendiri, tetapi menggunakan shared scenic engine.

## Phase 3 — Notification Experience

- Badge unread.
- Styling kartu notifikasi.
- Filter.
- Refresh state.
- Empty/error states.
- Mark-as-read integration.
- Navigation ke detail.
- Back state restoration.

## Phase 4 — Booking Detail Redesign

- Dynamic title berdasarkan dokumen.
- Ticket hierarchy.
- Status badge.
- Status information.
- Expand/collapse.
- Apa Selanjutnya?
- Document availability.
- Back-navigation compatibility.

## Phase 5 — QA & Regression

- Unit/widget tests.
- Navigation flow tests.
- Layout tests.
- Manual visual verification bila perangkat/emulator tersedia.
- Static analysis.
- Regression review.
- Dokumentasi handoff.

# 17. Test Plan

## Scenic System

- Pergantian 04.59 → 05.00.
- Pergantian 10.59 → 11.00.
- Pergantian 14.59 → 15.00.
- Pergantian 18.59 → 19.00.
- Resume setelah pergantian periode.
- Tidak ada duplicate timers.
- Berjalan pada semua empat tab.
- Perubahan scene tidak mereset data form/filter.

## Layout

Minimal:

- 320dp.
- 390dp.
- 430dp.
- Android system text scaling.
- Status bar punch-hole.
- Long email/name.
- Long booking code.
- Empty profile statistics.
- Long notification description.

## Notification Flow

- Filter Semua.
- Filter Belum dibaca.
- Mark-as-read berhasil.
- Mark-as-read gagal.
- Refresh berhasil.
- Refresh gagal.
- Notifikasi booking membuka booking yang sesuai.
- Back mempertahankan filter dan posisi scroll.
- System back gesture.
- Double tap.
- Stale API response.

## Booking Detail

- Menunggu pembayaran.
- Peninjauan pembayaran.
- Disetujui tanpa dokumen.
- Disetujui dengan dokumen.
- Ditolak.
- Status lain yang ada di backend.
- Expand/collapse.
- Format uang/tanggal.
- Booking identifier dan ownership.
- Document loading failure.
- Booking tidak ditemukan.

## Commands

Jalankan minimal:

```bash
flutter analyze
flutter test
git diff --check
```

Jika terdapat kegagalan existing yang tidak berkaitan dengan perubahan, dokumentasikan secara terpisah dan jangan mengklaim seluruh suite PASS.

# 18. Definition of Done

Pekerjaan dinyatakan selesai hanya jika:

- Empat halaman memiliki dynamic scenic headers.
- Scene mengikuti waktu perangkat secara benar.
- Full-bleed edge-to-edge berjalan.
- Visual mengikuti `DESIGN.md`.
- Profil menggunakan floating card yang responsif.
- Notifikasi memiliki header baru tanpa mengubah fungsionalitas inbox.
- Klik notifikasi booking membuka existing detail screen secara full-screen.
- Filter/scroll state dipertahankan saat kembali.
- Detail Pendaftaran/Tiket menggunakan hierarchy dan status-aware content baru.
- Semua data booking berasal dari Laravel.
- Tidak ada fake payment/ticket states.
- Tidak ada regression pada booking, auth, atau navigation.
- Tests dan analisis dilaporkan dengan jujur.
- Handoff mendokumentasikan perubahan, file yang disentuh, serta hasil validasi.

# 19. Out-of-Scope Protection

Jangan menyentuh modul:

- Laravel backend business logic.
- Quota availability calculation.
- Payment gateway.
- Booking creation/idempotency.
- Firebase authentication.
- FCM delivery infrastructure.
- Admin gallery upload/sequence.
- Destination image management.
- Authentication flow yang sudah selesai.
- Data migration.

Perubahan pada area tersebut memerlukan kebutuhan dan persetujuan terpisah.

# 20. Delivery Requirements

Implementer harus menyampaikan:

1. Ringkasan implementasi per modul.
2. Daftar file yang berubah.
3. Reusable component yang dibuat/diubah.
4. Penjelasan integrasi notification-to-booking.
5. Status mapping yang ditemukan di repository.
6. Hasil tests dan static analysis.
7. Known limitations.
8. Handoff document di `docs/` sesuai struktur proyek.

Tidak melakukan commit, push, deployment, atau perubahan backend tanpa instruksi.

---

# 21. Final Design Decisions

| Elemen | Keputusan Final |
|---|---|
| Scenic system | Shared, empat periode |
| Jam | Local device time |
| Transisi | 800ms easeInOut |
| Riwayat | Scenic header + glass statistics |
| Jelajah | Scenic header + existing search |
| Profil | Scenic header + floating profile card |
| Notifikasi | Compact scenic header + clean inbox |
| Filter notifikasi | Tetap Semua / Belum dibaca |
| Klik notifikasi booking | Full-screen existing booking detail |
| Detail booking | Clean soft redesign, bukan scenic |
| Judul detail | Berdasarkan penerbitan tiket aktual |
| Booking status | Backend authoritative |
| Dokumen | Berdasarkan ketersediaan aktual |
| Navigation | Preserve existing icon-only V4 |
| Design authority | `DESIGN.md` |
| Implementation | Incremental |
| Agents | Flutter Engineer + QA Engineer |
| Backend | Tidak diubah |
| Commit/push/deploy | Tidak dilakukan |

**END OF PRD — Wisata Daerahku Flutter UI/UX V4**
