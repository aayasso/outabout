# Tasks — Add Activity
# Created: 2026-05-04
# Requires: design.md approved

## Task 1 — Repository method
Visible when done: `insertWithConditions` method exists on
`ActivityRepository`, `flutter analyze` passes. No UI yet.

Files:
- `lib/data/repositories/activity_repository.dart` (update)

Subtasks:
- [ ] Add `insertWithConditions` method to `ActivityRepository`
      that inserts activity then condition_profiles in sequence
- [ ] Run `flutter analyze` — must pass before Task 2

---

## Task 2 — AddActivityScreen UI
Visible when done: Screen renders with name field, notes field, four
condition sections with toggles/sliders, and a Save button. Navigating
to `/activity/add` shows the screen. No save logic yet.

Files:
- `lib/features/add_activity/add_activity_screen.dart` (new)
- `lib/core/router.dart` (update — add route)

Subtasks:
- [ ] Create `AddActivityScreen` as ConsumerStatefulWidget
- [ ] Add `_ActivityNameField` — TextField with controller
- [ ] Add `_NotesField` — multiline TextField
- [ ] Add `_ConditionSection` — reusable widget: label + Switch toggle
      + child content, with `OutAboutHaptics.onConditionToggle()` on toggle
- [ ] Add `_TemperatureSection` — RangeSlider (0-50), labels
- [ ] Add `_PrecipitationSection` — SegmentedButton (none/light/any)
- [ ] Add `_WindSection` — Slider (0-80), label
- [ ] Add `_UvSection` — RangeSlider (0-11), labels
- [ ] Add Save button (disabled when name empty)
- [ ] Add route to `routerProvider` with fade transition
- [ ] All colors from `weatherThemeColorsProvider`
- [ ] All typography with `colors` argument
- [ ] All spacing from `OutAboutSpacing`, radius from `OutAboutRadius`
- [ ] Run `flutter analyze` — must pass before Task 3

---

## Task 3 — Save logic + integration
Visible when done: Filling the form and tapping Save creates the activity
in Supabase, logs the behavioral event, shows haptic feedback, and navigates
back to ActivitiesTab. Error state shows inline banner.

Files:
- `lib/features/add_activity/add_activity_screen.dart` (update)

Subtasks:
- [ ] Wire Save button to `_save()` method:
      - Validate name non-empty
      - Build `Activity` and `ConditionProfile` from form state
      - Call `activityRepository.insertWithConditions()`
      - Log `wishlist_added` via `behavioralEventServiceProvider`
      - Fire `OutAboutHaptics.onActivitySave()`
      - Invalidate `activitiesProvider`
      - `context.pop()` on success
- [ ] Show loading state on Save button during save
- [ ] Show inline error banner on failure
- [ ] Block back navigation during save (PopScope)
- [ ] Run `flutter analyze` — must pass before Task 4

---

## Task 4 — Tests + polish
Visible when done: Unit tests and widget tests pass. Pre-flight clean.

Files:
- `test/features/add_activity/add_activity_screen_test.dart` (new)

Subtasks:
- [ ] Widget test: screen renders name field and Save button
- [ ] Widget test: Save button disabled when name is empty
- [ ] Widget test: condition toggles show/hide sliders
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Pre-flight checklist from CLAUDE.md

---

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] `ai_docs/screens_navigation.md` updated if routes changed
