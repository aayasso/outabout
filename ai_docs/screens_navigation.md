# OutAbout — Screens & Navigation Map
# ai_docs/screens_navigation.md
# Living document. Update when screens or routes change.
# Last updated: 2026-05-03

## Route Constants

All route paths defined in `lib/core/router.dart` as `AppRoutes` constants.
Never hardcode a route string in a widget.

```dart
abstract class AppRoutes {
  static const String onboarding  = '/onboarding';
  static const String home        = '/home';
  static const String activities  = '/activities';
  static const String settings    = '/settings';
  static const String addActivity = '/activity/add';
  static const String activity    = '/activity/:id';
}
```

---

## Auth Redirect Logic

Dual-condition gate in `routerProvider`:
- `onboarding_complete` (SharedPreferences bool) = true
- `supabase.auth.currentUser != null` (live session)

Both must be true to reach `/home`.

```
App launch → /onboarding (initialLocation)
  redirect:
    complete=true  + session=true  + on /onboarding → /home
    complete=true  + session=false                  → reset flag → /onboarding
    complete=false + not on /onboarding             → /onboarding
    else → stay (null = no redirect)
```

All transitions: `FadeTransition` + `Curves.easeOutCubic` + `standardDuration` (300ms).
Copy this `pageBuilder` pattern for every new route:

```dart
GoRoute(
  path: AppRoutes.myScreen,
  pageBuilder: (context, state) => CustomTransitionPage(
    child: const MyScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
    transitionDuration: OutAboutAnimations.standardDuration,
  ),
),
```

---

## Screen Inventory

### OnboardingScreen `/onboarding`
**File:** `lib/features/onboarding/onboarding_screen.dart`
**Type:** ConsumerStatefulWidget
**State:** `onboardingStepProvider` (int, 0-5)
**Providers:** `weatherThemeColorsProvider`, `onboardingStepProvider`
**Layout:** ProgressDots at top + PageView body
**Navigation:** → `/home` (after step 5 completes auth)
**Notes:**
- PageController synced to provider via `ref.listen`
- `BouncingScrollPhysics` on PageView
- 6 pages rendered as children — see Onboarding Pages below

### HomeScreen `/home` (shell)
**File:** `lib/features/home/home_screen.dart`
**Type:** ConsumerStatefulWidget
**Providers:** `weatherThemeColorsProvider`, `selectedTabProvider`
**Layout:** Scaffold with 3-tab bottom `NavigationBar` + indexed body
**State:** Manages the active tab index and preserves tab state
**Notes:**
- Uses `StatefulShellRoute` (go_router) for bottom nav tab persistence
- Tab body switches between `TodayTab`, `ActivitiesTab`, `SettingsTab`
- Bottom nav colors from theme: `colors.surface` background,
  `colors.primary` selected, `colors.textSecondary` unselected

---

## Bottom Navigation (3 tabs)

| Index | Label | Icon | Widget | Purpose |
|---|---|---|---|---|
| 0 | Today | `Icons.wb_sunny_outlined` | `TodayTab` | Current weather + condition-matched activities |
| 1 | Activities | `Icons.directions_run_outlined` | `ActivitiesTab` | Full wishlist with condition profiles |
| 2 | Settings | `Icons.settings_outlined` | `SettingsTab` | Profile, location, notifications, theme override, sign out |

Colors from theme:
```dart
NavigationBarThemeData(
  backgroundColor: colors.surface,
  indicatorColor: colors.primary.withOpacity(0.15),
  labelTextStyle: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return OutAboutTypography.labelSmall(colors).copyWith(color: colors.primary);
    }
    return OutAboutTypography.labelSmall(colors);
  }),
)
```

---

## Tab Screens

### TodayTab (Tab 0 — default landing)
**File:** `lib/features/home/tabs/today_tab.dart`
**Type:** ConsumerWidget
**Purpose:** Current weather conditions + activities whose condition profiles
match the current weather. This is the main value screen — "what can I do
right now?"
**Planned content:**
- Weather summary card (current temp, condition, location)
- List of activities with matching conditions highlighted
- Empty state when no activities match or no activities exist

