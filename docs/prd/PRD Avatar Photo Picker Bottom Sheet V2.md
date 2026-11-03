# PRD — Avatar Photo Picker Bottom Sheet V2

**Project:** Wisata Daerahku  
**Platform:** Flutter — Android  
**Repository:** https://github.com/koyotot/pami-wisata-daearahku  
**Design Reference:** `DESIGN.md` (authoritative)  
**Primary Agent:** `flutter_engineer`  
**Design Skill:** `taste-skill-frontend` / mobile UI skill jika tersedia  
**Scope:** UI-only refinement  
**Status:** Approved for Direct Implementation

---

## 1. Background

Komponen pemilihan foto avatar saat ini menggunakan bottom sheet vertikal yang terdiri dari:

1. Pilih dari Galeri
2. Ambil dengan Kamera
3. Gunakan Avatar Default

Meskipun seluruh fungsi sudah tersedia, komponen ini belum memiliki visual hierarchy yang sesuai dengan standar desain Wisata Daerahku V4.

Permasalahan utama:

- Ketiga opsi memiliki bobot visual yang sama.
- Tidak ada pemisahan antara tindakan memilih foto dan mengembalikan avatar default.
- Ikon dan teks terlihat terlalu sederhana.
- Spacing dan alignment kurang terstruktur.
- Tidak ada deskripsi singkat untuk setiap tindakan.
- Komponen terlihat seperti menu generik Android, bukan bagian dari design system aplikasi.

**Tujuan:** Mengubah presentasi bottom sheet tanpa mengubah mekanisme pemilihan, cropping, upload, penghapusan, maupun pemulihan avatar yang sudah diimplementasikan.

## 2. Proposed Design — Modern Photo Action Sheet

### 2.1 Bottom Sheet Container

Gunakan modal bottom sheet yang muncul dari bagian bawah layar.

Ketentuan visual:

- Lebar penuh mengikuti viewport perangkat.
- Top corner radius mengikuti `DESIGN.md`, dengan target visual sekitar 24 px.
- Background menggunakan surface color dari design system.
- Padding horizontal sekitar 20 px.
- Padding vertikal proporsional.
- Mengikuti safe area dan gesture navigation Android.
- Tidak menampilkan navigation bar aplikasi di atas bottom sheet.
- Animasi slide-up yang halus dan konsisten dengan UI aplikasi.
- Backdrop menggunakan scrim transparan.

### 2.2 Header

Struktur:

**Ubah Foto Profil**  
Pilih cara untuk memperbarui foto profilmu.

Tampilan:

- Drag handle horizontal di posisi atas tengah.
- Title menggunakan typography heading dari `DESIGN.md`.
- Subtitle menggunakan secondary text color.
- Tombol tutup berbentuk circular icon button pada kanan header.
- Jarak antarunsur konsisten.

### 2.3 Primary Actions — Two-Column Grid

Galeri dan Kamera ditampilkan sebagai dua action card berdampingan.

**Card 1 — Galeri**

- Icon: `images` / gallery outline.
- Label: `Galeri`.
- Subtitle: `Pilih dari perangkat`.
- Icon container: rounded square dengan primary blue tint.
- Tap action: memanggil gallery image picker existing.

**Card 2 — Kamera**

- Icon: `camera` outline.
- Label: `Kamera`.
- Subtitle: `Ambil foto baru`.
- Icon container: rounded square dengan primary blue tint.
- Tap action: memanggil camera capture existing.

Ketentuan:

- Kedua card memiliki ukuran dan tinggi identik.
- Border tipis menggunakan neutral border token.
- Radius card mengikuti desain existing.
- Konten card center aligned.
- Area card sepenuhnya clickable.
- Minimum touch target 48 dp.
- Pressed state menggunakan subtle primary tint.
- Tidak menggunakan elevation atau shadow berlebihan.
- Layout responsif terhadap ukuran dan text scaling perangkat.

### 2.4 Secondary Action — Default Avatar

Tempatkan di bawah primary action cards.

Struktur:

- Divider horizontal.
- Icon `rotate-ccw` / restore.
- Label `Gunakan Avatar Default`.
- Teks dan ikon menggunakan secondary color.
- Center alignment.
- Touch target mencakup seluruh area action.

Ketentuan:

- Tidak menggunakan warna merah karena restore default bukan destructive deletion.
- Jika avatar sudah menggunakan default, sembunyikan action ini.
- Jika avatar custom sedang digunakan, tampilkan action ini.
- Pertahankan existing confirmation behavior sebelum restore jika sudah tersedia.
- Jangan membuat implementasi restore avatar baru.

## 3. Interaction Behavior

### 3.1 Open Bottom Sheet

Ketika pengguna memilih aksi perubahan foto pada halaman Profil atau Edit Profil:

1. Bottom sheet muncul dengan animasi slide-up.
2. Background halaman tetap terlihat dengan scrim.
3. Seluruh opsi langsung terlihat tanpa scrolling pada ukuran layar normal.

### 3.2 Select Gallery

