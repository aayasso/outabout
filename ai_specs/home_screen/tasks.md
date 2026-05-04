# Tasks — Home Screen
# Created: 2026-05-03
# Requires: design.md approved

## Task 1 — Pre-build cleanup
Visible when done: `lib/models/activity.dart` updated to match live schema,
`locationServiceProvider` confirmed accessible, `flutter analyze` passes
with clean baseline.

Files:
- `lib/models/activity.dart` (update)
- `lib/services/location_service.dart` (verify exists)

Subtasks:
- [ ] Update `lib/models/activity.dart`:
      - Remove legacy `category` (text) field
      - Add `categoryIds` (`List<String>`) mapped to `category_ids` (uuid[])
      - Add missing fields: `notes`, `url`, `location`, `isArchived`,
        `updatedAt`, `geographicContext`
      - Add nested `ConditionProfile? conditionProfile` parsed from
        joined query (`condition_profiles(*)`)
      - Update `fromJson` / `toJson` with snake_case keys
- [ ] Confirm `locationServiceProvider` exists at
      `lib/services/location_service.dart` and is importable from
      the `feature/home-screen` branch. If missing, copy from
      onboarding worktree.
- [ ] Run `flutter analyze` — must pass before Task 2

---

## Task 2 — Data models
Visible when done: Models importable, `flutter analyze` passes.
No UI change — these are pure Dart classes.

Files:
- `lib/data/models/condition_profile.dart` (new)
- `lib/data/models/weather_data.dart` (new)
- `lib/data/models/profile.dart` (new)
- `lib/data/models/user_location.dart` (new)
- `lib/data/models/condition_match.dart` (new)

Subtasks:
- [ ] Create `ConditionProfile` model matching `condition_profiles` table:
      `id`, `activityId`, `tempEnabled`, `tempMin`, `tempMax`,
      `precipEnabled`, `precipLevel`, `windEnabled`, `windMax`,
      `uvEnabled`, `uvMin`, `uvMax`, `createdAt`, `updatedAt`.
      Include `fromJson` / `toJson` with snake_case keys.
- [ ] Create `WeatherData` model for Tomorrow.io response:
      `weatherCode`, `temperature` (Celsius from API), `windSpeed`,
      `humidity`, `precipitationIntensity`, `uvIndex`.
      `fromJson` parses from `response['data']['values']`.
- [ ] Create `Profile` model matching `profiles` table:
      `id`, `displayName`, `avatarUrl`, `isPremium`, `temperatureUnit`,
      `createdAt`, `updatedAt`. Include `fromJson` / `toJson`.
- [ ] Create `UserLocation` model matching `user_locations` table:
      `id`, `userId`, `city`, `latitude`, `longitude`, `updatedAt`.
      Include `fromJson` / `toJson`.
- [ ] Create `ConditionMatch` — simple class:
      `final Activity activity; final bool isMatch;`
      No JSON serialization needed (derived in-memory only).
- [ ] Run `flutter analyze` — must pass before Task 3

---

## Task 3 — Repositories
Visible when done: Repository classes importable, `flutter analyze` passes.
No UI change — pure Dart with Supabase/HTTP calls.

Files:
- `lib/data/repositories/activity_repository.dart` (new)
- `lib/data/repositories/weather_repository.dart` (new)

Subtasks:
- [ ] Create `ActivityRepository` with methods:
      - `fetchForUser(String userId)` — select `*, condition_profiles(*)`
        where `user_id` = userId AND `is_archived` = false,
        ordered by `created_at` descending
      - `insert(Activity activity)` — insert + select with join, return single
      - `archive(String activityId)` — update `is_archived` = true
- [ ] Create `WeatherRepository` with:
      - Constructor takes `String apiKey`
      - `fetchCurrent(double lat, double lng)` — GET Tomorrow.io realtime
        endpoint, parse response into `WeatherData`
      - `WeatherFetchException` class (statusCode + body)
- [ ] Add `import 'package:http/http.dart' as http;` in weather_repository
- [ ] Run `flutter analyze` — must pass before Task 4

