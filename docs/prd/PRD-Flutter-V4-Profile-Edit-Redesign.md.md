# PRD — Flutter V4 Profile Card & Edit Profile Redesign

**Project:** Wisata Daerahku  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Platform:** Flutter Mobile  
**Status:** Approved — Direct Implementation  
**Priority:** UI/UX refinement  
**Design Authority:** `DESIGN.md`

## 1. Objective

Implementasikan redesign Profile Card dan Edit Profile Bottom Sheet berdasarkan interactive wireframe yang telah disetujui.

Tujuan utama:

- Membuat Profile Card lebih compact dan proporsional.
- Mempertahankan dynamic scenic header dan edge-to-edge.
- Mengubah tombol Edit Profil menjadi icon-only.
- Membuat country code selector terpisah dari nomor telepon.
- Mendukung auto-format nomor berdasarkan negara.
- Mempertahankan business logic dan integrasi Laravel yang sudah berjalan.

**Langsung implementasi. Tidak perlu membuat wireframe baru, PRD tambahan, atau meminta approval ulang.**

## 2. Agent & Skill Instructions

### Orchestrator — Ponytails

Gunakan existing master orchestrator **Ponytails** untuk koordinasi implementasi.

Tanggung jawab:

- Membaca `DESIGN.md`.
- Mengidentifikasi komponen profil dan phone input yang sudah tersedia.
- Mendelegasikan implementasi hanya kepada agent yang dibutuhkan.
- Menjaga scope tetap kecil.
- Menghindari delegasi agent berlapis dan pekerjaan berulang.

### Primary Agent — `flutter_engineer`

Menangani seluruh implementasi Flutter:

- Profile Card layout.
- Edit Profile Bottom Sheet.
- Country code selector.
- Phone number formatting.
- Existing profile update integration.
- Keyboard handling dan responsive layout.

Gunakan konfigurasi agent Flutter yang tersedia di `.codex/agents/` jika ditemukan.

### Design Skill — TasteSkill

Gunakan skill frontend/mobile **TasteSkill (`taste-skill-frontend` atau nama skill ekuivalen yang tersedia)** sebagai panduan kualitas visual.

Ketentuan:

- `DESIGN.md` merupakan sumber utama design system.
- TasteSkill digunakan untuk memperhalus hierarchy, spacing, interaction, typography, dan visual balance.
- Jangan mengganti brand color atau design token yang telah ditetapkan.
- Jangan membuat design system baru.

**Tidak menggunakan QA agent, security auditor, atau agent tambahan. Tidak membuat maupun menjalankan automated tests, test suite, screenshot regression, atau full Flutter analyze.**

---

## 3. Scope A — Compact Profile Card

### Current Issue

Profile Card menggunakan layout statistik 2×2 dengan tombol Edit Profil di baris terpisah. Akibatnya card terlalu tinggi.

### Target Layout

#### Identity Section

Gunakan horizontal layout:

`[ Avatar BS ] [ Nama + Email + Nomor ] [ Edit Icon ]`

Ketentuan:

- Avatar circular, sekitar 48–52dp.
- Nama pengguna bold.
- Email menggunakan secondary text color.
- Nomor ditampilkan dalam format internasional yang mudah dibaca.
- Edit icon berada di kanan identitas.
- Icon-only button dengan hit target minimum 48×48dp.
- Accessibility label: `Edit Profil`.

#### Statistics Section

Tampilkan tiga statistik secara horizontal:

| Pendaftaran | Dikunjungi | Ulasan |
|---|---|---|
| 4 | 0 | 0 |

Gunakan data aktual, bukan hardcoded.

- Three equal-width columns.
- Value menggunakan typography semibold/bold.
- Label menggunakan secondary text.
- Divider ringan di antara section atau kolom sesuai `DESIGN.md`.

#### Membership Metadata

Pindahkan `Tahun bergabung` dari grid statistik menjadi footer metadata.

Jika tersedia tanggal bergabung valid:

`Bergabung sejak 2026`

Jika tidak tersedia, tampilkan placeholder yang wajar atau sembunyikan metadata. Jangan mengarang tahun.

#### Scenic Header

