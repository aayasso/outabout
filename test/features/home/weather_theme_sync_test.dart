import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';

/// Regression tests for the wiring between live conditions and the theme.
///
/// The mapping itself is covered in theme_test; what is asserted here is that
/// the conditions actually reach the notifier. They never did: the
/// application was a side effect inside weatherDataProvider, and nothing in
/// the app watched that provider, so the theme sat on its default forever.
void main() {
  WeatherData conditions(int weatherCode) => WeatherData(
        weatherCode: weatherCode,
        temperature: 18,
        windSpeed: 10,
        humidity: 60,
        precipitationIntensity: 0,
        uvIndex: 3,
      );

  /// Midday, so the night override does not fire. Pinned rather than read from
  /// the wall clock — these assertions used to fail every evening.
  DateTime midday() => DateTime(2026, 4, 14, 12);

  /// Builds a container with [weatherDataProvider] pinned to [weatherCode].
  Future<ProviderContainer> containerFor(
    int weatherCode, {
    WeatherTheme? override,
    DateTime Function()? clock,
  }) async {
    SharedPreferences.setMockInitialValues(
      override == null
          ? {}
          : {'weather_theme_override': override.name},
    );
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nowProvider.overrideWithValue(clock ?? midday),
        weatherDataProvider.overrideWith((ref) async => conditions(weatherCode)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads the theme after the sync provider's deferred application runs.
  Future<WeatherTheme> themeAfterSync(ProviderContainer container) async {
    container.listen(weatherThemeSyncProvider, (_, _) {});
    await container.read(weatherDataProvider.future);
    // The sync defers via microtask so it does not mutate mid-build.
    await Future<void>.delayed(Duration.zero);
    return container.read(weatherThemeProvider);
  }

  group('weatherThemeSyncProvider', () {
    test('clear conditions produce the sunny theme', () async {
      final container = await containerFor(1000);
      expect(await themeAfterSync(container), WeatherTheme.sunny);
    });

    test('cloudy conditions produce the overcast theme', () async {
      // 1001 is the code that rendered as sunny before this wiring existed.
      final container = await containerFor(1001);
      expect(await themeAfterSync(container), WeatherTheme.overcast);
    });

    test('rain produces the rainy theme', () async {
      final container = await containerFor(4001);
      expect(await themeAfterSync(container), WeatherTheme.rainy);
    });

    test('snow produces the snowy theme', () async {
      final container = await containerFor(5001);
      expect(await themeAfterSync(container), WeatherTheme.snowy);
    });

    test('after sunset the night theme wins over live conditions', () async {
      final container = await containerFor(
        1000, // clear sky
        clock: () => DateTime(2026, 4, 14, 21),
      );
      expect(await themeAfterSync(container), WeatherTheme.night);
    });

    test('a manual override wins over live conditions', () async {
      // Rainy override while the sky is clear — the override must hold.
      final container = await containerFor(1000, override: WeatherTheme.rainy);
      expect(await themeAfterSync(container), WeatherTheme.rainy);
    });

    test('does nothing while conditions are unavailable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          weatherDataProvider.overrideWith(
            (ref) async => throw Exception('no location'),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(weatherThemeSyncProvider, (_, _) {});
      await expectLater(
        container.read(weatherDataProvider.future),
        throwsException,
      );
      await Future<void>.delayed(Duration.zero);

      // Falls back to the default rather than throwing.
      expect(container.read(weatherThemeProvider), WeatherTheme.sunny);
    });
  });
}
