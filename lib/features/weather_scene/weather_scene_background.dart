import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_animation/weather_animation.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import 'night_sky.dart';
import 'weather_scene_provider.dart';
import 'weather_scene_spec.dart';

/// The animated weather scene painted behind the Schedule tab.
///
/// Three guarantees, in the order they are applied:
///
/// * **Reduce Motion** — when the platform asks for less motion the particle
///   layers are dropped entirely rather than frozen. Every raindrop and
///   snowflake starts at `areaYStart` on its first frame, so a merely-paused
///   field renders as a straight line of drops. What remains is the sun, moon,
///   stars and clouds at rest.
/// * **Backgrounded / off-tab** — the whole subtree sits under a [TickerMode].
///   `StatefulShellRoute.indexedStack` already wraps each branch in one, so
///   leaving the Schedule tab mutes the scene for free; this adds the app
///   lifecycle to the same gate.
/// * **Scroll cost** — a [RepaintBoundary] keeps the scene's per-frame particle
///   repaints off the day list's layer, and the list's scrolling off the
///   scene's. No `BackdropFilter` anywhere.
class WeatherSceneBackground extends ConsumerStatefulWidget {
  const WeatherSceneBackground({super.key});

  @override
  ConsumerState<WeatherSceneBackground> createState() =>
      _WeatherSceneBackgroundState();
}