Wajib dipertahankan:

- Dynamic scenic background berdasarkan waktu perangkat.
- Existing illustration dan transisi.
- Full bleed / edge-to-edge.
- Status bar transparan yang sudah diterapkan.
- Card overlap di bawah scenic header.
- Existing navigation dan scroll behavior.

Jangan mengubah implementasi scenic header yang sudah bekerja.

---

## 4. Scope B — Edit Profile Bottom Sheet

### Presentation

Pertahankan `ModalBottomSheet`, bukan halaman baru.

#### Sheet Header

- Centered drag handle.
- Title: `Edit Profil`.
- Close icon di kanan.
- Top corner radius mengikuti `DESIGN.md`.
- Background menggunakan surface color aplikasi.

#### Nama Lengkap

Label: `Nama Lengkap`

- Prefilled dari profil aktual.
- Editable.
- Mendukung nama panjang.
- Keyboard text biasa.
- Tidak boleh menyimpan nama kosong.
- Gunakan validasi existing backend.

#### No. Telepon

Label: `No. Telepon`

Ubah single input menjadi **split international phone field**.

Struktur:

`[ 🇮🇩 +62  ⌄ ]  [ 896 5586 2781 ]`

**Left — Country Selector**

- Flag negara.
- International dialing code.
- Dropdown indicator.
- Dapat ditekan untuk memilih negara.
- Reuse existing country picker yang sudah digunakan pada booking flow apabila kompatibel.

**Right — Phone Input**

- Hanya nomor nasional, tanpa kode negara.
- `TextInputType.phone`.
- Mendukung auto-format saat mengetik.
- Menerima paste nomor internasional dan lokal.
- Prefix negara tidak diduplikasi.
- Cursor dan selection tidak boleh meloncat secara tidak wajar saat formatting.
- Tampilkan nomor awal dari data profil yang sudah ada.

### Supported Country Behavior

Country selector mengikuti daftar negara existing, bukan dibatasi pada empat negara di wireframe.

Minimal contoh:

| Country | Dialing code |
|---|---|
| Indonesia | +62 |
| Malaysia | +60 |
| Singapore | +65 |
| United States | +1 |

Gunakan metadata negara serta validation/formatting yang tersedia dalam project.

**Jangan menerapkan grouping nomor Indonesia secara paksa untuk semua negara.**

### Indonesia Formatting Example

| Input | Formatted local display |
|---|---|
| 089655862781 | 896 5586 2781 |
| 89655862781 | 896 5586 2781 |
| +6289655862781 | 896 5586 2781 |

Dengan country Indonesia `+62` terpilih.

Profile Card menampilkan:

`+62 896 5586 2781`

Backend menerima:

`+6289655862781`

Untuk negara lain, ikuti aturan parsing dan formatting negara terkait.

---

## 5. Phone Data & Laravel Integration

Pertahankan existing profile API, service, repository, dan authentication state.

Ketentuan:

1. Ambil phone number aktual dari profil pengguna.
2. Parse nomor internasional untuk menentukan country code dan national number.
3. Prefill kedua bagian field secara benar.
4. Ketika pengguna mengganti negara, perbarui dialing code tanpa merusak nomor yang sedang diedit.
5. Validasi menggunakan mekanisme nomor internasional existing.
6. Normalisasi menjadi E.164 sebelum dikirim ke Laravel.
7. Gunakan existing endpoint dan payload contract.
8. Setelah berhasil, perbarui profile state agar Profile Card langsung merefleksikan hasil tersimpan.
9. Jika backend menolak perubahan, pertahankan input dan tampilkan feedback yang sesuai.
10. Jangan membuat migration, endpoint baru, atau perubahan database kecuali benar-benar diperlukan oleh kontrak yang sudah ada.

Jangan mengubah Google Sign-In, email verification, atau business logic booking.

---

## 6. Bottom Sheet Interaction

### Initial State

- Field terisi dari data profil.
- Save button disabled jika tidak ada perubahan.
- Existing email tidak dapat diedit dari sheet ini.

### Editing State

