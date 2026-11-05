# PRD IMPLEMENTASI — FLUTTER PHASE 1A
## Wisata Daerahku — Admin & Superadmin Operations Experience (Role 1 / Role 2)

**Versi:** 1.0 · **Tanggal:** 5 November 2026 · **Status:** Implementation-ready / wireframe approved

**Flutter:** https://github.com/koyotot/pami-wisata-daearahku  
**Laravel 13:** https://github.com/joytimess/pami-wisata-daerahku-api  
**Baseline GitHub source yang diverifikasi:** Flutter `main` @ `cba3d0b581c4ddc38c345380846f1a4de8e37847`; Laravel `main` @ `c43a5d18183a660ccf45830c2c51e6e2698ff322`. **Checkout lokal Codex mungkin berbeda: cek HEAD dan `git status` sebelum melakukan perubahan.**

**ACUAN DESAIN YANG SUDAH DISETUJUI:** interactive wireframe ChatGPT A00–A09, E00–E08, X01–X08 dalam percakapan pengguna, **ditambah bottom navbar dengan gaya role 0**. Dokumen referensi sebelumnya: `PRD-FigCraft-Wisata-Daerahku-Admin-Superadmin-Phase1A-UIUX-V2.md` (sebagai daftar kebutuhan dan penamaan layar, BUKAN perintah membuka FigCraft lagi). A00 V5 adalah baseline visual yang disetujui. Jika gambar/font/ukuran belum tersedia di working tree, gunakan source Flutter aktual sebagai rujukan, jangan mencoba menghasilkan ulang seluruh file FigCraft atau membakar token untuk desain ulang.

> **Implementasi dilakukan DI REPOSITORY FLUTTER SAJA.** Read-only terhadap Laravel. User telah menyatakan readiness backend telah dicek. Validasi singkat kontrak di environment lokal tetap diperlukan sebelum uji end-to-end, tetapi jangan ulang audit backend dari nol. Tidak ada PRD baru, tidak ada pertanyaan 25 keputusan, tidak ada DOKU nyata, tidak ada AI/LLM.

---

## 1. Business outcome / definition of success

Implementasi UI + integrasi API Laravel Phase 1A bagi Admin role 1 dan Superadmin role 2 dalam Flutter Android; dashboard memiliki nilai server-authoritative dan workflow approval berbasis claim, bukan local fake metrics. Seluruh fitur role 0 tetap kompatibel.

**Success criteria:**
1. Sesudah JWT role 1, user masuk ke Admin Operations shell; JWT role 2 masuk ke Superadmin Executive shell; role 0 **tetap** ke `MainNavigationScreen` lama.
2. Role 1 hanya melihat destinasi assigned dan personal Admin performance; role 2 melihat global operational oversight plus staff comparison yang benar-benar didukung sumber backend.
3. Bottom navbar berpenampilan **persis keluarga desain** role 0: floating, blur translucent, outline/icon-only + tooltip/semantics, selected fill tanpa mengubah stroke design, center elevated with shadow/blue, safe area, keyboard handling; **jangan meng-copy label teks di bawah ikon seperti wireframe chat**.
4. Claim → detail → approve/reject/release dan Superadmin reassign bekerja dengan backend yang sah, idempotent, 409-aware dan session-safe. Tidak ada silent auto-claim UI atau optimistic fake approval.
5. Semua approved screens dan state memiliki navigasi/representasi UI yang jujur; fitur API yang belum tersedia tampil **Belum tersedia**, tidak menggunakan dummy metrics.
6. Tidak ada penggunaan endpoint DOKU, tidak ada perubahan status pembayaran dari UI, dan tidak ada perubahan pada scanner/QR rules.

**Prioritas:** (P0) navigation shell + existing-role compatibility; (P1) Admin dashboard/queue/claim; (P2) Superadmin executive/assignment/reassign; (P3) analytics + edge states + handoff. Prioritas menunjukkan urutan pekerjaan, bukan permintaan untuk memecah commit otomatis.

---

## 2. Verified repository baseline (reuse first)

