# PRD — Wisata Daerahku: Maps Integration V1

**Status:** Approved for implementation  
**Tanggal:** 3 November 2026  
**Target:** Flutter Android (emulator + perangkat fisik)  
**Area:** Halaman Detail Destinasi (pengunjung) dan fullscreen peta destinasi  
**Prioritas:** Adjustment UX dan perbaikan tautan navigasi; **tidak** mengubah booking/payment/auth.

## 1. Konteks dan masalah

Dalam Detail Destinasi Wisata Daerahku, peta OpenStreetMap dapat memperlihatkan titik destinasi, tetapi tombol **Buka Google Maps** menampilkan pesan **“Tidak dapat membuka peta”** pada emulator walaupun aplikasi Google Maps telah terinstal. Penyebab teknis belum terkonfirmasi; jangan mengasumsikan Google Maps tidak terpasang. Implementasi harus mengaudit URI, launcher, Android Intent/package visibility, penanganan kegagalan, dan validasi koordinat.

Pengunjung juga perlu mendapatkan pengalaman peta yang lebih jelas: pratinjau ringkas di Detail Destinasi, peta interaktif fullscreen saat diketuk, dan opsi **Lokasi Saya** berbasis GPS yang meminta izin hanya ketika dipilih.

## 2. Keputusan produk yang sudah disetujui (final)

1. **Navigasi Google Maps — Opsi A:** Menekan **Buka Google Maps** membuka **halaman petunjuk arah/rute** dari lokasi pengguna saat ini menuju koordinat destinasi. Prioritaskan aplikasi Google Maps Android; fallback ke Google Maps web/browser bila aplikasi tidak dapat dibuka. Menampilkan rute ≠ memulai navigasi turn-by-turn otomatis. Pengguna memulai navigasi melalui kontrol Google Maps.
2. **OpenStreetMap — Opsi B:** Card Detail Destinasi menampilkan **preview** OpenStreetMap, bukan peta yang langsung menangkap interaksi scroll. Ketukan pada preview membuka **halaman fullscreen interaktif**.
3. **Lokasi Saya — Opsi B:** Fullscreen OpenStreetMap **awalnya berpusat pada destinasi**; tombol **Lokasi Saya** akan meminta lokasi GPS **on demand** dan menggeser kamera peta ke posisi pengguna dengan marker berbeda. Peta destinasi harus tetap dapat digunakan tanpa izin lokasi.

## 3. Lingkup V1

### Termasuk

- Perbaikan tombol **Buka Google Maps** pada Detail Destinasi: URL/Intent directions yang benar, koordinat terverifikasi, penanganan kegagalan terstruktur, dan fallback browser.
- Card preview OpenStreetMap yang konsisten dengan komposisi Detail Destinasi dan token `DESIGN.md`.
- Navigasi preview → fullscreen → kembali ke detail tanpa reset scroll yang mengganggu.
- Fullscreen OpenStreetMap dengan zoom, pan, marker destinasi, tombol **Lokasi Saya**, tombol **Kembali ke Destinasi**, dan akses **Buka Google Maps** bila sesuai desain yang ada.
- Permission GPS runtime hanya saat pengguna menekan **Lokasi Saya**, termasuk penanganan GPS mati/izin ditolak/izin ditolak permanen.
- State loading dan error yang spesifik, tidak menutupi peta secara permanen.
- Responsif terhadap layar kecil, SafeArea, edge-to-edge Android, dan back navigation.

### Tidak termasuk

- Menambahkan sistem peta Google Maps embed atau Google Maps SDK ke Flutter.
- In-app turn-by-turn navigation atau menggambar polyline/rute di OpenStreetMap.
- Live tracking lokasi pengguna, background location, geofencing, atau menyimpan riwayat GPS.
- Mengubah mekanisme pemilihan titik koordinat di editor Admin/Superadmin; itu fitur terpisah.
- Migrasi/restrukturisasi backend atau penambahan API kecuali ditemukan data koordinat yang benar-benar belum terekspos.
- QA agent, full regression suite, test menyeluruh, atau refactor besar di luar scope.

## 4. User flow