- Form mempertahankan draft selama proses edit.
- Country selector dapat dibuka tanpa menutup sheet.
- Phone formatting berlangsung saat input.
- Layout tetap usable ketika keyboard terbuka.
- Konten dapat discroll jika tinggi layar terbatas.

### Saving State

- `Simpan Perubahan` menampilkan loading.
- Mencegah double submit.
- Jangan menutup sheet sebelum server mengonfirmasi keberhasilan.

### Success State

- Tutup bottom sheet.
- Sinkronkan data Profile Card.
- Tampilkan feedback singkat keberhasilan.

### Error State

- Pertahankan seluruh draft.
- Berikan pesan error inline bila tersedia.
- Pengguna dapat mencoba menyimpan kembali.

### Dismiss Behavior

- Close icon dan drag-down mengikuti perilaku modal existing.
- Jika draft berubah tetapi belum disimpan, lindungi dari kehilangan perubahan tidak sengaja dengan pola konfirmasi yang sesuai.
- Keyboard dan bottom safe area tetap diperhitungkan.

---

## 7. Visual Specifications

| Element | Specification |
|---|---|
| Profile Card | Compact white surface |
| Corner radius | Sesuai `DESIGN.md`, target sekitar 24dp |
| Avatar | 48–52dp |
| Edit action | Icon-only, minimum target 48dp |
| Stats | Three-column horizontal layout |
| Bottom Sheet | Rounded top corners |
| Sheet horizontal padding | 16–20dp |
| Text Field | 52–56dp |
| Country selector | Sekitar 112–122dp, responsive |
| Save button | Sekitar 52dp |
| Colors | Existing blue design tokens |
| Typography | Existing app typography |
| Layout | Mobile-first, adaptive |
| System UI | Preserve edge-to-edge |

Angka layout merupakan target desain; existing design tokens tetap diutamakan.

Jangan menggunakan hardcoded screen width. Gunakan constraints dan layout responsif.

---

## 8. Candidate Implementation Files

Mulai dengan inspeksi file berikut:

- `DESIGN.md`
- `lib/screens/profil_user_screen.dart`
- `lib/data/business_repository.dart`
- `lib/services/auth_session.dart`
- Komponen country picker pada existing booking flow.
- Shared widgets/theme terkait phone input dan bottom sheet.

Candidate files bukan instruksi untuk mengubah semuanya. Hanya sentuh file yang diperlukan setelah memahami struktur repository terbaru.

Jika formatter atau country selector sudah tersedia, gunakan kembali. Hindari duplikasi.

---

## 9. Explicit Non-Goals

Jangan mengerjakan:

- Redesign seluruh halaman Profil di luar card dan bottom sheet.
- Perubahan dynamic scenic header.
- Perubahan bottom navigation.
- Perubahan sistem autentikasi.
- Edit email.
- Backend API redesign.
- Database migration.
- Penggantian design system.
- Penambahan package jika solusi existing mencukupi.
- QA delegation.
- Automated tests atau full regression suite.
- Screenshot generation.
- Commit, push, atau deployment tanpa instruksi.

---

## 10. Implementation Directive

**Ponytails, execute this PRD immediately.**

1. Baca `DESIGN.md` dan kode profil saat ini.
2. Aktifkan TasteSkill frontend/mobile yang tersedia.
3. Delegasikan implementasi kepada `flutter_engineer`.
4. Implementasikan Compact Profile Card.
5. Implementasikan Edit Profile Bottom Sheet dengan international country selector.
6. Reuse existing international phone parsing, formatting, dan API integration.
7. Pertahankan dynamic scenic header, edge-to-edge, dan navigation.
8. Selesaikan implementasi langsung tanpa fase QA/testing.
9. Berikan ringkasan file yang berubah, fitur yang diimplementasikan, dan kendala aktual bila ada.

**Do not over-orchestrate. Do not spawn unnecessary agents. Do not expand scope.**

### Expected Result

Profile Card lebih ringkas, Edit Profil lebih nyaman digunakan di Flutter mobile, nomor telepon tampil dengan kode negara dan formatting internasional yang benar, serta semua perubahan dapat disimpan melalui integrasi Laravel yang sudah ada.

**Status akhir yang diinginkan: implementation complete, ready for user review.**