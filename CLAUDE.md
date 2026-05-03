# CLAUDE.md — OutAbout Flutter App
# AI coding rules for Claude Code
#
# Structure:
#   Part 1 — Official Flutter AI Rules (Flutter team, condensed)
#   Part 2 — OutAbout Project Overrides (takes precedence)
#
# Last updated: 2026-04-28

# ============================================================================
# PART 1 — OFFICIAL FLUTTER AI RULES
# Source: flutter.dev/ai/ai-rules
# ============================================================================

You are an expert Flutter and Dart developer. Build beautiful, performant,
maintainable applications following modern best practices. Target: iOS + Android.

## Interaction Guidelines
- User is an experienced product owner. No over-explaining.
- Ask ONE clarifying question if request is ambiguous — then write code.
- Explain tradeoffs when suggesting new pub.dev packages vs existing ones.
- Run `dart_format`, `dart_fix`, and `analyze_files` after every file change.

## Flutter Style
- SOLID principles throughout.
- Concise, modern Dart. Functional and declarative patterns preferred.
- Composition over inheritance.
- Immutable data. StatelessWidget / ConsumerWidget must be immutable.
- Separate ephemeral UI state from app state.
- Compose complex UIs from small, reusable private Widget classes.

## Code Quality
- UI logic separate from business logic. Always.
- Meaningful, descriptive names. No abbreviations.
- 80 character line limit.
- PascalCase classes, camelCase members/functions, snake_case files.
- Functions under 20 lines. Single purpose.
- Never fail silently. Handle all errors explicitly.
- Use `dart:developer` log — never print.

## Dart Best Practices
- Sound null safety. Avoid `!` unless value is guaranteed non-null.
- async/await with try-catch. Futures for single ops, Streams for sequences.
- Exhaustive switch expressions. Pattern matching where it simplifies.
- Arrow syntax for one-liners.
- Records for returning multiple types without a full class.

## Flutter Best Practices
- Small, private Widget classes instead of helper methods returning Widget.
- Break large build() into smaller private Widget classes.
- ListView.builder / GridView.builder for all lists (lazy loading).
- compute() for expensive work off the UI thread.
- const constructors everywhere possible.
- Never network calls or heavy computation in build().

## Architecture
- MVC/MVVM separation: Presentation → Domain → Data → Core.
- Feature-based folder structure.
- All Supabase access through repository classes — never from widgets.

## Routing
- go_router only. No Navigator.push except for dialogs/sheets.
- All route paths as constants. No hardcoded strings in widgets.
- Auth redirect logic lives in router, not in screens.

## State Management
- **Project standard: Riverpod (hand-written, no code-gen)**. See Part 2.

## Data & Serialization
- Manual fromJson/toJson on model classes (no json_serializable yet).
- Snake_case JSON keys to match Supabase columns.

## Layout Safety
- Always Expanded/Flexible for Row/Column children in unconstrained contexts.
- Wrap when Row would overflow.
- LayoutBuilder for responsive decisions.

## Testing
- flutter test. package:test for unit, package:flutter_test for widgets.
- package:integration_test for E2E.
- mocktail for mocks (already in dev deps).
- Arrange-Act-Assert convention.

## Lint Rules
```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    prefer_const_constructors: true
    avoid_unnecessary_containers: true
    sized_box_for_whitespace: true
```

# ============================================================================
# PART 2 — OUTABOUT PROJECT OVERRIDES
# These are specific to OutAbout and TAKE PRECEDENCE over Part 1.
# ============================================================================

## Project Identity
OutAbout is a weather-based activity reminder app (iOS + Android).
- Description: "weather-based-reminders" (repo description)
- Core concept: Users set activities with weather conditions. OutAbout monitors
  real-time weather via Tomorrow.io and reminds users when conditions are right.
- Weather API: Tomorrow.io (not OpenWeather, not WeatherAPI)
- Backend: Supabase (Auth + PostgreSQL + Realtime)
- UI adapts dynamically to current weather — this is the core brand expression.

## The Most Important Rule in This File
**Every widget that displays color or text MUST get its values from
`weatherThemeColorsProvider`. Never hardcode colors or use static
`OutAboutColors` values in widget files.**

The theme is runtime-dynamic. It changes based on real weather conditions.
Any hardcoded color will be wrong the moment the weather changes.