### Flow A — Detail Destinasi → Google Maps

1. Pengunjung membuka Detail Destinasi.
2. Sistem menampilkan preview peta dan marker berdasarkan latitude/longitude destinasi **dari data destination Laravel** (bukan hardcode).
3. Pengunjung menekan **Buka Google Maps**.
4. Sistem memvalidasi bahwa koordinat lengkap, finite, dan dalam rentang lintang [-90,90], bujur [-180,180]. Angka `0,0` **bukan** otomatis berarti kosong: perlakukan kekosongan berdasarkan data/null dan validasi data, bukan asumsi.
5. Sistem membangun Google Maps Directions URL resmi, misalnya `https://www.google.com/maps/dir/?api=1&destination=<lat>%2C<lng>`, tanpa `origin` eksplisit sehingga Google Maps dapat mengambil current location bila tersedia. Jangan gunakan endpoint `/maps/search/` karena itu hanya menunjukkan titik, bukan rute.
6. Di Android, prioritaskan membuka Google Maps native. Untuk URL universal, Android dapat memilih Maps atau browser; jika ingin menjamin prioritas aplikasi, gunakan Intent eksplisit dengan package `com.google.android.apps.maps` **jika tersedia**, kemudian fallback HTTPS ke browser. Jangan menambah plugin berat jika mekanisme existing sudah bisa melakukan hal ini dengan aman.
7. **Tidak meminta izin lokasi dari Flutter** hanya untuk menekan tombol Google Maps; aplikasi Google Maps sendiri yang menangani lokasi pengguna. Jika lokasi belum tersedia di Google Maps, pengguna dapat diminta mengatur titik asal di Google Maps. Jangan mengklaim current location pasti terdeteksi.
8. Jika native gagal: coba fallback browser dengan URL yang sama. Jika keduanya gagal: tampilkan pesan yang bisa dipahami dan opsi **Coba Lagi**; jangan silently fail.

### Flow B — Detail Destinasi → Fullscreen OpenStreetMap

1. Card Detail Destinasi menampilkan preview yang menonjolkan koordinat destinasi, marker, dan affordance "Ketuk untuk lihat peta" atau icon expand.
2. Preview memakai tap target yang jelas dan **tidak** mencuri drag/scroll vertikal dari halaman detail.
3. Ketika diketuk, buka halaman fullscreen map dengan transisi sesuai `DESIGN.md`.
4. Awalnya kamera langsung **center pada koordinat destinasi** dengan zoom yang sesuai untuk melihat konteks area.
5. Pengunjung bisa pan, pinch zoom, dan menggunakan tombol zoom/reset jika sesuai style existing.
6. Tampilkan marker destinasi beserta nama tempat, kontrol kembali, dan atribusi OpenStreetMap yang sesuai.
7. Saat pengguna kembali, Detail Destinasi dan posisi scroll dipertahankan.

### Flow C — Fullscreen → Lokasi Saya

1. Saat fullscreen pertama dibuka, **tidak ada prompt permission lokasi**.
2. Pengunjung menekan tombol **Lokasi Saya** (ikon locate target; tooltip/semantics berbahasa Indonesia).
3. Cek layanan lokasi/GPS dan permission secara bertahap. Request permission hanya pada aksi ini jika belum granted.
4. Setelah permission didapat, ambil **satu lokasi saat itu** (one-shot dengan timeout wajar; gunakan last-known location hanya jika layak dan tidak terlalu usang serta dapat dijelaskan ke pengguna).
5. Tampilkan marker **biru** pengguna yang berbeda jelas dari marker destinasi, lalu animate kamera ke posisi tersebut. Marker destinasi tetap berada di peta dan bisa dicapai dengan tombol **Kembali ke Destinasi**.
6. Jika GPS mati, permission denied, denied forever, timeout, mock/position belum tersedia, atau provider bermasalah: tampilkan pesan kontekstual dan tindakan yang relevan (Aktifkan Lokasi / Buka Pengaturan / Coba Lagi). Jangan membuat peta destinasi tidak dapat digunakan.
7. Tidak ada continuous tracking/background permission. Lokasi tidak dikirim atau disimpan ke backend.

