import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/features/home/tabs/schedule_tab.dart';
import 'package:outabout/features/shared/condition_profile_form.dart';

/// iOS accessibility text sizes, as `textScaler` factors.
///
/// 1.0 is the default; 3.0 is AX5, the largest size the OS offers. A layout
/// that overflows at any of these is broken for the users who need them most.
const _scales = <double>[1.0, 1.5, 2.0, 3.0];

void main() {
  Widget host({required Widget child, required double scale}) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  /// Fails if any render box reported an overflow while painting.
  ///
  /// Paired with a positive assertion at every call site: on its own,
  /// "nothing threw" also passes for a widget that rendered
  /// `SizedBox.shrink()` or took an early-return empty branch, which is the
  /// failure mode this suite most needs to notice.
  void expectNoOverflow(WidgetTester tester, double scale) {
    final errors = tester.takeException();
    expect(errors, isNull, reason: 'overflowed at textScaler ${scale}x');
  }

  _scheduleTests();

  group('condition form survives the accessibility text sizes', () {
    for (final scale in _scales) {
      testWidgets('temperature section at ${scale}x', (tester) async {
        await tester.pumpWidget(
          host(
            scale: scale,
            child: SizedBox(
              width: 320,
              child: TemperatureSection(
                colors: WeatherThemeColors.sunny,
                min: 10,
                max: 30,
                temperatureUnit: 'F',
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester, scale);
        // The section actually rendered its slider and both end labels.
        expect(find.byType(RangeSlider), findsOneWidget);
        expect(find.textContaining('°F'), findsWidgets);
      });

      testWidgets('precipitation picker at ${scale}x', (tester) async {
        await tester.pumpWidget(
          host(
            scale: scale,
            child: SizedBox(
              width: 320,
              child: PrecipitationSection(
                colors: WeatherThemeColors.sunny,
                level: PrecipLevel.avoidRain,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester, scale);
        expect(find.text('Avoid rain'), findsOneWidget);
        expect(find.text('Only when raining'), findsOneWidget);
      });

      testWidgets('wind section at ${scale}x', (tester) async {
        await tester.pumpWidget(
          host(
            scale: scale,
            child: SizedBox(
              width: 320,
              child: WindSection(
                colors: WeatherThemeColors.sunny,
                maxWind: 24,
                temperatureUnit: 'F',
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoOverflow(tester, scale);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.textContaining('mph'), findsOneWidget);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// The Schedule tab, whose day header packs five values onto two lines
// ---------------------------------------------------------------------------

class _MockEventService extends Mock implements BehavioralEventService {}

_MockEventService _silentEvents() {
  final mock = _MockEventService();
  when(
    () => mock.log(
      any(),
      extra: any(named: 'extra'),
      conditions: any(named: 'conditions'),
    ),
  ).thenAnswer((_) async {});
  return mock;
}

DailyForecast _forecast(DateTime day) => DailyForecast(
  date: day,
  temperatureMax: 31.5,
  temperatureMin: -12.5,
  precipitationProbability: 100,
  // 88 km/h, so both the mph and km/h renderings are two digits wide.
  windSpeedMax: 88,
  weatherCode: 4201,
);

Activity _activity(String name) =>
    Activity(id: 'a1', userId: 'u1', name: name, conditionProfile: null);

void _scheduleTests() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget scheduleHost({required double scale, required double width}) {
    final day = DateTime(2026, 8, 23);
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
        behavioralEventServiceProvider.overrideWithValue(_silentEvents()),
        categoriesProvider.overrideWith((ref) async => []),
        profileProvider.overrideWith((ref) async => null),
        nowProvider.overrideWithValue(() => day),
        activitiesProvider.overrideWith(
          (ref) async => [_activity('Cycle the long river loop')],
        ),
        scheduleMatchProvider.overrideWith(
          (ref) => AsyncValue.data([
            ScheduleDay(
              forecast: _forecast(day),
              matchedActivities: [_activity('Cycle the long river loop')],
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            size: Size(width, 900),
            // The weather scene animates for as long as it is mounted, so
            // pumpAndSettle never returns with motion on. Reduce Motion
            // stills it — and layout does not depend on motion either way.
            disableAnimations: true,
          ),
          child: const ScheduleTab(),
        ),
      ),
    );
  }

  group('schedule day header survives the accessibility text sizes', () {
    for (final scale in _scales) {
      testWidgets('day-first layout at ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(375, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(scheduleHost(scale: scale, width: 375));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'day header overflowed at textScaler ${scale}x',
        );
        // And the header is genuinely on screen — an empty schedule would
        // never overflow either.
        expect(find.text('Today'), findsOneWidget);
        expect(find.textContaining('H:'), findsOneWidget);
        expect(find.text('Cycle the long river loop'), findsWidgets);
        // Two 48pt actions now share the row with the name. The decorative
        // chevron was removed to pay for the second one; if it ever comes
        // back this is where the squeeze shows up first.
        expect(find.byTooltip('Find & book'), findsWidgets);
        expect(find.byTooltip(RegExp('^Add .* to calendar')), findsWidgets);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      });
    }
  });
}