---

## Task 4 — Providers
Visible when done: All providers importable, `flutter analyze` passes.
No UI change — wiring layer between repositories and future UI.

Files:
- `lib/features/home/home_providers.dart` (new)

Subtasks:
- [ ] Create `activityRepositoryProvider` — `Provider<ActivityRepository>`
      reads `supabaseClientProvider`
- [ ] Create `weatherRepositoryProvider` — `Provider<WeatherRepository>`
      reads `dotenv.env['TOMORROW_API_KEY']!`
- [ ] Create `userLocationProvider` — `FutureProvider<UserLocation?>`
      Query `user_locations` table for current user.
      Fallback: device GPS via geolocator + geocoding.
      Return null if no permission and no saved location.
- [ ] Create `weatherDataProvider` — `FutureProvider<WeatherData>`
      Depends on `userLocationProvider`. Calls `WeatherRepository.fetchCurrent`.
      Side-effect: calls `weatherThemeProvider.notifier.setThemeFromConditions`
      and `setThemeFromTimeOfDay` on success.
- [ ] Create `activitiesProvider` — `FutureProvider<List<Activity>>`
      Calls `ActivityRepository.fetchForUser(userId)`. Returns `[]` if no user.
- [ ] Create `conditionMatchProvider` — `Provider<AsyncValue<List<ConditionMatch>>>`
      Combines `activitiesProvider` + `weatherDataProvider`.
      Implements `_evaluateMatch` logic from design.md.
      Weather error → all activities as `isMatch: false` (no crash).
- [ ] Create `profileProvider` — `FutureProvider<Profile?>`
      Fetches from `profiles` table for current user.
- [ ] All providers hand-written — no @riverpod annotations
- [ ] Run `flutter analyze` — must pass before Task 5

---

## Task 5 — HomeScreen shell with bottom navigation
Visible when done: App launches to HomeScreen with 3-tab bottom nav.
Each tab shows a colored placeholder with the tab name.
Theme-adaptive colors on nav bar. Tapping tabs switches content.

Files:
- `lib/core/router.dart` (update existing)
- `lib/features/home/home_screen.dart` (new)
- `lib/features/home/tabs/today_tab.dart` (new — placeholder)
- `lib/features/home/tabs/activities_tab.dart` (new — placeholder)
- `lib/features/home/tabs/settings_tab.dart` (new — placeholder)
- `lib/main.dart` (update to use router)

Subtasks:
- [ ] Update existing `lib/core/router.dart`:
      - Add new route constants to `AppRoutes`:
        `activities`, `settings`, `addActivity`, `activity`
      - Add `StatefulShellRoute.indexedStack` for 3-tab bottom nav
        with branches for TodayTab, ActivitiesTab, SettingsTab
      - Preserve existing onboarding route and auth redirect logic
      - All transitions: FadeTransition + Curves.easeOutCubic + standardDuration
- [ ] Create `HomeScreen` — ConsumerStatefulWidget:
      - Receives `StatefulNavigationShell navigationShell`
      - Scaffold with `backgroundColor: colors.background`
      - `NavigationBar` with 3 destinations:
        Today (`Icons.wb_sunny_outlined`),
        Activities (`Icons.directions_run_outlined`),
        Settings (`Icons.settings_outlined`)
      - Nav bar colors: `colors.surface` bg, `colors.primary` selected,
        `colors.textSecondary` unselected
      - Body: `navigationShell` (go_router manages tab content)
- [ ] Create placeholder `TodayTab` — ConsumerWidget:
      Scaffold bg `colors.background`, centered Text "Today" using
      `OutAboutTypography.headingLarge(colors)`
- [ ] Create placeholder `ActivitiesTab` — same pattern, text "Activities"
- [ ] Create placeholder `SettingsTab` — same pattern, text "Settings"
- [ ] Update `lib/main.dart`:
      - Replace DesignSystemPreview with `MaterialApp.router`
      - Use `routerConfig: ref.watch(routerProvider)`
      - Keep existing dotenv + Supabase init
