import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/widgets/outcome_prompt.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _RecordingEventService extends BehavioralEventService {
  _RecordingEventService()
      : super(
          supabase: _MockSupabaseClient(),
          activeThemeName: 'sunny',
          appVersion: 'test',
        );

  final List<({String type, ConditionsAtEvent? conditions})> logged = [];

  @override
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
  }) async {
    logged.add((type: eventType, conditions: conditions));
  }
}

void main() {
  late _RecordingEventService events;
  late SharedPreferences prefs;

  final matchedDay = DateTime(2026, 8, 23);
  final forecast = DailyForecast(
    date: matchedDay,
    temperatureMax: 26.0,
    temperatureMin: 14.0,
    precipitationProbability: 18.6,
    windSpeedMax: 12.0,
    weatherCode: 1000,
  );

  setUp(() async {
    events = _RecordingEventService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget harness({required DateTime now}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(
          WeatherThemeColors.sunny,
        ),
        nowProvider.overrideWithValue(() => now),
        behavioralEventServiceProvider.overrideWithValue(events),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OutcomePrompt(
            activityId: 'act-1',
            activityName: 'Morning trail run',
            matchedDay: matchedDay,
            forecastDay: forecast,
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing before the threshold hour', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 9)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('renders nothing for a day that is not today', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 25, 18)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('appears in the evening on the matched day', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Not today'), findsOneWidget);
  });

  testWidgets('Yes logs activity_confirmed with the day\'s weather',
      (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(events.logged, hasLength(1));
    expect(events.logged.single.type, 'activity_confirmed');

    // The whole point of the outcome: it carries the conditions it happened
    // under, not a snapshot of zeros.
    final conditions = events.logged.single.conditions;
    expect(conditions, isNotNull);
    expect(conditions!.weatherCode, 1000);
    expect(conditions.tempMaxC, 26.0);
    expect(conditions.precipitationProbability, 19);
  });

  testWidgets('Not today logs condition_match_ignored', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(events.logged.single.type, 'condition_match_ignored');
  });

  testWidgets('dismissing settles the prompt without logging an outcome',
      (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(RegExp('^Dismiss')));
    await tester.pumpAndSettle();

    // A dismissal is not an outcome — recording one either way would be a lie
    // about what the user told us.
    expect(events.logged, isEmpty);
    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('disappears once answered and does not come back',
      (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);

    // Rebuild from scratch, same day: still settled, and no second event.
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 20)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
    expect(events.logged, hasLength(1));
  });

  testWidgets('the answer survives a fresh provider container',
      (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    // A brand new ProviderScope reading the same SharedPreferences, which is
    // what an app relaunch looks like.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 19)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('chips and the dismiss control meet the 48dp tap target',
      (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    for (final label in ['Yes', 'Not today']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(Container),
        ).first,
      );
      expect(size.height, greaterThanOrEqualTo(48.0), reason: label);
      expect(size.width, greaterThanOrEqualTo(48.0), reason: label);
    }

    expect(
      tester.getSize(find.byTooltip(RegExp('^Dismiss'))).height,
      greaterThanOrEqualTo(48.0),
    );
  });
}
