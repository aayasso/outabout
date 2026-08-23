import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/features/weather_scene/weather_scene_spec.dart';

/// The scene must agree with the palette in every case, including the ones
/// where the sky and the palette disagree — a manual override.
void main() {
  WeatherSceneSpec scene(WeatherTheme theme, [int? code]) =>
      resolveWeatherScene(theme: theme, liveWeatherCode: code);

  group('scene kind follows the resolved theme', () {
    test('sunny theme paints the sun', () {
      expect(scene(WeatherTheme.sunny, 1000).kind, WeatherSceneKind.sun);
    });

    test('overcast theme paints clouds', () {
      expect(scene(WeatherTheme.overcast, 1101).kind, WeatherSceneKind.clouds);
    });

    test('rainy theme paints rain', () {
      expect(scene(WeatherTheme.rainy, 4001).kind, WeatherSceneKind.rain);
    });

    test('snowy theme paints snow', () {
      expect(scene(WeatherTheme.snowy, 5000).kind, WeatherSceneKind.snow);
    });

    test('night theme paints the night sky', () {
      expect(scene(WeatherTheme.night, 1000).kind, WeatherSceneKind.night);
    });
  });

  group('intensity scales with live conditions', () {
    test('clear sky is sun only', () {
      expect(scene(WeatherTheme.sunny, 1000).cloudCount, 0);
    });

    test('mostly clear is a single cloud on the overcast palette', () {
      // 1100 maps to overcast, not sunny — the palette follows the mapping, so
      // the scene must too.
      expect(scene(WeatherTheme.overcast, 1100).cloudCount, 1);
    });

    test('the sunny scene is always a bare sun', () {
      for (final code in [1000, 1100, 4001, 5000, null]) {
        expect(scene(WeatherTheme.sunny, code).cloudCount, 0);
      }
    });

    test('partly cloudy is two clouds at full size', () {
      final spec = scene(WeatherTheme.overcast, 1101);
      expect(spec.cloudCount, 2);
      expect(spec.cloudScale, 1.0);
    });

    test('cloudy is three larger clouds', () {
      final spec = scene(WeatherTheme.overcast, 1001);
      expect(spec.cloudCount, 3);
      expect(spec.cloudScale, greaterThan(1.0));
    });

    test('mostly cloudy matches cloudy', () {
      expect(scene(WeatherTheme.overcast, 1102), scene(WeatherTheme.overcast, 1001));
    });

    test('drizzle is lighter than steady rain', () {
      expect(
        scene(WeatherTheme.rainy, 4000).particleCount,
        lessThan(scene(WeatherTheme.rainy, 4001).particleCount),
      );
    });

    test('light rain matches drizzle', () {
      expect(scene(WeatherTheme.rainy, 4200), scene(WeatherTheme.rainy, 4000));
    });

    test('heavy rain is heavier than steady rain and adds wind', () {
      final heavy = scene(WeatherTheme.rainy, 4201);
      expect(
        heavy.particleCount,
        greaterThan(scene(WeatherTheme.rainy, 4001).particleCount),
      );
      expect(heavy.hasWind, isTrue);
    });

    test('flurries and light snow are the lightest snowfall', () {
      expect(scene(WeatherTheme.snowy, 5001).particleCount, 12);
      expect(scene(WeatherTheme.snowy, 5100).particleCount, 12);
    });

    test('heavy snow is the heaviest snowfall', () {
      expect(
        scene(WeatherTheme.snowy, 5101).particleCount,
        greaterThan(scene(WeatherTheme.snowy, 5000).particleCount),
      );
    });

    test('no scene exceeds the particle ceiling', () {
      for (final code in [1000, 1001, 2000, 4001, 4201, 5101, 8000]) {
        for (final theme in WeatherTheme.values) {
          expect(
            scene(theme, code).particleCount,
            lessThanOrEqualTo(maxSceneParticles),
            reason: 'theme $theme, code $code',
          );
        }
      }
    });
  });

  group('thunder', () {
    test('a thunderstorm code adds thunder', () {
      final spec = scene(WeatherTheme.rainy, 8000);
      expect(spec.hasThunder, isTrue);
      expect(spec.hasWind, isTrue);
    });

    test('plain rain has no thunder', () {
      expect(scene(WeatherTheme.rainy, 4001).hasThunder, isFalse);
    });

    test('heavy rain alone has no thunder', () {
      expect(scene(WeatherTheme.rainy, 4201).hasThunder, isFalse);
    });
  });

  group('fog', () {
    test('fog is cloud cover with no falling water', () {
      final spec = scene(WeatherTheme.rainy, 2000);
      expect(spec.particleCount, 0);
      expect(spec.cloudCount, 3);
    });

    test('fog veils more heavily than rain', () {
      expect(
        scene(WeatherTheme.rainy, 2000).veilAlpha,
        greaterThan(scene(WeatherTheme.rainy, 4001).veilAlpha),
      );
    });

    test('light fog matches fog', () {
      expect(scene(WeatherTheme.rainy, 2100), scene(WeatherTheme.rainy, 2000));
    });
  });

  group('manual override drives the scene, live conditions do not', () {
    test('override to rainy on a clear day still rains', () {
      final spec = scene(WeatherTheme.rainy, 1000);
      expect(spec.kind, WeatherSceneKind.rain);
    });

    test('override to rainy on a clear day gets neutral intensity', () {
      expect(scene(WeatherTheme.rainy, 1000), scene(WeatherTheme.rainy));
    });

    test('override to rainy during a thunderstorm elsewhere adds no thunder '
        'when the code disagrees with the theme', () {
      // 5101 is heavy snow — it maps to snowy, so it cannot describe a rainy
      // palette and must not reach the rain intensity table.
      expect(scene(WeatherTheme.rainy, 5101).hasThunder, isFalse);
      expect(scene(WeatherTheme.rainy, 5101), scene(WeatherTheme.rainy));
    });

    test('override to snowy on a rainy day gets neutral snowfall', () {
      expect(scene(WeatherTheme.snowy, 4001), scene(WeatherTheme.snowy));
    });

    test('override to sunny during snow shows a bare sun', () {
      expect(scene(WeatherTheme.sunny, 5000).cloudCount, 0);
    });
  });

  group('night ignores the live code', () {
    test('night during a thunderstorm is still the fixed night sky', () {
      expect(scene(WeatherTheme.night, 8000), scene(WeatherTheme.night));
    });

    test('night has no particles and no thunder', () {
      final spec = scene(WeatherTheme.night);
      expect(spec.particleCount, 0);
      expect(spec.hasThunder, isFalse);
    });
  });

  group('weather not loaded yet', () {
    test('every theme resolves to its neutral scene with a null code', () {
      for (final theme in WeatherTheme.values) {
        expect(scene(theme), isA<WeatherSceneSpec>(), reason: 'theme $theme');
      }
      expect(scene(WeatherTheme.rainy).particleCount, 14);
      expect(scene(WeatherTheme.snowy).particleCount, 20);
      expect(scene(WeatherTheme.overcast).cloudCount, 2);
    });
  });
}
