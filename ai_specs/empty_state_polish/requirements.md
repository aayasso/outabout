# Requirements -- Empty State Polish
# Created: 2026-05-19
# Status: draft

## Summary

Polish empty states across all main screens for consistency, warmth, and
clear calls to action. Each empty state gets a friendly icon, descriptive
text, and (where applicable) a CTA button. All empty states follow the
same typography, spacing, and entrance animation patterns.

## User Stories

### Primary flow
- As a new user, I want to see a warm, helpful empty state when I have
  no activities so that I know what to do next.

### Secondary flows
- As a user with activities but no weather matches, I want to see "No
  matches right now" with the weather card still visible so I understand
  why nothing matched.
- As a user viewing an empty filtered list, I want a clear message and
  a way to clear filters.
- As a user without location set, I want a clear prompt to enable
  location in Settings.

### Edge cases
- What happens when both weather and activities fail to load? The error
  state takes precedence over empty states.

## Acceptance Criteria

- [ ] Today tab -- no activities: shows icon (wb_sunny_outlined, 64px),
      heading "Add your first outdoor activity", body text "We'll let
      you know when the weather is perfect for it", and an "Add Activity"
      CTA button. (Already exists -- verify and polish if needed.)
- [ ] Today tab -- activities exist but no matches: shows weather card
      normally, then "No matches right now" message with body text
      "Your activities don't match current conditions. We'll notify you
      when they do." (Already exists -- verify and polish if needed.)
- [ ] Activities tab -- no activities: shows icon
      (directions_run_outlined, 64px), heading "No activities yet",
      body text "Add outdoor activities and we'll track the weather
      for you", and "Add Activity" CTA button. (Partially exists as
      "Your wishlist is empty" -- update copy.)
- [ ] Activities tab -- filters yield zero: shows "No activities in
      these categories" with a "Clear filters" button. (New -- added
      by category_filtering spec, verify consistency here.)
- [ ] Settings tab -- location not set: location row shows "Location
      not set" text with an "Enable location" button/link.
- [ ] All empty states use `OutAboutTypography.headingMedium(colors)`
      for the heading and `OutAboutTypography.bodyMedium(colors)` with
      `colors.textSecondary` for the body.
- [ ] All empty states use `OutAboutSpacing` constants for padding.
- [ ] All empty states animate in with `flutter_animate` fadeIn at
      `OutAboutAnimations.standardDuration`.
- [ ] Icon color is `colors.textSecondary` in all empty states.

## Screens Involved

- TodayTab (`lib/features/home/tabs/today_tab.dart`) -- verify/polish
  existing empty states.
- ActivitiesTab (`lib/features/home/tabs/activities_tab.dart`) -- update
  copy and verify styling consistency.
- SettingsTab (`lib/features/home/tabs/settings_tab.dart`) -- modify
  location row to show "Location not set" with enable button.

## Data Requirements

- Supabase tables: none
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? No, but empty
  state icons and text must be legible across all five themes. Use
  `colors.textSecondary` for icons and secondary text.

## Dependencies

- Depends on Feature 2 (category_filtering): the "filters yield zero"
  empty state in ActivitiesTab is created by the category_filtering
  spec. This spec verifies its consistency with the other empty states
  but does not create it from scratch.

## Out of Scope

- Illustrations or custom artwork (use Material icons only)
- Onboarding empty states (handled in onboarding flow)
- Error states (already handled separately)
