# PRD — Wisata Daerahku: Flutter Admin & Superadmin Visual Fidelity Refinement V1

**Status:** IMPLEMENTATION BRIEF — desain telah disetujui pengguna, implementasi UI saja.  
**Tanggal:** 5 November 2026  
**Project:** Wisata Daerahku · Flutter Android · role 1 Admin & role 2 Superadmin  
**Tujuan:** Menyamakan tampilan Flutter Phase 1A yang **sudah berfungsi dengan Laravel** dengan **interactive wireframe yang sudah ACC**. **Bukan** rebuild Phase 1A dan **bukan** proyek FigCraft baru.  
**Dokumen visual sumber:** `docs/design/Wisata-Daerahku-Admin-Superadmin-Interactive-Wireframe-APPROVED.html` (**HARUS DIBUKA, DICOBA, dan dibaca bersama CSS/JS-nya**).  
**Handoff sumber:** `docs/phase-1a-flutter-handoff.md` (implementasi lokal).  
**Repos:** `https://github.com/koyotot/pami-wisata-daearahku` (Flutter); `https://github.com/joytimess/pami-wisata-daerahku-api` (Laravel **read-only**).  

> **KONTRAK UTAMA:** UI Flutter saat ini benar secara fungsi/fetch, tetapi visual pada screenshot emulator tidak cukup setia terhadap interactive wireframe. **Perbaiki visual, bukan logika.** Jangan mengisi angka dummy, jangan menyulap `null` menjadi `0`, jangan merusak API request, auth, claim, QR, maupun state ownership.

---

## 1. Urutan sumber kebenaran

1. **Perilaku/UI interaktif yang sudah disetujui:** file HTML dalam paket ini. Kode `A00–A09`, `E00–E08`, `X01–X08`, tampilan, state, dan click-through-nya menjadi **kontrak visual**. Dibuka di browser offline. Sampel angka dalam HTML adalah **DESIGN ONLY**, bukan data untuk dipindahkan ke aplikasi.
2. **Skill desain wajib:** `design-taste-frontend/SKILL.md` yang **terpasang secara lokal di komputer pengguna**, **termasuk seluruh references yang skill itu instruksikan untuk dibaca**. Tidak cukup hanya menyebut skill. Cari path aktual, baca, dan ikuti aturan yang berlaku untuk Flutter. Contoh jalur pencarian, **bukan bukti keberadaan**: `C:\Users\itsba\.agents\skills\design-taste-frontend\SKILL.md`, `C:\Users\itsba\.codex\skills\design-taste-frontend\SKILL.md`, atau jalur skill dari registry Codex yang aktif. Bila tidak ditemukan, **hentikan sebelum mengedit dan laporkan** — jangan mengarang isinya atau diam-diam melewatkan.
3. **Design system Flutter**: `docs/DESIGN.md`, `lib/theme/app_colors.dart`, `lib/screens/admin_common.dart`, kode visitor floating nav existing, dan layar operasi existing. **Perhatikan `DESIGN.md` merupakan audit statis lama**; source Flutter runtime yang terbaru menyelesaikan kontradiksi aktual.
4. **Sumber implementasi dan keamanan:** `docs/phase-1a-flutter-handoff.md`, lalu kelas Flutter actual: `operations_navigation_shell.dart`, `operations_dashboard.dart`, `operations_reports.dart`, `operations_filters.dart`, `operations_presentation.dart`, `operations_queue_screen.dart`, `operations_booking_screen.dart`, `operational_models.dart`, `approval_queue_state.dart`.
5. **Referensi negatif:** screenshot emulator `image(20261105-022059).png` (layout abu-abu pucat, filter outline panjang, KPI tanpa ikon/hierarchy), bukan target desain. Perbaiki pola tersebut pada UI, tetapi **hormati state asli**: screenshot menunjukkan role 1 **tanpa penugasan**, yang seharusnya memunculkan X01, bukan KPI contoh 128/12/86.

**Aturan konflik:** HTML menentukan tampilan dan interaksi; Laravel menentukan data/hak akses dan status operasional; Flutter existing menentukan implementasi yang aman. Jangan mengambil nilai atau hak akses dari mockup HTML.

## 2. Skill dan dokumen referensi — wajib nyata, bukan label kosmetik

Sebelum mengedit satu file Dart:

