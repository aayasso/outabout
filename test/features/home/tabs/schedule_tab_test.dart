import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/schedule_tab.dart';
import 'package:outabout/features/weather_scene/weather_scene_background.dart';

/// The Schedule tab had no widget coverage before the animated background
/// landed. These pin the parts the scene depends on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Widget> buildSubject({int weatherCode = 4001}) async {
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
        scheduleMatchProvider.overrideWithValue(const AsyncValue.data([])),
        activitiesProvider.overrideWith((ref) async => []),
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
  Future<void> pumpSubject(WidgetTester tester) async {
    await tester.pumpWidget(await buildSubject());
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
}
