# Requirements — Activity Detail
# Created: 2026-05-04
# Status: draft

## Summary
A full-screen view showing a single activity with its complete condition
profile. Users can edit the activity name, notes, and all condition settings
inline. Changes are saved to both the `activities` and `condition_profiles`
tables. Users can also archive the activity from this screen. A
`condition_profile_updated` behavioral event is logged on save.

## User Stories

### Primary flow
- As a user, I want to view an activity's full details and condition profile
  so I can understand what weather triggers it.
- As a user, I want to edit the activity name, notes, and condition settings
  inline so I can fine-tune when I get reminded.
- As a user, I want to save my edits and see updated condition chips when I
  return to the Activities list.

### Secondary flows
- As a user, I want to archive an activity I no longer care about so it
  stops appearing in my lists.
- As a user, I want to discard edits by tapping the back button without
  saving.

### Edge cases
- What happens when the activity ID in the URL doesn't exist?
  -> Show error state: "Activity not found" with a back button.
- What happens when the network fails during save?
  -> Show inline error banner. Keep the form populated.
- What happens when the user clears the activity name?
  -> Save button becomes disabled until a name is entered.
- What happens when another device archived the activity?
  -> On fetch, if `is_archived` is true, show "This activity has been
  archived" with a back button.

## Acceptance Criteria
- [ ] Screen accessible via `AppRoutes.activity` (`/activity/:id`)
- [ ] Fetches activity + condition_profiles from Supabase on mount
- [ ] Displays activity name, notes (editable)
- [ ] Displays full condition profile with same toggle/slider UI as
      AddActivityScreen
- [ ] Save updates `activities` row and upserts `condition_profiles` row
- [ ] `condition_profile_updated` behavioral event logged on save
- [ ] `OutAboutHaptics.onActivitySave()` fires on save
- [ ] Archive button with confirmation dialog
- [ ] Archive sets `is_archived = true`, fires
      `OutAboutHaptics.onActivitySave()`, navigates back
- [ ] `activitiesProvider` invalidated after save or archive
- [ ] Loading shimmer while activity is being fetched
- [ ] Error state with retry for fetch failures
- [ ] All colors from `weatherThemeColorsProvider`

## Screens Involved
- `ActivityDetailScreen` (`/activity/:id`) -- new screen

## Data Requirements
- Supabase tables: `activities` (read + update), `condition_profiles`
  (read + upsert), `behavioral_events` (insert via BehavioralEventService)
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations
- Yes -- standard theme-adaptive screen. No per-theme behavioral differences.

## Out of Scope
- Viewing condition match status on this screen (that's TodayTab's role)
- Notification preference management per activity
- Activity sharing or export
- Undo after archive

## Open Questions
- None -- all decisions made.
