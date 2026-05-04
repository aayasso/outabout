# Requirements — Home Screen (Full Implementation)
# Created: 2026-04-28
# Status: draft

## Summary
The home screen is the main hub users land on after onboarding. It shows
current weather conditions, the user's active activities with a live
conditions-match indicator, and recent reminders. The screen's visual
theme adapts to the active WeatherTheme, making the weather state
immediately visceral without the user needing to read any data.

## User Stories

### Primary flow
- As a user, I want to see my active activities and whether conditions
  are currently right for each one, so I know at a glance what I can do today.
- As a user, I want to see the current weather at my location so I
  understand why activities are or aren't highlighted.
- As a user, I want to tap an activity to see its full detail and conditions.

### Secondary flows
- As a user, I want to add a new activity from the home screen.
- As a user, I want to see my recent reminder history.

### Edge cases
- What happens when location permission is not granted?
  → Show a banner prompting to enable location. Activities show without
  conditions matching (all neutral state).
- What happens when Tomorrow.io fetch fails?
  → Show last cached conditions with a staleness indicator. Do not crash.
- What happens when the user has no activities yet?
  → Show empty state with CTA to add first activity.
- What happens when weather theme changes mid-session?
  → AnimatedTheme handles the transition automatically (500ms).

## Acceptance Criteria
- [ ] Current weather displayed (condition icon + temperature + location name)
- [ ] Active activities listed as cards with conditions-match indicator
- [ ] Green indicator when all conditions met, neutral when not
- [ ] Empty state shown when no activities exist
- [ ] Loading shimmer shown while data fetches
- [ ] Error state with retry when fetch fails
- [ ] All colors from `weatherThemeColorsProvider` — no hardcoded values
- [ ] Bottom navigation present with 4 tabs
- [ ] FAB or button to add new activity
- [ ] Haptic feedback: `onConditionMatch` when navigating to a matched activity

## Screens Involved
- `HomeScreen` (`/home`) — full implementation replacing current placeholder

## Data Requirements
- Supabase tables: `activities`, `activity_conditions`, `user_profiles`
- Tomorrow.io fields: `weatherCode`, `temperature`, `windSpeed`,
  `precipitationIntensity`, `uvIndex`
- SharedPreferences: read `onboarding_complete` (already handled by router)

## Weather Theme Considerations
- Yes — this screen is the primary showcase of weather theming.
- Card shadows switch between `OutAboutShadows.card` (light themes) and
  `OutAboutShadows.cardDark` (rainy/night themes).
- Weather condition icon tint uses static `OutAboutColors.X` (not dynamic).
- Background gradient could be subtle per-theme for extra atmosphere.

## Out of Scope
- Push notification management (Settings screen)
- Activity editing (ActivityDetail screen)
- Full reminder history (Reminders tab)
- Weather forecast (future WeatherDetail screen)

## Open Questions
- Should the weather fetch happen here or in a background service?
  → Fetch on HomeScreen mount and foreground. Background service is v2.
- Show temperature in F or C?
  → Follow device locale for v1. User preference setting is v2.