| Existing module | Confirmed behavior | Development impact |
|---|---|---|
| `lib/screens/session_destination.dart` | role 0 → `MainNavigationScreen`; role 1/2 → `AdminDashboard` | Replace role 1/2 routing with guarded Operations shell, preserve role 0 + verification flow |
| `lib/screens/main_navigation_screen.dart` | role-0 shell: `IndexedStack`, transitions, `FloatingBottomNav`, sessionGeneration guard, keyboard hide nav, `PopScope` | Mirror **patterns**, not copy visitor state or move role 0 routes |
| `lib/widgets/floating_bottom_nav.dart` | 5 hard-coded visitor tabs & `_NavIconPainter(tab, selected)`, raised blue center, blur, badge | Extend via optional role-specific config or separate thin wrapper while preserving legacy constructor and visitor appearance |
| `lib/screens/admin_dashboard.dart` | 1,358-line admin dashboard with drawer, counts via bookings/destinations pagination | Refactor into scoped dashboard view + shell; avoid layering new data/UI into giant single file |
| `lib/screens/daftar_pendaftar_screen.dart` | 1,021-line booking list, detail sheet, direct approve/reject | Integrate explicit claim at **every** decision entry point or route old entry points to one guarded flow |
| `lib/data/admin_state.dart` | `PagedListController`, `InFlightGuard`, `AdminBookingDecider` and stale response guards | Reuse + extend for claim/ownership/error 409; do not duplicate guards |
| `lib/data/business_repository.dart` | `BusinessRepository`, `Booking`, adminBookings/adminBooking/decideBooking; no dashboard/claim methods at verified baseline | Add typed models and functions, no redundant API client |
| `lib/services/api_client.dart` | `ApiClient.object` returns **only `data`**, `collection` returns `ApiPage(data, meta, links)`; supports headers | Preserve root meta using typed models or add small `objectWithMeta` additive method if needed; no breaking change to object |
| `lib/services/auth_session.dart` | JWT/sessionGeneration, `ApiException` status/code/context/outcomeUnknown | Honor session change, no credentials in logs; reconcile unknown mutation result |
| `lib/data/notification_state.dart` | Explicit role 0 gate (`session.role == 0`) | Do NOT reuse visitor notification state in role 1/2 without support; header action routes to operational Action Center without fake badge |
| `lib/screens/profil_user_screen.dart` | Visitor-focused favorites/reviews/history | Do NOT reuse unchanged for admin profile; create safe operational account/profile surface from existing auth data and actions |
| `lib/screens/admin_ticket_scanner_screen.dart` | Camera/preview/confirm scanner exists | Reuse via Navigator.push full-screen; preserve camera lifecycle/permission guards |
| `lib/screens/destination_admin_assignments_screen.dart` | Superadmin destination Admin assignment UI | Reuse existing flow and polish entry point, no new management logic |
| `lib/screens/kelola_admin_screen.dart` | Superadmin admin account list/management | Reuse within `Kelola` |
| `lib/screens/admin_common.dart`, `lib/theme/app_colors.dart`, `docs/DESIGN.md` | Admin UI pieces, visitor tokens; DESIGN.md contains older static audit details | Check actual code/tokens; share blue `#1976D2`, navy `#102D59`, pale `#F5F8FD`, Plus Jakarta Sans; don't use unrelated JoyUMKM palette |

**Mandatory non-regression:** role 0 Beranda/Riwayat/Jelajah/Notifikasi/Profil & visitor floating navbar, auth OTP/Google, review/favorites, image gallery, GPS/maps, ticket QR, and payment restrictions remain untouched.

---

## 3. Navigation and role shells — HARD REQUIREMENT

### 3.1 Main navigation (5 tabs; identical visual language to role 0)

| Index | Role 1 — Admin | Role 2 — Superadmin |
|---|---|---|
| 0 | **Beranda** → A00 | **Ringkasan** → E00 |
| 1 | **Booking** → A03 | **Operasi** → E03/E08 |
| 2 (elevated center) | **Scan QR** → opens existing full-screen scanner (NOT kept alive in IndexedStack); when pop, return to prior tab | **Analitik** → E01/E02 hub, actual tab with retention |
| 3 | **Destinasi** → A07 + existing destination management | **Kelola** → E05 + accounts/categories/facilities menus, role-scoped |
| 4 | **Profil** → role-appropriate profile, logout | **Profil** → role-appropriate profile, logout |