## 5. Interaksi dan spesifikasi UI

### Card preview

- Pertahankan peletakan area Lokasi pada Detail Destinasi, menyesuaikan visual desain immersive yang sudah disepakati, bukan merombak screen keseluruhan.
- Marker jelas, cukup padding, sudut rounded sesuai `DESIGN.md`, peta tetap terbaca dalam ukuran mobile.
- Overlay hint sederhana: icon expand + "Lihat peta"; tidak perlu mengulang tombol navigasi di area yang padat.
- Disabled/error visual bila koordinat tak valid, dengan copy spesifik "Lokasi destinasi belum tersedia".
- Gesture parent scroll tetap normal.

### Halaman fullscreen

- Edge-to-edge, SafeArea untuk kontrol (status/navigation bars tidak menutup UI).
- Top: back arrow dan judul singkat "Lokasi Destinasi" / nama destinasi sesuai ruang.
- Map memenuhi ruang dan mendukung pan/pinch zoom.
- Tombol floating kanan bawah: **Lokasi Saya** dan **Kembali ke Destinasi**; tidak bertabrakan dengan atribusi OSM atau bottom action.
- Jika tombol **Buka Google Maps** juga tersedia di fullscreen, gunakan service navigasi yang sama; hindari implementasi duplikat.
- Gunakan warna/typography/spacing/shadow/icons dari `DESIGN.md`, bukan membuat design system baru.

## 6. Kontrak data dan integrasi

- Sumber data: objek destinasi yang sudah diterima Flutter dari Laravel API. Baca field koordinat asli (`latitude`/`longitude` atau nama lokal yang existing), jangan membuat field baru berdasarkan asumsi.
- Konversi ke `double` aman; dukung nilai numerik/string hanya jika sesuai kontrak data existing, serta deteksi null/NaN/infinity/out of range.
- Preview, fullscreen, dan external directions **harus mengarah ke titik yang sama**; gunakan satu resolver/model koordinat dan satu handler Google Maps.
- Saat destinasi tidak punya lokasi valid: jangan buat URL invalid dan jangan gunakan current user location sebagai destination.
- Hindari panggilan Laravel baru hanya untuk membuka peta bila koordinat telah tersedia di detail.

## 7. Detail teknis untuk implementor

### Audit sebelum perubahan

- Inspeksi local working tree dan diff; jangan overwrite perubahan belum tercommit.
- Cari callback tombol **Buka Google Maps**, kode OpenStreetMap (dapat berupa map widget/WebView), dependency peta, launcher, `AndroidManifest.xml`, dan model `Destination`.
- Jangan menyimpulkan Google Maps tidak terpasang. Cek apakah kegagalan berasal dari pembentukan URI, `canLaunchUrl`, `launchUrl`, plugin, package visibility, atau error handling.
- Perhatikan: tampilan GitHub branch `main` yang terindeks bisa tertinggal dari working tree lokal pengguna. Di `main` publik 3 November 2026, `AndroidManifest.xml` sudah mencantumkan `ACCESS_COARSE_LOCATION` dan `ACCESS_FINE_LOCATION`, tetapi source map yang tampak di screenshot tidak ditemukan pada `detail_wisata_screen.dart` yang terlihat. **Gunakan state lokal sebagai sumber kebenaran utama.**

### Google Maps

- URL Google Maps Directions resmi `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>`; gunakan encoder URI yang benar; gunakan `origin` *omitted* untuk memanfaatkan origin paling relevan (sering lokasi perangkat), bukan literal "My Location" yang tidak terjamin.
- Tidak perlu Maps API key untuk Maps URLs.
- Pastikan `canLaunchUrl` (jika ada) tidak menjadi satu-satunya guard yang salah; pada Android 11+ package visibility dapat membuatnya `false` tanpa `<queries>` yang sesuai. Lebih baik lakukan attempt yang sesuai, tangani result/exception, dan fallback.
- Jika menggunakan explicit native Intent, tangani ketiadaan package/resolution secara aman, tanpa crash. Browser fallback harus benar-benar membuka browser eksternal (bukan melempar lagi ke native Maps lalu mengulang failure).
- Jangan mengirim `origin` dari lokasi Flutter yang memicu permission sebelum diperlukan; Google Maps bertanggung jawab untuk titik awal navigasi.