- [ ] Verify tab switching works, theme colors apply to nav bar
- [ ] Run `flutter analyze` — must pass before Task 6

---

## Task 6 — TodayTab UI
Visible when done: TodayTab shows weather summary card at top,
activity cards below with green match indicator for matching conditions,
shimmer loading state, error state with retry, empty state with CTA.

Files:
- `lib/features/home/tabs/today_tab.dart` (replace placeholder)

Subtasks:
- [ ] Implement `TodayTab` as ConsumerWidget watching:
      `weatherThemeColorsProvider`, `weatherThemeProvider`,
      `weatherDataProvider`, `activitiesProvider`,
      `conditionMatchProvider`, `userLocationProvider`
- [ ] Build `_WeatherSummaryCard` — current temp, condition icon
      (tinted with `OutAboutColors` semantic colors), location name.
      Card uses `colors.cardBackground`, `OutAboutRadius.cards`,
      shadow selected by theme brightness.
- [ ] Build `_MatchedActivityCard` — activity card with green
      `OutAboutColors.success` indicator when `isMatch: true`
- [ ] Build `_ActivityCard` — neutral state card (no match indicator)
- [ ] Render matched activities first, then unmatched
- [ ] Build `_TodayEmptyState` — "Add your first outdoor activity" +
      CTA button navigating to `AppRoutes.addActivity`
- [ ] Build `_TodayShimmer` — weather card skeleton (1 rect) +
      3 activity card skeletons using `Shimmer.fromColors`
- [ ] Build `_WeatherErrorBanner` — inline banner when weather fetch fails,
      "Couldn't load weather. Pull to refresh."
- [ ] Build `_LocationPermissionBanner` — inline banner when location denied
- [ ] Wire `ref.listen` on `conditionMatchProvider` to fire
      `OutAboutHaptics.onConditionMatch()` once per session when first
      match detected
- [ ] Pull-to-refresh via `RefreshIndicator` that invalidates
      `weatherDataProvider` and `activitiesProvider`
- [ ] Entrance animations with `flutter_animate`:
      `.fadeIn()` + `.slideY()` on cards, staggered with 60ms delay per index
