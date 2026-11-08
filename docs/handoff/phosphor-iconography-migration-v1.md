# Phosphor iconography migration V1 - implementation handoff

Date: 2026-11-07 WIB. Source implementation and static inspection only. QA, regression, testing, analyze, run, build, emulator, ADB, and screenshot inspection were NOT RUN by explicit user instruction.

## Local baseline and preserved work

- Branch: `main`; HEAD: `3fbf22b6a70c11dd4544c64db7550e484c64e5c7` (`feat(admin): redesign role 1 dashboards and destination management`). No Git commit/push/reset/clean/stash/checkout performed.
- Initial working tree: 13 deleted documentation paths, 15 untracked entries, and one modified source (`lib/screens/operations_navigation_shell.dart`). The document moves and existing PRD/inventory files were left intact.
- Existing shell changes (tab FadeTransition/SlideTransition, reduced-motion handling, logout confirmation and session checks) were preserved. Comparing the shell against the initial dirty source shows only its icon import, four glyph substitutions, and formatter wrapping.
- Final working tree: 52 modified tracked files, 13 deleted documentation paths, and 16 untracked entries (short-status groups). The migration adds 54 files to the review footprint, including this new report and the icon helper; the existing user documentation moves remain separate.
- Actual PRD read: `docs/prd/PRD_Wisata_Daerahku_Total_Phosphor_Iconography_V1.md`; there was no root-level copy.
- Global rules read: `C:/Users/itsba/.codex/Agents.md`. No AGENTS.md was found in the checked repository/ancestor paths or nested source tree. The instructions supplied in the conversation also applied.

## Dependency and API

- Local CLI: Flutter 3.44.4 stable, Dart 3.12.2. `flutter --version` completed.
- Added only `phosphor_icons: ^3.0.1`; `flutter pub get` resolved 3.0.1 and generated its real lockfile record. No other dependency version changed. Existing `cupertino_icons` remains unchanged.
- Import: `package:phosphor_icons/phosphor_icons.dart`. Ordinary `Icon` widgets consume `PhosphorIconsRegular.*` or `PhosphorIconsFill.*` static const IconData. No dynamic style selector, Duotone, font copying, or additional icon package.
- Getter names were inspected against the resolved package files in the local Pub cache. Part files `operations_{filters,financial,home,presentation,reports}.dart` share the package import in `operations_dashboard.dart`.
- Package/API documentation consulted: https://pub.dev/packages/phosphor_icons and https://pub.dev/documentation/phosphor_icons/latest/.

## Coverage and behavior boundaries

- Scanned every Dart source under `lib`: 85 original files plus one new helper = 86 final files. Migrated 398 original literal Material references (177 distinct identifiers) in 46 files.
- Total implementation footprint: 51 Dart files (50 existing plus the helper), pubspec.yaml, pubspec.lock, and this handoff. Entries with no owned glyph (operations tabs, main navigation shell, payment/deadline widgets, legacy forwarding auth/dashboard entries) reuse the migrated components without unnecessary edits.
- Roles 0/1/2, auth, visitor pages, CRUD, queue/claim, finance DEMO, scanner, map/picker, calendar, avatar, image placeholders, gallery, category/facility maps, defaults, and IconData callers are included.
- Existing handlers, routes, indices, validation, service/data code, assignment authorization, booking/payment state, actual QR, timezone/date selection, and V3 read-only Preview guards were not changed.
- Existing sizes, padding, colors, text, labels, tooltip, semantics, unread badge, center elevation, blur, and five-slot layout were retained. UI text was not rewritten.
- `_NavIconPainter` and `_OperationsIconPainter` were removed. Navbar now renders IconData directly at the existing 26dp bounds.
- `lib/theme/app_icons.dart` shares ActionIconTheme builders across root, auth, and visitor/operations themes, so BackButton/CloseButton/drawer buttons retain SDK behavior while rendering Phosphor.
- All five DropdownButtonFormField instances now specify caretDown. Date/time entry-mode switches use pencilSimple/calendarBlank/keyboard/clock. The DEMO ExpansionTile uses a Phosphor caret rotating with the existing tile controller; its SDK-equivalent animation duration/curve are retained.

## Navbar mapping

Every pair is Regular when inactive and Fill when selected by the existing index. Center background remains blue, its glyph white. Admin scanner remains an action rather than becoming a selected tab.

| Role | Slot 0 | Slot 1 | Slot 2 (raised center) | Slot 3 | Slot 4 |
|---|---|---|---|---|---|
| 0 User | house | ticket | compass | bell | userCircle |
| 1 Admin | house | ticket | qrCode | mapPin | userCircle |
| 2 Superadmin | chartPie | clipboardText | chartBar | squaresFour | userCircle |

## Non-identical semantic equivalents

| Original concept | Phosphor choice | Reason |
|---|---|---|
| Flash on/off | Fill.flashlight / Regular.lightningSlash | 3.0.1 has no flashlightSlash; use its explicit flash-off symbol. Existing tooltip/torch state remain. |
| Timer off/expired | Regular.timer | No timerOff getter; status label/color still communicates expiry. |
| Location unavailable | Regular.mapPinLine | No mapPinSlash getter; existing unavailable-location copy remains authoritative. |
| Group unavailable/empty | Regular.users | No usersSlash getter; existing empty-state copy is retained. |
| Room service/general facility | Regular.bellSimple | Closest service-bell concept in this package; named amenities retain dedicated glyphs. |
| Add photo | Regular.imageSquare | Photo action keeps its existing label/button without adding a composite glyph. |

## Residuals and explicit exceptions

- Literal Material/Cupertino source references in `lib`: **0**. ImageIcon: **0**. Old navbar painter identifiers/classes: **0**. Constructed/custom IconData sources: **0**.
- These source counts do not mean that every glyph generated inside Flutter/OS/third-party internals is Phosphor. The exceptions below remain.

| App location | Exception retained | Why |
|---|---|---|
| `lib/screens/kelola_kuota_screen.dart:306` | SDK calendar year dropdown and month chevrons | Flutter calendar_date_picker.dart hardcodes these glyphs with no public icon builder. Entry-mode icons were replaced; replacing the calendar would change the approved control/behavior. |
| `lib/screens/operations_filters.dart:167` | SDK date-range month chevrons | Shared calendar internals likewise expose no glyph override. Date range, guard, and timezone behavior were preserved. |
| `lib/screens/destination_admin_assignments_screen.dart:185` | SDK checkbox check painter | Checkbox/ListTile has no public check-glyph override; control and semantics retained. |
| `lib/widgets/booking_ticket_qr_section.dart:196`; `lib/screens/kelola_fasilitas_screen.dart:186`; `lib/screens/tambah_wisata_screen.dart:1257` | SDK selected-chip check painter | Chip checkmark glyph has no public replacement builder; hiding it or replacing the control changes existing affordances. |
| OS/SDK surfaces | Native image picker/camera, map tiles and attribution, text editing/system controls | No package/SDK fork or native UI redesign was performed. |