- Temukan dan **baca** `design-taste-frontend/SKILL.md`; ikuti urutan baca file referensi di skill (misal reference layout/type/spacing, interaction, Flutter applicability jika ada). Jangan mengasumsikan nama file referensi yang belum ditemukan. Catat singkat skill path aktual dan references yang dibaca dalam laporan akhir.
- Baca `docs/DESIGN.md` dan source Flutter yang digunakan (`lib/theme/app_colors.dart`, `lib/widgets/floating_bottom_nav.dart`, layar operasi terkait), bukan sekadar daftar nama berkas.
- Buka HTML offline, switch role, pilih screen ID, cek contoh A00/E00 dan edge state X01; gunakan eksplorasi tambahan untuk flow yang akan diubah (claim/reassign). **Jangan generate FigCraft, desain gambar baru, atau membuat interpretasi baru.**
- Prinsip pendukung yang telah direview saat penulisan PRD: `visualization-strategy-and-critique` dan `dashboards-and-real-time-visualization` (hierarki informasi, scan-first mobile dashboard, metrik/stale state jelas), plus praktik minimal YAGNI dari `ponytail`. **Tidak menggantikan skill wajib design-taste yang perlu dibaca langsung di Codex lokal.**

## 3. Scope, target visual, dan acceptance observasional

### 3.1 A00 — Beranda Admin (highest priority)

**Hero:** background biru brand `#1976D2` sampai deep blue `#1558B0`, scenic pegunungan halus, nama produk/role, judul putih dan subtitle jelas, notifikasi di sudut header. Hero **compact**, bukan setengah tinggi layar; status bar/safe area harus benar. Gunakan `CustomPainter`/dekorasi Flutter existing jika tersedia, jangan menambah aset gambar atau dependency hanya untuk gunung.

**Struktur vertikal:** `hero → metadata kecil jujur → segment Destinasi | Kinerja Saya → selector card dengan pin/lokasi dan chevron → KPI grid 2×2 → Action Center kuning lembut → chart card dengan periode/legend → CTA antrean`. Referensi hierarki dan spacing adalah file HTML. Pastikan scroll dan navbar tidak menutupi konten, dan **Action Center bukan sekadar teks di bawah dashboard**.

**KPI card:** putih, radius konsisten, border lembut, ikon biru, angka kuat, label dan sub-label ringkas; angka dan unit dari Laravel. Kartu finansial `— / Belum tersedia · DOKU belum aktif`, **jangan Rp0**. Hindari semua kartu menyampaikan bobot yang sama jika konteks berbeda. Responsif pada 360×800 dan 393×852.

**Segment dan selector:** selector terintegrasi seperti card, bukan outline pill besar dan terpisah seperti screenshot emulator; segmented control aktif jelas, tidak terlalu rapat.

**Chart:** grafik booking dibuat (basis created UTC) dalam card, bukan sekadar judul di area kosong; jika data server sungguh kosong tampilkan empty graph state di dalam card, bukan grafik ilustratif. Jangan menyamakan booking dibuat dengan tiket terjual/kunjungan.

### 3.2 X01 — Dedicated zero-assignment state (highest priority)

- Jika backend menyatakan role 1 tidak punya destinasi assigned, tampilkan **dedicated X01**, bukan dashboard normal dengan empat KPI nol.
- Judul `Belum ada destinasi`, penjelasan singkat, ilustrasi/icon kontekstual, arahan hubungi Superadmin. Tidak ada kebocoran data global atau fallback ke public catalog untuk scope.
- Jangan mengaktifkan CTA approval/scan/destination yang butuh assignment ketika tidak berizin. Tetap boleh navigasi ke Profil dan tindakan aman yang telah didukung existing.
- Mode `Contoh terisi` dalam HTML digunakan **untuk memahami A00 normal**, bukan untuk mengisi runtime production.

### 3.3 E00 — Executive Home (second priority)

- Identitas visual **satu keluarga** dengan Admin (hero biru, kartu, typography, navigasi), tetapi **information architecture berbeda**: scope global, KPI global, exception/Action Center, team decision trend, destination/staff drilldowns, financial unavailable.
- Filter global dan admin drilldown dari sumber server. Jangan mengganti judul A00 dengan `Superadmin` lalu mengulang layout yang sama.
- Jangan menampilkan auditor/leaderboard/staff performance yang tidak didukung API. E02 staff list hanya menyajikan data yang tersedia; filtered `approvals?admin_guid` untuk detail SLA.

### 3.4 A01–A09, E01–E08 — Visual consistency pass