**Implementation guidance:** prefer one `OperationsNavigationShell(role)` with role-specific tab specs and guards; or two wrappers around one composable navigation shell. Keep visitor `FloatingBottomNav` constructor behavior unchanged (either optional `items/config` with backward-compatible default or `OperationsFloatingBottomNav` leveraging a shared visual implementation). Avoid accidental visitor painter labels/icons on admin tabs. Center Superadmin = Analitik; Admin center = Scan QR with distinct full-screen route. Do not embed Scanner inside keep-alive index / do not keep camera running behind tabs.

**UI behavior:** icon-only visual labels, 44–48dp hit boxes; icons have tooltips/semantics; selected fill + muted stroke per existing style, notifications badge only with authorized real source; safe-area bottom, Android gesture bar, keyboard hides bottom nav, scroll content has bottom padding to avoid overlap; back from detail → parent screen, back from non-home tab → home, back at home → platform back behavior. SessionGeneration prevents stale private content after logout/role changes. Profile screen must not lead to role-0-only pages.

**Existing Drawer:** may remain *secondary* as a maintenance shortcut during transition, but bottom nav is primary. Ensure all existing role-2 entry points (Manage Admin, Category, Facility, Assignment) remain accessible; delete no functionality, avoid duplicate route destinations. Role 1 may access only assigned destination operations as backend permits.

---

## 4. API contract — Laravel Phase 1A source of truth

**Base prefix:** `/api/v1`; JWT Bearer via existing `AuthSession`. No custom role header. All mutation identifiers are real GUIDs from Laravel, not sample booking numbers. Existing API errors must be represented via `ApiException(status, code, context, fieldErrors)`.

| Request | Response shape / UX mapping | Important constraints |
|---|---|---|
| GET `admin/dashboard/overview` | `data` has `metrics`, `personal`, `assigned_workload`, `visitors`, `booking_trend`, `scope`, `period`, `financial`; `generated_at` may be nested | Decision totals by period; pending snapshot; inspect actual envelope, never assume zero |
| GET `admin/dashboard/approvals` | `team_operational_totals`, `personal`, `series`, Superadmin `staff` (`admin_guid`, `decisions`) and `staff_workload` (`admin_guid`, `active_claims`) | `admin_guid` filter only for Superadmin; per-admin SLA requires filtered request, not staff aggregate list |
| GET `admin/dashboard/destinations` | paginated items: `destination_guid`, `name`, `capacity`, `allocated`, `remaining`, `confirmed_quantity`, `reserved_occupancy_percent`, `confirmed_occupancy_percent`, etc. | `date_basis=visit`; confirmed vs allocated distinct; `eligible_tickets=null` |
| GET `admin/dashboard/visitors` | observed `checked_in_tickets`, `checked_in_bookings`; `attendance_rate=null`, `no_show_count=null`, `availability=unavailable` | `date_basis=visit`; never render `null` as `0%` |
| GET `admin/dashboard/action-center` | paginated action rows (`action`, booking/destination refs, expiry) | operational only; do not fabricate DOKU/QR alerts |
| GET `admin/approval-queue` | paginated `booking_guid`, `destination_guid`, `destination_name_snapshot`, `status`, `approval_expires_at`, `claim_guid`, `owner_user_guid`, `expires_at`, `claim_state`, `action` | No visitor PII/name/quantity in this response; fetch `admin/bookings/{guid}` on opening detail |
| POST `admin/bookings/{booking_guid}/claim` | claim state response (`booking_guid`, `claim_guid`, `owner_user_guid`, `expires_at`, `approval_expires_at`, `state`) | `Idempotency-Key` header required, 15-min capped by original approval deadline |
| POST `admin/bookings/{booking_guid}/release` | updated claim state response | `Idempotency-Key` header required; only owner or authorized override |
| POST `superadmin/bookings/{booking_guid}/reassign` | updated claim state response | Role 2 only, `Idempotency-Key`, body `{admin_guid: GUID, reason: string}`; only active assigned target |
| POST `admin/bookings/{booking_guid}/approve|reject` | existing authoritative `Booking` response | revalidate claim, role, status + deadline. No automated retry with new idempotency key after outcome unknown |
| GET `admin/accounts`, admin destination assignment GET/PUT | Admin identity for E02 and E05 | superadmin-only; paginate; don't leak roles to role 1 |
| GET `bookings/{booking}/payment-preview` | visitor owner-only preview, feature-flag default off | **OUT OF SCOPE** for Admin/Superadmin UI; no fake paid |

