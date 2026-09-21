/// Screenshot integration test.
///
/// Renders a single shot determined by the SHOT dart-define,
/// then waits for the driver to capture via xcrun simctl io.
///
/// Run via tool/screenshots.sh, not directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';

import 'demo_data.dart';
import 'screenshot_app.dart';

/// Which shot to render. Passed via --dart-define=SHOT=xx.
const _shot = String.fromEnvironment('SHOT');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot — $_shot', (tester) async {
    if (_shot.isEmpty) {
      fail('Pass --dart-define=SHOT=<shot_id>');
    }

    final config = _shotConfigs[_shot];
    if (config == null) {
      fail('Unknown shot: $_shot. '
          'Valid: ${_shotConfigs.keys.join(', ')}');
    }

    // Build prefs
    SharedPreferences.setMockInitialValues(
      config.authenticated
          ? <String, Object>{'onboarding_complete': true}
          : <String, Object>{},
    );
    final prefs = await SharedPreferences.getInstance();

    // Build strict mock Supabase
    final supabase = buildMockSupabase(
      authenticated: config.authenticated,
    );

    // Build no-op event service
    final eventService = NoOpBehavioralEventService();

    // Assemble overrides
    final overrides = <Override>[
      ...baseOverrides(
        supabase: supabase,
        eventService: eventService,
        prefs: prefs,
      ),
      weatherDataProvider.overrideWith(
        (ref) async => config.weatherData,
      ),
      dailyForecastProvider.overrideWith(
        (ref) async => forecastSnapshot(config.forecast),
      ),
      nowProvider.overrideWithValue(() => config.now),
      // Activity detail — return demo activity by ID
      activityDetailProvider.overrideWith(
        (ref, id) async => demoActivities
            .where((a) => a.id == id)
            .firstOrNull,
      ),
      // Outcomes — empty (no history for screenshots)
      activityOutcomesProvider.overrideWith(
        (ref, id) async => const [],
      ),
    ];

    // Render the app
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const ScreenshotApp(),
      ),
    );

    // Initial pump to let the router redirect and
    // weatherThemeSyncProvider fire its microtask.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // Navigate if needed
    if (config.navigate != null) {
      await config.navigate!(tester);
      await tester.pump(const Duration(seconds: 1));
    }

    // Extra pump for entrance animations
    await tester.pump(const Duration(seconds: 1));

    // Print match grid for schedule shots
    if (config.printGrid) {
      _printMatchGrid(
        config.forecast,
        '$_shot match grid',
      );
    }

    // Verify Supabase isolation — the strict mock throws on
    // any unstubbed access. This assertion proves no provider
    // reached Supabase beyond the stubbed auth members.
    verify(() => supabase.auth).called(greaterThan(0));
    verifyNoMoreInteractions(supabase);
    // ignore: avoid_print
    print(
      'ISOLATION: verifyNoMoreInteractions(supabase) '
      'passed for shot $_shot',
    );
  });
}

// ------------------------------------------------------------------
// Shot configurations
// ------------------------------------------------------------------

class _ShotConfig {
  const _ShotConfig({
    required this.weatherData,
    required this.forecast,
    required this.now,
    this.authenticated = true,
    this.navigate,
    this.printGrid = false,
  });

  final WeatherData weatherData;
  final List<DailyForecast> forecast;
  final DateTime now;
  final bool authenticated;
  final Future<void> Function(WidgetTester)? navigate;
  final bool printGrid;
}

final _day1 = DateTime(2026, 9, 21, 9, 0);

final _shotConfigs = <String, _ShotConfig>{
  '01': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    printGrid: true,
  ),
  '02': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    navigate: (tester) async {
      // Scroll to show the mid-schedule spread: the
      // rainy day with no matches and the windy day
      // with partial matches.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -900));
    },
    printGrid: true,
  ),
  '03': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    navigate: (tester) async {
      // Tap the Activities tab (second tab)
      final tabs = find.byType(NavigationDestination);
      await tester.tap(tabs.at(1));
    },
  ),
  '04': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    navigate: (tester) async {
      // Navigate to add-activity via the FAB
      final fab = find.byType(FloatingActionButton).first;
      await tester.tap(fab);
    },
  ),
  '05': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    navigate: (tester) async {
      // Navigate to the first activity's detail screen.
      // Tap the first activity card on the schedule.
      final firstActivity = find.text('Morning Run').first;
      await tester.tap(firstActivity);
    },
  ),
  '06': _ShotConfig(
    weatherData: rainyWeatherData,
    forecast: rainyForecast,
    now: _day1,
    printGrid: true,
  ),
  '07': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: DateTime(2026, 9, 21, 21, 0),
  ),
  '08': _ShotConfig(
    weatherData: sunnyWeatherData,
    forecast: sunnyForecast,
    now: _day1,
    authenticated: false,
  ),
};

// ------------------------------------------------------------------
// Match grid printer
// ------------------------------------------------------------------

void _printMatchGrid(
  List<DailyForecast> forecast,
  String label,
) {
  final buffer = StringBuffer('\n=== $label ===\n');
  buffer.write(''.padRight(22));
  for (var i = 0; i < forecast.length; i++) {
    buffer.write('Day${i + 1}'.padRight(6));
  }
  buffer.writeln();

  for (final activity in demoActivities) {
    buffer.write(activity.name.padRight(22));
    for (final day in forecast) {
      final matches = evaluateDayMatch(
        activity.conditionProfile,
        day,
      );
      buffer.write((matches ? 'Y' : 'N').padRight(6));
    }
    buffer.writeln();
  }

  buffer.write('Matches:'.padRight(22));
  for (final day in forecast) {
    final count = demoActivities
        .where(
          (a) => evaluateDayMatch(a.conditionProfile, day),
        )
        .length;
    buffer.write('$count/7'.padRight(6));
  }
  buffer.writeln();
  buffer.writeln('=== end $label ===');

  // Use debugPrint for long output (log truncates).
  // ignore: avoid_print
  print(buffer.toString());
}
