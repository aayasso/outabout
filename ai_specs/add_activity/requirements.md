# Requirements — Add Activity
# Created: 2026-05-04
# Status: draft

## Summary
A full-screen form where users create a new outdoor activity with a name,
optional notes, and a weather condition profile. The condition profile is
configured inline on the same screen via toggles and sliders. Saving writes
to both the `activities` and `condition_profiles` tables, logs a
`wishlist_added` behavioral event, and navigates back to the ActivitiesTab.

## User Stories

### Primary flow
- As a user, I want to name my activity and optionally add notes so I can
  describe what I plan to do outdoors.
- As a user, I want to set preferred weather conditions (temperature range,
  precipitation level, max wind speed, UV range) so OutAbout knows when to
  remind me.
- As a user, I want to save the activity and immediately see it in my
  Activities list.

### Secondary flows
- As a user, I want to skip setting conditions and add them later, so I can
  quickly add an activity without fussing with sliders.
- As a user, I want to discard my draft by tapping the back button or a
  cancel action.

### Edge cases
- What happens when the user taps Save with an empty name?
  -> Save button stays disabled until name is non-empty.
- What happens when the network is down during save?
  -> Show inline error banner: "Couldn't save. Check your connection and try
  again." Keep the form populated so the user doesn't lose input.
- What happens when the user has no auth session?
  -> Router redirect catches this before the screen loads. Not handled here.
- What happens if the Supabase insert fails (RLS, server error)?
  -> Show inline error with "Try again" option. Do not navigate away.

## Acceptance Criteria
- [ ] Screen accessible via `AppRoutes.addActivity` (`/activity/add`)
- [ ] Activity name field is required; Save disabled when empty
- [ ] Optional notes text field
- [ ] Temperature section: enable toggle + min/max range slider (0-50 C)
- [ ] Precipitation section: enable toggle + level picker (none / light OK / any)
- [ ] Wind section: enable toggle + max speed slider (0-80 km/h)
- [ ] UV section: enable toggle + min/max range slider (0-11+)
- [ ] Save inserts into `activities` table, then inserts into
      `condition_profiles` table using the returned activity ID
- [ ] `wishlist_added` behavioral event logged on successful save
- [ ] `OutAboutHaptics.onActivitySave()` fires on successful save
- [ ] Navigates back to ActivitiesTab on success
- [ ] `activitiesProvider` is invalidated so the list refreshes
- [ ] All colors from `weatherThemeColorsProvider`
- [ ] Loading state on Save button while request is in flight

## Screens Involved
- `AddActivityScreen` (`/activity/add`) -- new screen

## Data Requirements
- Supabase tables: `activities` (insert), `condition_profiles` (insert),
  `behavioral_events` (insert via BehavioralEventService)
- New columns needed: none -- all columns already exist
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations
- Yes -- screen adapts to active weather theme like all screens.
- No per-theme behavioral differences.

## Out of Scope
- Category selection (future feature)
- Location attachment per activity
- URL/booking link attachment
- Editing an existing activity (that's ActivityDetail)

## Open Questions
- None -- all decisions made.
