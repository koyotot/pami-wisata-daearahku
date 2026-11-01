# PRD — Flutter Forgot & Reset Password via Email OTP

**Project:** Wisata Daerahku  
**Target repository:** `C:\laragon\www\pami-mobile\pami-wisata-daearahku`  
**Stack:** Flutter / Dart · Android Emulator · Laravel REST API · Firebase Google Login existing  
**Environment:** `.env.development` with `--dart-define-from-file`  
**Date:** 2026-11-01  
**Scope:** Flutter mobile authentication only; Laravel backend already implements the OTP contract.  
**Status:** Implementation brief; do not claim Flutter changes have been made by this document.

## 1. Objective

Complete Forgot & Reset Password **entirely within the Flutter app** via a 6-digit email OTP. The user has confirmed the Laravel backend can send the recovery OTP to Gmail. Remove dependence on email reset links, browser opening, Android App Links, Laragon `.test` domains, Cloudflare Tunnel, and `PASSWORD_RESET_URL` for **this workflow**.

Target journey:

`LoginView` → `ForgotPasswordScreen` (email) → `VerifyResetOtpScreen` (6-digit code) → `ResetPasswordScreen` (new password) → `LoginView`.

Do not redesign registration OTP, Google Sign-In, admin login, JWT refresh, or any tourism business features.

## 2. Codex agents — global user directory

Before assigning work, inspect these real global paths, not project-relative `.codex/agents` files:

- **Flutter implementation:** `C:\Users\itsba\.codex\agents\flutter_engineer.toml`
- **Automated testing:** `C:\Users\itsba\.codex\agents\qa_engineer.toml`
- **Security review:** `C:\Users\itsba\.codex\agents\security_auditor.toml`

Use specialist roles provided by the runtime. Do not claim TOML files were loaded as runtime agent configuration unless actually supported. Keep context and token usage efficient: inspect only relevant auth, navigation, networking and tests; work from existing changes.

## 3. Known Laravel contract (source: completed backend implementation report)

All paths begin with `/api/v1/auth`; use existing `AppConfig.apiBaseUrl` instead of hard-coded URLs. Existing JSON response wrapper is `data`.

| Action | Method and path | Request JSON | Response |
|---|---|---|---|
| Request OTP | `POST /forgot-password` | `{"email":"user@example.com"}` | HTTP `200` with generic acknowledgement; no disclosure of account existence |
| Resend OTP | `POST /password-reset/resend-otp` | `{"email":"user@example.com"}` | HTTP `200` generic acknowledgement, even if email unknown or cooldown not elapsed |
| Verify OTP | `POST /password-reset/verify-otp` | `{"email":"user@example.com","otp":"012345"}` | HTTP `200`, `{"data":{"reset_ticket":"...","expires_in_seconds":300}}` |
| Submit password | `POST /reset-password` | `{"email":"user@example.com","reset_ticket":"...","password":"...","password_confirmation":"..."}` | HTTP `200`, `{"data":{"message":"Password reset."}}` |

Backend rules: OTP is **six numeric characters**, expires after **600 seconds**, at most **five failed attempts**, resend has **60-second cooldown**. Reset ticket lasts **300 seconds**, is single-use, and must be held in memory only. Bad OTP/ticket typically yields **422**, API throttle may yield **429**. Treat server as authoritative; local countdown is display only.

**API precautions:**

- Send OTP as `String`, never parse to `int`; preserve leading zeros.
- Send `reset_ticket`, **not** the legacy `token` field.
- Do not treat HTTP `200` on request/resend as evidence an email was delivered, or that an account exists.
- Inspect actual error envelope and validation conventions in existing Dart services; do not make up backend response fields.
- Recovery requests should be unauthenticated; do not accidentally attach stale JWTs or trigger session refresh on these endpoints.
- Respect existing service layering; do not create an additional HTTP client unless the current architecture requires it.

## 4. Existing Flutter structure and integration points

Inspect and reuse, rather than replacing:

- `lib/screens/user_login_screen.dart` — the existing **Lupa password?** action, do not redesign again.
- `lib/screens/forgot_password_screen.dart` — existing email request screen; adapt messaging from **tautan reset** to **kode OTP**.
- `lib/screens/verify_email_otp_screen.dart` — registration verification flow; only borrow/reuse *presentation* widgets if safe. Do not share security state or endpoints.
- `lib/services/auth_session.dart` — existing public request pathway, session-generation guard, JWT handling.
- `lib/screens/session_destination.dart` — existing login/verification/session restoration navigation; make only essential changes.
- `lib/core/config/app_config.dart` — existing base URL from env.
- Tests for login, OTP and AuthSession; update focused tests rather than rewriting the full suite.