### OpenStreetMap dan GPS

- Reuse dependency, widget, dan tile source yang **sudah** ada. Jangan migrasi ke package lain tanpa alasan teknis kuat.
- Jika perlu package GPS, pilih dependency stabil dan seminimal mungkin; konfigurasikan Android runtime permission sesuai kebutuhan. `ACCESS_BACKGROUND_LOCATION` tidak diperlukan.
- Hindari pemanggilan `getCurrentPosition` saat init screen; hanya setelah onTap **Lokasi Saya**.
- Kendalikan lifecycle: guard `mounted`, cancellation/stale results (misalnya layar ditutup saat permintaan lokasi masih berjalan), loading state dan double taps.
- Attribution OpenStreetMap tetap terlihat; ikuti kebijakan tile usage/User-Agent jika memakai tile server publik.
- Tidak menambahkan analytics/transmisi koordinat pribadi.

## 8. Acceptance criteria / definisi selesai

1. Pada Android emulator dengan Google Maps terpasang, tombol **Buka Google Maps** membuka petunjuk arah menuju koordinat destinasi, bukan hanya membuka pin/search atau snackbar gagal.
2. Jika Google Maps native tidak bisa digunakan, browser fallback menampilkan petunjuk arah sesuai koordinat tujuan; jika tidak ada handler, pesan error jelas.
3. Menekan preview membuka fullscreen OSM. Peta awal berpusat pada destinasi, bukan current user location.
4. Preview tidak mengganggu scroll Detail Destinasi.
5. Fullscreen mendukung zoom/pan, tombol kembali, marker destinasi, dan tombol **Lokasi Saya**.
6. Izin GPS tidak muncul sebelum pengguna menekan **Lokasi Saya**.
7. Setelah izin dan GPS tersedia, marker lokasi pengguna muncul, kamera mengarah ke posisi pengguna, dan tombol reset mengembalikan kamera ke destinasi.
8. Semua kondisi permission/GPS gagal tidak merusak fullscreen map atau Detail Destinasi.
9. Koordinat invalid/missing tidak menghasilkan crash atau URL yang salah.
10. UI mengikuti `DESIGN.md` dan perubahan tidak menyentuh business flow booking, auth, payment, galeri, atau data admin.

## 9. Eksekusi dan batasan agent

- **Lead utama:** `flutter_engineer` dari `C:\Users\itsba\.codex\agents\` jika tersedia; jika tidak, Codex langsung implementasi.
- Maksimal satu agent spesialis. **Tidak perlu** `master_orchestrator`, `qa_engineer`, `security_auditor`, atau agent berlapis.
- Baca `DESIGN.md`, skill/task guidance lokal (termasuk "ponytails"/"tasteskill" hanya jika benar-benar tersedia dan relevan), dan source terbaru sebelum editing.
- **Langsung implementasi**, tidak berhenti di rekomendasi/pseudocode, tidak minta rangkaian keputusan baru.
- Jangan jalankan full test, full regression, atau mass analyze. Jika perlu, cukup cek fungsional manual ringan pada dua alur yang berubah (Google Maps dan fullscreen + Lokasi Saya); tidak perlu QA delegation.
- Jangan commit atau push otomatis kecuali pengguna meminta.

## 10. Repo referensi

- Flutter: https://github.com/koyotot/pami-wisata-daearahku
- Laravel API: https://github.com/joytimess/pami-wisata-daerahku-api
- Google Maps URLs: https://developers.google.com/maps/documentation/urls/get-started
- `url_launcher` Android package-visibility: https://pub.dev/packages/url_launcher
- `flutter_map` (jika relevan dengan implementasi aktual): https://docs.fleaflet.dev/

> **Catatan realitas:** Dokumen ini adalah spesifikasi implementasi, bukan klaim bahwa bug sudah diperbaiki atau bahwa semua file yang tampak pada screenshot telah ter-commit ke GitHub.