**Query contract:** paired `from`/`to` in `YYYY-MM-DD`, max span 366 days; optional `destination_guid`, `page`, `per_page (<=100)`; optional `admin_guid` only Superadmin overview/approvals. **Do not send arbitrary date_basis**: backend forces `decision` on overview/approvals; `visit` on destinations/visitors/action-center; `created` on queue. Use response `period`, `metric_bases` to label graph axes; status snapshot vs period trend distinguish. On role 1 invalid destination, backend may 403/404; clear filter and show access-changed state, not global fallback.

**Envelope parsing:** `ApiClient.object()` returns only `data`, and `collection()` wraps items/meta/links. If report needs meta `generated_at`, read `data.generated_at` if provided; for paginated endpoints, use root `meta`, preserving pagination and `generated_at`. If more metadata is needed, add a **backward-compatible** method (not global API signature rewrite). Map API objects defensively without replacing null/unavailable with zero.

**Data semantics:**
- `approved_decisions`, `rejected_decisions`, `approval_rate_percent`, `avg_response_seconds`, `sla_compliance_percent` are **decision-time** metrics; snapshot `pending_approvals` is **current**, not part of period decisions.
- `quantity_requested`, `allocated`, `confirmed_quantity`, `checked_in_tickets` are **different units/status meanings**; never call allocated `sold`.
- Financial `availability=unavailable`, `gross_revenue/net_revenue/gateway_fees/refunds/settlement=null` → **Belum tersedia · DOKU belum terhubung** (not Rp0).
- `last_updated_at`/`generated_at` indicates server snapshot, not streaming/real-time SSE.
- Claim UI countdown derived from server `expires_at` and approval deadline, absolute timestamps/UTC, respecting local device time skew (re-query on resume, never assume local timer authorizes action).

---

## 5. Screen-by-screen implementation and mapping (27 approved variants)

### 5A. Admin role 1

| ID | Screen / interaction | API/service | Required states |
|---|---|---|---|
| A00 | Beranda Admin: scoped KPIs, segmented Destinasi/Kinerja Saya, chart, Action Center | overview, action-center | loading, error, zero assignment, financial unavailable |
| A01 | Kinerja Saya: personal decisions, response seconds, SLA, active claims | overview.personal + approvals.personal | percent null, empty period, data freshness |
| A02 | Filter Destinasi: only currently assigned options; reset/apply | `admin/destinations` + filtered dashboards | zero assigned, revoked assignment, preserve selection |
| A03 | Antrean Approval: paginated queue, filters, urgency/claim state | approval-queue | empty, `claim_state`, filter no result, refresh |
| A04 | Booking detail & Claim: fetch authoritative booking; claim then show decision/release | adminBooking, claim, release, approve/reject | available, mine, other, expired, decision-in-flight, completed |
| A05 | Konflik claim / expired detail | 409 code+context, read-after-conflict | block stale approval, retry refresh |
| A06 | Action Center: pending nearing SLA, expired claims, upcoming visits | action-center | empty, stale, pagination |
| A07 | Destination performance: quota/booking data | dashboard/destinations | capacity zero, unavailable attendance, scoped filter |
| A08 | Visits + Scan QR entry | visitors, existing `AdminTicketScannerScreen` | scanner full-screen, camera permission, back returns to shell |
| A09 | Financial unavailable | overview.financial | stable unavailable, no gateway CTA that pretends to work |

### 5B. Superadmin role 2

