# Tasks — Activity Detail
# Created: 2026-05-04
# Requires: design.md approved

## Task 1 — Repository methods + provider
Visible when done: `fetchById` and `updateWithConditions` methods on
`ActivityRepository`, `activityDetailProvider` exists, `flutter analyze`
passes. No UI yet.

Files:
- `lib/data/repositories/activity_repository.dart` (update)
- `lib/features/home/home_providers.dart` (update — add activityDetailProvider)

Subtasks:
- [ ] Add `fetchById(String activityId)` to `ActivityRepository`
- [ ] Add `updateWithConditions(activity, profile)` to `ActivityRepository`
- [ ] Add `activityDetailProvider` as `FutureProvider.family<Activity?, String>`
- [ ] Run `flutter analyze` — must pass before Task 2

---

## Task 2 — Extract shared condition widgets
Visible when done: Condition form widgets extracted to shared file,
AddActivityScreen still works, `flutter analyze` passes.

Files:
- `lib/features/shared/condition_profile_form.dart` (new)
- `lib/features/add_activity/add_activity_screen.dart` (update — import shared)

Subtasks:
- [ ] Extract `_ConditionSection`, `_TemperatureSection`,
      `_PrecipitationSection`, `_WindSection`, `_UvSection` to
      `lib/features/shared/condition_profile_form.dart` as public widgets
- [ ] Update `AddActivityScreen` to import from shared file
- [ ] Verify AddActivityScreen still works
- [ ] Run `flutter analyze` — must pass before Task 3

---

## Task 3 — ActivityDetailScreen UI
Visible when done: Navigating to `/activity/:id` shows the activity detail
screen with name, notes, condition profile (pre-populated from DB).
Loading shimmer while fetching. Error state with retry.

Files:
- `lib/features/activity_detail/activity_detail_screen.dart` (new)
- `lib/core/router.dart` (update — wire route)

Subtasks:
- [ ] Create `ActivityDetailScreen` as ConsumerStatefulWidget
- [ ] Wire `activityDetailProvider(activityId)` for data fetch
- [ ] Build loading shimmer `_ActivityDetailShimmer`
- [ ] Build error state `_ActivityDetailError` with retry
- [ ] Build `_ArchivedBanner` for archived activities
- [ ] Populate form fields from fetched activity data
- [ ] Reuse shared condition profile widgets
- [ ] Add route to `routerProvider` (already has path, wire builder)
- [ ] All colors, typography, spacing from design tokens
- [ ] Run `flutter analyze` — must pass before Task 4

---

## Task 4 — Save + archive logic
Visible when done: Editing fields and saving writes to Supabase. Archive
button with confirmation archives the activity. Both navigate back.

Files:
- `lib/features/activity_detail/activity_detail_screen.dart` (update)

Subtasks:
- [ ] Wire Save button to `updateWithConditions()`
- [ ] Log `condition_profile_updated` behavioral event
- [ ] Fire `OutAboutHaptics.onActivitySave()` on save
- [ ] Invalidate `activitiesProvider` + `activityDetailProvider`
- [ ] Build `_ArchiveButton` with confirmation AlertDialog
- [ ] Wire archive to `repo.archive()` + haptic + invalidate + pop
- [ ] Loading state on Save, block back during save
- [ ] Inline error banner on failure
- [ ] Run `flutter analyze` — must pass before Task 5

---

## Task 5 — Tests + polish
Visible when done: Tests pass, pre-flight clean.

Files:
- `test/features/activity_detail/activity_detail_screen_test.dart` (new)

Subtasks:
- [ ] Unit test: `fetchById` returns null for non-existent ID
- [ ] Widget test: screen shows shimmer in loading state
- [ ] Widget test: screen shows error state on fetch failure
- [ ] Widget test: Save button disabled when name empty
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Pre-flight checklist from CLAUDE.md

---

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] `ai_docs/screens_navigation.md` updated if routes changed
