import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/router.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/outcome_prompt_provider.dart';
import 'package:outabout/features/onboarding/onboarding_provider.dart';

/// Exposes the container's own [Ref], which is what clearUserScopedState
/// takes — a widget's ref is already disposed by the time a sign-out
/// redirect fires.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  _signOutBoundaryTests();

  group('userScopedPrefsKeys', () {
    test('covers per-user state and excludes device preferences', () {
      expect(
        userScopedPrefsKeys,
        containsAll(<String>[
          'onboarding_complete',
          'categories_seeded',
          cachedWeatherDataKey,
          cachedWeatherFetchedAtKey,
          cachedForecastDataKey,
          cachedForecastFetchedAtKey,
        ]),
      );

      // Device-level display preferences must survive a sign-out. These are
      // the real key strings — an earlier draft asserted 'theme_override',
      // which no code writes, so the check passed without proving anything.
      expect(userScopedPrefsKeys, isNot(contains('weather_theme_override')));
      expect(userScopedPrefsKeys, isNot(contains('schedule_layout')));
      // Temperature unit lives server-side on profiles, not in prefs.
      expect(userScopedPrefsKeys, isNot(contains('temperature_unit')));
    });
  });

  group('clearUserScopedState', () {
    test('clears user state and leaves device preferences alone', () async {
      SharedPreferences.setMockInitialValues({
        for (final key in userScopedPrefsKeys) key: 'previous-user',
        'weather_theme_override': 'rainy',
        'schedule_layout': 'activityFirst',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final captured = container.read(_refProvider);

      await clearUserScopedState(captured);

      for (final key in userScopedPrefsKeys) {
        expect(prefs.get(key), isNull, reason: '$key must be cleared');
      }
      expect(prefs.getString('weather_theme_override'), 'rainy');
      expect(prefs.getString('schedule_layout'), 'activityFirst');
    });

    test('resets the onboarding cursor so re-onboarding works', () async {
      // Regression: the step notifier clamps at 5, so a cursor left at the
      // last page made next() a no-op and "Get Started" did nothing after
      // signing out — onboarding became unreachable.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final captured = container.read(_refProvider);

      // Walk to the final onboarding page, as a completed run would.
      captured.read(onboardingStepProvider.notifier).goTo(5);
      expect(captured.read(onboardingStepProvider), 5);

      await clearUserScopedState(captured);

      expect(captured.read(onboardingStepProvider), 0);
      // And the cursor advances again rather than sticking.
      captured.read(onboardingStepProvider.notifier).next();
      expect(captured.read(onboardingStepProvider), 1);
    });

    test(
      'invalidateUserScopedProviders leaves prefs and the cursor alone',
      () async {
        // Runs on sign-IN: a new session must not inherit provider results
        // resolved while signed out, but wiping onboarding_complete or the
        // cursor mid-flow would break the very flow that just signed in.
        SharedPreferences.setMockInitialValues({
          for (final key in userScopedPrefsKeys) key: 'in-flight',
        });
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);
        final ref = container.read(_refProvider);

        ref.read(onboardingStepProvider.notifier).goTo(5);
        invalidateUserScopedProviders(ref);

        for (final key in userScopedPrefsKeys) {
          expect(prefs.get(key), 'in-flight', reason: '$key must survive');
        }
        expect(
          ref.read(onboardingStepProvider),
          5,
          reason: 'the anonymous sign-in happens at step 5',
        );
      },
    );

    test('is safe to call twice', () async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final captured = container.read(_refProvider);

      await clearUserScopedState(captured);
      await clearUserScopedState(captured);

      expect(prefs.get('onboarding_complete'), isNull);
    });
  });

  group('AuthRefreshNotifier', () {
    test('notifies listeners on every auth state change', () async {
      final controller = StreamController<AuthState>();
      final notifier = AuthRefreshNotifier(controller.stream);

      var notifications = 0;
      notifier.addListener(() => notifications++);

      controller.add(AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1, reason: 'sign-out must re-run the redirect');

      controller.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 2);

      await controller.close();
      notifier.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Sign-out ordering and outcome-prompt teardown
// ---------------------------------------------------------------------------

void _signOutBoundaryTests() {
  group('clearUserScopedState completes before it returns', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'categories_seeded': true,
        outcomePromptHandledKey: '["a1|2026-08-23"]',
      });
      prefs = await SharedPreferences.getInstance();
    });

    test('every user-scoped pref is gone once the future resolves', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // The regression: the router called this without awaiting, so it
      // returned at its first `await prefs.remove(...)` and the redirect ran
      // against state that had not been cleared. Awaiting must be enough.
      await clearUserScopedState(container.read(_refProvider));

      for (final key in userScopedPrefsKeys) {
        expect(prefs.get(key), isNull, reason: key);
      }
    });

    test(
      'the handled-prompt set does not survive into the next session',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            nowProvider.overrideWithValue(() => DateTime(2026, 8, 23, 18)),
          ],
        );
        addTearDown(container.dispose);

        // Loaded once, in the notifier's constructor.
        expect(
          container.read(outcomePromptProvider),
          contains('a1|2026-08-23'),
        );

        await clearUserScopedState(container.read(_refProvider));

        // Previously the pref was removed but the notifier was never
        // invalidated, so the previous user's answers stayed in memory — and
        // the next markHandled wrote them straight back into the cleared key.
        expect(container.read(outcomePromptProvider), isEmpty);
      },
    );
  });

  group('AuthRefreshNotifier ordering', () {
    test('onEvent runs to completion before listeners are notified', () async {
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);

      final order = <String>[];
      final notifier = AuthRefreshNotifier(
        controller.stream,
        onEvent: (_) async {
          order.add('onEvent:start');
          // Any await at all was enough to break the old ordering.
          await Future<void>.delayed(Duration.zero);
          order.add('onEvent:end');
        },
      );
      addTearDown(notifier.dispose);
      notifier.addListener(() => order.add('notified'));

      controller.add(AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(order, ['onEvent:start', 'onEvent:end', 'notified']);
    });
  });
}
