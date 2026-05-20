# Design -- Empty State Polish
# Created: 2026-05-19
# Requires: requirements.md approved

## Audit Results

### _TodayEmptyState (today_tab.dart:855)
- **Status:** Almost correct. Minor polish needed.
- Icon: `Icons.wb_sunny_outlined`, 64px, `colors.textSecondary` — correct
- Heading: "Add your first outdoor activity" — correct
- Body: "We'll let you know when the weather is perfect for it" — correct
- CTA: "Add Activity" ElevatedButton — correct
- Typography: `headingMedium(colors)` heading, `bodyMedium(colors)`
  with `textSecondary` body — correct
- Spacing: `OutAboutSpacing.xl` padding, `md`/`sm`/`lg` gaps — correct
- **Missing:** No entrance animation. Add `.animate().fadeIn(
  duration: OutAboutAnimations.standardDuration)`.

### _NoMatchesState (today_tab.dart:808)
- **Status:** Correct. No changes needed.
- Icon: `Icons.cloud_outlined`, 48px, `colors.textSecondary` — correct
  (48px is appropriate here since it's inline within content, not a
  full-screen empty state)
- Heading: "No matches right now" — correct
- Body: "Your activities don't match current conditions. We'll notify
  you when they do." — correct
- Typography: correct pattern
- Spacing: `OutAboutSpacing.lg` padding — correct
- Animation: `.animate().fadeIn(standardDuration)` — already present

### _ActivitiesEmptyState (activities_tab.dart:391)
- **Status:** Needs copy update and animation.
- Icon: `Icons.directions_run_outlined`, 64px, `colors.textSecondary` — correct
- Heading: **"Your wishlist is empty"** — change to **"No activities yet"**
- Body: "Add outdoor activities and we'll track the weather for you" — correct
- CTA: "Add Activity" ElevatedButton — correct
- Typography: correct pattern
- Spacing: correct pattern
- **Missing:** No entrance animation. Add `.animate().fadeIn(
  duration: OutAboutAnimations.standardDuration)`.

### _FilteredEmptyState (Feature 2 creates this)
- **Status:** Created by category_filtering spec. This spec verifies
  consistency only.
- Verify: icon uses `colors.textSecondary`, heading uses
  `headingMedium(colors)`, animation uses `standardDuration` fadeIn.
- No code changes — just visual verification during final check.

### Settings location row (settings_tab.dart:67-76)
- **Status:** Needs modification.
- Currently: `_SettingsRow` with `label: cityName` where `cityName`
  falls back to `'Location not set'`. No action button.
- **Change:** When location is null, replace the static row with a
  row that includes "Location not set" text plus an "Enable location"
  TextButton trailing widget.

## Screens & Widgets

### TodayTab (modified)
- **Change:** Add entrance animation to `_TodayEmptyState`.
- No structural changes.

### ActivitiesTab (modified)
- **Change:** Update `_ActivitiesEmptyState` heading copy. Add entrance
  animation.
- No structural changes.

### SettingsTab (modified)
- **Change:** Modify the Location section to show an "Enable location"
  button when `locationAsync.valueOrNull` is null.
- The `_SettingsRow` widget already supports a `trailing` widget and
  an `onTap` callback. Use `trailing` for the button.

## Settings Location Row Design

```dart
// When location is available:
_SettingsRow(
  icon: Icons.location_on_outlined,
  label: cityName, // e.g. "San Francisco, CA"
  colors: colors,
)

// When location is null:
_SettingsRow(
  icon: Icons.location_off_outlined,
  label: 'Location not set',
  colors: colors,
  trailing: TextButton(
    onPressed: openAppSettings, // from permission_handler
    child: Text(
      'Enable location',
      style: OutAboutTypography.labelLarge(colors)
          .copyWith(color: colors.primary),
    ),
  ),
)
```

The icon changes from `location_on_outlined` to `location_off_outlined`
when location is null, providing a visual signal.

### Permission behavior

The "Enable location" button unconditionally calls `openAppSettings()`
from `permission_handler`. It does NOT check permission status or call
`Permission.location.request()` first. This is deliberately heavy-handed
for simplicity — it matches the existing `_LocationPermissionBanner` in
today_tab.dart (line 285), which also unconditionally calls
`openAppSettings` without checking whether the user has been asked
before. Both locations use the same pattern: send the user to system
settings regardless of current permission status.

This means a first-time user who has never been prompted will go to
app settings rather than getting an in-app permission dialog. This is
acceptable because:
1. The onboarding flow (step 1, location_permission_page.dart) already
   prompts for location permission during initial setup.
2. If the user reaches this state, they either denied during onboarding
   or have a device-level restriction — both cases require app settings.

## Consistency Checklist

All empty states must follow this pattern:

| Property | Value |
|---|---|
| Icon size (full-screen) | 64px |
| Icon size (inline) | 48px |
| Icon color | `colors.textSecondary` |
| Heading style | `OutAboutTypography.headingMedium(colors)` |
| Heading alignment | `TextAlign.center` |
| Body style | `OutAboutTypography.bodyMedium(colors).copyWith(color: colors.textSecondary)` |
| Body alignment | `TextAlign.center` |
| CTA button | Full-width `ElevatedButton` (where applicable) |
| Outer padding | `OutAboutSpacing.xl` |
| Icon-to-heading gap | `OutAboutSpacing.md` |
| Heading-to-body gap | `OutAboutSpacing.sm` |
| Body-to-CTA gap | `OutAboutSpacing.lg` |
| Entrance animation | `.animate().fadeIn(duration: OutAboutAnimations.standardDuration)` |

## Data Flow

No new data flow. All changes are cosmetic — copy updates, animation
additions, and conditional UI in the settings location row.

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Weather + activities both fail | Error state takes precedence (existing behavior, unchanged) |
| Location null on Settings | "Location not set" + "Enable location" button |
| Location present on Settings | City name displayed (existing behavior) |
| User taps "Enable location" on Settings | Unconditionally opens system app settings via `openAppSettings()` |
| User returns after granting permission | `userLocationProvider` re-evaluates, city name appears |

## Haptic Moments

- No new haptic events.