## Token System — Do Not Refactor
OutAbout's design tokens use direct static classes (`WeatherThemeColors`,
`OutAboutTypography`, `OutAboutSpacing`, `OutAboutRadius`, `OutAboutShadows`).
The Flutter team's official rules recommend `ThemeExtension<T>` for custom
tokens — **do NOT apply this to OutAbout**. The existing system is intentional
and works with the dynamic weather theming architecture. Never introduce
`ThemeExtension`, `Theme.of(context).extension<X>()`, or `ColorScheme.fromSeed`
to replace the existing token classes. If asked to "improve" or "modernize"
the theme system, decline and explain the weather-adaptive architecture requires
the current approach.

```dart
// CORRECT — always this pattern
final colors = ref.watch(weatherThemeColorsProvider);
Text('Hello', style: OutAboutTypography.headingLarge(colors))
Container(color: colors.background)

// WRONG — never this
Text('Hello', style: OutAboutTypography.headingLarge)   // static style
Container(color: OutAboutColors.background)              // hardcoded color
Container(color: Color(0xFF...))                         // hardcoded hex
```

## Weather Theme System

### WeatherTheme enum
Five themes: `sunny`, `overcast`, `rainy`, `snowy`, `night`

### WeatherThemeColors — per-theme palette
Each theme provides: `background`, `primary`, `accent`, `text`,
`textSecondary`, `surface`, `cardBackground`, `divider`

| Theme | Background | Primary | Brightness |
|---|---|---|---|
| sunny | #FFF8EE | #F5A623 | light |
| overcast | #F0F2F5 | #4A9EFF | light |
| rainy | #1A2332 | #4A9EFF | dark |
| snowy | #F7F9FC | #90CAF9 | light |
| night | #0D1117 | #4A9EFF | dark |

### Provider chain
```dart
// Read current colors in any widget — this is the standard pattern
final colors = ref.watch(weatherThemeColorsProvider);

// Set theme from Tomorrow.io weather code
ref.read(weatherThemeProvider.notifier).setThemeFromConditions(weatherCode);

// Set night mode
ref.read(weatherThemeProvider.notifier).setThemeFromTimeOfDay(DateTime.now());

// User manual override (persisted to SharedPreferences)
ref.read(userThemeOverrideProvider.notifier).setOverride(WeatherTheme.rainy);
ref.read(userThemeOverrideProvider.notifier).setOverride(null); // clear override
```

### Tomorrow.io weather code mapping
```
5000–5999 → snowy     (snow)
4000–4999 → rainy     (rain/drizzle)
2000–2999 → rainy     (fog → rainy mood)
1100–1999 → overcast  (cloudy)
1001      → overcast  (cloudy)
default   → sunny     (clear)
```

Night mode: hour >= 20 OR hour < 6 → WeatherTheme.night

## Typography — HARD RULE
`OutAboutTypography` methods take `WeatherThemeColors` as a parameter.
Never call them without passing `colors`.

```dart
// CORRECT
OutAboutTypography.headingLarge(colors)
OutAboutTypography.bodyMedium(colors)
OutAboutTypography.labelSmall(colors)

// WRONG
OutAboutTypography.headingLarge   // missing colors arg
```

Full type scale:
- `displayLarge(colors)` — 34px, w700, ls -0.5
- `displayMedium(colors)` — 28px, w700, ls -0.3
- `headingLarge(colors)` — 22px, w700, ls -0.2
- `headingMedium(colors)` — 18px, w600, ls -0.1
- `headingSmall(colors)` — 16px, w600
- `bodyLarge(colors)` — 16px, w400, h 1.5
- `bodyMedium(colors)` — 14px, w400, h 1.5
- `bodySmall(colors)` — 12px, w400, h 1.4 (uses textSecondary)
- `labelLarge(colors)` — 15px, w600, ls 0.1
- `labelMedium(colors)` — 13px, w500, ls 0.1 (uses textSecondary)
- `labelSmall(colors)` — 11px, w500, ls 0.3 (uses textSecondary)

## Spacing — HARD RULE
Never hardcode padding/margin/gap values. Always use `OutAboutSpacing`.

| Constant | Value |
|---|---|
| `OutAboutSpacing.xs` | 4.0 |
| `OutAboutSpacing.sm` | 8.0 |
| `OutAboutSpacing.md` | 16.0 |
| `OutAboutSpacing.lg` | 24.0 |
| `OutAboutSpacing.xl` | 32.0 |
| `OutAboutSpacing.xxl` | 48.0 |
| `OutAboutSpacing.xxxl` | 64.0 |

## Border Radius — HARD RULE
Always use `OutAboutRadius` constants. Never hardcode radius values.

