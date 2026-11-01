# Auth refinement QA evidence

Android emulator-5554, Android 17 API37, 1080x2400, density420. Screenshots 01–06 show production screen widgets through `test/manual_auth_preview.dart` without Firebase initialization or live API mutations. Session HTTP client rejects requests with503; reset ticket is a rendering-only placeholder. This is rendering evidence, not authentication E2E. Screens are mounted at root, so automatic pushed-route AppBar back arrows are absent in this harness.

All six final PNGs were individually inspected: shared sans typography and blue identity, no green recovery CTA/AppBar; both OTP screens use identical six slots. Login password/action align left/right; Google logo retained. Register is intentionally scrollable; CTA lies below first viewport. The responsive widget matrix caught a Register link-row overflow, fixed before final regression.

07: emulator density540 and font scale1.3 reset layout, inspected. Native field labels ellipsize in narrow fields.
08: small/enlarged Login with Android keyboard toolbar, not full keyboard occlusion proof.
09–10: actual full Android Gboard on Reset, then scrolled with CTA above keyboard, inspected.
Emulator density/font/IME setting restored to420/1.0/0 after checks.

PASS: focused auth suites24 tests.
PASS: six-screen responsive widget matrix (320x640, keyboard inset260, text scale1.3), one test.
PASS: final full `flutter test --reporter expanded`:235 passed,1 skipped (live API environment test).
PASS: analyzer for new QA test/harness; production analyzer reported separately by Flutter lead.

NOT VERIFIED: live Google/Firebase/Laravel/email delivery, real OTP-to-Dashboard, physical devices, TalkBack, measured contrast. Full six-screen combined small+large-text+software-keyboard behavior is covered by widget assertions; emulator combined configuration inspected on Login/Reset, not exhaustively on all six.