| ID | Screen / interaction | API/service | Required states |
|---|---|---|---|
| E00 | Executive Home: global operational KPI, critical action center, team trends | overview, approvals, action-center | loading, no data, financial unavailable |
| E01 | Destination comparisons: name + real quantity/booking/capacity metrics | destinations (all) | explicit metric basis, pagination |
| E02 | Staff performance overview: identities and decisions/claims, tap to filtered personal details | approvals `staff/staff_workload`; admin/accounts; filtered approvals `admin_guid` | staff list does **not** contain individual SLA; query details or mark as unavailable |
| E03 | Shared queue oversight global | approval-queue | owner, active claim, escalation, 409 |
| E04 | Reassignment: choose active role-1 Admin assigned to booking destination + reason | `admin/accounts`, destination/admins, reassign | disabled confirm until valid target + reason, idempotency, validation 422 |
| E05 | Admin assignments + manage accounts/category/facilities | existing `DestinationAdminAssignmentsScreen`, `KelolaAdminScreen`, category/facility screens | preserve existing admin management, no new fake writes |
| E06 | Audit Activity Timeline | **NO confirmed global timeline endpoint in current Laravel** | implement honest `Belum tersedia` screen and note backend gap; never fake log entries or silently build backend |
| E07 | Financial global unavailable | overview.financial | null/unavailable, no fabricated revenue |
| E08 | Operational/global drill-down | action-center, queue | priority cases grounded in server actions |

### 5C. Edge states for both roles

| ID | Trigger | UI behavior |
|---|---|---|
| X01 | role 1 no assigned destinations | no data leak, no implicit global fallback, instruction to contact Superadmin |
| X02 | no pending queue | positive empty state with return/refresh |
| X03 | loading | skeletons, no dummy KPI 0 while loading |
| X04 | timeout/network | error retry, optionally stale snapshot **explicitly labeled**, disable mutating buttons until reconciled |
| X05 | valid filters with no results | explain date/destination selection, reset filters |
| X06 | role/assignment revoked, 403/404 | purge private cache, return to scoped selector; revalidate role/session; role change redirects appropriately |
| X07 | financial unavailable | `—`, null/unavailable, DOKU not integrated |
| X08 | 409 claim_owned, claim_required, not_pending, deadline expired | no auto-submit; show latest server state and explicit refresh/claim route |

These are **navigation states or variants**, not necessarily 27 newly instantiated Dart screen classes. Reuse common widgets without creating empty placeholder screens for API-ready flows. All copy Bahasa Indonesia, no `DATA CONTOH` once connected to live Laravel; demo mode must visibly label synthetic data if explicitly enabled.

---

## 6. Approval flow: request lifecycle and safety

**Canonical Admin flow:** `GET approval-queue` → tap `booking_guid` → `GET admin/bookings/{guid}` → validate status/deadline → `POST claim` with stable key → confirm ownership from response → optionally approve/reject via **existing** endpoints → server-confirmed booking status → refresh queue/dashboard, or `POST release` with new stable key.

- Clicking Approve/Reject is not a claim action. Disable decision buttons until claim owner is authenticated actor and claim not expired by latest server information. When role 2 legitimately overrides, require explicitly documented backend behavior, no silent bypass.
- **Compat mode:** legacy backend `APPROVAL_CLAIM_MODE=compat` exists, but **new Flutter UI must use explicit claim** regardless. Remove/hide old approve/reject widgets that bypass claim UX, including list cards and bottom sheets. `compat` does not authorize double UI flows.
- **Strict mode:** do not set or request change here; handoff says migration later when every supported Admin Flutter client is compatible.
- Claim idempotency: generate per user action once; hold same key while response outcome is unknown. Never issue blind new key on timeout; fetch server booking/queue state and reconcile first.
- 409 `claim_owned`: show owner state if backend exposes to authorized Admin, no forced takeover for role 1. `claim_required`: prompt claim on fresh status. `booking_not_pending` / `approval_deadline_passed`: refresh detail and disable decision. `claim_not_owned` → refresh; 401 → session resolution; 403/404 → access revoked/scoped cache purge; 422 → field validation.
- Claim TTL 15 minutes capped by original `approval_expires_at`; countdown decoration does not extend booking SLA or guarantee server authorization. On app resume / returning to detail call server to refresh. No polling storm; refresh on focus/return/manual retry.
- Superadmin reassign uses `POST /superadmin/bookings/{guid}/reassign`, requires `Idempotency-Key`, `admin_guid`, non-blank `reason`, target role 1 active and assigned to the booking destination. Use current destination assignment API to filter eligible targets. After successful response refresh both queue and detail; after unknown response reconcile instead of repeat with new key.
- **No optimistic success/approval.** Only show success if server confirms or explicit reconciliation verifies the final state.
- Avoid duplicate action entry points across old booking list and new queue. Centralize mutation guard and state transitions in a single controller/notifier/service layer.