| Constant | Value | Semantic use |
|---|---|---|
| `OutAboutRadius.sm` | 8.0 | Small elements |
| `OutAboutRadius.md` | 12.0 | Buttons, inputs |
| `OutAboutRadius.lg` | 16.0 | Cards |
| `OutAboutRadius.xl` | 24.0 | Bottom sheets |
| `OutAboutRadius.full` | 999.0 | Pills, chips |

Semantic aliases (use these over raw values):
- `OutAboutRadius.cards` = lg (16)
- `OutAboutRadius.bottomSheet` = xl (24)
- `OutAboutRadius.buttons` = md (12)

## Shadows
```dart
OutAboutShadows.card      // standard card — use on light themes
OutAboutShadows.cardDark  // standard card — use on dark themes (rainy/night)
OutAboutShadows.button    // primary action buttons
OutAboutShadows.elevated  // bottom sheets, modals
```

Select shadow variant based on theme brightness:
```dart
final isDark = weatherTheme.brightness == Brightness.dark;
boxShadow: isDark ? OutAboutShadows.cardDark : OutAboutShadows.card,
```

## Animations — HARD RULE
```dart
OutAboutAnimations.standardDuration       // 300ms — all screen transitions
OutAboutAnimations.themeTransitionDuration // 500ms — weather theme switches
OutAboutAnimations.standardCurve          // Curves.easeInOut
```

All route transitions use FadeTransition with Curves.easeOutCubic at
standardDuration (300ms). Match this pattern for all new routes.

Never use durations under 200ms for custom animations.

## Haptics
```dart
OutAboutHaptics.onActivitySave()      // medium impact — saving an activity
OutAboutHaptics.onConditionToggle()   // light impact — toggling a condition
OutAboutHaptics.onConditionMatch()    // vibrate — weather condition matched
```

## Screen Template (mandatory)
Every OutAbout screen follows this exact scaffold:

```dart
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      // content
    );
  }
}
```

For screens needing local state (PageController, TextEditingController, etc.):
```dart
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    return Scaffold(backgroundColor: colors.background, ...);
  }
}
```

## State Management — Hand-written Riverpod (no code-gen)
OutAbout uses Riverpod WITHOUT riverpod_annotation or riverpod_generator.
Do not add @riverpod annotations. Write providers manually.

```dart
// Async data (Supabase fetch)
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('activities').select().order('created_at');
  return data.map(Activity.fromJson).toList();
});

// Mutable state with notifier
final myNotifierProvider =
    StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier(ref.watch(supabaseClientProvider));
});

class MyNotifier extends StateNotifier<MyState> {
  MyNotifier(this._client) : super(const MyState());
  final SupabaseClient _client;
  // methods
}

// Simple state
final counterProvider = StateProvider<int>((ref) => 0);
```

Naming conventions:
- Async data: `activitiesProvider`, `remindersProvider`
- Notifiers: `activityNotifierProvider`, `reminderNotifierProvider`
- Simple state: `selectedTabProvider`, `isLoadingProvider`

## Navigation
All routes defined as constants. Never hardcode route strings in widgets.

```dart
// lib/core/router.dart — route constants
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home       = '/home';
  // add new routes here
}
```

All transitions: FadeTransition + Curves.easeOutCubic + standardDuration.
Replicate the existing pageBuilder pattern for every new route.

Auth redirect logic: onboarding_complete (SharedPreferences) AND live
Supabase session must both be true to reach /home.

## Onboarding Flow (6 pages)
PageView controlled by `onboardingStepProvider` in `onboarding_provider.dart`.

| Step | Page | File |
|---|---|---|
| 0 | Value proposition | pages/value_proposition_page.dart |
| 1 | Location permission | pages/location_permission_page.dart |
| 2 | Notification permission | pages/notification_permission_page.dart |
| 3 | Booking integrations | pages/booking_integrations_page.dart |
| 4 | Auth (sign in/up) | pages/auth_page.dart |
| 5 | First activity setup | pages/first_activity_page.dart |

Progress tracked by `ProgressDots` widget in `widgets/progress_dots.dart`.
Navigation: `ref.read(onboardingStepProvider.notifier).next()` or `.goTo(index)`.

## File & Folder Structure

