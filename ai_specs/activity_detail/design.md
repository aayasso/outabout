# Design — Activity Detail
# Created: 2026-05-04
# Requires: requirements.md approved

## 1. Screens & Widgets

### ActivityDetailScreen
- **Route:** `AppRoutes.activity` (`/activity/:id`)
- **Type:** ConsumerStatefulWidget (needs TextEditingControllers)
- **Props:** `String activityId` (from route path parameter)
- **Providers watched:** `weatherThemeColorsProvider`, `weatherThemeProvider`,
  `activityDetailProvider(activityId)`
- **Providers read (on save):** `activityRepositoryProvider`,
  `behavioralEventServiceProvider`
- **Sub-widgets:**
  - `_ActivityDetailShimmer` -- loading skeleton
  - `_ActivityDetailError` -- error state with retry
  - `_ArchivedBanner` -- shown if activity `is_archived` is true
  - Reuses condition section widgets from AddActivityScreen:
    `_ConditionSection`, `_TemperatureSection`, `_PrecipitationSection`,
    `_WindSection`, `_UvSection`
  - `_ArchiveButton` -- destructive action with confirmation dialog

---

## 2. Provider Structure

### New providers

```
activityDetailProvider(String id)  FutureProvider.family<Activity?, String>
  |-- reads: activityRepositoryProvider
  '-- fetches single activity by ID with condition profile
```

```dart
final activityDetailProvider =
    FutureProvider.family<Activity?, String>((ref, activityId) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchById(activityId);
});
```

---

## 3. Repository Methods

### ActivityRepository (add methods)
**File:** `lib/data/repositories/activity_repository.dart`

```dart
/// Fetches a single activity by ID with its condition profile.
Future<Activity?> fetchById(String activityId) async {
  final data = await _client
      .from('activities')
      .select('*, condition_profiles(*)')
      .eq('id', activityId)
      .maybeSingle();
  return data != null ? Activity.fromJson(data) : null;
}

/// Updates activity fields and upserts condition profile.
Future<Activity> updateWithConditions({
  required Activity activity,
  required ConditionProfile profile,
}) async {
  // 1. Update activity
  await _client
      .from('activities')
      .update({
        'name': activity.name,
        'notes': activity.notes,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', activity.id!);

  // 2. Upsert condition profile
  await _client
      .from('condition_profiles')
      .upsert({
        ...profile.toJson(),
        'activity_id': activity.id,
        'updated_at': DateTime.now().toIso8601String(),
      });

  // 3. Re-fetch with join to return complete object
  final data = await _client
      .from('activities')
      .select('*, condition_profiles(*)')
      .eq('id', activity.id!)
      .single();
  return Activity.fromJson(data);
}
```

---

## 4. Data Flow

### View flow
```
ActivityDetailScreen mounts with activityId from route
  |
  '-- activityDetailProvider(activityId)
       |-- repo.fetchById(activityId)
       '-- Result: Activity with nested ConditionProfile
           -> populate TextEditingControllers and slider values
```

### Save flow
```
User edits fields -> taps Save
  |
  |-- Validate name non-empty
  |-- setState isSaving = true
  |
  |-- repo.updateWithConditions(activity, profile)
  |-- behavioralEventService.log('condition_profile_updated',
  |     extra: {'activity_id': activityId})
  |-- OutAboutHaptics.onActivitySave()
  |-- ref.invalidate(activitiesProvider)
  |-- ref.invalidate(activityDetailProvider(activityId))
  |-- context.pop()
  |
  '-- On error: inline banner, isSaving = false
```

### Archive flow
```
User taps Archive -> confirmation dialog
  |-- repo.archive(activityId)
  |-- OutAboutHaptics.onActivitySave()
  |-- ref.invalidate(activitiesProvider)
  |-- context.pop()
```

---

## 5. Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Activity not found (null) | "Activity not found" + back button |
| Activity is archived | `_ArchivedBanner` + back button |
| Network failure on fetch | Error state with "Try again" button |
| Network failure on save | Inline error banner, form preserved |
| Save in progress | Save button loading, back blocked |
| Name cleared | Save button disabled |

---

## 6. Haptic Moments

| Interaction | Haptic | Method |
|---|---|---|
| Toggle condition on/off | Light | `OutAboutHaptics.onConditionToggle()` |
| Save succeeds | Medium | `OutAboutHaptics.onActivitySave()` |
| Archive succeeds | Medium | `OutAboutHaptics.onActivitySave()` |

---

## 7. Shared Condition Widgets

The condition section widgets (`_ConditionSection`, `_TemperatureSection`,
`_PrecipitationSection`, `_WindSection`, `_UvSection`) should be extracted
to `lib/features/shared/condition_profile_form.dart` so both
AddActivityScreen and ActivityDetailScreen can reuse them. Extract during
Task 2 of add_activity or Task 1 of activity_detail -- whichever is built
second.
