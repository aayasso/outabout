import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_animation/weather_animation.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/weather_scene/night_sky.dart';
import 'package:outabout/features/weather_scene/weather_scene_background.dart';
import 'package:outabout/features/weather_scene/weather_scene_provider.dart';
import 'package:outabout/features/weather_scene/weather_scene_spec.dart';

void main() {
  Widget harness({
    required WeatherSceneSpec spec,
    WeatherThemeColors colors = WeatherThemeColors.rainy,
    bool disableAnimations = false,
    bool isForeground = true,
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeColorsProvider.overrideWithValue(colors),
        weatherSceneProvider.overrideWithValue(spec),
        appIsForegroundProvider.overrideWith((ref) => isForeground),
      ],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: WeatherSceneBackground(),
        ),
      ),
    );
  }

  const rainySpec = WeatherSceneSpec(
    kind: WeatherSceneKind.rain,
    cloudCount: 2,
    particleCount: 14,
    hasWind: true,
    hasThunder: true,
    veilAlpha: SceneVeilAlpha.rainy,
  );

  const snowySpec = WeatherSceneSpec(
    kind: WeatherSceneKind.snow,
    cloudCount: 2,
    particleCount: 20,
    veilAlpha: SceneVeilAlpha.snowy,
  );

  bool tickerEnabled(WidgetTester tester) =>
      tester.widget<TickerMode>(find.byType(TickerMode)).enabled;

  LinearGradient veilGradient(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<LinearGradient>()
      .single;

  group('Reduce Motion', () {
    testWidgets('drops every moving particle layer', (tester) async {
      await tester.pumpWidget(
        harness(spec: rainySpec, disableAnimations: true),
      );
      await tester.pump();

      expect(find.byType(RainWidget), findsNothing);
      expect(find.byType(WindWidget), findsNothing);
      expect(find.byType(ThunderWidget), findsNothing);
    });

    testWidgets('drops snowfall too', (tester) async {
      await tester.pumpWidget(
        harness(spec: snowySpec, disableAnimations: true),
      );
      await tester.pump();

      expect(find.byType(SnowWidget), findsNothing);
    });

    testWidgets('keeps the static composition', (tester) async {
      await tester.pumpWidget(
        harness(spec: rainySpec, disableAnimations: true),
      );
      await tester.pump();

      expect(find.byType(CloudWidget), findsNWidgets(2));
    });

    testWidgets('mutes the tickers as well', (tester) async {
      await tester.pumpWidget(
        harness(spec: rainySpec, disableAnimations: true),
      );
      await tester.pump();

      expect(tickerEnabled(tester), isFalse);
    });
  });

  group("iOS's own Reduce Motion flag", () {
    // MediaQuery.disableAnimations stays false on iOS no matter how the
    // accessibility setting is set — iOS reports Reduce Motion through
    // AccessibilityFeatures.reduceMotion instead.
    testWidgets('reduceMotion alone drops the particle layers', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(harness(spec: rainySpec));
      await tester.pump();

      expect(find.byType(RainWidget), findsNothing);
      expect(tickerEnabled(tester), isFalse);
    });

    testWidgets('with no accessibility flag set the scene animates', (
      tester,
    ) async {
      await tester.pumpWidget(harness(spec: rainySpec));
      await tester.pump();

      expect(find.byType(RainWidget), findsOneWidget);
    });
  });

  group('motion allowed', () {
    testWidgets('renders the particle layers', (tester) async {
      await tester.pumpWidget(harness(spec: rainySpec));
      await tester.pump();

      expect(find.byType(RainWidget), findsOneWidget);
      expect(find.byType(WindWidget), findsOneWidget);
      expect(find.byType(ThunderWidget), findsOneWidget);
      expect(tickerEnabled(tester), isTrue);
    });

    testWidgets('renders snowfall', (tester) async {
      await tester.pumpWidget(harness(spec: snowySpec));
      await tester.pump();

      expect(find.byType(SnowWidget), findsOneWidget);
    });
  });

  group('lifecycle', () {
    testWidgets('a backgrounded app mutes the scene', (tester) async {
      await tester.pumpWidget(harness(spec: rainySpec, isForeground: false));
      await tester.pump();

      expect(tickerEnabled(tester), isFalse);
    });
  });

  group('composition', () {
    testWidgets('the scene sits behind a RepaintBoundary', (tester) async {
      await tester.pumpWidget(harness(spec: rainySpec));
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byType(TickerMode),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('the sunny scene paints a sun', (tester) async {
      await tester.pumpWidget(
        harness(
          spec: const WeatherSceneSpec(
            kind: WeatherSceneKind.sun,
            veilAlpha: SceneVeilAlpha.sunny,
          ),
          colors: WeatherThemeColors.sunny,
        ),
      );
      await tester.pump();

      expect(find.byType(SunWidget), findsOneWidget);
      expect(find.byType(RainWidget), findsNothing);
    });

    testWidgets('the night scene paints the sky, not a sun', (tester) async {
      await tester.pumpWidget(
        harness(
          spec: const WeatherSceneSpec(
            kind: WeatherSceneKind.night,
            cloudCount: 1,
            veilAlpha: SceneVeilAlpha.night,
          ),
          colors: WeatherThemeColors.night,
        ),
      );
      await tester.pump();

      expect(find.byType(NightSky), findsOneWidget);
      expect(find.byType(SunWidget), findsNothing);
    });

    testWidgets('the veil is drawn from the active background colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(spec: snowySpec, colors: WeatherThemeColors.snowy),
      );
      await tester.pump();

      final gradient = veilGradient(tester);

      expect(
        gradient.colors[1],
        WeatherThemeColors.snowy.background
            .withValues(alpha: SceneVeilAlpha.snowy),
      );
    });

    testWidgets('the veil deepens toward the foot of the list', (tester) async {
      await tester.pumpWidget(harness(spec: snowySpec));
      await tester.pump();

      final alphas = veilGradient(tester).colors.map((c) => c.a).toList();

      expect(alphas.first, lessThan(alphas[1]));
      expect(alphas.last, greaterThan(alphas[1]));
    });
  });

  group('every theme draws from its own palette', () {
    for (final theme in WeatherTheme.values) {
      testWidgets('${theme.name} paints without hardcoded colour', (
        tester,
      ) async {
        final colors = WeatherThemeColors.forTheme(theme);
        await tester.pumpWidget(
          harness(
            spec: resolveWeatherScene(theme: theme),
            colors: colors,
          ),
        );
        await tester.pump();

        for (final stop in veilGradient(tester).colors) {
          expect(
            stop.withValues(alpha: 1.0),
            colors.background,
            reason: 'the ${theme.name} veil must come from its own background',
          );
        }
      });
    }
  });
}
