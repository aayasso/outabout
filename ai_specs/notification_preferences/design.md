# Design — Notification Preferences
# Created: 2026-05-05
# Requires: requirements.md approved

## Screens & Widgets

### ActivityDetailScreen (modified)
- **Route:** existing `AppRoutes.activityDetail`
- **Type:** ConsumerStatefulWidget (already)
- **New widgets:**
  - `_NotificationPreferencesSection` — private widget inside activity_detail_screen.dart
  - Reuses the existing `ConditionSection` toggle pattern from `condition_profile_form.dart`
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (already in place)

### _NotificationPreferencesSection layout
```
"Notifications" heading (headingMedium)
┌─────────────────────────────────────┐
│ ☀ Morning of          [toggle]     │
│   ┌─ Time: 7:00 AM  [tap to edit] │  ← only visible when enabled
│                                     │
│ 🌙 Night before        [toggle]     │
│                                     │
│ 📅 Days before         [toggle]     │
│   ┌─ Days: 2  [- / +]             │  ← only visible when enabled
│                                     │
│ 📋 Sunday digest       [toggle]     │
└─────────────────────────────────────┘
```

Each toggle row uses `ConditionSection` (existing widget) with:
- `title`: notification type label
- `icon`: appropriate icon
- `enabled`: bound to local state bool
- `onToggled`: setState + `OutAboutHaptics.onConditionToggle()`
- `child`: sub-control (time picker or day stepper), shown only when enabled

## New Model

### NotificationPreference (`lib/data/models/notification_preference.dart`)

```dart
class NotificationPreference {
  final String id;
  final String activityId;
  final bool notifyDaysBefore;
  final int daysBeforeCount;
  final bool notifySundayDigest;
  final bool notifyNightBefore;
  final bool notifyMorningOf;
  final TimeOfDay morningTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotificationPreference({
    required this.id,
    required this.activityId,
    this.notifyDaysBefore = false,
    this.daysBeforeCount = 2,
    this.notifySundayDigest = false,
    this.notifyNightBefore = false,
    this.notifyMorningOf = false,
    this.morningTime = const TimeOfDay(hour: 7, minute: 0),
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

**morning_time handling:** Supabase stores `time` as `"07:00:00"` string. `fromJson` parses to `TimeOfDay`, `toJson` formats back to `"HH:mm:ss"`.

## Repository Methods

### NotificationPreferenceRepository (`lib/data/repositories/notification_preference_repository.dart`)

```dart
class NotificationPreferenceRepository {
  NotificationPreferenceRepository(this._client);
  final SupabaseClient _client;

  /// Fetch the notification preferences for an activity.
  /// Returns null if no row exists yet.
  Future<NotificationPreference?> fetchByActivityId(
    String activityId,
  ) async {
    final data = await _client
        .from('notification_preferences')
        .select()
        .eq('activity_id', activityId)
        .maybeSingle();
    if (data == null) return null;
    return NotificationPreference.fromJson(data);
  }

  /// Upsert notification preferences for an activity.
  /// Creates a new row if none exists, updates if one does.
  Future<void> upsert(NotificationPreference pref) async {
    final json = pref.toJson();
    json.remove('id');
    json.remove('created_at');
    json.remove('updated_at');
    json['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from('notification_preferences')
        .upsert(json, onConflict: 'activity_id');
  }
}
```

## Provider Structure

```dart
// Repository provider
final notificationPreferenceRepositoryProvider =
    Provider<NotificationPreferenceRepository>((ref) {
  return NotificationPreferenceRepository(
    ref.watch(supabaseClientProvider),
  );
});

// Fetch provider (family, keyed by activityId)
final notificationPreferenceProvider =
    FutureProvider.family<NotificationPreference?, String>(
  (ref, activityId) async {
    return ref
        .watch(notificationPreferenceRepositoryProvider)
        .fetchByActivityId(activityId);
  },
);
```

Providers live in `lib/features/activity_detail/` alongside the screen, or in `home_providers.dart` if co-location with `activityDetailProvider` is cleaner.

## Data Flow

### Load
```
ActivityDetailScreen opens
  → ref.watch(activityDetailProvider(id))        // existing
  → ref.watch(notificationPreferenceProvider(id)) // new
    → NotificationPreferenceRepository.fetchByActivityId()
      → Supabase SELECT from notification_preferences
        → returns NotificationPreference? (null = no row yet)
          → _initializeControllers populates local state bools
```

### Save (three sequential steps)
```
User taps Save
  → _onSave()
    → Step 1: UPDATE activities table
        await _client.from('activities').update({...}).eq('id', id)

    → Step 2: UPSERT condition_profiles table
        await _client.from('condition_profiles').upsert({...}, onConflict: 'activity_id')

    → Step 3: UPSERT notification_preferences table
        await notificationPreferenceRepository.upsert(pref)

    → All three complete successfully
    → OutAboutHaptics.onActivitySave()
    → ref.invalidate(activitiesProvider)
    → ref.invalidate(activityDetailProvider(id))
    → ref.invalidate(notificationPreferenceProvider(id))
    → context.pop()
```

If any step throws, the catch block sets `_errorMessage` and the user stays on the screen. Steps 1 and 2 remain in `ActivityRepository.updateWithConditions()`. Step 3 is a new call added after it in `_onSave()`.

## State Management in ActivityDetailScreen

New local state fields added to `_ActivityDetailScreenState`:

```dart
// Notification preferences state
bool _notifyMorningOf = false;
TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
bool _notifyNightBefore = false;
bool _notifyDaysBefore = false;
int _daysBeforeCount = 2;
bool _notifySundayDigest = false;
```

Initialized in `_initializeControllers()` from the fetched `NotificationPreference?`. If null, defaults remain.

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| No existing notification_preferences row | All toggles off (defaults). Upsert creates on first save. |
| Network failure on save | Error banner appears. User retries. Partial writes possible (activity updated but prefs not) — acceptable for MVP. |
| Activity loads but pref fetch fails | Notification section shows error state with retry. Rest of form still usable. |
| User toggles but doesn't save | Changes lost on navigation — matches existing behavior for conditions. |

## Haptic Moments
- Toggle any notification type on/off → `OutAboutHaptics.onConditionToggle()`
- Save button (all fields including notifications) → `OutAboutHaptics.onActivitySave()` (existing)

## Time Picker UX
When "Morning of" is enabled, tapping the time display opens the platform time picker via `showTimePicker()`. The selected time is stored as `TimeOfDay` locally and serialized to `"HH:mm:ss"` for Supabase.

## Day Count Stepper UX
When "Days before" is enabled, a row shows the current count with minus/plus buttons. Range: 1-7. Buttons disable at boundaries.

## Open Questions Resolved
- Save flow order: explicitly sequential — activities, then condition_profiles, then notification_preferences. All three must succeed before pop.
