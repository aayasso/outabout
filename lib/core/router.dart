import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity_detail/activity_detail_screen.dart';
import '../features/add_activity/add_activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/tabs/activities_tab.dart';
import '../features/home/tabs/settings_tab.dart';
import '../features/home/tabs/today_tab.dart';
import 'providers.dart';
import 'theme.dart';
import 'weather_theme_provider.dart';

// ---------------------------------------------------------------------------
// Route constants
// ---------------------------------------------------------------------------

abstract class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String activities = '/activities';
  static const String settings = '/settings';
  static const String addActivity = '/activity/add';
  static const String activity = '/activity/:id';
}

// ---------------------------------------------------------------------------
// Fade transition helper
// ---------------------------------------------------------------------------

CustomTransitionPage<void> _fadeTransitionPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
    transitionDuration:
        OutAboutAnimations.standardDuration,
  );
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    redirect: (context, state) {
      final onboardingComplete =
          prefs.getBool('onboarding_complete') ?? false;
      final hasSession =
          supabase.auth.currentUser != null;
      final isOnboarding =
          state.matchedLocation == AppRoutes.onboarding;

      if (onboardingComplete && !hasSession) {
        prefs.setBool('onboarding_complete', false);
        if (!isOnboarding) return AppRoutes.onboarding;
        return null;
      }
      if (onboardingComplete &&
          hasSession &&
          isOnboarding) {
        return AppRoutes.home;
      }
      if (!onboardingComplete && !isOnboarding) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _fadeTransitionPage(
          child: const _OnboardingPlaceholder(),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.activity,
        pageBuilder: (context, state) {
          final activityId =
              state.pathParameters['id']!;
          return _fadeTransitionPage(
            child: ActivityDetailScreen(
              activityId: activityId,
            ),
            state: state,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(
            navigationShell: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    _fadeTransitionPage(
                  child: const TodayTab(),
                  state: state,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activities,
                pageBuilder: (context, state) =>
                    _fadeTransitionPage(
                  child: const ActivitiesTab(),
                  state: state,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                pageBuilder: (context, state) =>
                    _fadeTransitionPage(
                  child: const SettingsTab(),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addActivity,
        pageBuilder: (context, state) =>
            _fadeTransitionPage(
          child: const AddActivityScreen(),
          state: state,
        ),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Temporary placeholder — will be replaced when onboarding feature merges
// ---------------------------------------------------------------------------

class _OnboardingPlaceholder extends ConsumerWidget {
  const _OnboardingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Text(
          'Onboarding',
          style: OutAboutTypography.headingLarge(colors),
        ),
      ),
    );
  }
}
