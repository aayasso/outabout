# Requirements -- Category Filtering
# Created: 2026-05-19
# Status: draft

## Summary

Add a horizontal filter chip row at the top of the Activities tab. Each
chip shows a category name from the user's categories. Selecting one or
more chips filters the activities list to show only activities whose
`category_ids` array contains any of the selected category IDs.
Multi-select with an "All" chip to clear filters.

## User Stories

### Primary flow
- As a user, I want to filter my activities list by category so that I
  can quickly find activities of a specific type.

### Secondary flows
- As a user, I want to select multiple category filters so that I can
  see activities across several categories at once.
- As a user, I want to tap "All" to clear all filters and see every
  activity again.

### Edge cases
- What happens when the user has no categories? Hide the filter chip
  row entirely.
- What happens when active filters yield zero matching activities?
  Show empty state: "No activities in these categories" with a "Clear
  filters" button.
- What happens when an activity has no category_ids? It is excluded
  from filtered results (since it doesn't match any selected category).
  It appears when "All" is selected.

## Acceptance Criteria

- [ ] A horizontal scrollable chip row appears below the Activities tab
      SliverAppBar, above the activity list.
- [ ] The first chip is "All" and is selected by default.
- [ ] Each subsequent chip shows a category name from the user's
      `categories` table.
- [ ] Tapping a category chip selects it and deselects "All". Tapping
      "All" deselects all category chips.
- [ ] Multiple category chips can be selected simultaneously (OR logic).
- [ ] The activities list filters in real-time as chips are toggled.
- [ ] Filtered list shows activities where `category_ids` contains at
      least one of the selected category IDs.
- [ ] When filters yield zero results, an empty state shows "No
      activities in these categories" with a "Clear filters" button.
- [ ] Filter state is ephemeral (resets when leaving the tab).
- [ ] Chip row uses `weatherThemeColorsProvider` for all styling.
- [ ] Haptic feedback fires on chip toggle (`onConditionToggle`).

## Screens Involved

- ActivitiesTab (`lib/features/home/tabs/activities_tab.dart`) --
  modified: add filter chip row, filter logic.

## Data Requirements

- Supabase tables: `categories` (read), `activities` (existing, uses
  `category_ids`)
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? No
- Selected chip uses `colors.primary`; unselected uses `colors.surface`
  with `colors.divider` border. Same pattern as category picker chips.

## Dependencies

- Depends on Feature 1 (activity_categories): categories must exist in
  the `categories` table and activities must have `category_ids`
  populated before filtering is meaningful. The categories provider and
  repository built in Feature 1 are reused here.

## Out of Scope

- Filtering on the Today tab (only Activities tab)
- Persistent filter state across sessions
- Search/text-based filtering