```
lib/
  main.dart
  core/
    theme.dart                    # WeatherTheme, WeatherThemeColors,
                                  # OutAboutColors, OutAboutTypography,
                                  # OutAboutSpacing, OutAboutRadius,
                                  # OutAboutShadows, OutAboutAnimations,
                                  # OutAboutHaptics, outAboutTheme()
    weather_theme_provider.dart   # sharedPreferencesProvider,
                                  # userThemeOverrideProvider,
                                  # weatherThemeProvider,
                                  # themeDataProvider,
                                  # weatherThemeColorsProvider
    router.dart                   # routerProvider, AppRoutes
    providers.dart                # supabaseClientProvider,
                                  # packageInfoProvider
  data/
    models/                       # Dart model classes
    repositories/                 # Supabase repository classes
  features/
    onboarding/
      onboarding_screen.dart
      onboarding_provider.dart
      pages/
        value_proposition_page.dart
        location_permission_page.dart
        notification_permission_page.dart
        booking_integrations_page.dart
        auth_page.dart
        first_activity_page.dart
      widgets/
        progress_dots.dart
    home/
      home_screen.dart
    [future features]/
  widgets/                        # Shared widgets used across features
```

## Key Dependencies
Do not add alternatives without explicit approval:

```yaml
# Core
flutter_riverpod: ^2.6.1     # state management (NO code-gen)
go_router: ^14.8.1           # navigation
supabase_flutter: ^2.12.0    # backend
flutter_dotenv: ^5.2.1       # env vars — ALWAYS use, never hardcode keys
shared_preferences: ^2.3.4   # onboarding flag + theme override persistence

# Location & permissions
geolocator: ^13.0.2
geocoding: ^3.0.0
permission_handler: ^11.4.0

# UI
flutter_animate: ^4.5.2      # declarative animations
shimmer: ^3.0.0              # loading skeletons
cupertino_icons: ^1.0.8

# Info
package_info_plus: ^8.3.0

# Dev
flutter_lints: ^6.0.0
mocktail: ^1.0.4
```

HTTP package for Tomorrow.io API calls not yet added — use `http` when needed.
JSON serialization done manually — no json_serializable yet.

## Condition Colors (weather-independent, semantic)
These are fixed regardless of theme — used for weather condition icons:

```dart
OutAboutColors.sunny   // #FFB800 — sun icon tint
OutAboutColors.cloudy  // #8FA3B1 — cloud icon tint
OutAboutColors.rainy   // #4A9EFF — rain icon tint
OutAboutColors.windy   // #6EC6CA — wind icon tint
OutAboutColors.cold    // #90CAF9 — cold/snow icon tint
OutAboutColors.hot     // #FF7043 — heat icon tint
```

Semantic status colors (also fixed):
```dart
OutAboutColors.success     // #34C759
OutAboutColors.warning     // #FF9500
OutAboutColors.errorColor  // #FF3B30
```

## Security — Non-Negotiable
- NEVER hardcode Supabase URL or anon key in source code.
- ALWAYS use flutter_dotenv: `dotenv.env['SUPABASE_URL']!`
- The .env file is in assets — never commit it with real values.
- Supabase anon key was previously exposed in main.dart — that key has
  been rotated. Do not repeat this mistake.

## Animations — flutter_animate (Use This, Not Raw Controllers)

OutAbout has `flutter_animate: ^4.5.2` in dependencies. Always use it for
entrance animations and transitions instead of raw `AnimationController`.
Never write a manual `AnimationController` + `Tween` + `AnimatedBuilder`
chain when `flutter_animate` can do it in one line.

```dart
import 'package:flutter_animate/flutter_animate.dart';

// Fade in on mount — most common entrance
Text('Welcome to OutAbout', style: OutAboutTypography.displayLarge(colors))
  .animate()
  .fadeIn(duration: OutAboutAnimations.standardDuration)

// Fade + slide up — for cards and list items
ActivityCard(activity: activity)
  .animate()
  .fadeIn(duration: 400.ms)
  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic)

// Staggered list — apply delay per index
ListView.builder(
  itemBuilder: (context, index) {
    return ActivityCard(activity: activities[index])
      .animate()
      .fadeIn(
        delay: Duration(milliseconds: index * 60),
        duration: OutAboutAnimations.standardDuration,
      )
      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  },
)

// Scale in — for FABs, badges, condition-match indicators
ConditionMatchBadge()
  .animate()
  .scale(
    begin: const Offset(0.8, 0.8),
    end: const Offset(1.0, 1.0),
    duration: OutAboutAnimations.standardDuration,
    curve: Curves.easeOutBack,
  )

// Shimmer pulse — for loading indicators (prefer shimmer package for skeletons,
// flutter_animate for subtle pulse on existing widgets)
WeatherIcon()
  .animate(onPlay: (c) => c.repeat(reverse: true))
  .shimmer(duration: 1200.ms, color: colors.primary.withOpacity(0.3))
```