Choose sensible filenames consistent with repository style, e.g. `verify_reset_otp_screen.dart` and `reset_password_screen.dart`. If existing files already serve those roles, extend them instead of duplicating.

## 5. Screen A — ForgotPasswordScreen (modify existing)

- Preserve the overall blue/white Wisata Daerahku auth design, keyboard responsiveness, and existing navigation from Login.
- Title and explanatory text explicitly say **kode OTP 6 digit dikirim ke email**; remove all promise of a reset **link**.
- Email input validation, clear error messages, inline loading, disable duplicate submissions.
- On successful API acknowledgement, navigate to VerifyResetOtpScreen with normalized email and a **locally initiated** 60-second resend cooldown. Display a privacy-preserving generic message (e.g. "Jika alamat email memenuhi syarat, kode verifikasi akan dikirim.").
- Do not persist email/OTP/reset ticket as secrets or query parameters. Email may pass as a constructor argument in app memory.
- Distinguish form validation errors from offline, timeout, 429, and other server errors. Preserve server response without exposing technical data to users.

## 6. Screen B — VerifyResetOtpScreen (new)

- Six **visual** OTP slots, with one accessible underlying text input (as already proven in registration OTP UX) supporting numeric keyboard, paste, autofocus where appropriate, Android SMS/email autofill when available, and backspace.
- Never log the code. Avoid separate per-box focus traps; manage a single six-character source of truth.
- Show masked destination email if suitable and a clear edit-email/back action to return to Forgot screen; restarting should safely discard any earlier flow.
- On verify, use `POST /password-reset/verify-otp` with email and OTP string. Protect against concurrent submits and stale responses after dispose/navigation. HTTP 422: generic invalid/expired/used feedback and permit recovery; HTTP 429: rate-limit guidance; connection error: retry without falsifying success.
- On HTTP 200, strictly validate that `data.reset_ticket` is a nonempty string and `data.expires_in_seconds` is valid. **Never enter ResetPasswordScreen without a valid ticket.**
- Navigate with an in-memory ticket. Clear the typed OTP when verification succeeds and when a successful resend creates a new code; consider clearing after invalid submissions to avoid reuse confusion.
- Resend action uses `POST /password-reset/resend-otp`; show countdown as local UX, but do not claim server sent a new email merely because it returned generic HTTP 200. Starting or resetting a 60s client cooldown does **not** overrule server throttling; no infinite resend loop.
- Countdown/timers must be disposed correctly. Do not depend exclusively on `Future.delayed` loops that survive screen disposal. Keep logic testable with a controllable clock or injectable time source where appropriate.
- Process/app termination mid-flow returns to starting recovery; do not restore an OTP or reset ticket from storage.

## 7. Screen C — ResetPasswordScreen (new)

- Password and confirmation fields, show/hide toggles, strength/help requirements matching existing Laravel validation, keyboard-safe scrolling and responsive layout.
- Receive **email + reset ticket in memory only**. The ticket stays out of local storage, analytics, logs, deep links, browser URLs, toasts and widget diagnostics.
- Display a 5-minute remaining-time indicator based on `expires_in_seconds` returned at verification. Local timer is advisory; server expiry remains authoritative.
- Submit exact body: `email`, `reset_ticket`, `password`, `password_confirmation` to `POST /api/v1/auth/reset-password`.
- Prevent duplicate requests and stale async navigation. Handle 422 invalid/expired/consumed ticket by discarding the ticket and returning users to **request a new OTP** (not resubmitting stale proof). Handle field-specific password validation errors inline; do not discard a still-valid ticket just because the new password failed complexity rules, unless backend marks ticket invalid.
- On HTTP 200, clear secrets and form controllers, show confirmation, and navigate to **LoginView** with no automatic login. The backend revokes prior sessions; maintain normal existing authenticated-session invalidation rules and do not secretly create new JWTs.
- Avoid leaving plaintext password or ticket in navigation history/screen state after success. If app restarts, the ticket is gone and the user must restart recovery.

## 8. Routing and state architecture

