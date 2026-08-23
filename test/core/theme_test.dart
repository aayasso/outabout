import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';

void main() {
  group('WeatherTheme enum', () {
    test('has exactly 5 values', () {
      expect(WeatherTheme.values.length, 5);
    });

    test('sunny, overcast, snowy are light brightness', () {
      expect(WeatherTheme.sunny.brightness, Brightness.light);
      expect(WeatherTheme.overcast.brightness, Brightness.light);
      expect(WeatherTheme.snowy.brightness, Brightness.light);
    });

    test('rainy, night are dark brightness', () {
      expect(WeatherTheme.rainy.brightness, Brightness.dark);
      expect(WeatherTheme.night.brightness, Brightness.dark);
    });

    test('displayName returns capitalized name', () {
      expect(WeatherTheme.sunny.displayName, 'Sunny');
      expect(WeatherTheme.night.displayName, 'Night');
    });
  });

  group('WeatherThemeColors', () {
    test('sunny colors match CLAUDE.md spec', () {
      const c = WeatherThemeColors.sunny;
      expect(c.background, const Color(0xFFFFF8EE));
      expect(c.primary, const Color(0xFFF5A623));
      expect(c.accent, const Color(0xFFFF6B35));
      expect(c.text, const Color(0xFF1A1A1A));
    });

    test('overcast colors match CLAUDE.md spec', () {
      const c = WeatherThemeColors.overcast;
      expect(c.background, const Color(0xFFF0F2F5));
      expect(c.primary, const Color(0xFF4A9EFF));
      expect(c.accent, const Color(0xFF7B8FA1));
      expect(c.text, const Color(0xFF2C3E50));
    });

    test('rainy colors match CLAUDE.md spec', () {
      const c = WeatherThemeColors.rainy;
      expect(c.background, const Color(0xFF1A2332));
      expect(c.primary, const Color(0xFF4A9EFF));
      expect(c.accent, const Color(0xFF64B5F6));
      expect(c.text, const Color(0xFFE8EDF2));
    });

    test('snowy colors match CLAUDE.md spec', () {
      const c = WeatherThemeColors.snowy;
      expect(c.background, const Color(0xFFF7F9FC));
      expect(c.primary, const Color(0xFF90CAF9));
      expect(c.accent, const Color(0xFF546E7A));
      expect(c.text, const Color(0xFF263238));
    });

    test('night colors match CLAUDE.md spec', () {
      const c = WeatherThemeColors.night;
      expect(c.background, const Color(0xFF0D1117));
      expect(c.primary, const Color(0xFF4A9EFF));
      expect(c.accent, const Color(0xFFF5A623));
      expect(c.text, const Color(0xFFE8EDF2));
    });

    test('forTheme returns the palette that belongs to each theme', () {
      // Every field here is non-nullable, so the old isNotNull assertions
      // could not fail. Map each theme to its own palette instead.
      expect(
        WeatherThemeColors.forTheme(WeatherTheme.sunny).background,
        WeatherThemeColors.sunny.background,
      );
      expect(
        WeatherThemeColors.forTheme(WeatherTheme.overcast).background,
        WeatherThemeColors.overcast.background,
      );
      expect(
        WeatherThemeColors.forTheme(WeatherTheme.rainy).background,
        WeatherThemeColors.rainy.background,
      );
      expect(
        WeatherThemeColors.forTheme(WeatherTheme.snowy).background,
        WeatherThemeColors.snowy.background,
      );
      expect(
        WeatherThemeColors.forTheme(WeatherTheme.night).background,
        WeatherThemeColors.night.background,
      );

      // And no two themes share a background, so the mapping is not a
      // constant function.
      final backgrounds = WeatherTheme.values
          .map((t) => WeatherThemeColors.forTheme(t).background)
          .toSet();
      expect(backgrounds, hasLength(WeatherTheme.values.length));
    });
  });

  group('outAboutTheme()', () {
    test('produces valid ThemeData for every WeatherTheme', () {
      for (final theme in WeatherTheme.values) {
        final themeData = outAboutTheme(theme);
        final colors = WeatherThemeColors.forTheme(theme);
        // `isA<ThemeData>()` on a ThemeData-returning function is a tautology.
        // Assert what the builder is actually responsible for.
        expect(themeData.useMaterial3, true, reason: '$theme');
        expect(themeData.brightness, theme.brightness, reason: '$theme');
        expect(
          themeData.colorScheme.primary,
          colors.primary,
          reason: '$theme',
        );
        expect(
          themeData.colorScheme.onPrimary,
          colors.onPrimary,
          reason: '$theme',
        );
        expect(
          themeData.scaffoldBackgroundColor,
          colors.background,
          reason: '$theme',
        );
      }
    });

    test('default parameter uses sunny', () {
      final themeData = outAboutTheme();
      expect(themeData.scaffoldBackgroundColor, WeatherThemeColors.sunny.background);
    });

    test('dark themes have dark brightness', () {
      final rainy = outAboutTheme(WeatherTheme.rainy);
      final night = outAboutTheme(WeatherTheme.night);
      expect(rainy.brightness, Brightness.dark);
      expect(night.brightness, Brightness.dark);
    });

    test('light themes have light brightness', () {
      final sunny = outAboutTheme(WeatherTheme.sunny);
      final overcast = outAboutTheme(WeatherTheme.overcast);
      final snowy = outAboutTheme(WeatherTheme.snowy);
      expect(sunny.brightness, Brightness.light);
      expect(overcast.brightness, Brightness.light);
      expect(snowy.brightness, Brightness.light);
    });

    test('scaffold background matches theme background', () {
      for (final theme in WeatherTheme.values) {
        final themeData = outAboutTheme(theme);
        final colors = WeatherThemeColors.forTheme(theme);
        expect(themeData.scaffoldBackgroundColor, colors.background);
      }
    });

    test('card border radius is 16px (cards token)', () {
      final themeData = outAboutTheme(WeatherTheme.sunny);
      final cardShape = themeData.cardTheme.shape as RoundedRectangleBorder;
      final radius = (cardShape.borderRadius as BorderRadius).topLeft;
      // The literal, not the token — reading OutAboutRadius.cards on both
      // sides passed for any value the token happened to hold.
      expect(radius.x, 16.0);
      expect(radius.x, OutAboutRadius.cards);
    });

    test('button border radius is 12px (buttons token)', () {
      final themeData = outAboutTheme(WeatherTheme.sunny);
      final buttonStyle = themeData.elevatedButtonTheme.style!;
      final shape = buttonStyle.shape!.resolve({}) as RoundedRectangleBorder;
      final radius = (shape.borderRadius as BorderRadius).topLeft;
      expect(radius.x, 12.0);
      expect(radius.x, OutAboutRadius.buttons);
    });
  });

  group('OutAboutAnimations', () {
    test('standard duration is 300ms', () {
      expect(OutAboutAnimations.standardDuration.inMilliseconds, 300);
    });

    test('theme transition duration is 500ms', () {
      expect(OutAboutAnimations.themeTransitionDuration.inMilliseconds, 500);
    });
  });

  group('OutAboutRadius semantic aliases', () {
    test('cards is 16px', () => expect(OutAboutRadius.cards, 16.0));
    test('bottomSheet is 24px', () => expect(OutAboutRadius.bottomSheet, 24.0));
    test('buttons is 12px', () => expect(OutAboutRadius.buttons, 12.0));
  });

  group('WeatherThemeNotifier', () {
    test('maps clear weather codes to sunny', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(1000); // clear
      expect(notifier.state, WeatherTheme.sunny);
    });

    test('maps cloudy codes to overcast', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(1101); // partly cloudy
      expect(notifier.state, WeatherTheme.overcast);
    });

    test('maps rain codes to rainy', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(4001); // rain
      expect(notifier.state, WeatherTheme.rainy);
    });

    test('maps snow codes to snowy', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(5001); // snow
      expect(notifier.state, WeatherTheme.snowy);
    });

    test('maps thunderstorm codes to rainy', () {
      // 8000 used to fall through to the default and paint the *sunny* theme
      // during a thunderstorm.
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(8000); // thunderstorm
      expect(notifier.state, WeatherTheme.rainy);
    });

    test('maps freezing rain codes to rainy', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(6001); // freezing rain
      expect(notifier.state, WeatherTheme.rainy);
    });

    test('maps ice pellet codes to snowy', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(7101); // heavy ice pellets
      expect(notifier.state, WeatherTheme.snowy);
    });

    test('mapWeatherCode is exposed for the scene to share', () {
      expect(WeatherThemeNotifier.mapWeatherCode(1000), WeatherTheme.sunny);
      expect(WeatherThemeNotifier.mapWeatherCode(8000), WeatherTheme.rainy);
    });

    test('night override applied after sunset', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromTimeOfDay(DateTime(2026, 4, 14, 21)); // 9 PM
      expect(notifier.state, WeatherTheme.night);
    });

    test('night override not applied during day', () {
      final notifier = WeatherThemeNotifier(null);
      notifier.setThemeFromConditions(1000);
      notifier.setThemeFromTimeOfDay(DateTime(2026, 4, 14, 12)); // noon
      expect(notifier.state, WeatherTheme.sunny);
    });

    test('user override prevents weather-adaptive changes', () {
      final notifier = WeatherThemeNotifier(WeatherTheme.snowy);
      notifier.setThemeFromConditions(1000); // would be sunny
      expect(notifier.state, WeatherTheme.snowy); // stays snowy
    });

    test('user override prevents night override', () {
      final notifier = WeatherThemeNotifier(WeatherTheme.overcast);
      notifier.setThemeFromTimeOfDay(DateTime(2026, 4, 14, 23)); // 11 PM
      expect(notifier.state, WeatherTheme.overcast); // stays overcast
    });

    test('activeThemeName returns theme name string', () {
      final notifier = WeatherThemeNotifier(null);
      expect(notifier.activeThemeName, 'sunny');
      notifier.setThemeFromConditions(4001);
      expect(notifier.activeThemeName, 'rainy');
    });
  });
}
