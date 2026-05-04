# OutAbout — Architecture
# ai_docs/architecture.md
# Living document. Update when architecture decisions change.
# Last updated: 2026-04-28

## Overview

OutAbout is a weather-based activity reminder app (iOS + Android) built with
Flutter. Users define outdoor activities with preferred weather conditions.
OutAbout monitors real-time weather via Tomorrow.io and surfaces reminders
when conditions match. The UI adapts its visual theme dynamically to reflect
current weather — this is the core brand expression of the app.

---

## Tech Stack

| Layer | Technology | Role |
|---|---|---|
| Frontend | Flutter (Dart, SDK ^3.11.1) | iOS + Android |
| State management | Riverpod (hand-written, no code-gen) | All app state |
| Navigation | go_router ^14.8.1 | Declarative routing |
| Backend | Supabase | Auth, PostgreSQL, Realtime |
| Weather API | Tomorrow.io | Real-time conditions + forecasts |
| Location | geolocator + geocoding | User location for weather fetch |
| Permissions | permission_handler | Location + notifications |
| Animation | flutter_animate | Declarative animations |
| Loading states | shimmer | Skeleton screens |
| Env vars | flutter_dotenv | API keys (.env asset) |
| Persistence | shared_preferences | Onboarding flag, theme override |
| App info | package_info_plus | Version display |

---

## Core Architectural Concept — Dynamic Weather Theming

The weather theme system is the architectural spine of the entire app.
Every screen observes `weatherThemeColorsProvider` and rebuilds when the
weather (and therefore theme) changes. This is not optional or cosmetic —
it is the core user experience.

```
Tomorrow.io API
  → weatherCode (int)
    → WeatherThemeNotifier.setThemeFromConditions(code)
      → weatherThemeProvider (WeatherTheme enum state)
        → weatherThemeColorsProvider (WeatherThemeColors)
          → Every widget rebuilds with new colors
            → AnimatedTheme in MaterialApp.router transitions smoothly
```

Time-of-day check runs in parallel:
```
DateTime.now()
  → WeatherThemeNotifier.setThemeFromTimeOfDay(now)
    → WeatherTheme.night if hour >= 20 or < 6
```

User override takes full precedence:
```
userThemeOverrideProvider (WeatherTheme? persisted to SharedPreferences)
  → If non-null, weatherThemeProvider ignores API and time signals
```

---

## Provider Architecture

```
sharedPreferencesProvider       # injected at ProviderScope in main.dart
  ↓
userThemeOverrideProvider       # StateNotifierProvider<WeatherTheme?>
  ↓
weatherThemeProvider            # StateNotifierProvider<WeatherTheme>
  ↓
themeDataProvider               # Provider<ThemeData>  (used by MaterialApp)
weatherThemeColorsProvider      # Provider<WeatherThemeColors> (used by widgets)

supabaseClientProvider          # Provider<SupabaseClient>
packageInfoProvider             # FutureProvider<PackageInfo>
```

Feature providers live in their feature folder:
```
onboarding/onboarding_provider.dart
  onboardingStepProvider        # StateNotifierProvider<int>
```

---

## Folder Structure

```
lib/
  main.dart                         # Entry point, ProviderScope, AnimatedTheme
  core/
    theme.dart                      # All design tokens + outAboutTheme()
    weather_theme_provider.dart     # All weather theme providers
    router.dart                     # routerProvider, AppRoutes, auth redirect
    providers.dart                  # supabaseClientProvider, packageInfoProvider
  data/
    models/                         # Dart model classes (manual fromJson/toJson)
    repositories/                   # Supabase repository classes
  features/
    onboarding/
      onboarding_screen.dart        # ConsumerStatefulWidget, PageView host
      onboarding_provider.dart      # onboardingStepProvider
      pages/
        value_proposition_page.dart  # Step 0
        location_permission_page.dart # Step 1
        notification_permission_page.dart # Step 2
        booking_integrations_page.dart # Step 3
        auth_page.dart               # Step 4
        first_activity_page.dart     # Step 5
      widgets/
        progress_dots.dart           # Step indicator
    home/
      home_screen.dart              # ConsumerWidget (placeholder, to be built)
    [future features]/
  widgets/                          # Shared widgets across features
```

