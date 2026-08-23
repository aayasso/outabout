import 'package:flutter/foundation.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';

/// The kind of animated scene painted behind the Schedule tab.
enum WeatherSceneKind { sun, clouds, rain, snow, night }

/// Hard ceiling on animated particles in any one scene.
///
/// Each raindrop and snowflake is its own [StatefulWidget] with three
/// [AnimationController]s, so the count is the scene's frame cost.
const int maxSceneParticles = 32;

/// Opacity of the themed veil drawn between the scene and the day list.
///
/// Tuned by measurement on device — see the branch notes. Higher values buy
/// text contrast at the cost of scene visibility.
abstract class SceneVeilAlpha {
  static const double sunny = 0.26;
  static const double overcast = 0.24;
  static const double rainy = 0.34;
  static const double snowy = 0.24;
  static const double night = 0.20;
  static const double fog = 0.46;
}

/// Everything the scene widget needs to draw one frame of weather.
///
/// Deliberately free of `Color` and `Size`: colours come from
/// `weatherThemeColorsProvider` at paint time and geometry from the layout, so
/// this stays a small pure value that is cheap to compare and easy to assert on.
@immutable
class WeatherSceneSpec {
  final WeatherSceneKind kind;
  final int cloudCount;
  final double cloudScale;
  final int particleCount;
  final bool hasThunder;
  final bool hasWind;
  final double veilAlpha;

  const WeatherSceneSpec({
    required this.kind,
    required this.veilAlpha,
    this.cloudCount = 0,
    this.cloudScale = 1.0,
    this.particleCount = 0,
    this.hasThunder = false,
    this.hasWind = false,
  }) : assert(
          particleCount <= maxSceneParticles,
          'particleCount must stay within maxSceneParticles',
        );

  @override
  bool operator ==(Object other) =>
      other is WeatherSceneSpec &&
      other.kind == kind &&
      other.cloudCount == cloudCount &&
      other.cloudScale == cloudScale &&
      other.particleCount == particleCount &&
      other.hasThunder == hasThunder &&
      other.hasWind == hasWind &&
      other.veilAlpha == veilAlpha;

  @override
  int get hashCode => Object.hash(
        kind,
        cloudCount,
        cloudScale,
        particleCount,
        hasThunder,
        hasWind,
        veilAlpha,
      );

  @override
  String toString() =>
      'WeatherSceneSpec(kind: $kind, clouds: $cloudCount x$cloudScale, '
      'particles: $particleCount, thunder: $hasThunder, wind: $hasWind, '
      'veil: $veilAlpha)';
}

/// Resolves the scene for the theme the app has already settled on.
///
/// [theme] is the single source of truth: it comes from
/// `weatherThemeProvider`, which has already applied any manual override. So an
/// override to rainy shows rain whatever the sky is doing.
///
/// [liveWeatherCode] only scales intensity, and only when it still describes
/// [theme] — see [_describingCode].
WeatherSceneSpec resolveWeatherScene({
  required WeatherTheme theme,
  int? liveWeatherCode,
}) {
  final code = _describingCode(theme, liveWeatherCode);
  return switch (theme) {
    WeatherTheme.sunny => _sunnyScene(code),
    WeatherTheme.overcast => _overcastScene(code),
    WeatherTheme.rainy => _rainyScene(code),
    WeatherTheme.snowy => _snowyScene(code),
    WeatherTheme.night => _nightScene,
  };
}

/// The live code, but only when it still describes [theme].
///
/// A manual override decouples the palette from the sky. Letting the live code
/// drive intensity anyway would put thunder behind a rainy theme the user
/// picked on a clear afternoon. Night falls out for free: the mapping never
/// returns night, so a night palette always lands on the fixed scene.
int? _describingCode(WeatherTheme theme, int? code) {
  if (code == null) return null;
  return WeatherThemeNotifier.mapWeatherCode(code) == theme ? code : null;
}

// ---------------------------------------------------------------------------
// Per-theme scenes
// ---------------------------------------------------------------------------

/// Sunny means clear: the mapping sends every cloud code from 1100 up to
/// overcast, so there is no sunny-with-clouds case to express here.
WeatherSceneSpec _sunnyScene(int? code) => const WeatherSceneSpec(
      kind: WeatherSceneKind.sun,
      veilAlpha: SceneVeilAlpha.sunny,
    );

WeatherSceneSpec _overcastScene(int? code) {
  final isHeavy = code == _mostlyCloudy || code == _cloudy;
  return WeatherSceneSpec(
    kind: WeatherSceneKind.clouds,
    cloudCount: switch (code) {
      _mostlyClear => 1,
      _ => isHeavy ? 3 : 2,
    },
    cloudScale: isHeavy ? 1.15 : 1.0,
    veilAlpha: SceneVeilAlpha.overcast,
  );
}

WeatherSceneSpec _rainyScene(int? code) {
  if (code != null && code >= 2000 && code < 3000) return _fogScene;

  final drops = _rainDropCount(code);
  return WeatherSceneSpec(
    kind: WeatherSceneKind.rain,
    cloudCount: 2,
    particleCount: drops,
    hasWind: drops == _heavyRainDrops,
    hasThunder: code != null && code >= 8000 && code < 9000,
    veilAlpha: SceneVeilAlpha.rainy,
  );
}

WeatherSceneSpec _snowyScene(int? code) => WeatherSceneSpec(
      kind: WeatherSceneKind.snow,
      cloudCount: 2,
      particleCount: _snowflakeCount(code),
      veilAlpha: SceneVeilAlpha.snowy,
    );

/// Fog reads as stillness, not as falling water — clouds only, heavier veil.
const _fogScene = WeatherSceneSpec(
  kind: WeatherSceneKind.rain,
  cloudCount: 3,
  cloudScale: 1.2,
  veilAlpha: SceneVeilAlpha.fog,
);

/// Night is a time-of-day collapse, so the live code no longer describes it.
const _nightScene = WeatherSceneSpec(
  kind: WeatherSceneKind.night,
  cloudCount: 1,
  veilAlpha: SceneVeilAlpha.night,
);

// ---------------------------------------------------------------------------
// Intensity
// ---------------------------------------------------------------------------

int _rainDropCount(int? code) {
  if (code == null) return _steadyRainDrops;
  if (code == _drizzle || code == _lightRain) return _lightRainDrops;
  if (code == _heavyRain) return _heavyRainDrops;
  if (code >= 8000 && code < 9000) return _heavyRainDrops; // thunderstorm
  return _steadyRainDrops;
}

int _snowflakeCount(int? code) {
  if (code == _flurries || code == _lightSnow) return 12;
  if (code == _heavySnow) return maxSceneParticles;
  return 20;
}

const int _lightRainDrops = 8;
const int _steadyRainDrops = 14;
const int _heavyRainDrops = 22;

// Tomorrow.io weather codes.
// https://docs.tomorrow.io/reference/data-layers-weather-codes
const int _mostlyClear = 1100;
const int _cloudy = 1001;
const int _mostlyCloudy = 1102;
const int _drizzle = 4000;
const int _lightRain = 4200;
const int _heavyRain = 4201;
const int _flurries = 5001;
const int _lightSnow = 5100;
const int _heavySnow = 5101;
