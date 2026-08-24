import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/features/widget/widget_payload.dart';

/// Midday on 2026-08-23, so nothing here depends on when the suite runs.
final _now = DateTime(2026, 8, 23, 12);

DailyForecast _forecast({
  DateTime? date,
  double high = 20,
  double low = 13,
  int weatherCode = 1001,
}) => DailyForecast(
  date: date ?? DateTime(2026, 8, 23, 13),
  temperatureMax: high,
  temperatureMin: low,
  precipitationProbability: 5,
  windSpeedMax: 12,
  weatherCode: weatherCode,
);

Activity _activity(String name) =>
    Activity(id: name, userId: 'user-1', name: name);

List<ScheduleDay> _days({
  List<String> matches = const [],
  DateTime? date,
  int weatherCode = 1001,
  double high = 20,
  double low = 13,
}) => [
  ScheduleDay(
    forecast: _forecast(
      date: date,
      weatherCode: weatherCode,
      high: high,
      low: low,
    ),
    matchedActivities: [for (final name in matches) _activity(name)],
  ),
];

Map<String, dynamic>? _build({
  List<String> matches = const [],
  String unit = 'C',
  DateTime? date,
  int weatherCode = 1001,
  double high = 20,
  double low = 13,
  List<ScheduleDay>? days,
}) => buildWidgetPayload(
  days:
      days ??
      _days(
        matches: matches,
        date: date,
        weatherCode: weatherCode,
        high: high,
        low: low,
      ),
  now: _now,
  temperatureUnit: unit,
);

