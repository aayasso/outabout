# Design -- Behavioral Event Audit
# Created: 2026-05-19
# Requires: requirements.md approved

## Architecture Context

### BehavioralEventService (existing)
- Located at `lib/services/behavioral_event_service.dart`
- Provider: `behavioralEventServiceProvider` in same file
- `log(String eventType, {Map<String, dynamic>? extra})` — fire-and-forget,
  never throws. Validates eventType against local `approvedEventTypes`
  list before inserting. Unknown types are silently skipped with a
  `debugPrint` warning.
- `extra` is merged into `session_context` jsonb field (not a separate
  column).
- The service already captures `active_theme`, `platform`, `app_version`,
  temporal context (hour, day, season), and geographic context in every
  event automatically.
- Error logging uses `debugPrint` (not `dart:developer`'s `log()`).

### Two-Layer Validation
Events must pass both:
1. **Client-side:** `approvedEventTypes` list in
   `behavioral_event_service.dart` — prevents unknown types from
   being sent to Supabase.
2. **Server-side:** `behavioral_events.event_type` CHECK constraint
   in Supabase — rejects inserts with unapproved types.

Both must be updated for new event types. If only client-side is
updated, the Supabase CHECK constraint will reject the insert (caught
by the service's try/catch, logged via debugPrint).

## Audit Results — Existing Events

| Event type | Where it fires | Status |
|---|---|---|
| `wishlist_added` | add_activity_screen.dart:98 | Fires. Extra: `activity_name`. Correct. |
| `wishlist_removed` | **MISSING** — in `approvedEventTypes` (line 17) and Supabase CHECK constraint but never fired. Should fire on activity archive in activity_detail_screen.dart:204 and on swipe-to-dismiss in activities_tab.dart:167. | **Needs fix.** |
| `condition_profile_updated` | activity_detail_screen.dart:175 | Fires. Extra: `activity_id`. Correct. |
| `auth_completed` | auth_page.dart:74 | Fires. Correct. |
| `auth_skipped` | auth_page.dart:96 | Fires. Correct. |
| `booking_integration_viewed` | booking_integrations_page.dart:26 | Fires. Correct. |
| `onboarding_completed` | Multiple onboarding pages (steps 1-6) | Fires with `step` in extra. Correct. |
| `theme_override_set` | **MISSING** — in `approvedEventTypes` list but never fired. `_ThemeOverrideSelector` in settings_tab.dart does not call the service. | **Needs fix.** |
| `notification_opened` | notification_service.dart:55 | Fires. Extra: `activity_id`. Correct. |

## Changes Required

### 1. Fix missing `theme_override_set` (SettingsTab)
Add to `_ThemeOverrideSelector.onTap` in settings_tab.dart:
```dart
ref.read(behavioralEventServiceProvider).log(
  'theme_override_set',
  extra: {'theme': option.theme?.name ?? 'adaptive'},
);
```
This event type already exists in `approvedEventTypes` and the Supabase
CHECK constraint. Only the firing call is missing.

### 2. Add `settings_changed` (SettingsTab)
Fire in `_TemperatureUnitRow.onTap`:
```dart
ref.read(behavioralEventServiceProvider).log(
  'settings_changed',
  extra: {'setting': 'temperature_unit', 'new_value': newUnit},
);
```
Also fire `settings_changed` alongside `theme_override_set` for the
theme change:
```dart
ref.read(behavioralEventServiceProvider).log(
  'settings_changed',
  extra: {'setting': 'theme_override', 'new_value': option.theme?.name ?? 'adaptive'},
);
```
Theme changes produce two events deliberately: `theme_override_set` for
theme-specific analytics, `settings_changed` for generic
settings-engagement analytics. These are related, not duplicates.

### 3. Fix missing `wishlist_removed` (ActivityDetailScreen + ActivitiesTab)
The event type exists in `approvedEventTypes` and the Supabase CHECK
constraint but is never fired. Add it to both archive code paths:

In `activity_detail_screen.dart`, inside `_onArchive` after
`repo.archive(activity.id!)` succeeds:
```dart
ref.read(behavioralEventServiceProvider).log(
  'wishlist_removed',
  extra: {'activity_id': activity.id, 'method': 'archive_button'},
);
```

In `activities_tab.dart`, inside the `Dismissible.onDismissed` callback
after `repo.archive(activity.id!)`:
```dart
ref.read(behavioralEventServiceProvider).log(
  'wishlist_removed',
  extra: {'activity_id': activity.id, 'method': 'swipe_dismiss'},
);
```

### 4. Add `weather_refreshed` (TodayTab)
Fire in the `RefreshIndicator.onRefresh` callback (today_tab.dart:87):
```dart
ref.read(behavioralEventServiceProvider).log('weather_refreshed');
```
No extra needed — temporal/session context is captured automatically.

### 5. Add `notification_preference_changed` (ActivityDetailScreen)
Fire in each notification toggle's `onToggled` callback in
`_buildNotificationSection`:
```dart
ref.read(behavioralEventServiceProvider).log(
  'notification_preference_changed',
  extra: {
    'activity_id': widget.activityId,
    'preference_type': 'morning_of', // or night_before, days_before, sunday_digest
    'new_value': newValue,
  },
);
```

### 6. Add category events (CategoryChipPicker + CreateCategoryDialog)
These fire from widgets built by Feature 1.

**`category_selected` / `category_deselected`** — fire in the
`onToggle` callback wired in AddActivityScreen and ActivityDetailScreen:
```dart
ref.read(behavioralEventServiceProvider).log(
  isNowSelected ? 'category_selected' : 'category_deselected',
  extra: {
    'category_id': categoryId,
    'activity_id': activityId, // null on AddActivityScreen (not yet saved)
  },
);
```

**`category_created`** — fire after successful
`CategoryRepository.insert` in the dialog wiring:
```dart
ref.read(behavioralEventServiceProvider).log(
  'category_created',
  extra: {
    'category_name': result.name,
    'has_color': result.color != null,
  },
);
```

### 7. Add filter events (ActivitiesTab)
These fire from the chip toggle handlers built by Feature 2.

**`filter_applied`** — fire in the `onToggle` handler:
```dart
ref.read(behavioralEventServiceProvider).log(
  'filter_applied',
  extra: {
    'category_id': categoryId,
    'active_filter_count': _selectedCategoryIds.length,
  },
);
```

**`filter_cleared`** — fire in the `onClearAll` handler. Capture
`previousCount` BEFORE clearing the set:
```dart
final previousCount = _selectedCategoryIds.length;
setState(() => _selectedCategoryIds = {});
ref.read(behavioralEventServiceProvider).log(
  'filter_cleared',
  extra: {'previous_filter_count': previousCount},
);
```

## Client-Side Approved Types Update

Add to `approvedEventTypes` list in `behavioral_event_service.dart`:
```dart
'category_created',
'category_selected',
'category_deselected',
'filter_applied',
'filter_cleared',
'weather_refreshed',
'notification_preference_changed',
'settings_changed',
```

Note: `wishlist_removed` and `theme_override_set` are already in the
list — they just need their firing calls added.

## Supabase Migration

Create migration file
`supabase/migrations/YYYYMMDDHHMMSS_add_behavioral_event_types.sql`:

```sql
ALTER TABLE behavioral_events
  DROP CONSTRAINT IF EXISTS behavioral_events_event_type_check;

ALTER TABLE behavioral_events
  ADD CONSTRAINT behavioral_events_event_type_check
  CHECK (event_type IN (
    -- existing
    'condition_match_notified',
    'notification_opened',
    'app_opened_post_notification',
    'activity_confirmed',
    'condition_match_ignored',
    'activity_viewed',
    'wishlist_added',
    'wishlist_removed',
    'condition_profile_updated',
    'affiliate_link_clicked',
    'partner_impression_viewed',
    'partner_cta_clicked',
    'auth_completed',
    'auth_skipped',
    'onboarding_completed',
    'booking_integration_viewed',
    'theme_override_set',
    -- new
    'category_created',
    'category_selected',
    'category_deselected',
    'filter_applied',
    'filter_cleared',
    'weather_refreshed',
    'notification_preference_changed',
    'settings_changed'
  ));
```

This drops the old constraint and recreates it with all types. The
migration is idempotent — running it twice is safe because of
`DROP CONSTRAINT IF EXISTS`.

## Files Modified

| File | Changes |
|---|---|
| `lib/services/behavioral_event_service.dart` | Add 8 new types to `approvedEventTypes` |
| `lib/features/home/tabs/settings_tab.dart` | Add `theme_override_set` + `settings_changed` events |
| `lib/features/home/tabs/today_tab.dart` | Add `weather_refreshed` event |
| `lib/features/activity_detail/activity_detail_screen.dart` | Add `notification_preference_changed` + `wishlist_removed` events |
| `lib/features/home/tabs/activities_tab.dart` | Add `filter_applied` / `filter_cleared` + `wishlist_removed` events |
| `lib/widgets/category_chip_picker.dart` | Add `category_selected` / `category_deselected` events |
| `lib/widgets/create_category_dialog.dart` (or its wiring site) | Add `category_created` event |
| `supabase/migrations/` | New migration for CHECK constraint |

## Edge Cases

| Scenario | Behavior |
|---|---|
| Event logging fails | Caught by service try/catch. debugPrint logs error. User action not blocked. |
| New event type not in approvedEventTypes | Service skips with debugPrint warning. Never reaches Supabase. |
| New event type in approvedEventTypes but not in CHECK constraint | Supabase rejects insert. Service catches error, logs via debugPrint. |
| Migration not yet applied | New events fail at Supabase level. Service catches silently. Events start working once migration runs. |
| User not authenticated | Service uses 'anonymous' as user_id (existing behavior). |

## Haptic Moments

- No new haptic events. This feature only adds logging.
