# Skills dan agents

QA dijalankan terhadap source lokal, tanpa install skill, dependency, atau MCP baru. Tidak membuka FigCraft dan tidak melakukan redesign.

## Agents aktual

Definisi dibaca dari `C:/Users/itsba/.codex/agents/flutter_engineer.toml` dan `qa_engineer.toml`. Maksimal dua subagent dipakai dan tidak ada delegasi bertingkat.

| Agent | Tugas dan hasil |
|---|---|
| `flutter_engineer` / `/root/visual_android_qa` | Audit PRD/HTML/preview, discovery AVD, Android login smoke, 10 screenshot perangkat, pemeriksaan empat widget render. Laporan: `VISUAL_AGENT.md`. Tidak mengedit produk/test. |
| `qa_engineer` / `/root/functional_regression_qa` | Coverage claim/kalender/role; menulis `operations_post_relayout_test.dart` dan `operations_scanner_scope_regression_test.dart`; mereproduksi scope scanner dan ticker tersembunyi. Laporan: `FUNCTIONAL_AGENT.md`. Tidak mengedit produk. |

Main menjalankan preflight, batch tes, integrasi, dua perbaikan produk, retest gabungan, matrix, dan sign-off. Semua perubahan berada pada working tree bersama; tidak ada commit/push.

## Skill yang dibaca dan digunakan

| Exact SKILL.md | Referensi yang dibaca | Penggunaan/output |
|---|---|---|
| `C:/Users/itsba/.codex/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md` | Tidak memerlukan referensi tambahan | Reuse HTTP fixture dan komponen; perubahan produk hanya semantics tap dan TickerMode. Tidak mengganti arsitektur/kontrak. |
| `C:/Users/itsba/.agents/skills/flutter-custom-design-system/SKILL.md` | `C:/Users/itsba/.agents/skills/flutter-custom-design-system/references/tokens.md` | Memeriksa AppColors/OperationsTheme dan theme legacy/modal; font produk tracked dimuat untuk tes layout. Tidak membuat sistem token/Pressable baru. |
| `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/SKILL.md` | `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/references/recipes.md` | Repro semantics navbar tiga role; retest aksi semantics dan empat guideline Flutter; widget text scaling/IME serta Android login 1.0/1.3. TalkBack/VoiceOver belum dijalankan. |
| `C:/Users/itsba/.agents/skills/impeccable/SKILL.md` | `C:/Users/itsba/.agents/skills/impeccable/reference/audit.md`, `audit.native.md`, `android.md`, `craft-floor.md` pada direktori reference yang sama | Agent menjalankan launcher lokal `scripts/impeccable.cmd context --target lib/screens/operations_dashboard.dart`, exit 0, tanpa download. Audit native terhadap approved V1; perbandingan preview/current widget render dan kontras legacy. |
| `C:/Users/itsba/.agents/skills/humanizer/SKILL.md` | Tidak memerlukan referensi tambahan | Penyuntingan laporan secara embedded: klaim singkat, ketidakpastian dan bukti tetap dipertahankan. Tidak mengubah copy produk. |

`C:/Users/itsba/.codex/plugins/cache/openai-bundled/computer-use/26.1027.30824/skills/computer-use/SKILL.md` dibaca agent untuk routing, tetapi **tidak digunakan** untuk otomasi Windows. Android dikendalikan dengan ADB bawaan SDK.

## Discovery dan skill yang tidak digunakan

Roots diperiksa: `C:/Users/itsba/.agents/skills/`, `C:/Users/itsba/.codex/skills/`, repo `.agents/skills/`, repo `.codex/skills/`, dan `C:/Users/itsba/.codex/plugins/cache/`. Dua roots skill di repo tidak ditemukan.

- INSTALLED_NOT_USED: `C:/Users/itsba/.agents/skills/design-taste-frontend/SKILL.md` dan `C:/Users/itsba/.agents/skills/ui-ux-pro-max/SKILL.md`. QA mengikuti desain disetujui; workflow generasi/restyle tidak dibutuhkan.
- NOT_INSTALLED: tidak ditemukan skill khusus Flutter testing, debugging Flutter, mobile test, atau screenshot comparison pada inventaris yang diperiksa. Pengujian memakai Flutter SDK dan harness repository.
- Plugin `build-web-data-visualization/.../accessibility-and-inclusive-visualization/SKILL.md` dan `testing-data-visualizations/SKILL.md` ditemukan; tidak digunakan karena khusus visualisasi web.
- FigCraft, anatomy, reverse-engineer-anything, dan skill pembuatan website: N/A.

Global instructions dibaca dari `C:/Users/itsba/.codex/Agents.md`. Pemeriksaan ancestor/repo tidak menemukan AGENTS.md tambahan. `docs/DESIGN.md` adalah audit lama yang berbeda dari source terkini; PRD Admin V1 dan source lokal didahulukan. Instruksi user terbaru secara eksplisit mengizinkan QA, mengesampingkan larangan tes pada PRD implementasi lama.