- Keep the existing auth navigation architecture and role logic intact.
- Maintain a coherent **single recovery flow**: email → verify OTP → reset password → login. Use typed constructors / local state or existing routing patterns, not URLs or persistence.
- No `PASSWORD_RESET_URL`, webview, browser, Cloudflare Quick Tunnel, Firebase Dynamic Links, Android App Links or deep links required for this OTP-based recovery.
- Avoid duplicate network calls during rebuild; manage mounted/disposed and session generation races.
- Do not touch registration email verification OTP flow or allow tokens/tickets to cross purposes.
- Follow existing `AuthSession` and API error abstraction; where an external recovery service is cleaner, add it minimally and keep unauthenticated requests separate from authenticated session restoration.

## 9. UI/UX requirements

- Indonesian copy, consistent with LoginView's blue mountain branding and white rounded cards.
- Visually distinguish OTP registration from OTP reset through headings while staying stylistically consistent.
- Form fields centered within responsive content constraints, labels aligned left; reachable buttons on small Android viewport and with keyboard open. Support font scaling, error labels, screen reader focus order, semantic labels and touch targets.
- Display loading, failure, cooldown, expiration, success and retry states clearly.
- Password visibility toggle must not reset text cursor/content.
- Back navigation: returning from password setup discards the ticket only if the flow is explicitly abandoned; avoid an unsafe implicit recovery resume.

## 10. Tests and manual Android E2E

Add focused widget/service tests with mock HTTP responses **without claiming mock results prove Gmail delivery**:

1. Forgot request with syntactically valid/invalid email; 200 generic response for unknown addresses; offline/timeout/429.
2. Navigation from Login → Forgot → Verify → Reset → Login.
3. Six-slot input with leading-zero OTP (`"012345"`), paste/backspace/autofill, text scaling and small screen.
4. Countdown and resend success, resend 429, stale code input cleared, disposal and stale response safety.
5. Verify 422 and valid `{data:{reset_ticket, expires_in_seconds:300}}` 200; malformed/empty ticket must fail closed.
6. Reset form password mismatch and backend per-field 422, invalid/expired ticket, single submission, correct body and success return to Login.
7. Process loss / navigation abandonment: ticket not persisted, no attempt to resume proof.
8. Regression: registration OTP, login email/password, Google native Sign-In, admin role routing, AuthSession refresh generation guard and logout unaffected.
9. Analyzer for changed Dart files, focused tests, full Flutter tests, and `flutter build apk --debug --dart-define-from-file=.env.development`.

**Manual real-device/emulator test after implementation**:

- Laravel `php artisan serve --host=127.0.0.1 --port=8000`, queue worker, and Gmail SMTP active.
- Android emulator is running. From PowerShell use `& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000`.
- `flutter run -d emulator-5554 --dart-define-from-file=.env.development` (adjust device ID if needed).
- From app: Forgot → Gmail receives new OTP → Verify → new password → login with new password → old password rejected; test old session revocation, resend/invalid/expired OTP. Do not share code, passwords or reset ticket in reports.
- Label each criterion `PASS`, `FAIL`, `NOT VERIFIED`, or `BLOCKED` with realistic evidence. Run Flutter widget tests separately from manual E2E, and do not claim real Gmail delivery based on mocks.

## 11. Explicit exclusions

- **No modifications to Laravel backend**, migrations, API routes, SMTP config or queue.
- **No modifications to Firebase/Google OAuth native flow**, Gradle, or Google credentials.
- **No changes to registration OTP**, email verification flow, JWT architecture, admin/superadmin role policy.
- **No changes to tourism features**: catalogs, favorites, booking, quotas, payments, reviews, check-in, profile, admin business functionality.
- No new reset-link web page, tunnel or deep-link implementation.
- No Git commit, push, deployment, mass dependency upgrades, or unrelated UI redesign.

## 12. Deliverables to report

1. Exact files changed and purpose of each.
2. Confirmed request/response mapping to existing Laravel endpoints and error handling.
3. UX screenshots from emulator if possible, avoiding sensitive codes/tickets.
4. Focused tests, full regression, analyzer, Android debug build results.
5. Real Gmail/Android E2E status, including failures or blockers (do not assume success).
6. Security notes: ticket in memory only, OTP preserved as string, stale request and replay protections, no logging of secrets.
7. Any backend mismatch found: report it, but do not silently modify backend.

## 13. Completion criteria

**Implementation COMPLETE** when all three screens are wired to real Laravel API contract, error navigation is correct, and tests/build pass without new errors. **E2E VERIFIED** is separate: it requires real manual emulator flow with Gmail reception and successful new-password login. Do not mark E2E verified before those steps actually pass.
