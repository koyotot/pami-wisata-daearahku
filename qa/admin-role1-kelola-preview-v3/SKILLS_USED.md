# Skill dan agen V3

Manifest dicari pada `C:/Users/itsba/.agents/skills`, `C:/Users/itsba/.codex/skills`, `.agents/skills`, `.codex/skills`, dan katalog plugin sesi. Dua direktori skill di repo tidak ada: NOT_INSTALLED. Tidak ada instalasi skill, dependency, MCP, atau CLI baru.

| Skill | Manifest aktual | Status dan penerapan |
|---|---|---|
| flutter-custom-design-system | `C:/Users/itsba/.agents/skills/flutter-custom-design-system/SKILL.md` | READ / APPLIED: inspect AppColors, operations chrome, NoSplash, font dan pola tombol existing; reuse tanpa migrasi sistem tema |
| flutter-improving-accessibility | `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/SKILL.md` | READ / APPLIED, termasuk `references/recipes.md`: hit target, tooltip, disabled semantics, text scale1.3, safe-area, overflow, guideline widget |
| ponytail | `C:/Users/itsba/.codex/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md` | READ / APPLIED: extend daftar/detail/editor existing, tanpa CRUD, parser, auth, dependency atau state-management baru |
| humanizer | `C:/Users/itsba/.agents/skills/humanizer/SKILL.md` | READ / APPLIED secara embedded: microcopy Indonesia jelas, label Nonaktifkan sesuai kontrak, laporan tanpa klaim pengujian live |
| impeccable | `C:/Users/itsba/.agents/skills/impeccable/SKILL.md` | READ; context command dijalankan dengan target detail; craft-floor dan panduan native review dibaca untuk pemeriksaan render. Tidak menjalankan command critique lengkap, detector web, atau membuat PRODUCT/DESIGN baru. Brief V3 dan source terkini tetap acuan |
| design-taste-frontend | `C:/Users/itsba/.agents/skills/design-taste-frontend/SKILL.md` | FOUND / NOT_RUN: bukan eksplorasi desain/web baru |
| ui-ux-pro-max | `C:/Users/itsba/.agents/skills/ui-ux-pro-max/SKILL.md` | FOUND / NOT_RUN: tidak perlu memilih ulang palette/type/layout yang disetujui |
| Flutter widget/integration testing dedicated skill | Tidak ditemukan dalam direktori skill user/repo yang diinventarisasi | NOT_INSTALLED; QA memakai harness flutter_test, MockClient dan fixture existing |

Instruksi global dibaca dari `C:/Users/itsba/.codex/Agents.md`. Tidak ditemukan AGENTS.md lain pada ancestor repo atau lib/test. Konfigurasi di `C:/Users/itsba/.codex/agents/` diinventarisasi, termasuk konfigurasi nyata flutter_engineer dan qa_engineer yang dibaca.

Tepat dua subagent dijalankan:

- `/root/hub`, role `flutter_engineer`: memiliki daftar_wisata_screen, operations_reports, tambah_wisata_screen.
- `/root/qa`, role `qa_engineer`: memiliki test/admin_kelola_preview_v3_test.dart; regresi, font harness, capture widget, dan review independen.

Main thread memiliki detail, reviews/gallery guard, integrasi, baseline comparison, quality gate dan laporan. Tidak ada kepemilikan file tulis yang tumpang tindih selama agen bekerja. Tidak menggunakan FigCraft, anatomy, reverse-engineer, atau port HTML.