---

## 7. UI behavior, performance and accessibility

- Use existing Plus Jakarta Sans and blue/white design grammar of approved A00 V5; avoid random gradients, unnecessary cards, repetitive bland CTA or English-only labels.
- Mobile master 393×852; verify layout at 360×800 and keyboard open, large text scaler, reduced motion, Android status/navigation safe areas. No bottom nav clipping chart or bottom buttons.
- Prefer `IndexedStack` only for light non-camera tabs; lazy load expensive tab data when selected; reuse backend pagination and `PagedListController`, do not preload every tab/destination/user.
- Pull-to-refresh on meaningful lists/cards; `generated_at` label and coherent client cache invalidation after mutations; no assertion of real-time push.
- Accessibility: tooltips/semantics labels for all icon-only tabs and alerts, selected state, adequate contrast/touch area; center action always discoverable.
- Role switch on the same physical device: clear stale role-specific dashboard, queue, PII and profile state when sessionGeneration changes; avoid orphan Navigator routes referencing prior role.
- Keep bottom nav tab page state independently from child full-screen details; standard Android back semantics and no duplicate Scaffold bottom bars.
- Avoid loading full admin accounts/pages just to render E02 if server permits bounded requests. For E05 existing management may already paginate; don't regress.

---

## 8. Error, data and gap handling (no invented backend)

| Condition | Handling | Test expectation |
|---|---|---|
| `financial.availability=unavailable` | Show unavailable, never 0 | No `Rp0` from unknown |
| `attendance_rate=null`, `no_show_count=null` | `—` with why unavailable | Do not show zero attendance |
| Superadmin staff list only `admin_guid`, `decisions` | Resolve names via paged authorized admin/accounts; details via `admin_guid` filtered approvals | No invented SLA names; no N+1 unbounded calls |
| E06 audit timeline API missing | Honest static **unavailable** explanation and route-preserving screen; flag backend follow-up | No fabricated audit entries |
| 409 claim conflict | no second blind mutation | Fresh GET then actionable UI |
| Changed assignment | clear scoped caches | No persistent stale destination data |
| Network failure after mutation | reconcile GET before any retry | No double approval claim |
| No destination assignment | X01 | Role 1 cannot see global data |
| User switches role or logs out | session generation guard + destroy cached sensitive state | No role 1/2 state crosses sessions |

**Backend gap escalation (NOT permission to edit Laravel):** if E02 needs a fully aggregated per-staff SLA list instead of filtered requests, or E06 requires a true global audit endpoint, document a minimal Laravel follow-up contract separately in handoff. Do not stop entire Flutter integration solely due to these two optional detail surfaces.

---

## 9. Implementation sequence, work packages and milestones

| Milestone | Changes | Exit gate |
|---|---|---|
| M0 — Read-only preflight | Check local HEAD/status, `AGENTS.md`, `docs/DESIGN.md`, actual backend API availability, existing tests; user reports migrations/readiness complete | No silent rework/repo overwrite |
| M1 — Navigation shell | Role 1/2 shell, configurable floating nav, role-specific profile, scanner full-screen; preserve role 0 | Role-based navigation and back behavior correct |
| M2 — Data contracts | Models, `BusinessRepository` methods, meta/error handling, scoped dashboard state | API real payloads mapped; no fake values |
| M3 — Admin operations | A00–A09, queue and claim safety, action center, destinations, visitors | Role 1 scoped; claim/release/decision 409-safe |
| M4 — Superadmin executive | E00–E08, admin comparison, reassign and existing management flows | Role 2 operations work; E02/E06 gaps handled honestly |
| M5 — States + handoff | X01–X08, targeted widget/integration tests, emulator focused smoke where available | All essential flows verified or limitations explicitly reported |

**Suggested new files (not mandatory):** `lib/screens/operations_navigation_shell.dart`, role home/dashboard widgets under `lib/widgets/admin/` or `lib/screens/operations/`, `lib/data/operational_models.dart`, `lib/data/approval_queue_state.dart`, API methods extending `business_repository.dart`. Follow existing conventions; keep files small and avoid expanding `admin_dashboard.dart` to >2k lines.

