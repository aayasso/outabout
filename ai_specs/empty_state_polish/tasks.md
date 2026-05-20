# Tasks -- Empty State Polish
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- TodayTab Empty State Animation
Visible when done: _TodayEmptyState fades in on mount.

- [ ] In `_TodayEmptyState` (today_tab.dart:855):
  - Add `.animate().fadeIn(
    duration: OutAboutAnimations.standardDuration)` to the
    `SliverFillRemaining` child (the Center widget or its parent)
- [ ] Verify all other properties already match the consistency
  checklist: icon 64px, `colors.textSecondary`, `headingMedium`,
  `bodyMedium` with `textSecondary`, `OutAboutSpacing` constants
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- TodayTab No-Matches Verification
Visible when done: _NoMatchesState confirmed correct. No code changes
expected.

- [ ] Verify `_NoMatchesState` (today_tab.dart:808) matches the
  consistency checklist:
  - Icon: `Icons.cloud_outlined`, 48px (inline size), `colors.textSecondary`
  - Heading: `headingMedium(colors)`
  - Body: `bodyMedium(colors)` with `textSecondary`
  - Animation: `.animate().fadeIn(standardDuration)` — already present
  - Spacing: `OutAboutSpacing` constants
- [ ] If any deviation found, fix it. If correct, mark as done.
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- ActivitiesTab Empty State Copy + Animation
Visible when done: _ActivitiesEmptyState shows "No activities yet"
heading and fades in on mount.

- [ ] In `_ActivitiesEmptyState` (activities_tab.dart:391):
  - Change heading from `'Your wishlist is empty'` to
    `'No activities yet'`
  - Add `.animate().fadeIn(
    duration: OutAboutAnimations.standardDuration)` to the Center
    widget (or wrap the return value)
- [ ] Verify all other properties match consistency checklist:
  - Icon: `Icons.directions_run_outlined`, 64px, `colors.textSecondary`
  - Body: "Add outdoor activities and we'll track the weather for you"
  - CTA: "Add Activity" full-width ElevatedButton
  - Spacing: `OutAboutSpacing` constants
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- ActivitiesTab Filtered Empty State Verification
Visible when done: _FilteredEmptyState (created by Feature 2) verified
consistent with other empty states.

- [ ] Verify `_FilteredEmptyState` (created by category_filtering spec)
  matches the consistency checklist:
  - Icon: 48px (inline), `colors.textSecondary`
  - Heading: `headingMedium(colors)`
  - CTA: TextButton with `colors.primary`
  - Animation: `.animate().fadeIn(standardDuration)`
  - Spacing: `OutAboutSpacing` constants
- [ ] If any deviation found, fix it. If correct, mark as done.
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- Settings Location Not Set
Visible when done: Settings tab location row shows "Location not set"
with "Enable location" button when location is null.

- [ ] In `SettingsTab.build` (settings_tab.dart), modify the Location
  section:
  - When `locationAsync.valueOrNull` is null:
    - Change icon from `Icons.location_on_outlined` to
      `Icons.location_off_outlined`
    - Set label to `'Location not set'`
    - Add `trailing:` TextButton with text **"Enable location"**
    - Style: `OutAboutTypography.labelLarge(colors).copyWith(
      color: colors.primary)`
    - `onPressed: openAppSettings` — unconditionally opens system
      app settings. Does NOT check permission status or call
      `Permission.location.request()` first. This is correct because
      the onboarding flow already prompts for permission; if the user
      reaches this state they either denied during onboarding or have
      a device-level restriction, both of which require app settings.
  - When `locationAsync.valueOrNull` is not null:
    - Keep existing behavior: `Icons.location_on_outlined`,
      `label: cityName`, no trailing widget
- [ ] Import `permission_handler` if not already imported in
  settings_tab.dart
- [ ] All typography passes `colors` argument
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Final Verification
Visible when done: All empty states are consistent across screens.

- [ ] Manual visual check across all five themes (sunny, overcast,
  rainy, snowy, night):
  - _TodayEmptyState: icon, text, and CTA legible
  - _NoMatchesState: icon and text legible
  - _ActivitiesEmptyState: icon, text, and CTA legible
  - _FilteredEmptyState: icon, text, and CTA legible
  - Settings location "not set" row: text and button legible
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors — all from `weatherThemeColorsProvider`
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`
- [ ] All entrance animations use `OutAboutAnimations.standardDuration`
- [ ] `ai_docs/` does not need updating (no schema changes)
```

---

Task count is 6: 1, 2, 3, 4, 5, 6.