1. Pengguna menekan card Galeri.
2. Bottom sheet ditutup.
3. Existing gallery picker dipanggil.
4. Existing interactive crop 1:1 tetap digunakan.
5. Existing avatar upload flow diteruskan.

### 3.3 Select Camera

1. Pengguna menekan card Kamera.
2. Bottom sheet ditutup.
3. Existing camera capture flow dipanggil.
4. Existing crop 1:1 diteruskan.
5. Existing upload flow tetap berjalan.

### 3.4 Restore Default

1. Pengguna memilih Gunakan Avatar Default.
2. Bottom sheet ditutup.
3. Existing reset/confirmation flow diteruskan.
4. Avatar kembali menggunakan state default berdasarkan mekanisme yang sudah tersedia.

### 3.5 Dismissal

Bottom sheet dapat ditutup melalui:

- Tombol X di header.
- Tap area backdrop.
- Swipe down.
- Android system back.

Dismissal tidak memodifikasi avatar maupun draft foto.

### 3.6 Interaction Safety

- Hindari double-tap yang menyebabkan picker terbuka beberapa kali.
- Tidak membuka gallery atau camera dua kali dalam satu aksi.
- Pertahankan penanganan permission, cancel, dan error existing.
- Jangan mengubah mekanisme cropping ataupun upload state.

## 4. Component Architecture

Prioritaskan reusable widget yang tidak memuat business logic.

Suggested component:

`AvatarPhotoPickerSheet`

Responsibilities:

- Render header.
- Render gallery action card.
- Render camera action card.
- Render default avatar action.
- Mengelola visual interaction state.
- Meneruskan aksi melalui callbacks.

Suggested public interface:

```dart
AvatarPhotoPickerSheet(
  hasCustomAvatar: bool,
  onGallerySelected: ...,
  onCameraSelected: ...,
  onDefaultAvatarSelected: ...,
)
```

Signature final mengikuti pola arsitektur repository.

Jika existing component sudah memiliki tanggung jawab yang sama, refactor komponen tersebut. Jangan membuat duplicate widget tanpa alasan.

Pisahkan UI presentation dari avatar business logic.

## 5. Design System Compliance

Wajib membaca `DESIGN.md` sebelum modifikasi.

Gunakan:

- Existing color tokens.
- Existing typography.
- Existing spacing conventions.
- Existing icon system.
- Existing border radius conventions.
- Existing animation patterns.

Jangan membuat design system baru atau memperkenalkan package UI hanya untuk bottom sheet.

Pastikan komponen konsisten dengan visual aplikasi Wisata Daerahku V4.

## 6. Implementation Scope

Repository:

https://github.com/koyotot/pami-wisata-daearahku

File kandidat utama:

- `lib/screens/profil_user_screen.dart`
- `lib/screens/widgets/profile_avatar.dart`

Jika diperlukan, tambahkan reusable widget di folder widgets sesuai struktur repository.

File aktual harus ditentukan dengan membaca implementasi existing, bukan berdasarkan asumsi nama file.

Perubahan hanya boleh menyentuh bagian yang diperlukan untuk mengganti tampilan avatar photo picker.

## 7. Out of Scope

Jangan mengubah:

- AvatarService Laravel.
- Avatar API endpoint.
- Database atau migration.
- Mekanisme upload foto.
- Avatar cropping 1:1.
- Gallery/camera image source.
- Avatar preview overlay.
- Avatar caching.
- Profile editor layout.
- Session handling.
- Avatar restore business logic.
- Authentication.
- Navigation architecture.

Tidak ada perubahan backend.

Tidak ada perubahan payload API.

Tidak ada perubahan business rules avatar.

## 8. Implementation Constraints

- Implementasi langsung, tanpa fase eksplorasi tambahan.
- Gunakan satu primary agent: `flutter_engineer`.
- Gunakan mobile design skill yang tersedia secara selektif.
- Tidak perlu orchestration multi-agent.
- Tidak perlu `qa_engineer` atau `security_auditor`.
- Tidak membuat test baru.
- Tidak menjalankan automated testing.
- Tidak menjalankan regression testing.
- Tidak menjalankan full Flutter test suite.
- Tidak menjalankan full Flutter analyze.
- Tidak melakukan audit atau review berkepanjangan.
- Tidak commit, push, atau deploy otomatis.

## 9. Definition of Done

Implementasi dianggap selesai ketika:

- Bottom sheet lama telah diganti dengan Modern Photo Action Sheet.
- Header dan drag handle sudah sesuai konsep.
- Galeri dan Kamera tampil dalam dua equal-width action card.
- Action Avatar Default terpisah sebagai secondary action.
- Semua callbacks menggunakan existing implementation.
- Dismissal berfungsi sesuai interaksi native.
- UI konsisten dengan `DESIGN.md`.
- Tidak ada perubahan business logic avatar atau backend.

**Final deliverable:** Implementasi source code Flutter beserta ringkasan file yang berubah. Tanpa QA, testing, dan regresi.