- [ ] All colors from `colors.X` — zero hardcoded values
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`, radius from `OutAboutRadius`
- [ ] Run `flutter analyze` — must pass before Task 7

---

## Task 7 — ActivitiesTab UI
Visible when done: ActivitiesTab shows scrollable list of all non-archived
activities with condition profile summary chips on each card.
Empty state for new users. FAB to add new activity.

Files:
- `lib/features/home/tabs/activities_tab.dart` (replace placeholder)

Subtasks:
- [ ] Implement `ActivitiesTab` as ConsumerWidget watching:
      `weatherThemeColorsProvider`, `weatherThemeProvider`,
      `activitiesProvider`
- [ ] Build `_ActivityListCard` — activity name + condition profile
      summary as chips (e.g. "60-80F", "No rain", "Wind < 15mph").
      Card uses `colors.cardBackground`, `OutAboutRadius.cards`,
      shadow by brightness.
- [ ] Tapping card navigates to `AppRoutes.activity` with activity id
- [ ] FAB to navigate to `AppRoutes.addActivity` —
      `colors.primary` background, scale-in entrance animation
- [ ] Build `_ActivitiesEmptyState` — "Your wishlist is empty" + CTA
- [ ] Build `_ActivitiesShimmer` — 4 activity card skeletons
- [ ] Handle error state with retry (`ref.invalidate(activitiesProvider)`)
- [ ] Entrance animations: staggered fadeIn + slideY on list items
- [ ] Swipe-to-archive with `Dismissible`:
      calls `activityRepositoryProvider` archive method,
      fires `OutAboutHaptics.onActivitySave()`
- [ ] All colors, typography, spacing, radius from design tokens
- [ ] Run `flutter analyze` — must pass before Task 8

---

## Task 8 — SettingsTab UI
Visible when done: SettingsTab shows profile section, location,
theme override selector (adaptive + 5 manual), temperature unit toggle,
sign out button with confirmation, app version at bottom.

Files:
- `lib/features/home/tabs/settings_tab.dart` (replace placeholder)

Subtasks:
- [ ] Implement `SettingsTab` as ConsumerWidget watching:
      `weatherThemeColorsProvider`, `weatherThemeProvider`,
      `userThemeOverrideProvider`, `profileProvider`,
      `userLocationProvider`, `packageInfoProvider`
- [ ] Build `_SettingsSection` — grouped section with header text
      using `OutAboutTypography.labelMedium(colors)`
- [ ] Build `_SettingsRow` — label + trailing widget (toggle, chevron, value)
      Min height 48dp for tap targets
- [ ] Profile section: display name, avatar placeholder
- [ ] Location section: shows current city from `userLocationProvider`
- [ ] Build `_ThemeOverrideSelector`:
      - "Adaptive" option (null override — follows weather)
      - 5 manual options (sunny, overcast, rainy, snowy, night)
      - Selecting calls `ref.read(userThemeOverrideProvider.notifier).setOverride()`
      - Fires `OutAboutHaptics.onConditionToggle()` on selection
- [ ] Temperature unit toggle (F/C):
      Reads from `profileProvider`, updates via Supabase profiles table.
      Fires `OutAboutHaptics.onConditionToggle()`.
- [ ] Build `_SignOutButton` — destructive style, shows confirmation dialog
      before calling `supabaseClientProvider.auth.signOut()`.
      On success: reset `onboarding_complete` SharedPreferences flag,
      router redirect handles navigation to `/onboarding`.
- [ ] App version at bottom from `packageInfoProvider`
- [ ] All colors, typography, spacing, radius from design tokens
- [ ] Run `flutter analyze` — must pass before Task 9

---

## Task 9 — Integration, polish, and tests
Visible when done: Full home screen feature working end-to-end.
All tests pass. Ready for PR review.

Files:
- All files from Tasks 1-8 (review pass)
- `test/` (new test files)

Subtasks:
- [ ] Integration review: navigate through all 3 tabs, verify
      state preservation when switching tabs
- [ ] Verify weather theme updates automatically on TodayTab load
      (weatherDataProvider side-effect)
- [ ] Verify theme override in Settings overrides weather-based theme
- [ ] Verify pull-to-refresh on TodayTab invalidates weather + activities
- [ ] Verify empty states render correctly (no activities)
- [ ] Verify error states render correctly (mock network failure)
- [ ] Write unit tests:
      - `Activity.fromJson` / `toJson` round-trip
      - `ConditionProfile.fromJson` / `toJson` round-trip
      - `WeatherData.fromJson` parsing from Tomorrow.io response shape
      - `Profile.fromJson` / `toJson` round-trip
      - `_evaluateMatch` logic — all condition combinations
- [ ] Write widget tests:
      - `HomeScreen` renders 3 nav bar destinations
      - `TodayTab` shows shimmer in loading state
      - `TodayTab` shows empty state when activities list is empty
      - `ActivitiesTab` shows empty state when no activities
      - `SettingsTab` renders all sections
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Full pre-flight checklist from CLAUDE.md:
      - [ ] No hardcoded colors or static OutAboutColors in widgets
      - [ ] All typography calls pass `colors` argument
      - [ ] No hardcoded spacing or radius values
      - [ ] No hardcoded route strings
      - [ ] Supabase operations through repository classes
      - [ ] Env vars via dotenv
      - [ ] Routes in AppRoutes + routerProvider
      - [ ] Animation durations use OutAboutAnimations constants
      - [ ] flutter_animate for entrances — no raw AnimationController
      - [ ] Interactive elements have tooltip or Semantics label
      - [ ] Tap targets >= 48x48dp
- [ ] Update `ai_docs/screens_navigation.md` if any routes changed

---

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] Tested on iOS simulator
- [ ] Tested on Android emulator
- [ ] `ai_docs/` updated if schema or architecture changed
