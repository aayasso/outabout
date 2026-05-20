# Requirements -- Activity Categories
# Created: 2026-05-19
# Status: draft

## Summary

Add category support to activities. Categories are stored in the existing
`categories` Supabase table and referenced via `activities.category_ids`
(uuid array). On first app launch for a user, seed 8 default categories.
Users can also create custom categories. A category picker UI (horizontal
chip row) appears on Add Activity and Activity Detail screens above the
weather conditions section.

## User Stories

### Primary flow
- As a user, I want to assign one or more categories to an activity so
  that I can organize my outdoor activities by type.
- As a user, I want default categories pre-populated on my first launch
  so that I can start categorizing immediately without setup.

### Secondary flows
- As a user, I want to create a custom category with a name and optional
  color so that I can categorize activities the defaults don't cover.
- As a user, I want to toggle categories on and off on an activity by
  tapping chips so that assigning feels fast and lightweight.

### Edge cases
- What happens when the user has zero categories and just completed
  onboarding? Defaults are seeded as part of onboarding completion.
  If seeding fails (network error), log the error but don't block
  onboarding — the user can create categories manually later.
- What happens for existing users who completed onboarding before this
  feature existed? A one-time migration seeds defaults on first home
  screen load, gated by a `categories_seeded` SharedPreferences flag.
- What happens when the user already has categories? Skip seeding.
- What happens when a custom category name is empty? Disable the create
  button until a name is entered.
- What happens when a custom category name duplicates an existing one?
  Allow it -- users may want duplicates with different colors.

## Acceptance Criteria

- [ ] On onboarding completion, 8 default categories are seeded for the
      user: Running, Hiking, Cycling, Photography, Beach, Skiing,
      Camping, Picnic. Seeding fires in `first_activity_page.dart`
      after `setBool('onboarding_complete', true)`.
- [ ] For existing users, a one-time migration seeds defaults on first
      home screen load if `categories_seeded` SharedPreferences flag is
      false AND the user has zero categories. Flag is set after seeding.
- [ ] Seeding is a lifecycle event, NOT triggered by provider reads.
      `categoriesProvider` is a pure fetch — it never seeds.
- [ ] Default category colors are contrast-safe against all five weather
      theme chip backgrounds (surface and primary-with-alpha). The
      locked default colors are:
      - Running: #E55934
      - Hiking: #43A047
      - Cycling: #1E88E5
      - Photography: #8E24AA
      - Beach: #F4B942
      - Skiing: #039BE5
      - Camping: #8D6E63
      - Picnic: #FB8C00
- [ ] A horizontal scrollable chip row appears on Add Activity screen
      above the "Weather Conditions" heading.
- [ ] A horizontal scrollable chip row appears on Activity Detail screen
      above the "Weather Conditions" heading.
- [ ] Tapping a category chip toggles selection (multi-select).
- [ ] Selected category IDs are saved to `activities.category_ids` on
      activity save.
- [ ] Activity Detail screen pre-selects chips matching the activity's
      existing `category_ids`.
- [ ] A "+" chip at the end of the row opens a dialog to create a
      custom category with name (required) and optional color.
- [ ] Creating a custom category inserts a row into the `categories`
      table and the new chip appears immediately in the picker.
- [ ] Category picker uses `weatherThemeColorsProvider` for all colors.
- [ ] Haptic feedback fires on chip toggle (`onConditionToggle`).
- [ ] Each chip displays the category's own color (from the `color`
      column) as a small colored dot indicator. Chip background and
      border follow the weather theme: selected uses `colors.primary`
      with alpha, unselected uses `colors.surface` with `colors.divider`
      border.
- [ ] If a chip row encounters an activity's `category_ids` referencing
      a category that no longer exists, the orphaned ID is skipped and
      a warning is logged via `dart:developer`.

## Screens Involved

- AddActivityScreen (`lib/features/add_activity/add_activity_screen.dart`)
  -- modified: add category chip row above weather conditions.
- ActivityDetailScreen (`lib/features/activity_detail/activity_detail_screen.dart`)
  -- modified: add category chip row above weather conditions.
- FirstActivityPage (`lib/features/onboarding/pages/first_activity_page.dart`)
  -- modified: seed default categories on onboarding completion.

## Data Requirements

- Supabase tables: `categories` (existing), `activities` (existing,
  `category_ids` column already present)
- New columns needed: none -- schema already supports this
- Tomorrow.io fields needed: none
- SharedPreferences keys: `categories_seeded` (bool, one-time migration
  flag for existing users)

## Weather Theme Considerations

- Does this feature behave differently across themes? No
- Chip styling (selected/unselected) must adapt to active weather theme
  colors. Selected chip uses `colors.primary` with alpha; unselected uses
  `colors.surface` with `colors.divider` border.

## Dependencies

- No dependencies on other specs in this batch.

## Out of Scope

- Category management screen (edit/delete/reorder categories)
- Category icons rendered as actual icon widgets (string identifier
  stored; icon rendering is a future feature)
- Icon picker in the create category dialog (icon field stored as null;
  rendering infrastructure doesn't exist yet)
- Filtering activities by category (separate spec: category_filtering)
