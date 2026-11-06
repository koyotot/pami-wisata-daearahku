# Defect dan blocker V3

Tidak ada failure V3 baru pada 21 widget case final. Release global tetap BLOCKED.

## D-003, S2, OPEN: scanner stale scope

`operations_scanner_scope_regression_test.dart` tetap gagal dua case: same-generation role downgrade dan assignment revoke. Expected canConfirm false, actual true. `logs/scanner.txt` merekam assertion asli. Tidak ada confirm POST yang diuji atau klaim bypass backend. Scanner tidak diubah karena workstream keamanan di luar scope V3. Temuan menghalangi signoff release.

## D-004, S3, OPEN: kontras legacy

Defect warisan di `../admin-role1-post-relayout/results/DEFECTS.md`: metadata legacy #728099 pada #F5F8FD di bawah4.5:1. Tidak ada perubahan palette shared dalam V3. Guideline hub yang lulus tidak menutup defect seluruh aplikasi ini. Full contrast audit dan TalkBack belum dijalankan.

## B-001, OPEN baseline: scanner-return navbar test

`operations_shell_test.dart`, case `Admin center pushes full-screen scanner then returns to previous tab; back returns home`: expected tidak menemukan FloatingBottomNav, actual masih satu. Gagal pada source V3 dan source HEAD bbab506 yang diekstrak terpisah. Bukti `logs/regression-final.txt` dan `logs/baseline-failures.txt`. Belum menentukan perbaikan source/harness; assertion dipertahankan.

## B-002, OPEN baseline: description wrapping test

`detail_description_test.dart`, case `description toggle follows actual four-line overflow`, line65: expected tidak ada Baca selengkapnya, actual satu. Direproduksi identik pada source HEAD terpisah. Ini failure lokal pada ekspektasi wrapping; belum diklasifikasikan sebagai defect perangkat. Tidak melemahkan assertion atau mengubah layout deskripsi dalam V3.

## V3-F01, FIXED: text-scale overflow editor

QA membuka editor dari sheet pada layar kecil scale1.3 dan menemukan overflow rating header/save. Existing editor memakai Wrap untuk rating serta Flexible/minHeight pada tombol simpan. Regresi route create/edit/gallery dan final21 case lulus. Bukti source `tambah_wisata_screen.dart` dan `logs/v3-widget-tests-capture.txt`.

## V3-F02, FIXED: risiko foto privat di route fullscreen

Review independen menemukan gallery fullscreen tidak memiliki invalidasi scope. Dalam adminPreview, fullscreen dinonaktifkan pada boundary DestinationHeroGallery; carousel tetap aktif. Visitor default tidak berubah. Test memeriksa tap foto tidak membuka fullscreen dan same-generation revoke menghapus detail. Tidak ada viewer privat terpisah yang bisa tetap menampilkan data lama.

## V3-B01, BLOCKED: Android Admin dan backend live

Emulator tersedia tetapi data terisolasi/sesi Admin uji belum diverifikasi. Tidak ada login atau mutable E2E live. Host loopback dan APP_ENV development bukan bukti dataset aman. Memerlukan lingkungan terisolasi beserta sesi Admin uji sebelum live mutation QA.

## V3-B02, BLOCKED: referensi PNG dan media aktual

Empat PNG preview, README paket dan ZIP tidak tersedia pada checkout. HTML suffix(1) dan PRD user tersedia. Screenshot hasil QA adalah fixture native Flutter. Data media asli, tile OSM, dan tulisan "Galeri telah berubah" dalam gambar belum dapat ditelusuri. Tidak mengklaim perbandingan pixel atau menyembunyikan konflik409.

## V3-L01, NOT VERIFIED: batas coverage

TalkBack/VoiceOver, keyboard sistem Android, tile OSM aktual, authenticated favorite write melalui singleton visitor, dan live assignment revoke tidak diuji. Tombol favorit visitor tetap enabled dan booking route terbuka dalam widget test; suite favorite API/state existing lulus. Bukti ini tidak sama dengan authenticated device E2E.