Non-icon artwork retained: AuthMountainPainter, _ScenePainter, _DashboardScenery; _TrendPainter chart paths; _AvatarCropOverlay crop guide; _DashedLinePainter, _BoardingPassRule, _JourneyEmptyBorder divider/border paths; actual QR SVG (booking_ticket_qr_section), destination photos, Google logo, launcher/app assets, country flags, and map tiles. Inline arrows in workflow/action text remain part of unchanged text.

## Skills and agent actually used

- Discovered installed skill folders under C:/Users/itsba/.agents/skills and C:/Users/itsba/.codex/skills, plus the runtime skill catalog. Repository .agents/skills and .codex/skills were absent. No skill/plugin was installed.
- Priority candidates found: design-taste-frontend, ui-ux-pro-max, flutter-custom-design-system, flutter-improving-accessibility, impeccable; Ponytail was available in the runtime plugin cache.
- Read and applied: `C:/Users/itsba/.agents/skills/flutter-custom-design-system/SKILL.md` (reuse current tokens/shell); `C:/Users/itsba/.agents/skills/flutter-improving-accessibility/SKILL.md` (preserve semantics/tooltips/hit targets); `C:/Users/itsba/.codex/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md` (icon-only changes, no new dependencies/wrappers beyond the small shared theme helper). User restrictions override skill suggestions to run analyzer/device checks or redesign controls.
- Inspected C:/Users/itsba/.codex/agents definitions and read system_architect.toml. One `system_architect` subagent performed read-only discovery of implicit SDK glyphs, custom painters, and semantic mapping exceptions. Main thread made all edits. No QA agent or other subagent was used.

## Commands and limits

- PASS (implementation only): flutter pub get; dart format on only 51 changed/new Dart files; git diff --check.
- Completed source/diff inspection: complete lib scan, static class/getter lookup in installed package, import/part ownership inspection, navbar/implicit widget overrides, and comparison against the original dirty source. These are not runtime validation.
- QA/regression/testing/flutter test/flutter analyze/dart analyze/flutter run/flutter build/integration/emulator/ADB/screenshot: **NOT RUN - user instruction**.
- Existing tests were not executed or edited. Several test icon finders still reference Material constants and will need corresponding updates when a testing phase is authorized. No failing scanner or other test was removed or hidden.
- Runtime rendering, font asset loading/tree shaking, platform behavior, and optical bounds remain unverified. Historical scanner/contrast findings are outside this migration and are not claimed fixed. No release-readiness claim.

## Changed files

