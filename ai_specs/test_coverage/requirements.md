# Requirements -- Test Hardening
# Created: 2026-05-19 (as "test_coverage")
# Reconciled and executed: 2026-08-23
# Status: complete

## Summary

Find what is broken, fix it, and leave the suite able to catch it next time.
The original spec assumed the suite's problem was *absence* of tests. The
larger problem turned out to be tests that pass regardless of what the code
does.

## Reconciliation note (2026-08-23)

The 2026-05-19 draft was `Status: draft` with all 83 checkboxes unchecked. Its
one commit, `9cf60a1` ("Implement Features 1-5"), shipped it as spec-only — the
sixth member of a batch of five.

| Original task | Outcome |
|---|---|
| 1 — NotificationPreference unit tests | **Impossible.** Model and repository deleted in `49760bf` (2026-08-22). |
| 2 — Condition-matching edge cases | **~40% aimed at deleted code.** UV fields removed in `3d3e4f2`; precipitation `'light'` replaced by the bidirectional levels in `fb287b2`; `evaluateMatch` renamed to `evaluateDayMatch` with a changed signature in `6f51462`. Rewritten from scratch as `test/features/home/match_reason_test.dart`. |
| 3 — Category filtering | **Already done** by the `category_filtering` spec; all six cases exist verbatim. Verified, not repeated. |
| 4 — AddActivityScreen widget tests | Still valid; folded into this pass. |
| 5 — ActivityDetailScreen widget tests | Partly moot (notification prefs gone); the save-error and archive paths remain valid. |
| 6 — Integration test | **Blocked** — `integration_test` is not a dependency and was never added. |
| 7 — Final verification | Superseded by the checks below. |

Other stale references now removed: `home_providers.dart:192-197` (that range
is `nowProvider` today), `precipitationIntensity`, `today_tab.dart`.

## Acceptance criteria

### Bugs
- [x] Every defect found by static review of the notification path, matching
      logic, session boundaries and `behavioral_events` writes is fixed, or
      explicitly deferred with a reason.
- [x] The app was driven adversarially in the simulator and every exception,
      wrong render and stuck state was recorded before any fix was made.
- [x] No unfinished-work markers left misdescribing the code.

### Tests that can fail
- [x] No test asserts against a re-implementation of the code under test.
- [x] No test asserts a literal the app never renders.
- [x] No assertion is a tautology over a non-nullable or a declared type.
- [x] No test reads its expected value from the same call the code under test
      makes.
- [x] Every "nothing threw" assertion is paired with a positive one.
- [x] Every new regression test was confirmed failing against the pre-fix code
      before it was kept.

### Coverage
- [x] Notification payload parsing, including the malformed shapes that used
      to throw inside the click listener.
- [x] Matching: unconstrained profiles, boundary equality, bidirectional
      precipitation, legacy stored levels.
- [x] Session boundaries: teardown ordering, and state that must not survive.
- [x] `behavioral_events`: pre-auth buffering, geographic context, and the
      rule that no placeholder user id is ever written.

## Out of scope

Integration tests via `package:integration_test` (still not a dependency).
Wiring UI for the five allowlisted-but-unused event types — reported for a
product decision instead, see `design.md`.
