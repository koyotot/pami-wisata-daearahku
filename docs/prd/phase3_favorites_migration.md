# Phase 3: favorit Laravel dan data legacy

Favorit aktif menggunakan `BusinessRepository` dan sesi Bearer Laravel. Daftar
`GET favorites` berpaginasi; `PUT favorites/{destination}` dan
`DELETE favorites/{destination}` memakai GUID destinasi Laravel. Backend
menentukan pemilik dari token, dan PUT bersifat idempoten.

## Inventaris legacy

Sebelumnya detail membaca, menambah, dan menghapus dokumen koleksi Firestore
`wisataTersimpan`; profil membaca koleksi yang sama untuk pratinjau dan daftar.
Dokumen menyimpan `userId` Firebase, `wisataId`, `namaWisata`, `lokasi`,
`kategori`, `imagePath`, dan `savedAt`. Firestore tetap digunakan oleh fitur
lain di luar migrasi ini; koleksi dan data historis tidak dihapus.

Tidak ada pemetaan terverifikasi dari Firebase UID ke pengguna Laravel atau
dari ID dokumen wisata Firebase ke GUID destinasi Laravel. Versi campuran
bahkan dapat menyimpan GUID Laravel di `wisataId`. Kecocokan nama atau email
tidak membuktikan identitas atau kepemilikan. Karena itu favorit historis belum
dipindahkan dan tidak diimpor otomatis. Migrasi historis memerlukan pemetaan
identitas dan destinasi yang dapat diverifikasi serta proses terpisah.

Phase 4 tetap memerlukan audit kontrak booking dan kuota, termasuk idempotency,
status, otorisasi dan pengujian terhadap backend nyata; Phase 3 tidak
memvalidasi alur tersebut.