---

## Auth & Onboarding Logic

Dual-condition gate in router redirect:
- `onboarding_complete` (SharedPreferences bool) must be `true`
- Supabase `currentUser` must be non-null (live session)

If flag is set but session has expired → flag is reset, user returns to onboarding.
This prevents ghost sessions from bypassing onboarding.

```
App launch → /onboarding (initialLocation)
  redirect checks:
    complete=true  + session=true  + on /onboarding → /home
    complete=true  + session=false + anywhere       → reset flag → /onboarding
    complete=false + not on /onboarding             → /onboarding
    else → stay
```

Debug mode: session is cleared and onboarding flag is reset on every launch
(allows re-testing onboarding without clearing app data manually).

---

## Tomorrow.io Integration

Weather code mapping (from Tomorrow.io docs):
```
5000–5999 → WeatherTheme.snowy
4000–4999 → WeatherTheme.rainy
2000–2999 → WeatherTheme.rainy  (fog maps to rainy mood)
1100–1999 → WeatherTheme.overcast
1001      → WeatherTheme.overcast
default   → WeatherTheme.sunny
```

HTTP package (`http`) to be added when Tomorrow.io fetch is implemented.
API key stored in `.env` as `TOMORROW_API_KEY`.
Fetch on: app foreground, location change, user-triggered refresh.
Log active theme name via `weatherThemeNotifier.activeThemeName` for
Supabase session analytics (`session_context.active_theme`).

---

## Supabase Schema (planned)

### activities
```sql
id              uuid PRIMARY KEY DEFAULT gen_random_uuid()
user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
name            text NOT NULL
description     text
icon            text                    -- icon identifier string
is_active       bool NOT NULL DEFAULT true
created_at      timestamptz NOT NULL DEFAULT now()
updated_at      timestamptz NOT NULL DEFAULT now()
```

### activity_conditions
```sql
id              uuid PRIMARY KEY DEFAULT gen_random_uuid()
activity_id     uuid NOT NULL REFERENCES activities(id) ON DELETE CASCADE
condition_type  text NOT NULL           -- 'temp_min','temp_max','wind_max',
                                        --   'no_rain','no_snow','uv_max', etc.
condition_value float
created_at      timestamptz NOT NULL DEFAULT now()
```

### reminders
```sql
id              uuid PRIMARY KEY DEFAULT gen_random_uuid()
user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
activity_id     uuid NOT NULL REFERENCES activities(id) ON DELETE CASCADE
triggered_at    timestamptz NOT NULL DEFAULT now()
weather_snapshot jsonb                  -- Tomorrow.io response at trigger time
active_theme    text                    -- WeatherTheme.name at trigger time
was_dismissed   bool NOT NULL DEFAULT false
```

### user_profiles
```sql
id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
display_name    text
location_lat    float
location_lng    float
location_name   text
notifications_enabled bool NOT NULL DEFAULT false
onboarding_completed_at timestamptz
created_at      timestamptz NOT NULL DEFAULT now()
```

---

## Environment Variables

File: `.env` (declared as Flutter asset, never committed with real values)

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
TOMORROW_API_KEY=xxx
```

Access pattern:
```dart
dotenv.env['SUPABASE_URL']!
dotenv.env['SUPABASE_ANON_KEY']!
dotenv.env['TOMORROW_API_KEY']!
```

Never hardcode these values. The previous main.dart hardcoded the Supabase
anon key — that key has been rotated. Do not repeat.

---

## Architectural Principles

1. **Theme-first** — every color and text style comes from the active
   WeatherThemeColors. No exceptions.
2. **Repository pattern** — widgets never call Supabase directly.
3. **Hand-written Riverpod** — no riverpod_annotation, no code generation.
4. **Dual auth gate** — SharedPreferences flag AND live session required.
5. **Single responsibility** — one provider per concern, one repo per entity.
6. **Fail loudly** — never swallow exceptions silently.
7. **Const everywhere** — const constructors on all widgets and tokens.