| ID | Kontrak visual wajib | Perilaku fungsional yang harus dipertahankan |
|---|---|---|
| A01 | Personal KPI yang jelas, approval/rejection, status claim, response/SLA nullable | Metrik pribadi bukan agregat tim |
| A02 | Filter card/bottom sheet, penugasan aktif, Apply/Reset | Scoped destination + from/to paired |
| A03 | Queue card: booking, destinasi, urgency, status owner, deadline, CTA | Paginated Laravel non-PII queue |
| A04 | Detail ringkas; claim available/mine/other; confirm approve/reject/release | 15-min claim, 24-h original SLA, authoritative refresh |
| A05 | Konflik 409 kontekstual dan jalur muat ulang | Jangan auto-submit atau retry dengan idempotency key baru |
| A06 | Action Center action-first, kebutuhannya terbaca sekilas | Urgency dari server, bukan AI/LLM |
| A07 | Kapasitas, alokasi, remaining, confirmed; progress bar semantik | Unit berbeda; null bukan zero |
| A08 | Entry scanner dengan alur QR singkat | Reuse kamera scanner existing fullscreen |
| A09 | Financial unavailable card + disabled empty values | Tidak ada DOKU/payment mutation |
| E01 | Destination comparison dengan bar/progress, label metrik | Tidak ada ranking fake revenue |
| E02 | Staff card + detail query sesuai sumber | Staff per-SLA tidak diinvent dari aggregate |
| E03 | Global queue, filter, claim owner & deadline | Laravel scope/role 2 authority |
| E04 | Form target Admin assigned, alasan wajib, CTA gated | Reassign UUID/idempotency/422/409 tetap |
| E05 | Management entry points, list assignment | Accounts, categories, quotas, facilities existing terjangkau |
| E06 | Dedicated unavailable (API global audit timeline belum ada) | Tidak ada histori audit palsu |
| E07 | Executive financial unavailable | `null` tetap `—` |
| E08 | Global Action Center + link ke queue/detail | Prioritas dari backend, tidak diada-adakan |

### 3.5 Shared state X01–X08 — jangan diseragamkan jadi kartu generik

| State | State spesifik | Tampilan dan CTA |
|---|---|---|
| X01 | Admin no assignment | Dedicated no-assignment + arahan hubungi Superadmin |
| X02 | No pending queue | Empty state positif + Beranda/refresh |
| X03 | Loading | Skeleton ukuran wajar; jangan gunakan KPI 0 palsu |
| X04 | Network/stale | Error + retry, snapshot lama diberi label stale, mutasi diblokir sampai reread |
| X05 | Filter no result | Pesan scoped empty + Reset Filter |
| X06 | Access revoked | Hapus data privat; signpost akses berubah dan validasi ulang |
| X07 | Payment unavailable | `—`; DOKU belum aktif, tanpa nominal palsu |
| X08 | Claim owned/expired/required/409 | Status konflik + manual re-read, jangan auto approve |

### 3.6 Floating bottom navbar role 0 — perubahan **tidak boleh menghancurkan sesuatu yang sudah benar**

- Komponen existing `lib/widgets/floating_bottom_nav.dart` telah dipakai role 0 dan digunakan bersama secara opsional; **jaga constructor default role 0 dan icon painter/semantics-nya**. Gunakan tampilan yang telah dihasilkan Phase 1A bila sudah matching, **tidak perlu redesign**.
- Role 1: **Beranda / Booking / center Scan QR / Destinasi / Profil**. Center membuka kamera fullscreen melalui route kemudian kembali ke tab sebelumnya, bukan meletakkan scanner dalam `IndexedStack` aktif.
- Role 2: **Ringkasan / Operasi / center Analitik / Kelola / Profil**. Center adalah tab Analitik, bukan kamera.
- **Ikon saja** secara visual; tooltip/semantics untuk label. Floating translucent blur, elevated blue center, shadow halus, selected state sesuai role 0, touch area >=48dp, SafeArea, navbar hilang ketika keyboard muncul, dan konten scroll punya bottom inset.

## 4. Constraints non-visual: tidak disentuh

- Role 0 `MainNavigationScreen`, auth email/Google/OTP, user profile, galeri, payment eligibility, booking user, QR ticket, maps, favorites dan review existing **out-of-scope**.
- **Laravel API code, DB/migration, `.env`, DOKU settings, `APPROVAL_CLAIM_MODE=compat`, payments, webhooks, ledger** **tidak boleh diubah**.
- **Tidak mengubah network/business-state**: `AuthSession`, role/session generation, 403/404 purge, HTTP 409 reconciliation, state stale, original request idempotency-key retention, own-active-claim guard, callback booking decision, reassign eligibility. UI harus membaca state existing; boleh menyesuaikan presentational widget atau local UI state jika mutlak diperlukan untuk tampilan.
- Jangan tambah Flutter dependency, package font, native plugin, atau proyek dashboard/web terpisah. Gunakan widget komposisi yang sudah ada; extract hanya jika reuse nyata untuk 2+ layar, bukan speculative abstraction.
- Null semantics: `gross_revenue`, `net_revenue`, `gateway_fees`, `refunds`, `settlement`, `attendance_rate`, `no_show_count`, `eligible_tickets` tidak dipaksa jadi nol. Status financial **unavailable**.
- Semua sample angka di HTML (128/12/86 dll) **tidak boleh ada sebagai hardcoded KPI runtime**. `booking_number` visual pada HTML adalah fixture; operasi sesungguhnya memakai booking GUID.

## 5. Lokasi source yang ditargetkan — hemat perubahan