### ActivitiesTab (Tab 1)
**File:** `lib/features/home/tabs/activities_tab.dart`
**Type:** ConsumerWidget
**Purpose:** Full activity wishlist with condition profile summaries.
Browse, add, edit, archive activities.
**Planned content:**
- Scrollable list of all non-archived activities
- Each card shows activity name + condition profile summary
- FAB or header action to add new activity
- Swipe or long-press to archive
- Empty state for new users (encourage adding first activity)

### SettingsTab (Tab 2)
**File:** `lib/features/home/tabs/settings_tab.dart`
**Type:** ConsumerWidget
**Purpose:** Profile, location, notifications, theme override, sign out.
**Planned content:**
- Profile section (display name, avatar)
- Location management
- Notification preferences
- Theme override (adaptive / manual selection)
- Temperature unit toggle (F / C)
- Sign out
- App version

---

## Onboarding Pages (6 steps)

All pages in `lib/features/onboarding/pages/`.
Each page receives `onNext: VoidCallback` (except FirstActivityPage).

| Step | Widget | File | Purpose |
|---|---|---|---|
| 0 | `ValuePropositionPage` | value_proposition_page.dart | App value prop, hero CTA |
| 1 | `LocationPermissionPage` | location_permission_page.dart | Request location access |
| 2 | `NotificationPermissionPage` | notification_permission_page.dart | Request push notifications |
| 3 | `BookingIntegrationsPage` | booking_integrations_page.dart | Connect calendars/bookings |
| 4 | `AuthPage` | auth_page.dart | Sign up / sign in |
| 5 | `FirstActivityPage` | first_activity_page.dart | Set up first activity (no onNext) |

**ProgressDots widget:** `lib/features/onboarding/widgets/progress_dots.dart`
Receives `currentPage` (int). Shows 6 dots, active dot uses `colors.primary`.

**Page navigation pattern:**
```dart
// From any page — advance to next step
onNext: () => ref.read(onboardingStepProvider.notifier).next(),

// From OnboardingScreen PageView onPageChanged
onPageChanged: (index) {
  ref.read(onboardingStepProvider.notifier).goTo(index);
},
```

---

## Built Screens (push routes)

### AddActivityScreen `/activity/add`
**File:** `lib/features/add_activity/add_activity_screen.dart`
**Type:** ConsumerStatefulWidget
**Purpose:** Create new activity with weather condition profile.
**Providers:** `weatherThemeColorsProvider`, `activityRepositoryProvider`,
`behavioralEventServiceProvider`, `activitiesProvider` (invalidate on save)
**Layout:** AppBar with close button + scrollable form body
**Sub-widgets:** `_ActivityNameField`, `_NotesField`, `_ConditionSection`,
`_TemperatureSection`, `_PrecipitationSection`, `_WindSection`, `_UvSection`,
`_SaveButton`
**Navigation:** `context.pop()` on save success

## Planned Screens (not yet built)

Add to AppRoutes and routerProvider when building each one.

| Screen | Route | Purpose |
|---|---|---|
| ActivityDetailScreen | `/activity/:id` | View/edit activity + condition profile |

---

## go_router Config Skeleton

The router uses `StatefulShellRoute` for bottom-nav tab persistence.
Each tab branch maintains its own navigation stack.

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    redirect: (context, state) {
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      final hasSession = supabase.auth.currentUser != null;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (onboardingComplete && !hasSession) {
        prefs.setBool('onboarding_complete', false);
        if (!isOnboarding) return AppRoutes.onboarding;
        return null;
      }
      if (onboardingComplete && hasSession && isOnboarding) return AppRoutes.home;
      if (!onboardingComplete && !isOnboarding) return AppRoutes.onboarding;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: _fadeTransition(const OnboardingScreen()),
      ),
      // Bottom nav shell — preserves tab state across navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              pageBuilder: _fadeTransition(const TodayTab()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.activities,
              pageBuilder: _fadeTransition(const ActivitiesTab()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: _fadeTransition(const SettingsTab()),
            ),
          ]),
        ],
      ),
      // Push routes (overlay on top of any tab)
      GoRoute(
        path: AppRoutes.addActivity,
        pageBuilder: _fadeTransition(const AddActivityScreen()),
      ),
      GoRoute(
        path: AppRoutes.activity,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _fadeTransitionPage(ActivityDetailScreen(activityId: id));
        },
      ),
    ],
  );
});
```
