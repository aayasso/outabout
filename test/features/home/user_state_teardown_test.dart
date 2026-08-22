import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/router.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';

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
    testWidgets('clears user state and leaves device preferences alone',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        for (final key in userScopedPrefsKeys) key: 'previous-user',
        'theme_override': 'rainy',
        'schedule_layout': 'activityFirst',
      });
      final prefs = await SharedPreferences.getInstance();

      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await clearUserScopedState(captured);

      for (final key in userScopedPrefsKeys) {
        expect(prefs.get(key), isNull, reason: '$key must be cleared');
      }
      expect(prefs.getString('theme_override'), 'rainy');
      expect(prefs.getString('schedule_layout'), 'activityFirst');
    });

    testWidgets('is safe to call twice', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();

      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

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