**Prefer presentational/UI files (existing Phase 1A):**

- `lib/screens/operations_dashboard.dart` — A00/A01/E00.
- `lib/screens/operations_presentation.dart` — shared UI components/empty state/card/hero jika ada.
- `lib/screens/operations_reports.dart` — A06/A07/A08/E01/E02/E06/E08.
- `lib/screens/operations_filters.dart` — A02.
- `lib/screens/operations_queue_screen.dart` — A03/E03.
- `lib/screens/operations_booking_screen.dart` — A04/A05/E04.
- `lib/screens/operations_navigation_shell.dart` — visual/insets/layout shell bila benar-benar perlu.
- `lib/widgets/floating_bottom_nav.dart` **hanya jika** perlu visual fix dan tetap backward-compatible dengan role 0.

**Jangan mengubah** `lib/data/operational_models.dart`, `lib/data/approval_queue_state.dart`, `lib/data/business_repository.dart`, `lib/data/admin_state.dart`, `lib/services/auth_session.dart`, `lib/services/api_client.dart` hanya untuk mempercantik UI. Bila visual memerlukan metadata yang tidak tersedia, pertahankan empty/unavailable tanpa mengutak-atik kontrak.

## 6. Eksekusi bertahap, tanpa scope creep

**Tahap 0 (read-only):** Cari & baca seluruh skill+references `design-taste-frontend`, lalu HTML A00/E00/X01 serta state yang relevan; lihat source Flutter lokal/handoff. Laporkan hanya jika skill atau HTML tak ditemukan. **Tidak perlu audit repo backend lagi**.

**Tahap 1 (visual core):** A00 normal + dedicated X01. Hero scenic, selector, segmented tabs, KPI icons, Action Center, chart card, honest data state. Jangan ubah logika fetch.

**Tahap 2 (executive):** E00 menggunakan komponen yang sama tanpa kehilangan global hierarchy. Pastikan adaptasi visual tidak membuat E00 menyalin A00.

**Tahap 3 (consistency):** Samakan komponen untuk layar A01–A09, E01–E08, dan X02–X08 sesuai HTML; reuse yang sudah baik, jangan rewrite besar. Pertahankan E06 unavailable dan center nav sesuai role.

**HARD STOP:** setelah perubahan UI selesai, buat handoff singkat. Tidak perlu PRD tambahan, tidak melakukan Phase 1B, Phase 2, FigCraft, commit atau push.

## 7. Batas penggunaan Codex / subagents

**Root aturan:** `C:\Users\itsba\.codex\Agents.md` jika ada, agent definitions di `C:\Users\itsba\.codex\agents\`. File kandidat: `flutter_engineer.toml` untuk implementasi UI. `security_auditor.toml` **hanya bila tersentuh boundary auth/claim (idealnya tidak)**. **Jumlah subagents total maksimum DUA**; untuk visual-only ini dianjurkan **satu atau nol**. **Jangan spawn** `figcraft_designer`, `figcraft_critic`, `qa_engineer`, `master_orchestrator`, atau subagents lain hanya untuk memenuhi kuota. Sesi Codex utama tetap owner orkestrasi.

## 8. PERINTAH LARANGAN VERIFIKASI OTOMATIS — diminta pengguna

**Pengguna secara eksplisit tidak menginginkan tahap Flutter analyze, QA, testing, ataupun regresi dalam tugas visual ini.** Jangan melakukan atau merencanakan:

- `flutter analyze`, `dart analyze`, `flutter test`, `dart test`, widget tests, integration tests, regression tests, E2E, full suite, lint sweep.
- QA cycle, security audit cycle, screenshot diff automated, visual regression loop, build APK (`flutter build`), auto-run emulator, atau workflow pengujian lain.
- `dart format` massal / perubahan file tidak terkait, commit, push, merge, deploy.

**Artinya:** serahkan kode UI tanpa klaim telah diverifikasi otomatis. Boleh tulis catatan `BELUM DIUJI atas permintaan pengguna`. Review visual final dilakukan **pengguna secara manual** setelah handoff, bukan putaran otomatis Codex.

## 9. Handoff akhir yang wajib singkat

Jelaskan: (1) skill actual dan refs yang dibaca; (2) file yang diubah dan fitur visual yang dibenahi; (3) ID layar yang sesuai / masih terbatas; (4) fitur non-visual yang sengaja tidak disentuh; (5) visual yang memerlukan review manual dari pengguna; (6) `NO ANALYZE / NO TESTING / NO QA / NO REGRESSION` sesuai instruksi; (7) tidak ada commit/push.

**Definition of Done:** presentational Flutter mengikuti struktur HTML ACC dengan data runtime Laravel tetap jujur, tanpa modifikasi business logic. **Jangan mengklaim visual telah tervalidasi di emulator bila tidak diperiksa secara manual.**
