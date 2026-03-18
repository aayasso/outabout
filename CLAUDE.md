# OutAbout — Claude Code Project Brief

## What This App Does
OutAbout is a weather-aware activity reminder app. Users build a personal wishlist of activities (golf, hiking, visiting a rooftop bar, renting bikes, etc.) and get notified when weather conditions are right for each one. The core loop: save activities → set weather conditions → get a notification when it's time to go.

## Tech Stack
- **Frontend:** Flutter (iOS + Android)
- **Backend:** Supabase (project URL: https://tswxxjwqnppqlfcbfowt.supabase.co)
- **Weather API:** Tomorrow.io
- **Push notifications:** OneSignal
- **Auth:** Google Sign-In, email/password

## Supabase Schema
Six tables:
- `profiles` — user profile data
- `categories` — activity categories (e.g. Food & Drink, Sports, Culture)
- `activities` — user's saved activities with name, notes, category
- `condition_profiles` — weather conditions attached to each activity (temp range, precipitation, wind, UV)
- `notification_preferences` — ption settings
- `user_locations` — user's saved location for weather checking

## Design System
Always import and use the OutAbout theme from `lib/core/theme.dart`. Never hardcode colors, font sizes, or spacing values — always reference theme constants.

## Visual Direction
- **Vibe:** Warm, friendly, approachable, slightly playful
- **Personality:** Energetic and motivating — makes the user want to get off the couch
- **Primary color:** Sky blue (#4A9EFF)
- **Feel:** Like a clear-sky morning that makes you want to go outside

## UI Standards — Non-Negotiable
These are what separate a polished App Store app from a "vibecoded" one:

1. **No raw MaterialApp defaults** — every screen uses the OutAbout theme, never Flutter's grey defaults
2. **Loading skeletons, not spinners** — when data is loading, show shimmer skeleton placeholders shaped like the content
3. **Contextual empty states** — when a list is empty, show an illustration and an inviting message, never a blank screen
4. **Haptic feedbacicFeedback.lightImpact() when activities are saved, HapticFeedback.mediumImpact() when conditions match
5. **Hero transitions** — activity cards should hero-animate into their detail views
6. **Smooth page transitions** — use custom PageRouteBuilder with fade+slide, never the default push transition
7. **Safe area aware** — all screens must respect SafeArea for notch and home indicator
8. **Keyboard aware** — all forms must use SingleChildScrollView so the keyboard never covers inputs
9. **Error states** — every network call must handle errors gracefully with a user-friendly message
10. **No debug banner** — always set debugShowCheckedModeBanner: false in MaterialApp

## Screen Inventory
1. Onboarding / Auth
2. Activity Library (tabs: All / By Category / Conditions Met Now)
3. Add / Edit Activity
4. Browse Right Now
5. Settings / Account

## Bundle ID
com.outabout

## Tone of Voice (for empty states, onboarding copy, etc.)
Warm, direct, slightly playful. Like a friend who knows the weather and wmake the most of it. Never clinical, never corporate.
Examples:
- Empty activity list: "No activities yet. Add something you've been meaning to do."
- Conditions met: "Today's looking good for this. Go for it."
- No conditions met: "Nothing matching today's weather. Check back tomorrow."
