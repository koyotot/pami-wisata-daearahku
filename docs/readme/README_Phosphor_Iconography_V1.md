# Wisata Daerahku — Total Phosphor Icons V1

## Isi paket

- `PRD_Wisata_Daerahku_Total_Phosphor_Iconography_V1.md` — spesifikasi lengkap scope lintas role, API package, design tokens, semantik mapping, pengecualian, dan batas safety.
- `PROMPT_SAKTI_Codex_Total_Phosphor_Iconography_V1.txt` — instruksi langsung implementasi Codex, pengaturan agents, dan discovery skill aktual yang terpasang.
- `ICON_MIGRATION_INVENTORY_V1.md` — inventaris audit GitHub pada 56 file UI (394 referensi literal Material icon + 2 custom nav icon painters); implementasi harus melakukan scan lokal seluruh repo.

## Cara eksekusi

1. Ekstrak paket ini ke root: `C:\laragon\www\pami-mobile\pami-wisata-daearahku`.
2. Jalankan Codex di root repository itu.
3. Tempel seluruh isi `PROMPT_SAKTI_Codex_Total_Phosphor_Iconography_V1.txt` dalam sesi Codex.
4. Periksa laporan perubahan akhir Codex sebelum commit. **Tidak ada auto commit/push.**

## Batasan penting

- Target Phosphor `phosphor_icons: ^3.0.1` dengan kompatibilitas Flutter 3.43+; jika SDK lokal tak cocok, Codex harus melaporkan blocker, bukan menebak versi.
- Tidak ada QA / regression / tests / `flutter analyze` / run / build, sesuai instruksi pemilik proyek. `flutter pub get` untuk dependency, `dart format`, dan `git diff --check` merupakan aktivitas implementasi yang diperbolehkan.
- Backend/API, login, klaim booking, QR confirmation, V3 Kelola + Preview read-only, dan fitur role 0/1/2 tidak boleh berubah.
- Nama icon Phosphor yang ada pada tabel semantik adalah konsep; nama getter Dart final perlu diverifikasi terhadap dependency installed.

## Source links

- Source project: https://github.com/koyotot/pami-wisata-daearahku
- Remote HEAD audit: `3fbf22b6a70c11dd4544c64db7550e484c64e5c7`
- Package: https://pub.dev/packages/phosphor_icons
- Catalog: https://phosphoricons.com

Paket ini **dokumen instruksi**, belum mengubah kode aplikasi.