- `lib/main.dart`
- `lib/screens/admin_common.dart`
- `lib/screens/admin_ticket_scanner_screen.dart`
- `lib/screens/auth_presentation.dart`
- `lib/screens/beranda_user_screen.dart`
- `lib/screens/bukti_pendaftaran_screen.dart`
- `lib/screens/cari_wisata_screen.dart`
- `lib/screens/daftar_kunjungan_screen.dart`
- `lib/screens/daftar_pendaftar_screen.dart`
- `lib/screens/daftar_wisata_screen.dart`
- `lib/screens/demo_checkout_screen.dart`
- `lib/screens/destination_admin_assignments_screen.dart`
- `lib/screens/destination_location_picker_screen.dart`
- `lib/screens/destination_map_screen.dart`
- `lib/screens/detail_wisata_screen.dart`
- `lib/screens/forgot_password_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/kelola_admin_screen.dart`
- `lib/screens/kelola_fasilitas_screen.dart`
- `lib/screens/kelola_kategori_screen.dart`
- `lib/screens/kelola_kuota_screen.dart`
- `lib/screens/notifikasi_screen.dart`
- `lib/screens/operations_booking_screen.dart`
- `lib/screens/operations_dashboard.dart`
- `lib/screens/operations_filters.dart`
- `lib/screens/operations_financial.dart`
- `lib/screens/operations_home.dart`
- `lib/screens/operations_navigation_shell.dart`
- `lib/screens/operations_presentation.dart`
- `lib/screens/operations_queue_screen.dart`
- `lib/screens/operations_reports.dart`
- `lib/screens/permintaan_terkirim_screen.dart`
- `lib/screens/profil_user_screen.dart`
- `lib/screens/reset_password_screen.dart`
- `lib/screens/tambah_wisata_screen.dart`
- `lib/screens/user_login_screen.dart`
- `lib/screens/user_register_screen.dart`
- `lib/screens/verify_email_otp_screen.dart`
- `lib/theme/app_colors.dart`
- `lib/widgets/admin_destination_gallery_editor.dart`
- `lib/widgets/api_image.dart`
- `lib/widgets/availability_calendar.dart`
- `lib/widgets/booking_ticket_qr_section.dart`
- `lib/widgets/destination_hero_gallery.dart`
- `lib/widgets/destination_location_map_preview.dart`
- `lib/widgets/floating_bottom_nav.dart`
- `lib/widgets/international_phone_field.dart`
- `lib/widgets/operations_chrome.dart`
- `lib/widgets/profile_avatar.dart`
- `lib/widgets/reviews_sheet.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `lib/theme/app_icons.dart`
- `docs/handoff/phosphor-iconography-migration-v1.md`

## Original use-site matrix

Locations below refer to the initial working tree before replacement/formatting. Same old concept in a file is grouped with its original line numbers. Styles are explicit in each replacement identifier. Dynamic map keys, caller types, labels, and handlers remain unchanged.

| Original file:line(s) | Old concept/source | Phosphor equivalent/style |
|---|---|---|
| `lib/screens/admin_common.dart:89` | `Icons.arrow_back_ios_new_rounded` | `PhosphorIconsRegular.caretLeft` |
| `lib/screens/admin_ticket_scanner_screen.dart:237` | `Icons.check_circle_outline_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/admin_ticket_scanner_screen.dart:182` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/screens/admin_ticket_scanner_screen.dart:403` | `Icons.flash_off` | `PhosphorIconsRegular.lightningSlash` |
| `lib/screens/admin_ticket_scanner_screen.dart:402` | `Icons.flash_on` | `PhosphorIconsFill.flashlight` |
| `lib/screens/admin_ticket_scanner_screen.dart:268` | `Icons.verified_user_outlined` | `PhosphorIconsRegular.shieldCheck` |
| `lib/screens/auth_presentation.dart:243` | `Icons.arrow_back_rounded` | `PhosphorIconsRegular.arrowLeft` |
| `lib/screens/auth_presentation.dart:229` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/auth_presentation.dart:142` | `Icons.travel_explore_rounded` | `PhosphorIconsRegular.globeHemisphereWest` |
| `lib/screens/beranda_user_screen.dart:538, 802` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/beranda_user_screen.dart:698` | `Icons.auto_awesome` | `PhosphorIconsRegular.sparkle` |
| `lib/screens/beranda_user_screen.dart:490` | `Icons.calendar_today_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/beranda_user_screen.dart:493, 505` | `Icons.confirmation_number_outlined` | `PhosphorIconsRegular.ticket` |
| `lib/screens/beranda_user_screen.dart:389` | `Icons.explore_outlined` | `PhosphorIconsRegular.compass` |
| `lib/screens/beranda_user_screen.dart:636` | `Icons.favorite_rounded` | `PhosphorIconsFill.heart` |
| `lib/screens/beranda_user_screen.dart:560` | `Icons.landscape_outlined` | `PhosphorIconsRegular.mountains` |
| `lib/screens/beranda_user_screen.dart:312` | `Icons.menu_rounded` | `PhosphorIconsRegular.list` |
| `lib/screens/beranda_user_screen.dart:734` | `Icons.north_east_rounded` | `PhosphorIconsRegular.arrowUpRight` |
| `lib/screens/beranda_user_screen.dart:607, 716` | `Icons.place_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/bukti_pendaftaran_screen.dart:84` | `Icons.block_rounded` | `PhosphorIconsRegular.prohibit` |
| `lib/screens/bukti_pendaftaran_screen.dart:385` | `Icons.bookmark_rounded` | `PhosphorIconsRegular.bookmark` |
| `lib/screens/bukti_pendaftaran_screen.dart:1067` | `Icons.calendar_today_rounded` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/bukti_pendaftaran_screen.dart:68, 873` | `Icons.cancel_rounded` | `PhosphorIconsFill.xCircle` |
| `lib/screens/bukti_pendaftaran_screen.dart:64, 855, 915, 1431` | `Icons.check_circle_rounded` | `PhosphorIconsFill.checkCircle` |
| `lib/screens/bukti_pendaftaran_screen.dart:587` | `Icons.confirmation_number_rounded` | `PhosphorIconsRegular.ticket` |
| `lib/screens/bukti_pendaftaran_screen.dart:1011` | `Icons.copy_outlined` | `PhosphorIconsRegular.copy` |
| `lib/screens/bukti_pendaftaran_screen.dart:1181` | `Icons.email_rounded` | `PhosphorIconsRegular.envelope` |
| `lib/screens/bukti_pendaftaran_screen.dart:619` | `Icons.explore_rounded` | `PhosphorIconsRegular.compass` |
| `lib/screens/bukti_pendaftaran_screen.dart:1071` | `Icons.group_rounded` | `PhosphorIconsRegular.users` |
| `lib/screens/bukti_pendaftaran_screen.dart:71, 74, 77, 81` | `Icons.hourglass_top_rounded` | `PhosphorIconsRegular.hourglassHigh` |
| `lib/screens/bukti_pendaftaran_screen.dart:649` | `Icons.inbox_rounded` | `PhosphorIconsRegular.tray` |
| `lib/screens/bukti_pendaftaran_screen.dart:90` | `Icons.info_outline_rounded` | `PhosphorIconsRegular.info` |
| `lib/screens/bukti_pendaftaran_screen.dart:1170` | `Icons.keyboard_arrow_down_rounded` | `PhosphorIconsRegular.caretDown` |
| `lib/screens/bukti_pendaftaran_screen.dart:398` | `Icons.menu_rounded` | `PhosphorIconsRegular.list` |
| `lib/screens/bukti_pendaftaran_screen.dart:1188` | `Icons.notes_rounded` | `PhosphorIconsRegular.note` |
| `lib/screens/bukti_pendaftaran_screen.dart:1255` | `Icons.payments_rounded` | `PhosphorIconsRegular.money` |
| `lib/screens/bukti_pendaftaran_screen.dart:1063` | `Icons.person_rounded` | `PhosphorIconsRegular.userCircle` |
| `lib/screens/bukti_pendaftaran_screen.dart:1075` | `Icons.phone_rounded` | `PhosphorIconsRegular.phone` |
| `lib/screens/bukti_pendaftaran_screen.dart:1432, 1581` | `Icons.rate_review_rounded` | `PhosphorIconsRegular.chatText` |
| `lib/screens/bukti_pendaftaran_screen.dart:1708` | `Icons.send_rounded` | `PhosphorIconsRegular.paperPlaneTilt` |
| `lib/screens/bukti_pendaftaran_screen.dart:1617` | `Icons.star_border_rounded` | `PhosphorIconsRegular.star` |
| `lib/screens/bukti_pendaftaran_screen.dart:1616` | `Icons.star_rounded` | `PhosphorIconsFill.star` |
| `lib/screens/bukti_pendaftaran_screen.dart:87` | `Icons.timer_off_rounded` | `PhosphorIconsRegular.timer` |
| `lib/screens/bukti_pendaftaran_screen.dart:1664` | `Icons.warning_amber_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/cari_wisata_screen.dart:57` | `Icons.account_balance_rounded` | `PhosphorIconsRegular.bank` |
| `lib/screens/cari_wisata_screen.dart:467` | `Icons.apps_rounded` | `PhosphorIconsRegular.squaresFour` |
| `lib/screens/cari_wisata_screen.dart:1113` | `Icons.arrow_forward_ios_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/cari_wisata_screen.dart:861, 984` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/cari_wisata_screen.dart:56` | `Icons.beach_access_rounded` | `PhosphorIconsRegular.umbrella` |
| `lib/screens/cari_wisata_screen.dart:684` | `Icons.broken_image_rounded` | `PhosphorIconsRegular.imageBroken` |
| `lib/screens/cari_wisata_screen.dart:393` | `Icons.close_rounded` | `PhosphorIconsRegular.x` |
| `lib/screens/cari_wisata_screen.dart:578` | `Icons.dashboard_rounded` | `PhosphorIconsRegular.squaresFour` |
| `lib/screens/cari_wisata_screen.dart:62, 660, 725, 1010` | `Icons.explore_rounded` | `PhosphorIconsRegular.compass` |
| `lib/screens/cari_wisata_screen.dart:58` | `Icons.forest_rounded` | `PhosphorIconsRegular.tree` |
| `lib/screens/cari_wisata_screen.dart:837, 1094` | `Icons.local_offer_rounded` | `PhosphorIconsRegular.tag` |
| `lib/screens/cari_wisata_screen.dart:61` | `Icons.location_city_rounded` | `PhosphorIconsRegular.buildings` |
| `lib/screens/cari_wisata_screen.dart:809, 952, 1079` | `Icons.location_on_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/cari_wisata_screen.dart:302` | `Icons.menu_rounded` | `PhosphorIconsRegular.list` |
| `lib/screens/cari_wisata_screen.dart:289` | `Icons.place_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/cari_wisata_screen.dart:60` | `Icons.restaurant_rounded` | `PhosphorIconsRegular.forkKnife` |
| `lib/screens/cari_wisata_screen.dart:59` | `Icons.sailing_rounded` | `PhosphorIconsRegular.sailboat` |
| `lib/screens/cari_wisata_screen.dart:599` | `Icons.search_off_rounded` | `PhosphorIconsRegular.magnifyingGlassMinus` |
| `lib/screens/cari_wisata_screen.dart:390` | `Icons.search_rounded` | `PhosphorIconsRegular.magnifyingGlass` |
| `lib/screens/cari_wisata_screen.dart:579` | `Icons.view_agenda_rounded` | `PhosphorIconsRegular.rows` |
| `lib/screens/daftar_kunjungan_screen.dart:991, 1393` | `Icons.add_rounded` | `PhosphorIconsRegular.plus` |
| `lib/screens/daftar_kunjungan_screen.dart:716` | `Icons.arrow_back_rounded` | `PhosphorIconsRegular.arrowLeft` |
| `lib/screens/daftar_kunjungan_screen.dart:1243` | `Icons.landscape_rounded` | `PhosphorIconsRegular.mountains` |
| `lib/screens/daftar_kunjungan_screen.dart:904` | `Icons.mail_outline_rounded` | `PhosphorIconsRegular.envelope` |
| `lib/screens/daftar_kunjungan_screen.dart:1024` | `Icons.notes_rounded` | `PhosphorIconsRegular.note` |
| `lib/screens/daftar_kunjungan_screen.dart:864` | `Icons.person_outline_rounded` | `PhosphorIconsRegular.userCircle` |
| `lib/screens/daftar_kunjungan_screen.dart:978` | `Icons.remove_rounded` | `PhosphorIconsRegular.minus` |
| `lib/screens/daftar_pendaftar_screen.dart:315` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/daftar_pendaftar_screen.dart:265` | `Icons.chevron_right_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/daftar_pendaftar_screen.dart:298` | `Icons.people_outline` | `PhosphorIconsRegular.users` |
| `lib/screens/daftar_pendaftar_screen.dart:248` | `Icons.people_outline_rounded` | `PhosphorIconsRegular.users` |
| `lib/screens/daftar_wisata_screen.dart:1551` | `Icons.access_time_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/daftar_wisata_screen.dart:58` | `Icons.account_balance_rounded` | `PhosphorIconsRegular.bank` |
| `lib/screens/daftar_wisata_screen.dart:527` | `Icons.add` | `PhosphorIconsRegular.plus` |
| `lib/screens/daftar_wisata_screen.dart:1240` | `Icons.add_rounded` | `PhosphorIconsRegular.plus` |
| `lib/screens/daftar_wisata_screen.dart:803` | `Icons.arrow_back_ios_new_rounded` | `PhosphorIconsRegular.caretLeft` |
| `lib/screens/daftar_wisata_screen.dart:1580` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/daftar_wisata_screen.dart:57` | `Icons.beach_access_rounded` | `PhosphorIconsRegular.umbrella` |
| `lib/screens/daftar_wisata_screen.dart:446` | `Icons.block_outlined` | `PhosphorIconsRegular.prohibit` |
| `lib/screens/daftar_wisata_screen.dart:438` | `Icons.calendar_today_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/daftar_wisata_screen.dart:685` | `Icons.circle` | `PhosphorIconsFill.circle` |
| `lib/screens/daftar_wisata_screen.dart:407, 552` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/screens/daftar_wisata_screen.dart:988` | `Icons.close_rounded` | `PhosphorIconsRegular.x` |
| `lib/screens/daftar_wisata_screen.dart:252, 1487` | `Icons.delete_rounded` | `PhosphorIconsRegular.trash` |
| `lib/screens/daftar_wisata_screen.dart:428` | `Icons.edit_outlined` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/daftar_wisata_screen.dart:1464` | `Icons.edit_rounded` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/daftar_wisata_screen.dart:1458, 1498` | `Icons.event_available_rounded` | `PhosphorIconsRegular.calendarCheck` |
| `lib/screens/daftar_wisata_screen.dart:56, 63` | `Icons.explore_rounded` | `PhosphorIconsRegular.compass` |
| `lib/screens/daftar_wisata_screen.dart:59` | `Icons.forest_rounded` | `PhosphorIconsRegular.tree` |
| `lib/screens/daftar_wisata_screen.dart:638` | `Icons.landscape_outlined` | `PhosphorIconsRegular.mountains` |
| `lib/screens/daftar_wisata_screen.dart:823, 1626` | `Icons.landscape_rounded` | `PhosphorIconsRegular.mountains` |
| `lib/screens/daftar_wisata_screen.dart:1412` | `Icons.local_offer_rounded` | `PhosphorIconsRegular.tag` |
| `lib/screens/daftar_wisata_screen.dart:62` | `Icons.location_city_rounded` | `PhosphorIconsRegular.buildings` |
| `lib/screens/daftar_wisata_screen.dart:654` | `Icons.location_on_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/daftar_wisata_screen.dart:1521` | `Icons.location_on_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/daftar_wisata_screen.dart:433` | `Icons.photo_library_outlined` | `PhosphorIconsRegular.images` |
| `lib/screens/daftar_wisata_screen.dart:1073, 1358` | `Icons.place_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/daftar_wisata_screen.dart:61` | `Icons.restaurant_rounded` | `PhosphorIconsRegular.forkKnife` |
| `lib/screens/daftar_wisata_screen.dart:253, 447, 1488` | `Icons.restore_rounded` | `PhosphorIconsRegular.arrowCounterClockwise` |
| `lib/screens/daftar_wisata_screen.dart:60` | `Icons.sailing_rounded` | `PhosphorIconsRegular.sailboat` |
| `lib/screens/daftar_wisata_screen.dart:543` | `Icons.search` | `PhosphorIconsRegular.magnifyingGlass` |
| `lib/screens/daftar_wisata_screen.dart:1168` | `Icons.search_off_rounded` | `PhosphorIconsRegular.magnifyingGlassMinus` |
| `lib/screens/daftar_wisata_screen.dart:984` | `Icons.search_rounded` | `PhosphorIconsRegular.magnifyingGlass` |
| `lib/screens/daftar_wisata_screen.dart:732` | `Icons.tune_rounded` | `PhosphorIconsRegular.slidersHorizontal` |
| `lib/screens/daftar_wisata_screen.dart:423, 714` | `Icons.visibility_outlined` | `PhosphorIconsRegular.eye` |
| `lib/screens/demo_checkout_screen.dart:398` | `Icons.account_balance_wallet_outlined` | `PhosphorIconsRegular.wallet` |
| `lib/screens/demo_checkout_screen.dart:248, 409` | `Icons.check_circle_outline` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/demo_checkout_screen.dart:278` | `Icons.error_outline` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/demo_checkout_screen.dart:450` | `Icons.hourglass_top` | `PhosphorIconsRegular.hourglassHigh` |
| `lib/screens/demo_checkout_screen.dart:475` | `Icons.lock_outline` | `PhosphorIconsRegular.lock` |
| `lib/screens/demo_checkout_screen.dart:388` | `Icons.sync_outlined` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/screens/demo_checkout_screen.dart:277` | `Icons.timer_off_outlined` | `PhosphorIconsRegular.timer` |
| `lib/screens/destination_location_picker_screen.dart:177` | `Icons.my_location` | `PhosphorIconsRegular.crosshair` |
| `lib/screens/destination_map_screen.dart:227` | `Icons.location_on_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/destination_map_screen.dart:218` | `Icons.my_location` | `PhosphorIconsRegular.crosshair` |
| `lib/screens/detail_wisata_screen.dart:783` | `Icons.accessible_rounded` | `PhosphorIconsRegular.wheelchair` |
| `lib/screens/detail_wisata_screen.dart:371` | `Icons.arrow_back_rounded` | `PhosphorIconsRegular.arrowLeft` |
| `lib/screens/detail_wisata_screen.dart:440` | `Icons.category_outlined` | `PhosphorIconsRegular.squaresFour` |
| `lib/screens/detail_wisata_screen.dart:784` | `Icons.check_circle_outline_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/detail_wisata_screen.dart:599` | `Icons.directions_outlined` | `PhosphorIconsRegular.navigationArrow` |
| `lib/screens/detail_wisata_screen.dart:319` | `Icons.favorite` | `PhosphorIconsFill.heart` |
| `lib/screens/detail_wisata_screen.dart:320` | `Icons.favorite_border` | `PhosphorIconsRegular.heart` |
| `lib/screens/detail_wisata_screen.dart:381` | `Icons.favorite_border_rounded` | `PhosphorIconsRegular.heart` |
| `lib/screens/detail_wisata_screen.dart:380` | `Icons.favorite_rounded` | `PhosphorIconsFill.heart` |
| `lib/screens/detail_wisata_screen.dart:582` | `Icons.fullscreen_rounded` | `PhosphorIconsRegular.arrowsOut` |
| `lib/screens/detail_wisata_screen.dart:778` | `Icons.local_parking_outlined` | `PhosphorIconsRegular.car` |
| `lib/screens/detail_wisata_screen.dart:756` | `Icons.location_on_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/detail_wisata_screen.dart:782` | `Icons.mosque_outlined` | `PhosphorIconsRegular.mosque` |
| `lib/screens/detail_wisata_screen.dart:781` | `Icons.restaurant_outlined` | `PhosphorIconsRegular.forkKnife` |
| `lib/screens/detail_wisata_screen.dart:443` | `Icons.schedule_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/detail_wisata_screen.dart:412` | `Icons.star_rounded` | `PhosphorIconsFill.star` |
| `lib/screens/detail_wisata_screen.dart:779` | `Icons.wc_outlined` | `PhosphorIconsRegular.toilet` |
| `lib/screens/detail_wisata_screen.dart:780` | `Icons.wifi_rounded` | `PhosphorIconsRegular.wifiHigh` |
| `lib/screens/forgot_password_screen.dart:100` | `Icons.mail_outline_rounded` | `PhosphorIconsRegular.envelope` |
| `lib/screens/home_screen.dart:77` | `Icons.explore_rounded` | `PhosphorIconsRegular.compass` |
| `lib/screens/home_screen.dart:118` | `Icons.travel_explore_rounded` | `PhosphorIconsRegular.globeHemisphereWest` |
| `lib/screens/kelola_admin_screen.dart:400` | `Icons.block_rounded` | `PhosphorIconsRegular.prohibit` |
| `lib/screens/kelola_admin_screen.dart:401` | `Icons.check_circle_outline_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/kelola_admin_screen.dart:251` | `Icons.group_off_rounded` | `PhosphorIconsRegular.users` |
| `lib/screens/kelola_admin_screen.dart:244` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/screens/kelola_admin_screen.dart:201` | `Icons.person_add_alt_1_rounded` | `PhosphorIconsRegular.userPlus` |
| `lib/screens/kelola_admin_screen.dart:162` | `Icons.radio_button_checked_rounded` | `PhosphorIconsRegular.radioButton` |
| `lib/screens/kelola_admin_screen.dart:163` | `Icons.radio_button_unchecked_rounded` | `PhosphorIconsRegular.circle` |
| `lib/screens/kelola_admin_screen.dart:361` | `Icons.shield_rounded` | `PhosphorIconsRegular.shield` |
| `lib/screens/kelola_admin_screen.dart:384` | `Icons.swap_horiz_rounded` | `PhosphorIconsRegular.arrowsLeftRight` |
| `lib/screens/kelola_fasilitas_screen.dart:167` | `Icons.add_rounded` | `PhosphorIconsRegular.plus` |
| `lib/screens/kelola_fasilitas_screen.dart:303` | `Icons.edit_rounded` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/kelola_fasilitas_screen.dart:195` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/screens/kelola_fasilitas_screen.dart:311` | `Icons.restore_rounded` | `PhosphorIconsRegular.arrowCounterClockwise` |
| `lib/screens/kelola_fasilitas_screen.dart:202` | `Icons.room_service_outlined` | `PhosphorIconsRegular.bellSimple` |
| `lib/screens/kelola_fasilitas_screen.dart:263` | `Icons.room_service_rounded` | `PhosphorIconsRegular.bellSimple` |
| `lib/screens/kelola_fasilitas_screen.dart:311` | `Icons.visibility_off_rounded` | `PhosphorIconsRegular.eyeSlash` |
| `lib/screens/kelola_kategori_screen.dart:146` | `Icons.add_rounded` | `PhosphorIconsRegular.plus` |
| `lib/screens/kelola_kategori_screen.dart:162` | `Icons.category_outlined` | `PhosphorIconsRegular.squaresFour` |
| `lib/screens/kelola_kategori_screen.dart:223` | `Icons.category_rounded` | `PhosphorIconsRegular.squaresFour` |
| `lib/screens/kelola_kategori_screen.dart:263` | `Icons.edit_rounded` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/kelola_kategori_screen.dart:155` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/screens/kelola_kategori_screen.dart:271` | `Icons.restore_rounded` | `PhosphorIconsRegular.arrowCounterClockwise` |
| `lib/screens/kelola_kategori_screen.dart:271` | `Icons.visibility_off_rounded` | `PhosphorIconsRegular.eyeSlash` |
| `lib/screens/kelola_kuota_screen.dart:122` | `Icons.add_rounded` | `PhosphorIconsRegular.plus` |
| `lib/screens/kelola_kuota_screen.dart:222` | `Icons.edit_rounded` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/kelola_kuota_screen.dart:139` | `Icons.event_busy_rounded` | `PhosphorIconsRegular.calendarX` |
| `lib/screens/kelola_kuota_screen.dart:208` | `Icons.event_rounded` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/kelola_kuota_screen.dart:131` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/screens/notifikasi_screen.dart:287` | `Icons.access_time_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/notifikasi_screen.dart:272` | `Icons.account_balance_wallet_outlined` | `PhosphorIconsRegular.wallet` |
| `lib/screens/notifikasi_screen.dart:282` | `Icons.check_rounded` | `PhosphorIconsRegular.check` |
| `lib/screens/notifikasi_screen.dart:380` | `Icons.chevron_right_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/notifikasi_screen.dart:277` | `Icons.close_rounded` | `PhosphorIconsRegular.x` |
| `lib/screens/notifikasi_screen.dart:208` | `Icons.cloud_off_outlined` | `PhosphorIconsRegular.cloudSlash` |
| `lib/screens/notifikasi_screen.dart:239` | `Icons.done_all_rounded` | `PhosphorIconsRegular.checks` |
| `lib/screens/notifikasi_screen.dart:220, 238, 292, 297` | `Icons.notifications_none_rounded` | `PhosphorIconsRegular.bell` |
| `lib/screens/operations_booking_screen.dart:546` | `Icons.copy_outlined` | `PhosphorIconsRegular.copy` |
| `lib/screens/operations_booking_screen.dart:613` | `Icons.info_outline` | `PhosphorIconsRegular.info` |
| `lib/screens/operations_booking_screen.dart:497` | `Icons.info_outline_rounded` | `PhosphorIconsRegular.info` |
| `lib/screens/operations_booking_screen.dart:612` | `Icons.lock_outline` | `PhosphorIconsRegular.lock` |
| `lib/screens/operations_booking_screen.dart:287` | `Icons.more_horiz` | `PhosphorIconsRegular.dotsThree` |
| `lib/screens/operations_booking_screen.dart:480, 509` | `Icons.refresh` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/screens/operations_booking_screen.dart:610` | `Icons.verified_user_outlined` | `PhosphorIconsRegular.shieldCheck` |
| `lib/screens/operations_dashboard.dart:766` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/operations_dashboard.dart:647, 656` | `Icons.cancel_outlined` | `PhosphorIconsRegular.xCircle` |
| `lib/screens/operations_dashboard.dart:310, 353` | `Icons.check_rounded` | `PhosphorIconsRegular.check` |
| `lib/screens/operations_dashboard.dart:877` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_dashboard.dart:311` | `Icons.close_rounded` | `PhosphorIconsRegular.x` |
| `lib/screens/operations_dashboard.dart:327, 380` | `Icons.inbox_outlined` | `PhosphorIconsRegular.tray` |
| `lib/screens/operations_dashboard.dart:403` | `Icons.people_outline_rounded` | `PhosphorIconsRegular.users` |
| `lib/screens/operations_dashboard.dart:648` | `Icons.percent_rounded` | `PhosphorIconsRegular.percent` |
| `lib/screens/operations_dashboard.dart:352, 654` | `Icons.place_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/operations_dashboard.dart:392` | `Icons.qr_code_rounded` | `PhosphorIconsRegular.qrCode` |
| `lib/screens/operations_dashboard.dart:312, 351` | `Icons.schedule_outlined` | `PhosphorIconsRegular.clock` |
| `lib/screens/operations_dashboard.dart:653` | `Icons.schedule_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/operations_dashboard.dart:386` | `Icons.show_chart_rounded` | `PhosphorIconsRegular.chartLine` |
| `lib/screens/operations_dashboard.dart:646, 655` | `Icons.task_alt_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/operations_dashboard.dart:649` | `Icons.timer_outlined` | `PhosphorIconsRegular.timer` |
| `lib/screens/operations_dashboard.dart:650` | `Icons.verified_outlined` | `PhosphorIconsRegular.sealCheck` |
| `lib/screens/operations_dashboard.dart:313` | `Icons.verified_user_outlined` | `PhosphorIconsRegular.shieldCheck` |
| `lib/screens/operations_dashboard.dart:354` | `Icons.warning_amber_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/operations_filters.dart:426` | `Icons.calendar_today_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/operations_filters.dart:801` | `Icons.check_rounded` | `PhosphorIconsRegular.check` |
| `lib/screens/operations_filters.dart:1047` | `Icons.chevron_left` | `PhosphorIconsRegular.caretLeft` |
| `lib/screens/operations_filters.dart:1063` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_filters.dart:427` | `Icons.chevron_right_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_filters.dart:1216` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/screens/operations_filters.dart:325, 514` | `Icons.date_range_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/operations_filters.dart:1009, 1026, 1227` | `Icons.keyboard_arrow_down` | `PhosphorIconsRegular.caretDown` |
| `lib/screens/operations_filters.dart:231, 395, 488, 785` | `Icons.place_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/operations_filters.dart:802` | `Icons.radio_button_checked` | `PhosphorIconsRegular.radioButton` |
| `lib/screens/operations_filters.dart:803` | `Icons.radio_button_off` | `PhosphorIconsRegular.circle` |
| `lib/screens/operations_filters.dart:718` | `Icons.search` | `PhosphorIconsRegular.magnifyingGlass` |
| `lib/screens/operations_financial.dart:657` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/operations_financial.dart:403` | `Icons.circle` | `PhosphorIconsFill.circle` |
| `lib/screens/operations_financial.dart:491` | `Icons.confirmation_number_outlined` | `PhosphorIconsRegular.ticket` |
| `lib/screens/operations_financial.dart:490, 619` | `Icons.payments_outlined` | `PhosphorIconsRegular.money` |
| `lib/screens/operations_financial.dart:367` | `Icons.refresh` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/screens/operations_financial.dart:280` | `Icons.tune_rounded` | `PhosphorIconsRegular.slidersHorizontal` |
| `lib/screens/operations_home.dart:239` | `Icons.calendar_today_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/operations_home.dart:253, 297` | `Icons.chevron_right_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_home.dart:239` | `Icons.schedule` | `PhosphorIconsRegular.clock` |
| `lib/screens/operations_navigation_shell.dart:301` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_navigation_shell.dart:528` | `Icons.logout` | `PhosphorIconsRegular.signOut` |
| `lib/screens/operations_navigation_shell.dart:508` | `Icons.logout_rounded` | `PhosphorIconsRegular.signOut` |
| `lib/screens/operations_navigation_shell.dart:427` | `Icons.person_outline_rounded` | `PhosphorIconsRegular.userCircle` |
| `lib/screens/operations_presentation.dart:376` | `Icons.account_balance_wallet_outlined` | `PhosphorIconsRegular.wallet` |
| `lib/screens/operations_presentation.dart:193` | `Icons.business_outlined` | `PhosphorIconsRegular.buildings` |
| `lib/screens/operations_presentation.dart:711` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_presentation.dart:279, 799` | `Icons.chevron_right_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_presentation.dart:781` | `Icons.event_available_outlined` | `PhosphorIconsRegular.calendarCheck` |
| `lib/screens/operations_presentation.dart:341` | `Icons.history_rounded` | `PhosphorIconsRegular.clockCounterClockwise` |
| `lib/screens/operations_presentation.dart:214` | `Icons.keyboard_arrow_down_rounded` | `PhosphorIconsRegular.caretDown` |
| `lib/screens/operations_presentation.dart:50` | `Icons.landscape_outlined` | `PhosphorIconsRegular.mountains` |
| `lib/screens/operations_presentation.dart:297` | `Icons.location_off_outlined` | `PhosphorIconsRegular.mapPinLine` |
| `lib/screens/operations_presentation.dart:731` | `Icons.lock_outline` | `PhosphorIconsRegular.lock` |
| `lib/screens/operations_presentation.dart:33, 85` | `Icons.notifications_none_rounded` | `PhosphorIconsRegular.bell` |
| `lib/screens/operations_presentation.dart:193` | `Icons.place_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/operations_presentation.dart:759` | `Icons.refresh_rounded` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/screens/operations_presentation.dart:782` | `Icons.schedule_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/operations_presentation.dart:252` | `Icons.warning_amber_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/operations_presentation.dart:732` | `Icons.wifi_off_rounded` | `PhosphorIconsRegular.wifiSlash` |
| `lib/screens/operations_queue_screen.dart:326` | `Icons.lock_outline` | `PhosphorIconsRegular.lock` |
| `lib/screens/operations_queue_screen.dart:429` | `Icons.schedule_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/operations_queue_screen.dart:349` | `Icons.search_off_rounded` | `PhosphorIconsRegular.magnifyingGlassMinus` |
| `lib/screens/operations_queue_screen.dart:350` | `Icons.task_alt_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/operations_queue_screen.dart:326` | `Icons.wifi_off` | `PhosphorIconsRegular.wifiSlash` |
| `lib/screens/operations_reports.dart:427` | `Icons.cancel_outlined` | `PhosphorIconsRegular.xCircle` |
| `lib/screens/operations_reports.dart:532` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/operations_reports.dart:384` | `Icons.confirmation_number_outlined` | `PhosphorIconsRegular.ticket` |
| `lib/screens/operations_reports.dart:385, 428` | `Icons.percent_rounded` | `PhosphorIconsRegular.percent` |
| `lib/screens/operations_reports.dart:386` | `Icons.person_off_outlined` | `PhosphorIconsRegular.userMinus` |
| `lib/screens/operations_reports.dart:524` | `Icons.person_outline_rounded` | `PhosphorIconsRegular.userCircle` |
| `lib/screens/operations_reports.dart:561` | `Icons.place_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/operations_reports.dart:357, 376, 383` | `Icons.qr_code_scanner_rounded` | `PhosphorIconsRegular.qrCode` |
| `lib/screens/operations_reports.dart:426` | `Icons.task_alt_rounded` | `PhosphorIconsRegular.checkCircle` |
| `lib/screens/operations_reports.dart:429` | `Icons.timer_outlined` | `PhosphorIconsRegular.timer` |
| `lib/screens/operations_reports.dart:430` | `Icons.verified_outlined` | `PhosphorIconsRegular.sealCheck` |
| `lib/screens/permintaan_terkirim_screen.dart:190` | `Icons.arrow_forward_rounded` | `PhosphorIconsRegular.arrowRight` |
| `lib/screens/permintaan_terkirim_screen.dart:112` | `Icons.check_rounded` | `PhosphorIconsRegular.check` |
| `lib/screens/profil_user_screen.dart:1224` | `Icons.arrow_back_rounded` | `PhosphorIconsRegular.arrowLeft` |
| `lib/screens/profil_user_screen.dart:874, 1490` | `Icons.arrow_forward_ios_rounded` | `PhosphorIconsRegular.caretRight` |
| `lib/screens/profil_user_screen.dart:696, 1477` | `Icons.bookmark_rounded` | `PhosphorIconsRegular.bookmark` |
| `lib/screens/profil_user_screen.dart:641` | `Icons.calendar_month_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/screens/profil_user_screen.dart:456` | `Icons.delete_outline_rounded` | `PhosphorIconsRegular.trash` |
| `lib/screens/profil_user_screen.dart:616` | `Icons.edit_outlined` | `PhosphorIconsRegular.pencilSimple` |
| `lib/screens/profil_user_screen.dart:442` | `Icons.info_outline_rounded` | `PhosphorIconsRegular.info` |
| `lib/screens/profil_user_screen.dart:416` | `Icons.language_rounded` | `PhosphorIconsRegular.globe` |
| `lib/screens/profil_user_screen.dart:1306` | `Icons.lock_outline` | `PhosphorIconsRegular.lock` |
| `lib/screens/profil_user_screen.dart:426` | `Icons.lock_reset_rounded` | `PhosphorIconsRegular.key` |
| `lib/screens/profil_user_screen.dart:918` | `Icons.logout_rounded` | `PhosphorIconsRegular.signOut` |
| `lib/screens/profil_user_screen.dart:514` | `Icons.menu_rounded` | `PhosphorIconsRegular.list` |
| `lib/screens/profil_user_screen.dart:398` | `Icons.rate_review_rounded` | `PhosphorIconsRegular.chatText` |
| `lib/screens/profil_user_screen.dart:389` | `Icons.refresh_rounded` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/screens/profil_user_screen.dart:943` | `Icons.travel_explore_rounded` | `PhosphorIconsRegular.globeHemisphereWest` |
| `lib/screens/profil_user_screen.dart:1518` | `Icons.warning_amber_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/reset_password_screen.dart:228` | `Icons.check_rounded` | `PhosphorIconsRegular.check` |
| `lib/screens/reset_password_screen.dart:162, 187` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lockKey` |
| `lib/screens/reset_password_screen.dart:173, 198` | `Icons.visibility_off_outlined` | `PhosphorIconsRegular.eyeSlash` |
| `lib/screens/reset_password_screen.dart:174, 199` | `Icons.visibility_outlined` | `PhosphorIconsRegular.eye` |
| `lib/screens/tambah_wisata_screen.dart:871` | `Icons.add_location_alt_rounded` | `PhosphorIconsRegular.mapPinPlus` |
| `lib/screens/tambah_wisata_screen.dart:559` | `Icons.arrow_back_ios_new_rounded` | `PhosphorIconsRegular.caretLeft` |
| `lib/screens/tambah_wisata_screen.dart:285` | `Icons.check_circle_rounded` | `PhosphorIconsFill.checkCircle` |
| `lib/screens/tambah_wisata_screen.dart:761` | `Icons.description_rounded` | `PhosphorIconsRegular.fileText` |
| `lib/screens/tambah_wisata_screen.dart:285` | `Icons.error_rounded` | `PhosphorIconsFill.warningCircle` |
| `lib/screens/tambah_wisata_screen.dart:1284` | `Icons.explore_rounded` | `PhosphorIconsRegular.compass` |
| `lib/screens/tambah_wisata_screen.dart:741` | `Icons.landscape_rounded` | `PhosphorIconsRegular.mountains` |
| `lib/screens/tambah_wisata_screen.dart:775` | `Icons.local_activity_rounded` | `PhosphorIconsRegular.ticket` |
| `lib/screens/tambah_wisata_screen.dart:1016` | `Icons.location_on_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/tambah_wisata_screen.dart:1132` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/screens/tambah_wisata_screen.dart:1007` | `Icons.pin_drop_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/screens/tambah_wisata_screen.dart:923` | `Icons.public_rounded` | `PhosphorIconsRegular.globe` |
| `lib/screens/tambah_wisata_screen.dart:870` | `Icons.save_rounded` | `PhosphorIconsRegular.floppyDisk` |
| `lib/screens/tambah_wisata_screen.dart:795` | `Icons.schedule_rounded` | `PhosphorIconsRegular.clock` |
| `lib/screens/tambah_wisata_screen.dart:1119` | `Icons.star_half_rounded` | `PhosphorIconsFill.starHalf` |
| `lib/screens/tambah_wisata_screen.dart:1120` | `Icons.star_outline_rounded` | `PhosphorIconsRegular.star` |
| `lib/screens/tambah_wisata_screen.dart:1093, 1117` | `Icons.star_rounded` | `PhosphorIconsFill.star` |
| `lib/screens/user_login_screen.dart:341` | `Icons.email_rounded` | `PhosphorIconsRegular.envelope` |
| `lib/screens/user_login_screen.dart:523` | `Icons.error_outline_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/user_login_screen.dart:385` | `Icons.lock_rounded` | `PhosphorIconsRegular.lockKey` |
| `lib/screens/user_login_screen.dart:395` | `Icons.visibility_off_outlined` | `PhosphorIconsRegular.eyeSlash` |
| `lib/screens/user_login_screen.dart:394` | `Icons.visibility_outlined` | `PhosphorIconsRegular.eye` |
| `lib/screens/user_register_screen.dart:214` | `Icons.email_rounded` | `PhosphorIconsRegular.envelope` |
| `lib/screens/user_register_screen.dart:466` | `Icons.error_outline_rounded` | `PhosphorIconsRegular.warningCircle` |
| `lib/screens/user_register_screen.dart:267` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lockKey` |
| `lib/screens/user_register_screen.dart:246` | `Icons.lock_rounded` | `PhosphorIconsRegular.lockKey` |
| `lib/screens/user_register_screen.dart:196` | `Icons.person_rounded` | `PhosphorIconsRegular.userCircle` |
| `lib/screens/user_register_screen.dart:414` | `Icons.visibility_off_outlined` | `PhosphorIconsRegular.eyeSlash` |
| `lib/screens/user_register_screen.dart:413` | `Icons.visibility_outlined` | `PhosphorIconsRegular.eye` |
| `lib/screens/verify_email_otp_screen.dart:167` | `Icons.mark_email_unread_outlined` | `PhosphorIconsRegular.envelopeSimpleOpen` |
| `lib/widgets/admin_destination_gallery_editor.dart:46` | `Icons.add_photo_alternate_outlined` | `PhosphorIconsRegular.imageSquare` |
| `lib/widgets/admin_destination_gallery_editor.dart:29` | `Icons.broken_image_outlined` | `PhosphorIconsRegular.imageBroken` |
| `lib/widgets/admin_destination_gallery_editor.dart:75, 99` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/widgets/api_image.dart:174` | `Icons.image_not_supported_outlined` | `PhosphorIconsRegular.imageBroken` |
| `lib/widgets/availability_calendar.dart:73` | `Icons.chevron_left` | `PhosphorIconsRegular.caretLeft` |
| `lib/widgets/availability_calendar.dart:86` | `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` |
| `lib/widgets/availability_calendar.dart:164` | `Icons.lock_outline_rounded` | `PhosphorIconsRegular.lock` |
| `lib/widgets/booking_ticket_qr_section.dart:173` | `Icons.refresh` | `PhosphorIconsRegular.arrowsClockwise` |
| `lib/widgets/destination_hero_gallery.dart:298` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/widgets/destination_hero_gallery.dart:64` | `Icons.landscape_outlined` | `PhosphorIconsRegular.mountains` |
| `lib/widgets/destination_location_map_preview.dart:89` | `Icons.location_on` | `PhosphorIconsRegular.mapPin` |
| `lib/widgets/international_phone_field.dart:103` | `Icons.arrow_drop_down` | `PhosphorIconsRegular.caretDown` |
| `lib/widgets/international_phone_field.dart:221` | `Icons.check` | `PhosphorIconsRegular.check` |
| `lib/widgets/international_phone_field.dart:201` | `Icons.search` | `PhosphorIconsRegular.magnifyingGlass` |
| `lib/widgets/operations_chrome.dart:86` | `Icons.calendar_today_outlined` | `PhosphorIconsRegular.calendarBlank` |
| `lib/widgets/operations_chrome.dart:70` | `Icons.keyboard_arrow_down_rounded` | `PhosphorIconsRegular.caretDown` |
| `lib/widgets/operations_chrome.dart:135` | `Icons.landscape_outlined` | `PhosphorIconsRegular.mountains` |
| `lib/widgets/operations_chrome.dart:58` | `Icons.place_outlined` | `PhosphorIconsRegular.mapPin` |
| `lib/widgets/profile_avatar.dart:60, 397` | `Icons.camera_alt_outlined` | `PhosphorIconsRegular.camera` |
| `lib/widgets/profile_avatar.dart:380, 597` | `Icons.close` | `PhosphorIconsRegular.x` |
| `lib/widgets/profile_avatar.dart:211` | `Icons.edit_outlined` | `PhosphorIconsRegular.pencilSimple` |
| `lib/widgets/profile_avatar.dart:92` | `Icons.person_outline` | `PhosphorIconsRegular.userCircle` |
| `lib/widgets/profile_avatar.dart:388` | `Icons.photo_library_outlined` | `PhosphorIconsRegular.images` |
| `lib/widgets/profile_avatar.dart:421` | `Icons.restart_alt` | `PhosphorIconsRegular.arrowCounterClockwise` |
| `lib/widgets/profile_avatar.dart:413` | `Icons.restore` | `PhosphorIconsRegular.arrowCounterClockwise` |
| `lib/widgets/reviews_sheet.dart:134` | `Icons.place_rounded` | `PhosphorIconsRegular.mapPin` |
| `lib/widgets/reviews_sheet.dart:146` | `Icons.star_rounded` | `PhosphorIconsFill.star` |
