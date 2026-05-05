# Tasks — Notification Preferences
# Created: 2026-05-05
# Requires: design.md approved

## Task 1 — Data Layer (model + repository + provider)
Visible when done: `flutter analyze` passes, no UI yet.

- [ ] Create model: `lib/data/models/notification_preference.dart`
  - Fields: id, activityId, notifyDaysBefore, daysBeforeCount, notifySundayDigest, notifyNightBefore, notifyMorningOf, morningTime (TimeOfDay), createdAt, updatedAt
  - `fromJson()`: parse `morning_time` string (`"07:00:00"`) to `TimeOfDay`
  - `toJson()`: format `TimeOfDay` back to `"HH:mm:ss"` string
  - All booleans default to `false`, daysBeforeCount defaults to `2`
- [ ] Create repository: `lib/data/repositories/notification_preference_repository.dart`
  - `fetchByActivityId(String activityId)` → `Future<NotificationPreference?>`
  - `upsert(NotificationPreference pref)` → `Future<void>` — upsert on conflict `activity_id`, strip id/created_at/updated_at, set updated_at to now
- [ ] Add providers (in `lib/features/home/home_providers.dart` or a new `activity_detail_providers.dart`):
  - `notificationPreferenceRepositoryProvider` — `Provider<NotificationPreferenceRepository>`
  - `notificationPreferenceProvider` — `FutureProvider.family<NotificationPreference?, String>` keyed by activityId
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 — UI: Notification section in ActivityDetailScreen
Visible when done: Notification toggles appear below weather conditions. Sub-controls expand when toggled. No save wiring yet.

- [ ] Add local state fields to `_ActivityDetailScreenState`:
  - `_notifyMorningOf`, `_morningTime`, `_notifyNightBefore`, `_notifyDaysBefore`, `_daysBeforeCount`, `_notifySundayDigest`
- [ ] Watch `notificationPreferenceProvider(widget.activityId)` in `build()`
- [ ] Initialize notification state in `_initializeControllers()` from fetched `NotificationPreference?` (null → defaults)
- [ ] Add `_NotificationPreferencesSection` private widget below the UV ConditionSection in `_buildForm()`
  - "Notifications" heading using `OutAboutTypography.headingMedium(colors)`
  - Four toggle rows reusing `ConditionSection` pattern:
    - Morning of → child: time display, tappable to open `showTimePicker()`
    - Night before → no child (simple toggle)
    - Days before → child: day count with -/+ buttons (range 1-7)
    - Sunday digest → no child (simple toggle)
  - All colors from `colors.X` — no hardcoded values
  - All spacing from `OutAboutSpacing`
  - All radii from `OutAboutRadius`
  - `OutAboutHaptics.onConditionToggle()` on every toggle change
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 — Save flow integration
Visible when done: Save button persists notification preferences. Three-step sequential save completes before navigating back.

- [ ] Modify `_onSave()` in `_ActivityDetailScreenState`:
  - Step 1 (existing): `repo.updateWithConditions(activity, profile)` — updates activities + upserts condition_profiles
  - Step 2 (new): `notificationPreferenceRepository.upsert(pref)` — upserts notification_preferences
  - Both steps must complete before proceeding
  - On error in either step: set `_errorMessage`, stay on screen
- [ ] Build `NotificationPreference` object from local state in `_onSave()`:
  - `activityId: original.id!`
  - Map local bools and values to model fields
  - `morningTime: _morningTime`
- [ ] After successful save:
  - `ref.invalidate(notificationPreferenceProvider(widget.activityId))` (new)
  - Existing invalidations for activitiesProvider and activityDetailProvider remain
  - `OutAboutHaptics.onActivitySave()` (existing)
  - `context.pop()` (existing)
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 — Polish & edge cases
Visible when done: Loading, error, and empty states handled. Section looks correct on all five themes.

- [ ] Handle `notificationPreferenceProvider` loading state — show shimmer for notification section while loading
- [ ] Handle `notificationPreferenceProvider` error state — show inline error with retry in notification section only (rest of form still usable)
- [ ] Entrance animation on notification section: `.animate().fadeIn()` matching existing form pattern
- [ ] Verify section renders correctly on all five themes (sunny, overcast, rainy, snowy, night)
- [ ] Verify time picker opens and returns selected time correctly
- [ ] Verify day count stepper disables at boundaries (1 and 7)
- [ ] Verify toggle haptics fire on each toggle
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors, no static OutAboutColors in widgets
- [ ] All typography calls pass `colors` argument
- [ ] No hardcoded spacing or radius values
- [ ] Supabase operations through repository classes only
- [ ] Haptics at correct interaction points
- [ ] Interactive elements have tooltip or Semantics label
- [ ] Tap targets >= 48x48dp on all tappable widgets