class _WeatherSceneBackgroundState extends ConsumerState<WeatherSceneBackground>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rebuilds when the user toggles Reduce Motion with the app already open.
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  /// Whether the platform is asking for less motion.
  ///
  /// iOS reports Reduce Motion as its own `reduceMotion` feature;
  /// `MediaQuery.disableAnimations` carries only Android's "Remove animations"
  /// and stays false on iOS however the accessibility setting is set. Reading
  /// just the MediaQuery flag — the obvious choice — silently does nothing on
  /// the platform this app ships to first.
  bool _prefersReducedMotion(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.reduceMotion ||
        features.disableAnimations ||
        MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final spec = ref.watch(weatherSceneProvider);
    final isForeground = ref.watch(appIsForegroundProvider);
    final reduceMotion = _prefersReducedMotion(context);

    return RepaintBoundary(
      child: TickerMode(
        enabled: isForeground && !reduceMotion,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              _SceneLayers(
                spec: spec,
                colors: colors,
                size: constraints.biggest,
                reduceMotion: reduceMotion,
              ),
              _SceneVeil(colors: colors, alpha: spec.veilAlpha),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dispatches to the scene for the resolved theme.
class _SceneLayers extends StatelessWidget {
  const _SceneLayers({
    required this.spec,
    required this.colors,
    required this.size,
    required this.reduceMotion,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => switch (spec.kind) {
        WeatherSceneKind.sun =>
          _SunScene(spec: spec, colors: colors, size: size),
        WeatherSceneKind.clouds =>
          _CloudBank(spec: spec, colors: colors, size: size, alpha: 0.40),
        WeatherSceneKind.rain => _RainScene(
            spec: spec,
            colors: colors,
            size: size,
            reduceMotion: reduceMotion,
          ),
        WeatherSceneKind.snow => _SnowScene(
            spec: spec,
            colors: colors,
            size: size,
            reduceMotion: reduceMotion,
          ),
        WeatherSceneKind.night =>
          _NightScene(spec: spec, colors: colors, size: size),
      };
}

// ---------------------------------------------------------------------------
// Scenes
// ---------------------------------------------------------------------------

class _SunScene extends StatelessWidget {
  const _SunScene({
    required this.spec,
    required this.colors,
    required this.size,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Heavily alpha'd: the core is a filled arc, and at full strength it
        // floods the top-left quadrant of a light palette.
        SunWidget(
          sunConfig: SunConfig(
            width: size.width * 0.66,
            blurSigma: 16,
            coreColor: colors.primary.withValues(alpha: 0.38),
            midColor: colors.accent.withValues(alpha: 0.26),
            outColor: colors.primary.withValues(alpha: 0.22),
            animMidMill: 2200,
            animOutMill: 2600,
          ),
        ),
        _CloudBank(spec: spec, colors: colors, size: size, alpha: 0.28),
      ],
    );
  }
}

class _RainScene extends StatelessWidget {
  const _RainScene({
    required this.spec,
    required this.colors,
    required this.size,
    required this.reduceMotion,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _CloudBank(spec: spec, colors: colors, size: size, alpha: 0.38),
        if (!reduceMotion && spec.particleCount > 0)
          RainWidget(
            rainConfig: RainConfig(
              count: spec.particleCount,
              lengthDrop: 14,
              widthDrop: 3,
              color: colors.primary.withValues(alpha: 0.60),
              fallRangeMinDurMill: 900,
              fallRangeMaxDurMill: 1900,
              areaXStart: 0,
              areaXEnd: size.width,
              areaYStart: -24,
              areaYEnd: size.height,
              slideX: 3,
            ),
          ),
        if (!reduceMotion && spec.hasWind)
          WindWidget(
            windConfig: WindConfig(
              width: 5,
              y: size.height * 0.36,
              windGap: 16,
              blurSigma: 6,
              color: colors.textSecondary.withValues(alpha: 0.30),
              slideXStart: -60,
              slideXEnd: size.width + 60,
              pauseStartMill: 800,
              pauseEndMill: 5000,
              slideDurMill: 1400,
            ),
          ),
        if (!reduceMotion && spec.hasThunder)
          ThunderWidget(
            thunderConfig: ThunderConfig(
              thunderWidth: 8,
              blurSigma: 12,
              color: colors.accent.withValues(alpha: 0.65),
              pauseStartMill: 2000,
              pauseEndMill: 9000,
              points: [
                Offset(size.width * 0.64, size.height * 0.08),
                Offset(size.width * 0.72, size.height * 0.22),
              ],
            ),
          ),
      ],
    );
  }
}

class _SnowScene extends StatelessWidget {
  const _SnowScene({
    required this.spec,
    required this.colors,
    required this.size,
    required this.reduceMotion,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _CloudBank(spec: spec, colors: colors, size: size, alpha: 0.30),
        if (!reduceMotion && spec.particleCount > 0)
          SnowWidget(
            snowConfig: SnowConfig(
              count: spec.particleCount,
              size: 14,
              color: colors.primary.withValues(alpha: 0.75),
              areaXStart: 0,
              areaXEnd: size.width,
              areaYStart: -30,
              areaYEnd: size.height,
              waveMinSec: 5,
              waveMaxSec: 14,
              fallMinSec: 12,
              fallMaxSec: 30,
            ),
          ),
      ],
    );
  }
}

class _NightScene extends StatelessWidget {
  const _NightScene({
    required this.spec,
    required this.colors,
    required this.size,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NightSky(colors: colors),
        _CloudBank(spec: spec, colors: colors, size: size, alpha: 0.16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layers
// ---------------------------------------------------------------------------

/// Up to three drifting clouds at fixed proportional slots.
///
/// Tinted from `textSecondary` rather than `divider`: on the snowy and night
/// palettes `divider` sits within a few percent of `background`, so clouds drawn
/// from it are invisible.
class _CloudBank extends StatelessWidget {
  const _CloudBank({
    required this.spec,
    required this.colors,
    required this.size,
    required this.alpha,
  });

  final WeatherSceneSpec spec;
  final WeatherThemeColors colors;
  final Size size;
  final double alpha;

  /// Kept in the upper third: the day list starts at the very top of the tab
  /// (there is no app bar), so a cloud any lower reads as a grey smear behind
  /// the first card rather than as sky.
  static const List<Offset> _slots = [
    Offset(-0.04, 0.01),
    Offset(0.58, 0.06),
    Offset(0.28, 0.14),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < spec.cloudCount; index++)
          CloudWidget(
            cloudConfig: CloudConfig(
              size: size.width * (0.34 - index * 0.05) * spec.cloudScale,
              color: colors.textSecondary.withValues(alpha: alpha),
              x: size.width * _slots[index % _slots.length].dx,
              y: size.height * _slots[index % _slots.length].dy,
              scaleEnd: 1.06,
              slideX: 14 + index * 4,
              slideY: 4,
              slideDurMill: 2600 + index * 700,
            ),
          ),
      ],
    );
  }
}

/// Themed scrim between the scene and the day list.
///
/// Drawn from `colors.background` so it dims the scene toward the palette the
/// content was contrast-checked against, rather than toward an arbitrary black
/// or white overlay.
///
/// Graded rather than flat: the sky is worth seeing at the top of the tab, and
/// the bottom is where day sections stack up densest, so the veil deepens as it
/// descends.
class _SceneVeil extends StatelessWidget {
  const _SceneVeil({required this.colors, required this.alpha});

  final WeatherThemeColors colors;
  final double alpha;

  /// How much more the veil dims at the foot of the list than at its middle.
  static const double falloff = 0.22;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.background.withValues(alpha: alpha * 0.5),
              colors.background.withValues(alpha: alpha),
              colors.background
                  .withValues(alpha: (alpha + falloff).clamp(0.0, 1.0)),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      );
}
