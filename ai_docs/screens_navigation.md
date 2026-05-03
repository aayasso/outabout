# OutAbout — Screens & Navigation Map
# ai_docs/screens_navigation.md
# Living document. Update when screens or routes change.
# Last updated: 2026-04-28

## Route Constants

All route paths defined in `lib/core/router.dart` as `AppRoutes` constants.
Never hardcode a route string in a widget.

```dart
abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home       = '/home';
  // Add new routes here as the app grows
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
**State:** `onboardingStepProvider` (int, 0–5)
**Providers:** `weatherThemeColorsProvider`, `onboardingStepProvider`
**Layout:** ProgressDots at top + PageView body
**Navigation:** → `/home` (after step 5 completes auth)
**Notes:**
- PageController synced to provider via `ref.listen`
- `BouncingScrollPhysics` on PageView
- 6 pages rendered as children — see Onboarding Pages below

### HomeScreen `/home`
**File:** `lib/features/home/home_screen.dart`
**Type:** ConsumerWidget
**Status:** Placeholder — needs full implementation
**Providers:** `weatherThemeColorsProvider`
**Planned content:** Active activities list, current weather display,
  reminder feed, bottom navigation

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

## Planned Screens (not yet built)

Add to AppRoutes and routerProvider when building each one.

| Screen | Route | Purpose |
|---|---|---|
| HomeScreen (full) | `/home` | Activities dashboard, weather, reminders |
| AddActivityScreen | `/activity/add` | Create new activity + conditions |
| ActivityDetailScreen | `/activity/:id` | View/edit activity + conditions |
| SettingsScreen | `/settings` | Profile, notifications, theme override, sign out |
| WeatherDetailScreen | `/weather` | Expanded current conditions |

---

## Bottom Navigation (planned for HomeScreen)

| Index | Label | Icon | Target |
|---|---|---|---|
| 0 | Today | Icons.wb_sunny_outlined | Home/dashboard |
| 1 | Activities | Icons.directions_run_outlined | Activities list |
| 2 | Reminders | Icons.notifications_outlined | Reminder history |
| 3 | Settings | Icons.settings_outlined | Settings |

Colors from theme:
```dart
BottomNavigationBarThemeData(
  backgroundColor: colors.surface,
  selectedItemColor: colors.primary,
  unselectedItemColor: colors.textSecondary,
)
```

---

## go_router Config Skeleton (current)

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
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: _fadeTransition(const HomeScreen()),
      ),
      // Add new routes here
    ],
  );
});
```
