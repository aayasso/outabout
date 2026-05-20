# Requirements -- Form Validation
# Created: 2026-05-19
# Status: draft

## Summary

Add validation feedback across all form inputs in the app. Activity name
fields enforce 1-50 character limits, notes fields enforce a 200 character
max with a visible counter, sliders show current values with units, and
the save button displays a specific reason when disabled.

## User Stories

### Primary flow
- As a user, I want to see how many characters I've typed in the notes
  field so that I stay within the limit.
- As a user, I want to know why the save button is disabled so that I
  can fix the issue.

### Secondary flows
- As a user, I want to see an inline error if my activity name exceeds
  50 characters so that I can shorten it before saving.
- As a user, I want required fields marked with an asterisk so that I
  know what's mandatory.

### Edge cases
- What happens when the user pastes text that exceeds the limit? Show
  the character counter in an error state (red) and disable save.
- What happens when the name is only whitespace? Treat as empty -- save
  button stays disabled, show "Enter a name to save".

## Acceptance Criteria

- [ ] Add Activity screen: name field label shows "Activity name *"
      (asterisk indicates required).
- [ ] Add Activity screen: name field shows inline error text when
      length exceeds 50 characters: "Name must be 50 characters or less".
- [ ] Add Activity screen: notes field shows character counter below
      the field in format "X / 200". Counter turns error color when
      over 200.
- [ ] Add Activity screen: notes field input is not hard-limited (user
      can type beyond 200) but save is disabled if over limit.
- [ ] Add Activity screen: save button shows tooltip/helper text when
      disabled. If name is empty: "Enter a name to save". If name is
      too long: "Name is too long". If notes are too long: "Notes
      exceed 200 characters".
- [ ] Activity Detail screen: same name validation (1-50 chars) with
      inline error.
- [ ] Activity Detail screen: same notes validation (max 200 chars)
      with character counter.
- [ ] Activity Detail screen: save button shows same disabled-reason
      text.
- [ ] All sliders display their current value with units clearly.
      Temperature: "15-30 C" or "59-86 F" (respects user's unit).
      Wind: "Max 25 km/h" or "Max 15 mph". UV: "0-11".
- [ ] Validation text uses `OutAboutColors.errorColor` for errors.
- [ ] Character counter uses `OutAboutTypography.bodySmall(colors)`.

## Screens Involved

- AddActivityScreen (`lib/features/add_activity/add_activity_screen.dart`)
  -- modified: name validation, notes counter, save button reason.
- ActivityDetailScreen (`lib/features/activity_detail/activity_detail_screen.dart`)
  -- modified: same validation additions.

## Data Requirements

- Supabase tables: none (client-side validation only)
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? No
- Error text color uses `OutAboutColors.errorColor` (static, theme-
  independent). Character counter text uses `colors.textSecondary` in
  normal state.

## Dependencies

- No dependencies on other specs in this batch. Validation applies to
  the existing AddActivityScreen and ActivityDetailScreen fields
  regardless of whether categories or other features have shipped.

## Out of Scope

- Server-side validation (Supabase constraints)
- Settings display name field validation (confirmed: `_ProfileRow` in
  settings_tab.dart is read-only display; no editable display name field
  exists anywhere in the app)
- URL or location field validation
