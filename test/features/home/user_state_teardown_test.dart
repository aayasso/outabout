import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/router.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/onboarding/onboarding_provider.dart';

/// Exposes the container's own [Ref], which is what clearUserScopedState
/// takes — a widget's ref is already disposed by the time a sign-out
/// redirect fires.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
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

      // Device-level display preferences must survive a sign-out.
      expect(userScopedPrefsKeys, isNot(contains('theme_override')));
      expect(userScopedPrefsKeys, isNot(contains('schedule_layout')));
      // Temperature unit lives server-side on profiles, not in prefs.
      expect(userScopedPrefsKeys, isNot(contains('temperature_unit')));
    });
  });

  group('clearUserScopedState', () {
    test('clears user state and leaves device preferences alone', () async {
      SharedPreferences.setMockInitialValues({
        for (final key in userScopedPrefsKeys) key: 'previous-user',
        'theme_override': 'rainy',
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
      expect(prefs.getString('theme_override'), 'rainy');
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

    test('invalidateUserScopedProviders leaves prefs and the cursor alone',
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
    });

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
