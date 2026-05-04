# Design — Add Activity
# Created: 2026-05-04
# Requires: requirements.md approved

## 1. Screens & Widgets

### AddActivityScreen
- **Route:** `AppRoutes.addActivity` (`/activity/add`)
- **Type:** ConsumerStatefulWidget (needs TextEditingControllers)
- **Providers watched:** `weatherThemeColorsProvider`, `weatherThemeProvider`
- **Providers read (on save):** `activityRepositoryProvider`,
  `behavioralEventServiceProvider`, `supabaseClientProvider`
- **Sub-widgets:**
  - `_ActivityNameField` -- required text input
  - `_NotesField` -- optional multiline text input
  - `_ConditionSection` -- reusable section with enable toggle + child content
  - `_TemperatureSection` -- RangeSlider for min/max (0-50 C)
  - `_PrecipitationSection` -- SegmentedButton (none / light OK / any)
  - `_WindSection` -- Slider for max speed (0-80 km/h)
  - `_UvSection` -- RangeSlider for min/max (0-11)
  - `_SaveButton` -- full-width ElevatedButton, disabled when name empty or saving

---

## 2. Provider Structure

No new providers needed. The screen uses local state for form fields
and calls existing providers on save:

```
activityRepositoryProvider    Provider<ActivityRepository> (existing)
behavioralEventServiceProvider Provider<BehavioralEventService> (existing)
supabaseClientProvider        Provider<SupabaseClient> (existing)
activitiesProvider            FutureProvider<List<Activity>> (existing -- invalidate on save)
```

---

## 3. Repository Methods

### ActivityRepository (existing -- add method)
**File:** `lib/data/repositories/activity_repository.dart`

```dart
/// Inserts activity + condition profile in sequence.
/// Returns the activity with nested condition profile.
Future<Activity> insertWithConditions({
  required Activity activity,
  required ConditionProfile profile,
}) async {
  // 1. Insert activity
  final activityData = await _client
      .from('activities')
      .insert(activity.toJson())
      .select()
      .single();
  final savedActivity = Activity.fromJson(activityData);

  // 2. Insert condition profile with the new activity ID
  final profileData = await _client
      .from('condition_profiles')
      .insert({
        ...profile.toJson(),
        'activity_id': savedActivity.id,
      })
      .select()
      .single();

  // 3. Return activity with nested profile
  return Activity(
    id: savedActivity.id,
    userId: savedActivity.userId,
    name: savedActivity.name,
    notes: savedActivity.notes,
    categoryIds: savedActivity.categoryIds,
    createdAt: savedActivity.createdAt,
    updatedAt: savedActivity.updatedAt,
    geographicContext: savedActivity.geographicContext,
    conditionProfile: ConditionProfile.fromJson(profileData),
  );
}
```

---

## 4. Data Flow

```
User fills form -> taps Save
  |
  |-- Validate name non-empty
  |-- setState isSaving = true
  |
  |-- activityRepository.insertWithConditions(activity, profile)
  |    |-- Insert into activities table
  |    |-- Insert into condition_profiles table
  |    '-- Return Activity with nested ConditionProfile
  |
  |-- behavioralEventService.log('wishlist_added',
  |     extra: {'activity_name': name})
  |
  |-- OutAboutHaptics.onActivitySave()
  |-- ref.invalidate(activitiesProvider)
  |-- context.pop()  // back to ActivitiesTab
  |
  '-- On error: show inline banner, setState isSaving = false
```

---

## 5. Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Empty name | Save button disabled |
| Network failure on save | Inline error banner, form preserved |
| RLS violation | Same as network failure -- generic error message |
| Save in progress | Save button shows CircularProgressIndicator, disabled |
| Back button while saving | Ignore back (PopScope) |
| No conditions enabled | Save without condition profile row (profile optional) |

---

## 6. Haptic Moments

| Interaction | Haptic | Method |
|---|---|---|
| Toggle condition section on/off | Light | `OutAboutHaptics.onConditionToggle()` |
| Save succeeds | Medium | `OutAboutHaptics.onActivitySave()` |

---

## 7. Condition Profile UI Details

### Temperature Section
- Toggle: "Temperature" with Switch
- When enabled: RangeSlider 0-50 C
- Display: "15 C - 30 C" labels at slider ends
- Default range: 15-30 C

### Precipitation Section
- Toggle: "Precipitation" with Switch
- When enabled: 3-option SegmentedButton
  - "No rain" (precipLevel = 'none')
  - "Light OK" (precipLevel = 'light')
  - "Any" (precipLevel = 'any')
- Default: 'none'

### Wind Section
- Toggle: "Wind" with Switch
- When enabled: Slider 0-80 km/h
- Display: "Max 25 km/h" label
- Default: 25 km/h

### UV Section
- Toggle: "UV Index" with Switch
- When enabled: RangeSlider 0-11
- Display: "3 - 8" labels
- Default range: 0-11
