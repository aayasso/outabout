import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/activity_detail/activity_detail_screen.dart';
import '../features/add_activity/add_activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/tabs/activities_tab.dart';
import '../features/home/tabs/settings_tab.dart';
import '../features/home/home_providers.dart';
import '../features/home/tabs/schedule_tab.dart';
import '../features/onboarding/onboarding_screen.dart';
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
  // Deliberately NOT '/activity/add': go_router matches top-level routes in
  // declaration order and returns the first hit, so '/activity/add' resolved
  // to '/activity/:id' with id='add' and the add screen was unreachable.
  static const String addActivity = '/add-activity';
  static const String activity = '/activity/:id';
}

// ---------------------------------------------------------------------------
// Safe pop
// ---------------------------------------------------------------------------

extension SafePop on BuildContext {
  /// Pops when there is something to pop, otherwise navigates to [fallback].
  ///
  /// Screens reachable by deep link — or entered with `go()` rather than
  /// `push()` — can be the only page on the stack, where a bare `pop()`
  /// throws `GoError: There is nothing to pop`.
  void popOrGo([String fallback = AppRoutes.home]) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}

// ---------------------------------------------------------------------------
// Auth-driven router refresh
// ---------------------------------------------------------------------------

/// Re-runs the router's [GoRouter.redirect] whenever the auth state changes.
///
/// Without this the redirect only runs on navigation, so a session ending
/// mid-flow — sign-out, or a refresh token rejected because the user was
/// deleted — left the user sitting on a sub-route with a dead session.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(
    Stream<AuthState> stream, {
    void Function(AuthState)? onEvent,
  }) {
    _subscription = stream.listen((state) {
      onEvent?.call(state);
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
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
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
    transitionDuration: OutAboutAnimations.standardDuration,
  );
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final authRefresh = AuthRefreshNotifier(
    supabase.auth.onAuthStateChange,
    onEvent: (authState) {
      // Drop the previous user's cached data the moment the session ends —
      // sign-out, account deletion, or a refresh token rejected because the
      // user no longer exists. Runs before notifyListeners so the redirect
      // sees cleared state.
      switch (authState.event) {
        case AuthChangeEvent.signedOut:
          clearUserScopedState(ref);
        case AuthChangeEvent.signedIn:
          // A new session must not inherit results the providers resolved
          // while signed out — those are cached and would otherwise persist
          // for the whole app run. Preferences are left alone here.
          invalidateUserScopedProviders(ref);
        default:
          break;
      }
    },
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      final hasSession = supabase.auth.currentUser != null;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (onboardingComplete && !hasSession) {
        prefs.setBool('onboarding_complete', false);
        if (!isOnboarding) return AppRoutes.onboarding;
        return null;
      }
      if (onboardingComplete && hasSession && isOnboarding) {
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
        pageBuilder: (context, state) => _fadeTransitionPage(
          child: const OnboardingScreen(),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.activity,
        pageBuilder: (context, state) {
          final activityId = state.pathParameters['id']!;
          return _fadeTransitionPage(
            child: ActivityDetailScreen(activityId: activityId),
            state: state,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) => _fadeTransitionPage(
                  child: const ScheduleTab(),
                  state: state,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activities,
                pageBuilder: (context, state) => _fadeTransitionPage(
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
                pageBuilder: (context, state) => _fadeTransitionPage(
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
            _fadeTransitionPage(child: const AddActivityScreen(), state: state),
      ),
    ],
  );
});