**Existing files requiring targeted changes:** `session_destination.dart`, `floating_bottom_nav.dart` (or shared presentation/wrapper), `admin_dashboard.dart`, `daftar_pendaftar_screen.dart`, `admin_state.dart`, `business_repository.dart`, `admin_common.dart`, existing management/profile entry points. Do not edit role 0 screens except minimal demonstrably necessary shared-component adaptation with pixel-behavior preservation.

---

## 10. Verification plan (LIGHT, focused on changed flows)

1. Add/adjust widget tests for role 0 nav visual/semantics regression and role 1/2 tab indexes, bottom-center action, safe-area, back navigation, full-screen scanner route.
2. API mapping tests for dashboard overview/approvals/destinations/visitors/action-center, paginated queue and `meta`, null financial/attendance handling.
3. Claim state tests: available/mine/other/expired, 409 conflict, idempotency key stable on unknown outcome, post-success reconcile, release/reassign, `claim_required`/deadline conflicts.
4. Security UI tests: no-assignment role 1, scope revoked, role switch and sessionGeneration stale payload cancellation, role 2 only assignment and E02 identity.
5. Manual Android targeted smoke if emulator available: 360×800 + 393×852, navigation, keyboard, QR full-screen, pull-to-refresh, parent/back, important CTA not obscured.
6. Run **focused test files** and `flutter analyze` only on changed files or targeted context if tooling permits; no costly repeated full suite/analyze by default. Report exact commands and counts; never fabricate PASS.
7. If Laravel local backend unreachable, use deterministic mock responses in **tests only**; do not mark E2E working. Do not insert fake live dashboard numbers in production UI.

Do not modify `.env`, credentials, run destructive DB commands, install new packages without justification, commit/push, or alter Laravel code. Scope ends after Phase 1A integration. No DOKU real payment or advanced Phase 2/3 intelligence.

---

## 11. Delegation and token-efficiency: MAXIMUM TWO subagents TOTAL

**Codex main is orchestrator.** Under `C:\Users\itsba\.codex\agents\` invoke **only these two if available**:
1. `flutter_engineer.toml` — implements Operations shell, UI, API models, claim workflow, and targeted tests.
2. `security_auditor.toml` — read-only targeted review for session isolation, claim/idempotency, backend-authoritative state, PII and role boundaries; minimal pointed feedback only.

Read `C:\Users\itsba\.codex\Agents.md`, repo `AGENTS.md` if present, relevant `docs/DESIGN.md`. Verify actual filenames (Windows may hide `.toml`). **DO NOT** also spawn `master_orchestrator`, `qa_engineer`, `system_architect` or other agents; no 2-per-phase reset. Avoid concurrent edits to same file and endless review loops. If subagent API absent, work directly main and report. Do not launch FigCraft/MCP, Gemini/Astra or agent-based image generation. Use approved conversation wireframe as design authority; source code runtime and actual Laravel contract for data.

**Checkpoints:** implement in M1–M5 order; main Codex should keep progressing unless a genuine safety blocker requires a precise stop. Do not ask the user to re-approve the already approved wireframe. Existing working changes remain intact.

---

## 12. Final delivery requirements

Codex must report:
- Flutter local branch/HEAD, `git status` before/after, created/changed files; confirm Laravel unchanged.
- Route/screen inventory mapping A00–A09, E00–E08, X01–X08 to implementation files and UI states; indicate COMPLETE/PARTIAL/BLOCKED honestly.
- Bottom navbar proof: role 0 unchanged, role 1 Scan QR center, role 2 Analitik center, icon-only and no overflow.
- API contract matrix GET/POST and example **real** verified JSON/pagination/metrics (sanitized) or clearly test fixture examples.
- Claim/reassign flow error and reconciliation behavior; compat remains, no strict switch.
- Targeted test results, manual smoke results if actually executed, and unrun checks.
- Gap E02 staff details and E06 audit endpoint if unresolved; no fabricated numbers.
- Flutter pending Phase 1B DOKU dependencies as a separate follow-up only.
- Explicit confirmation: no role 0 redesign, no Laravel edits, no DOKU live, no commit/push.

**Definition of done:** Approved operations wireframe transformed into Flutter mobile experiences backed by Laravel Phase 1A where data exists, with accurate state handling and role 0 protected from regressions. **STOP BEFORE PAYMENT PHASE 1B OR PHASE 2.**
