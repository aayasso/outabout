# Requirements — Notification Preferences
# Created: 2026-05-05
# Status: draft

## Summary

Per-activity notification preferences allow users to control how and when they receive reminders for each activity. Users configure these preferences directly from the Activity Detail screen via a new "Notifications" section below the weather conditions. Preferences are persisted to the existing `notification_preferences` Supabase table using upsert. No new screen or route is needed.

## User Stories

### Primary flow
- As a user, I want to toggle notification types (morning-of, night-before, days-before, Sunday digest) for a specific activity so that I only receive reminders at times that work for me.

### Secondary flows
- As a user, I want to set how many days in advance I'm notified when "days before" is enabled so that I get enough lead time.
- As a user, I want to set what time "morning of" notifications arrive so that I'm notified at a useful hour.
- As a user, I want my notification preferences to load automatically when I open an activity so that I see my current settings.

### Edge cases
- What happens when the activity has no existing notification_preferences row? The section shows all toggles off (defaults). On first save, an upsert creates the row.
- What happens when the save fails (network error)? An error banner appears below the notification section. The user can retry.
- What happens when the user changes preferences but navigates away without saving? Changes are lost — the existing Save button at the bottom of the form saves everything together (activity fields + conditions + notification preferences).

## Acceptance Criteria
- [ ] A "Notifications" section appears below the Weather Conditions section on ActivityDetailScreen
- [ ] Section contains four toggles: Morning of, Night before, Days before, Sunday digest
- [ ] When "Morning of" is enabled, a time picker allows setting the notification time (default 7:00 AM)
- [ ] When "Days before" is enabled, a stepper or picker allows setting the day count (default 2, range 1-7)
- [ ] Existing notification preferences load from Supabase when the activity detail screen opens
- [ ] The existing Save button persists notification preferences via upsert alongside the activity update
- [ ] Toggle interactions trigger `OutAboutHaptics.onConditionToggle()`
- [ ] All UI elements use dynamic weather theme colors — no hardcoded colors
- [ ] The section renders correctly across all five weather themes (sunny, overcast, rainy, snowy, night)

## Screens Involved
- ActivityDetailScreen (`lib/features/activity_detail/activity_detail_screen.dart`) — modified, new notification section added below weather conditions

## Data Requirements
- Supabase tables: `notification_preferences` (existing)
- New columns needed: none — table already has all required columns
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

### notification_preferences columns (reference)
| Column | Type | Default |
|---|---|---|
| id | uuid PK | uuid_generate_v4() |
| activity_id | uuid FK | — |
| notify_days_before | boolean | false |
| days_before_count | integer | 2 |
| notify_sunday_digest | boolean | false |
| notify_night_before | boolean | false |
| notify_morning_of | boolean | false |
| morning_time | time | 07:00:00 |
| created_at | timestamptz | now() |
| updated_at | timestamptz | now() |

## Weather Theme Considerations
- Does this feature behave differently across themes? No
- All toggle and section styling follows the same dynamic color pattern used by the existing condition sections

## Out of Scope
- Push notification delivery infrastructure (handled separately in ai_specs/push_notifications/)
- Notification scheduling logic (backend/edge function concern)
- Global notification settings (this is per-activity only)
- New screen or route — everything lives within the existing ActivityDetailScreen

## Open Questions
- None — the table schema, target screen, and interaction model are all defined.
