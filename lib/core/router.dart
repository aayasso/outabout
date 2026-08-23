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
import '../services/behavioral_event_service.dart';
import '../features/home/tabs/schedule_tab.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'providers.dart';
import 'motion.dart';
import 'theme.dart';
import 'weather_theme_provider.dart';

// ---------------------------------------------------------------------------
// Route constants
// ---------------------------------------------------------------------------

/// A deep link that arrived before the app could show it.
///
/// A notification tap on a cold start runs `redirect` immediately, and an
/// unauthenticated user is sent to onboarding — with the activity id dropped
/// on the floor. `notification_opened` has already been logged by then, so the
/// funnel records an open that produced no screen. Holding the link here lets
/// the redirect replay it once a session exists.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

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
  /// [onEvent] runs to completion *before* listeners are notified.
  ///
  /// It returns a Future and that Future is awaited. Taking a plain `void`
  /// callback here silently accepted an async teardown and dropped it at its
  /// first await, so the redirect ran against state that had not been cleared
  /// yet — the exact ordering the sign-out path depends on.
  AuthRefreshNotifier(
    Stream<AuthState> stream, {
    Future<void> Function(AuthState)? onEvent,
  }) {
    _subscription = stream.listen((state) async {
      await onEvent?.call(state);
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
      // A route change is a layout change, so the destination has to arrive
      // either way. Under Reduce Motion it arrives at once rather than fading.
      if (prefersReducedMotion(context)) return child;
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
    onEvent: (authState) async {
      // Drop the previous user's cached data the moment the session ends —
      // sign-out, account deletion, or a refresh token rejected because the
      // user no longer exists. Runs before notifyListeners so the redirect
      // sees cleared state.
      switch (authState.event) {
        case AuthChangeEvent.signedOut:
          // Awaited: clearUserScopedState's first statement is an await, so
          // calling it bare returned at the first prefs.remove and let
          // notifyListeners fire — and the redirect run — before a single key
          // was gone or a single provider invalidated.
          await clearUserScopedState(ref);
        case AuthChangeEvent.signedIn:
          // A new session must not inherit results the providers resolved
          // while signed out — those are cached and would otherwise persist
          // for the whole app run. Preferences are left alone here.
          invalidateUserScopedProviders(ref);
          // Onboarding logs its funnel events from steps 1-3, before the auth
          // page at step 5. They were buffered rather than dropped; now there
          // is a real user id to attribute them to.
          await ref.read(behavioralEventServiceProvider).flushPending();
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

      // A deep link that could not be shown earlier gets one replay, the
      // moment the user is past onboarding and signed in.
      if (onboardingComplete && hasSession) {
        final pending = ref.read(pendingDeepLinkProvider);
        if (pending != null) {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          if (state.matchedLocation != pending) return pending;
        }
      }

      if (onboardingComplete && !hasSession) {
        // Hold whatever the user was trying to reach, so the tap is not lost.
        if (!isOnboarding && state.matchedLocation != AppRoutes.home) {
          ref.read(pendingDeepLinkProvider.notifier).state =
              state.matchedLocation;
        }
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
        pageBuilder: (context, state) =>
            _fadeTransitionPage(child: const OnboardingScreen(), state: state),
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