void main() {
  group('today selection', () {
    test('builds from the day matching the local calendar date', () {
      final payload = _build(matches: ['Morning Run'])!;
      expect(payload['local_date'], '2026-08-23');
    });

    test('is null when the forecast has no entry for today', () {
      // The five-day window always starts at today in practice, but a stale
      // cache served after midnight would not. Writing a payload dated
      // yesterday and labelling it today is the one thing the widget must
      // never do — better to leave the last good payload in place.
      final payload = _build(date: DateTime(2026, 8, 24, 13));
      expect(payload, isNull);
    });

    test('is null when the forecast is empty', () {
      expect(_build(days: const []), isNull);
    });

    test('picks today out of a multi-day forecast', () {
      final payload = buildWidgetPayload(
        days: [
          ScheduleDay(
            forecast: _forecast(date: DateTime(2026, 8, 22, 13), high: 99),
            matchedActivities: [],
          ),
          ScheduleDay(
            forecast: _forecast(date: DateTime(2026, 8, 23, 13), high: 20),
            matchedActivities: [_activity('Morning Run')],
          ),
          ScheduleDay(
            forecast: _forecast(date: DateTime(2026, 8, 24, 13), high: 1),
            matchedActivities: [_activity('Never')],
          ),
        ],
        now: _now,
        temperatureUnit: 'C',
      )!;

      expect(payload['temp_high'], 20);
      expect(payload['matches'], ['Morning Run']);
    });
  });

  group('matches', () {
    test('carries every name when there are four or fewer', () {
      final payload = _build(matches: ['A', 'B', 'C', 'D'])!;
      expect(payload['matches'], ['A', 'B', 'C', 'D']);
      expect(payload['match_count'], 4);
    });

    test('caps the list at four but keeps the true total', () {
      // The medium size says "+N more", and N is only correct if the count is
      // the real one rather than the length of the truncated list.
      final payload = _build(matches: ['A', 'B', 'C', 'D', 'E', 'F'])!;
      expect(payload['matches'], ['A', 'B', 'C', 'D']);
      expect(payload['match_count'], 6);
      expect(widgetMatchNameLimit, 4);
    });

    test('reports an empty day honestly', () {
      final payload = _build()!;
      expect(payload['matches'], isEmpty);
      expect(payload['match_count'], 0);
    });

    test(
      'skips an activity with no name rather than rendering a blank row',
      () {
        final payload = buildWidgetPayload(
          days: [
            ScheduleDay(
              forecast: _forecast(),
              matchedActivities: [
                Activity(id: 'a', userId: 'u', name: '  '),
                _activity('Morning Run'),
              ],
            ),
          ],
          now: _now,
          temperatureUnit: 'C',
        )!;
        expect(payload['matches'], ['Morning Run']);
        expect(payload['match_count'], 1);
      },
    );
  });

  group('units', () {
    test('ships Celsius untouched', () {
      final payload = _build(high: 20.4, low: 13.6, unit: 'C')!;
      expect(payload['temp_high'], 20);
      expect(payload['temp_low'], 14);
      expect(payload['unit'], 'C');
    });

    test('converts to Fahrenheit before it leaves Dart', () {
      // The widget cannot resolve the unit itself: it lives on
      // profiles.temperature_unit, server-side, and deliberately not in
      // SharedPreferences. So the numbers cross the bridge already converted.
      final payload = _build(high: 20, low: 10, unit: 'F')!;
      expect(payload['temp_high'], 68);
      expect(payload['temp_low'], 50);
      expect(payload['unit'], 'F');
    });
  });

  group('conditions', () {
    test('names the condition so Swift needs no lookup table', () {
      expect(_build(weatherCode: 1001)!['condition'], 'Cloudy');
      expect(_build(weatherCode: 4001)!['condition'], 'Rain');
      expect(_build(weatherCode: 5000)!['condition'], 'Snow');
    });

    test('falls back for an unknown code rather than emitting nothing', () {
      final payload = _build(weatherCode: 9999)!;
      expect(payload['condition'], 'Clear');
      expect(payload['weather_code'], 9999);
    });

    test('carries the raw code too, for the icon', () {
      expect(_build(weatherCode: 8000)!['weather_code'], 8000);
    });
  });

  group('colors', () {
    // Resolved in Dart and shipped as hex. A second copy of five palettes in
    // Swift would drift the moment one value changed, and CLAUDE.md's central
    // rule is that nothing hardcodes a palette.
    test('resolves the palette from the weather code', () {
      expect(_build(weatherCode: 1000)!['theme'], 'sunny');
      expect(_build(weatherCode: 1001)!['theme'], 'overcast');
      expect(_build(weatherCode: 4001)!['theme'], 'rainy');
      expect(_build(weatherCode: 5000)!['theme'], 'snowy');
    });

    test('ships every colour the widget draws with', () {
      final colors = _build(weatherCode: 1001)!['colors'] as Map;
      expect(
        colors.keys,
        containsAll(<String>[
          'background',
          'surface',
          'text',
          'textSecondary',
          'primary',
        ]),
      );
    });

    test('emits hex that matches the app palette exactly', () {
      final colors = _build(weatherCode: 1001)!['colors'] as Map;
      expect(colors['background'], '#F0F2F5');
      expect(colors['text'], '#2C3E50');
    });

    test('ships primaryInteractive as the accent, not primary', () {
      // The widget uses this colour as ink — the match count, the icon tint —
      // never as a fill. theme.dart is explicit that `primary` reaches only
      // 1.66-2.46:1 as a foreground on the light palettes, which is the whole
      // reason `primaryInteractive` exists. Shipping `primary` here would put
      // unreadable text on three of the five themes.
      expect(
        (_build(weatherCode: 1001)!['colors'] as Map)['primary'],
        '#1565C0',
      );
      expect(
        (_build(weatherCode: 1000)!['colors'] as Map)['primary'],
        '#A05E00',
      );
      expect(
        (_build(weatherCode: 4001)!['colors'] as Map)['primary'],
        '#7DBBFF',
      );
    });

    test('every theme round-trips to eight-digit-free six-digit hex', () {
      for (final code in [1000, 1001, 4001, 5000]) {
        final colors = _build(weatherCode: code)!['colors'] as Map;
        for (final value in colors.values) {
          expect(value, matches(RegExp(r'^#[0-9A-F]{6}$')), reason: '$code');
        }
      }
    });

    test('hexOf drops the alpha channel', () {
      expect(hexOf(const Color(0xFFF5A623)), '#F5A623');
      expect(hexOf(const Color(0xFF000000)), '#000000');
    });
  });

  group('schema', () {
    test('is versioned so an older widget can refuse a newer payload', () {
      expect(_build()!['schema'], widgetPayloadSchema);
      expect(widgetPayloadSchema, 1);
    });

    test('encodes to JSON without throwing', () {
      // It crosses the bridge as a string; a non-encodable value would fail
      // at the platform channel with nothing useful in the log.
      expect(
        () => encodeWidgetPayload(_build(matches: ['A'])!),
        returnsNormally,
      );
    });
  });
}
