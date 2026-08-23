# Tasks -- Test Hardening
# Created: 2026-05-19 (as "test_coverage")
# Reconciled and executed: 2026-08-23
# Status: complete

Ticks record what shipped, not what was planned.

## 0. Reconcile
- [x] Re-read the 2026-05-19 draft against the current app.
- [x] Drop Task 1 (subject deleted), the UV and precipitation-`'light'` half
      of Task 2, and Task 6 (dependency never added).
- [x] Record that Task 3 was already done by `category_filtering`.

## 1. Bug hunt
- [x] Static review of the notification path, matching logic, session
      boundaries and `behavioral_events` writes.
- [x] Hostile simulator walk, findings recorded before any fix.
- [x] Search for unfinished-work markers. No literal TODO/FIXME/HACK exists in
      `lib/`; three stale comments misdescribing the code were removed.

## 2. Fixes
- [x] Delete the condition profile when every condition is cleared, and make
      add/edit agree about what "no conditions" stores.
- [x] Stop claiming a weather match for an activity that constrains nothing.
- [x] Date-derive day labels; carry cache age; show a staleness banner.
- [x] Unique hero tags on both branch FABs.
- [x] Schedule error state: name what failed, add a retry.
- [x] Populate geographic context from the saved location; report absence as
      empty rather than `'US'`.
- [x] Read the active theme at log time instead of capturing it.
- [x] Await the sign-out teardown; invalidate `outcomePromptProvider`.
- [x] Harden notification payload parsing; buffer a pre-auth deep link.
- [x] Error handling on the temperature-unit write and on sign-out.
- [x] Buffer pre-auth events and flush on sign-in, with no placeholder id.
- [x] Wind chip units, categories-error row, unlogged save exception,
      `currentUser!` bang, `weekOfSeason` DST, dead `condition_match.dart`.

## 3. Vacuous assertions
- [x] Rewrite `location_service_test` against production code; make
      `mapPermission` and `mapPlacemark` reachable.
- [x] Replace `isNotNull` / `isA<Function>` / declared-type assertions.
- [x] Point `home_screen_test` at the label the app actually renders.
- [x] Import `SceneVeilAlpha` in `contrast_test`; drop the duplicated group.
- [x] Pair every `takeException(), isNull` with a positive assertion.
- [x] Make the six name/body mismatches do what their names say.
- [x] Confirm no test asserts a string absent from `lib/`.

## 4. Coverage
- [x] `test/features/home/match_reason_test.dart` (new)
- [x] `test/data/repositories/activity_repository_test.dart` (new)
- [x] Session-boundary group in `user_state_teardown_test.dart`
- [x] Pre-auth buffering group in `behavioral_event_service_test.dart`
- [x] Payload-parsing group in `notification_service_test.dart`
- [x] Each new regression test confirmed failing against pre-fix code.

## 5. Verification
- [x] `flutter analyze` — no new issues.
- [x] `flutter test` — 576 passing.
- [x] Simulator re-run: condition-clear persists, false match rails gone,
      hero exceptions 4 → 0.

## Open, awaiting a decision
- [ ] The five allowlisted event types with no call site — wire them or drop
      them from the allowlist. See `design.md` §1.13.
- [ ] 45 theme-parameterised widget tests are change-detectors that read their
      expected value from the code under test. See `design.md` §2.4.
- [ ] `integration_test` is still not a dependency, so there is no end-to-end
      activity-creation test.
