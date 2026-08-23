import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/schedule_tab.dart';
import 'package:outabout/features/weather_scene/weather_scene_background.dart';

/// The Schedule tab had no widget coverage before the animated background
/// landed. These pin the parts the scene depends on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final forecast = DailyForecast(
    date: DateTime(2026, 8, 23),
    temperatureMax: 24,
    temperatureMin: 14,
    precipitationProbability: 10,
    windSpeedMax: 12,
    weatherCode: 1000,
  );

  const activity = Activity(
    id: 'act-1',
    userId: 'user-1',
    name: 'Trail run',
  );

  Future<Widget> buildSubject({
    int weatherCode = 4001,
    List<ScheduleDay> days = const [],
    List<Activity> activities = const [],
    ScheduleLayout layout = ScheduleLayout.dayFirst,
  }) async {
    // ScheduleLayoutNotifier reads the layout straight from prefs.
    SharedPreferences.setMockInitialValues(
      layout == ScheduleLayout.activityFirst
          ? {'schedule_layout': 'activityFirst'}
          : <String, Object>{},
    );
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.rainy),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.rainy),
        weatherDataProvider.overrideWith(
          (ref) async => WeatherData(
            weatherCode: weatherCode,
            temperature: 12,
            windSpeed: 8,
            humidity: 70,
            precipitationIntensity: 1,
            uvIndex: 1,
          ),
        ),
        scheduleMatchProvider.overrideWithValue(AsyncValue.data(days)),
        activitiesProvider.overrideWith((ref) async => activities),

        profileProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: ScheduleTab()),
    );
  }

  /// Pumps the tab without settling.
  ///
  /// `pumpAndSettle` would spin forever: the scene's rain loops by design. The
  /// extra millisecond flushes the zero-duration timer `flutter_animate`
  /// schedules for the tab's existing entrance animations.
  Future<void> pumpSubject(
    WidgetTester tester, {
    List<ScheduleDay> days = const [],
    List<Activity> activities = const [],
    ScheduleLayout layout = ScheduleLayout.dayFirst,
  }) async {
    await tester.pumpWidget(await buildSubject(
      days: days,
      activities: activities,
      layout: layout,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders the animated scene behind the day list', (tester) async {
    await pumpSubject(tester);

    expect(find.byType(WeatherSceneBackground), findsOneWidget);
  });

  testWidgets('the scene sits below the scrollable content', (tester) async {
    await pumpSubject(tester);

    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(WeatherSceneBackground),
            matching: find.byType(Stack),
          )
          .first,
    );

    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.length, greaterThan(1));
  });

  testWidgets('the refresh indicator still wraps the content', (tester) async {
    await pumpSubject(tester);

    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  group('activity cards carry no activity glyph', () {
    // Every activity rendered the same hardcoded running icon, so it carried
    // no information. Nothing asserted on it before, so without these the
    // removal is untested.
    testWidgets('the day-first activity card shows only its name', (
      tester,
    ) async {
      await pumpSubject(
        tester,
        days: [
          ScheduleDay(forecast: forecast, matchedActivities: const [activity]),
        ],
        activities: const [activity],
      );

      expect(find.text('Trail run'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_outlined), findsNothing);
    });

    testWidgets('the day header keeps its weather icon', (tester) async {
      await pumpSubject(
        tester,
        days: [
          ScheduleDay(forecast: forecast, matchedActivities: const [activity]),
        ],
        activities: const [activity],
      );

      // weatherCode 1000 is clear.
      expect(find.byIcon(Icons.wb_sunny), findsWidgets);
    });

    testWidgets('the activity-first section header shows only its name', (
      tester,
    ) async {
      await pumpSubject(
        tester,
        days: [
          ScheduleDay(forecast: forecast, matchedActivities: const [activity]),
        ],
        activities: const [activity],
        layout: ScheduleLayout.activityFirst,
      );

      expect(find.text('Trail run'), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_outlined), findsNothing);
    });
  });
}
