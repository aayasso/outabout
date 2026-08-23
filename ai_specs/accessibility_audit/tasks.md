# Tasks -- Accessibility Audit
# Created: 2026-05-19
# Reconciled and executed: 2026-08-23
# Status: complete

All work below is done. Ticks record what shipped, not what was planned.

## 0. Reconcile the 2026-05-19 draft
- [x] Re-verify every contrast figure against current `lib/core/theme.dart`
      — all five reproduced exactly; none of the fixes had landed.
- [x] Drop the `today_tab.dart` rows (replaced by `schedule_tab.dart` in
      `6f51462`) and the notification-timing rows (removed in `3d3e4f2`).
- [x] Extend scope to the surfaces built since: schedule view, weather
      scene, shared condition form, Find & book, outcome prompt, account
      deletion, Settings, onboarding.

## 1. Tokens (`lib/core/theme.dart`)
- [x] Add `onPrimary` per palette; wire `colorScheme.onPrimary`,
      `elevatedButtonTheme`, both FABs, the outcome chip, the theme chip,
      the segmented control and the switch thumb to it.
- [x] Add `primaryInteractive`; migrate every ink/border/indicator use of
      `primary` to it, leaving fills alone.
- [x] Darken `textSecondary` on overcast and snowy.
- [x] Sync `ai_docs/design_system.md`.

## 2. Contrast over the scene
- [x] Add `_sceneSurface()` and put `_EmptyText`, `_ActivityHeader` and
      `_ScheduleEmptyState` on it.
- [x] Leave `SceneVeilAlpha` untouched.

## 3. VoiceOver
- [x] Schedule card: `container` + `explicitChildNodes`, tap on the node,
      `excludeFromSemantics` on the GestureDetector.
- [x] Day header as a `header`, with named precipitation and wind figures.
- [x] Declare `onTap` wherever `excludeSemantics` drops the subtree's action
      (outcome chips, provider rows, theme chips, legal rows).
- [x] Stop double announcements (theme chips, legal rows, settings values,
      outcome prompt, provider rows, schedule card).
- [x] Delete dialog: hint inside the button, `liveRegion` on the error,
      `sendAnnouncement` when the confirm arms.
- [x] `semanticFormatterCallback` on both sliders.
- [x] `MergeSemantics` on condition rows; group label on the precipitation
      picker; label on `_MatchingDayBadge`; "Step N of 6" on `ProgressDots`.
- [x] Value and hint on the two tap-to-cycle settings rows.
- [x] Exclude the weather scene from semantics.
- [x] Consolidate `add_activity_screen.dart` onto the shared
      `ConditionSection` / `TemperatureSection` / `PrecipitationSection` /
      `WindSection`, deleting four private near-duplicates that carried no
      semantics at all.

## 4. Touch targets
- [x] Theme chips wrapped to 48 (measured 24-26pt before).
- [x] Confirm the precipitation segments were already 48.

## 5. Dynamic Type
- [x] `_DayHeader` second row -> `Wrap` (overflowed 92px and 106px at AX5).
- [x] `TemperatureSection` end labels -> `Flexible` (71px at AX5).
- [x] `_MatchingDayBadge` -> `Flexible` + ellipsis.
- [x] `AlertDialog(scrollable: true)`; sheet `isScrollControlled`.

## 6. Reduce Motion
- [x] Lift the scene's three-way check into `lib/core/motion.dart`.
- [x] `MotionSafeShimmer` for all six skeletons.
- [x] `animateSafely()` for all 16 entrance chains.
- [x] `motionDuration()` for the route fade, the theme cross-fade, the
      condition cross-fade and the progress dots.

## 7. Tests
- [x] `test/accessibility/contrast_test.dart`
- [x] `test/accessibility/semantics_test.dart`
- [x] `test/accessibility/tap_target_test.dart`
- [x] `test/accessibility/dynamic_type_test.dart`
- [x] `test/accessibility/reduce_motion_test.dart`
- [x] Each regression test confirmed failing against the pre-fix code.
- [x] Update `category_chip_picker_test`, `outcome_prompt_test` and
      `add_activity_screen_test` to the changed contracts.

## 8. Verification
- [x] `flutter analyze` — no new issues (16 pre-existing infos).
- [x] `flutter test` — 546 pass.
- [x] Device pass on iPhone 16e (iOS 26.3) with the semantics tree dumped
      at each step; delete dialog armed and then cancelled.

## Follow-ups not taken here
- `ColorScheme.onSecondary` is latent-failing but never painted; see
  `design.md` section 7.
- No CI runs these suites — the repo has no `.github/` workflows, so the
  gate is still the CLAUDE.md pre-flight checklist.
