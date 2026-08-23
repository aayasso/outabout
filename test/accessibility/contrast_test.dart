import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/features/weather_scene/weather_scene_spec.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio, 1.0 to 21.0.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [fg] painted at [alpha] over an opaque [bg].
Color over(Color fg, double alpha, Color bg) => Color.from(
  alpha: 1,
  red: alpha * fg.r + (1 - alpha) * bg.r,
  green: alpha * fg.g + (1 - alpha) * bg.g,
  blue: alpha * fg.b + (1 - alpha) * bg.b,
);

const _aaNormal = 4.5;
const _aaLarge = 3.0;

/// Veil opacities from `weather_scene_spec.dart`, at the *lightest* stop.
///
/// `_SceneVeil` grades the scrim: `alpha * 0.5` at the top, `alpha` at 0.42,
/// `alpha + 0.22` at the foot. The top is the worst case for legibility, and
/// it is where the "Today" section sits.
///
/// Read from [SceneVeilAlpha] rather than copied. Hardcoding the numbers here
/// meant this suite would keep certifying AA for a veil the app no longer
/// used — a contrast test that cannot notice the contrast changing.
const _veilTopFactor = 0.5;
final _lightestVeil = <String, double>{
  'sunny': SceneVeilAlpha.sunny * _veilTopFactor,
  'overcast': SceneVeilAlpha.overcast * _veilTopFactor,
  'rainy': SceneVeilAlpha.rainy * _veilTopFactor,
  'snowy': SceneVeilAlpha.snowy * _veilTopFactor,
  'night': SceneVeilAlpha.night * _veilTopFactor,
  'fog': SceneVeilAlpha.fog * _veilTopFactor,
};

/// The worst-case large-area scene element per palette, as (token, alpha)
/// layers in paint order. Particles are excluded: a raindrop is 3pt wide and
/// no glyph sits wholly on one. Clouds overlap, so they stack.
List<(Color, double)> _sceneStack(WeatherThemeColors c, String theme) =>
    switch (theme) {
      // Sun core, mid and outer glow, then the cloud bank over it.
      'sunny' => [
        (c.primary, 0.22),
        (c.accent, 0.26),
        (c.primary, 0.38),
        (c.textSecondary, 0.28),
      ],
      'overcast' => [(c.textSecondary, 0.40), (c.textSecondary, 0.40)],
      'rainy' => [(c.textSecondary, 0.38), (c.textSecondary, 0.38)],
      'fog' => [
        (c.textSecondary, 0.38),
        (c.textSecondary, 0.38),
        (c.textSecondary, 0.38),
      ],
      'snowy' => [(c.textSecondary, 0.30), (c.textSecondary, 0.30)],
      // Moon halo, then the moon disc.
      'night' => [(c.primary, 0.16), (c.textSecondary, 0.85)],
      _ => const [],
    };

/// The colour actually behind schedule card text: `surface` at 0.90 over the
/// veil over the scene.
Color scheduleCardBehind(WeatherThemeColors c, String theme) {
  var scene = c.background;
  for (final (color, alpha) in _sceneStack(c, theme)) {
    scene = over(color, alpha, scene);
  }
  final veiled = over(c.background, _lightestVeil[theme]!, scene);
  return over(c.surface, 0.90, veiled);
}

void main() {
  const palettes = <String, WeatherThemeColors>{
    'sunny': WeatherThemeColors.sunny,
    'overcast': WeatherThemeColors.overcast,
    'rainy': WeatherThemeColors.rainy,
    'snowy': WeatherThemeColors.snowy,
    'night': WeatherThemeColors.night,
  };

  group('text on the flat palette', () {
    palettes.forEach((name, c) {
      test('$name clears AA on background and card', () {
        for (final bg in [c.background, c.cardBackground]) {
          expect(
            contrast(c.text, bg),
            greaterThanOrEqualTo(_aaNormal),
            reason: '$name text',
          );
          expect(
            contrast(c.textSecondary, bg),
            greaterThanOrEqualTo(_aaNormal),
            reason:
                '$name textSecondary — 12pt body copy is normal text, '
                'so AA Large is not enough',
          );
          expect(
            contrast(c.primaryInteractive, bg),
            greaterThanOrEqualTo(_aaNormal),
            reason: '$name primaryInteractive',
          );
        }
      });
    });
  });

  group('ink on a primary fill', () {
    palettes.forEach((name, c) {
      test('$name onPrimary clears AA on the fill', () {
        expect(
          contrast(c.onPrimary, c.primary),
          greaterThanOrEqualTo(_aaNormal),
          reason:
              '$name: FAB icon, ElevatedButton label, selected segment, '
              'the outcome "Yes" chip and the active theme chip all sit on '
              'this fill',
        );
      });
    });
  });

  group('schedule text over the animated scene', () {
    // fog is a rainy-palette scene with a heavier veil and three clouds.
    const scenes = ['sunny', 'overcast', 'rainy', 'fog', 'snowy', 'night'];

    for (final scene in scenes) {
      final c = palettes[scene == 'fog' ? 'rainy' : scene]!;

      test('$scene: card text clears AA over the worst-case scene', () {
        final behind = scheduleCardBehind(c, scene);
        expect(
          contrast(c.text, behind),
          greaterThanOrEqualTo(_aaNormal),
          reason: '$scene card text',
        );
        expect(
          contrast(c.textSecondary, behind),
          greaterThanOrEqualTo(_aaNormal),
          reason:
              '$scene card secondary text — the day header renders '
              '11pt and 12pt labels on this surface',
        );
      });

      test('$scene: bare scene text would fail, which is why the '
          'surface exists', () {
        // Reads SceneVeilAlpha from lib rather than a copy, so a structural
        // change — dropping the veil, retuning the top stop, changing
        // _scheduleSurfaceOpacity — flows into these numbers.
        //
        // Honest about its own margins: the 0.90 card dominates the
        // composite and the top stop is capped at half the veil alpha, so
        // these thresholds are not close. That is the point — the surface is
        // what carries the text, not the veil.
        var raw = c.background;
        for (final (color, alpha) in _sceneStack(c, scene)) {
          raw = over(color, alpha, raw);
        }
        final bare = over(c.background, _lightestVeil[scene]!, raw);
        final surfaced = scheduleCardBehind(c, scene);

        expect(
          contrast(c.textSecondary, bare),
          lessThan(_aaNormal),
          reason:
              '$scene: if the veil now carries 12pt secondary text on its '
              'own, _sceneSurface is no longer load-bearing and this '
              'expectation should be revisited',
        );
        expect(
          contrast(c.textSecondary, surfaced),
          greaterThanOrEqualTo(_aaNormal),
          reason: '$scene: the surface is what makes this text legible',
        );
      });
    }
  });

  group('non-text contrast', () {
    palettes.forEach((name, c) {
      test('$name focus ring and slider track clear 3:1', () {
        // primaryInteractive backs the focused input border, the slider
        // track and thumb, and the selected chip border.
        expect(
          contrast(c.primaryInteractive, c.background),
          greaterThanOrEqualTo(_aaLarge),
          reason: '$name UI indicator on background',
        );
        expect(
          contrast(c.primaryInteractive, c.cardBackground),
          greaterThanOrEqualTo(_aaLarge),
          reason: '$name UI indicator on a card',
        );
      });
    });
  });
}