Rules for flutter_animate:
- Use `.animate()` chains for all entrance animations on new screens/widgets
- Always anchor duration to `OutAboutAnimations.standardDuration` or multiples
- Stagger list items with `delay: Duration(milliseconds: index * 60)`
- Never exceed 600ms for any single animation
- Theme transitions (500ms) are handled by `AnimatedTheme` — do not animate

## Anti-Patterns — Never Do These
1. **Never use static OutAboutColors in widget files** — always `colors.X`
2. **Never call OutAboutTypography without colors arg** — always pass `colors`
3. **Never hardcode spacing values** — always OutAboutSpacing
4. **Never hardcode radius values** — always OutAboutRadius
5. **Never hardcode Supabase keys** — always dotenv
6. **Never call Supabase from a widget** — always via repository → provider
7. **Never hardcode route strings** — always AppRoutes.X
8. **Never use Navigator.push for main navigation** — always context.go()
9. **Never use @riverpod annotation** — hand-written providers only
10. **Never unconstrained height in Column children** — Expanded or Flexible
11. **Never add animations faster than 200ms** for custom interactions
12. **Never use a different HTTP client** for Tomorrow.io — use `http` package
13. **Never introduce ThemeExtension** — existing token system is intentional
14. **Never write raw AnimationController** — use flutter_animate instead

## Accessibility — Minimum Requirements
OutAbout's five weather palettes have very different contrast characteristics.
When building new components, verify contrast is sufficient across all themes.

WCAG 2.1 minimums:
- Normal text (under 18pt): 4.5:1 contrast ratio minimum
- Large text (18pt+ or 14pt bold): 3:1 contrast ratio minimum
- Interactive elements: 3:1 against adjacent colors

High-risk combinations to verify manually:
- Sunny theme: `colors.textSecondary` (#6B5B3E) on `colors.background` (#FFF8EE)
- Snowy theme: `colors.primary` (#90CAF9) on `colors.background` (#F7F9FC)
- Any theme: disabled/muted text on card backgrounds

Accessibility in code:
```dart
// Always add semantics to icon-only interactive elements
IconButton(
  icon: const Icon(Icons.add),
  onPressed: () {},
  tooltip: 'Add activity',   // generates Semantics label automatically
)

// Explicit semantics for custom interactive widgets
Semantics(
  label: 'Activity: ${activity.name}, conditions ${isMatch ? 'met' : 'not met'}',
  button: true,
  child: GestureDetector(onTap: onTap, child: ActivityCard(...)),
)

// Minimum tap target: 48x48dp
SizedBox(
  width: 48,
  height: 48,
  child: Center(child: Icon(Icons.close, size: 20)),
)
```

## analysis_options.yaml — Verify This File Exists at Repo Root
```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    prefer_const_constructors: true
    avoid_unnecessary_containers: true
    sized_box_for_whitespace: true
```
If this file doesn't exist, create it. Run `flutter analyze` to confirm zero
warnings before any commit. Note: existing `main.dart` uses `debugPrint` which
is allowed — `avoid_print` only flags bare `print()` calls.

## Pre-Flight Checklist (before every commit)
- [ ] `flutter analyze` — zero warnings
- [ ] `flutter test` — all pass
- [ ] No hardcoded colors, no static OutAboutColors in widgets
- [ ] All typography calls pass `colors` argument
- [ ] No hardcoded spacing or radius values
- [ ] No hardcoded route strings
- [ ] New Supabase operations through repository classes
- [ ] Env vars via dotenv, not hardcoded
- [ ] New routes added to AppRoutes and routerProvider
- [ ] Animation durations use OutAboutAnimations constants
- [ ] flutter_animate used for entrances — no raw AnimationController
- [ ] No ThemeExtension introduced
- [ ] Interactive elements have tooltip or Semantics label
- [ ] Tap targets ≥ 48x48dp on all tappable widgets
- [ ] analysis_options.yaml exists at repo root

## MCP Servers (connect for maximum agent capability)
- **Dart & Flutter MCP** — `dart mcp-server` — widget tree, runtime errors,
  hot reload, pub.dev search
- **Supabase MCP** — direct schema inspection and query execution
- **GitHub MCP** — branch/PR workflow

When Dart & Flutter MCP is connected:
1. Check `get_runtime_errors` after every UI change
2. Inspect widget tree before marking any task complete
3. Hot reload between iterations
