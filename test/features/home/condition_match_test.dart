import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/features/home/home_providers.dart';

void main() {
  final day = DailyForecast(
    date: DateTime(2026, 6, 27),
    temperatureMax: 28.0,
    temperatureMin: 18.0,
    precipitationProbability: 10.0,
    windSpeedMax: 15.0,
    weatherCode: 1000,
  );

  group('evaluateDayMatch', () {
    test('null profile (no conditions) returns true', () {
      expect(evaluateDayMatch(null, day), true);
    });

    test('all conditions disabled returns true', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: false,
        precipEnabled: false,
        windEnabled: false,
      );
      expect(evaluateDayMatch(profile, day), true);
    });

    test('temp overlap — day range overlaps activity range', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 25.0,
        tempMax: 35.0,
      );
      // day max 28 >= 25, day min 18 <= 35 => overlap
      expect(evaluateDayMatch(profile, day), true);
    });

    test('temp no overlap — day entirely below range', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 30.0,
        tempMax: 40.0,
      );
      // day max 28 < 30 => no overlap
      expect(evaluateDayMatch(profile, day), false);
    });

    test('temp no overlap — day entirely above range', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 5.0,
        tempMax: 15.0,
      );
      // day min 18 > 15 => no overlap
      expect(evaluateDayMatch(profile, day), false);
    });

    DailyForecast dayWithPrecip(double probability) => DailyForecast(
          date: DateTime(2026, 6, 27),
          temperatureMax: 28.0,
          temperatureMin: 18.0,
          precipitationProbability: probability,
          windSpeedMax: 15.0,
          weatherCode: 4001,
        );

    const avoidRain = ConditionProfile(
      id: 'cp-1',
      activityId: 'act-1',
      precipEnabled: true,
      precipLevel: PrecipLevel.avoidRain,
    );

    const rainOnly = ConditionProfile(
      id: 'cp-1',
      activityId: 'act-1',
      precipEnabled: true,
      precipLevel: PrecipLevel.rainOnly,
    );

    test('avoid_rain passes on a dry day', () {
      // The shared `day` fixture sits at 10%.
      expect(evaluateDayMatch(avoidRain, day), true);
    });

    test('avoid_rain fails once rain is likely', () {
      expect(evaluateDayMatch(avoidRain, dayWithPrecip(25)), false);
    });

    test('rain_only fails on a dry day', () {
      expect(evaluateDayMatch(rainOnly, day), false);
    });

    test('rain_only passes when rain is likely', () {
      expect(evaluateDayMatch(rainOnly, dayWithPrecip(80)), true);
    });

    test('the two levels are exactly complementary at the boundary', () {
      // 20% is the threshold itself: avoid_rain still passes, rain_only does
      // not. No gap and no overlap.
      final atThreshold = dayWithPrecip(PrecipLevel.dryThreshold.toDouble());
      expect(evaluateDayMatch(avoidRain, atThreshold), true);
      expect(evaluateDayMatch(rainOnly, atThreshold), false);

      final justOver = dayWithPrecip(20.1);
      expect(evaluateDayMatch(avoidRain, justOver), false);
      expect(evaluateDayMatch(rainOnly, justOver), true);
    });

    test('a legacy level reads as avoid_rain rather than no filter at all', () {
      // Rows written before the migration hold 'none' / 'light' / 'any'.
      // 'light' used to match every day, which was the bug.
      const legacy = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: 'light',
      );
      expect(evaluateDayMatch(legacy, dayWithPrecip(80)), false);
    });

    test('a disabled precipitation condition ignores the level', () {
      const disabled = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipLevel: PrecipLevel.rainOnly,
      );
      expect(evaluateDayMatch(disabled, day), true);
    });

    test('wind within limit passes', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 20.0,
      );
      // windSpeedMax 15 <= 20 => passes
      expect(evaluateDayMatch(profile, day), true);
    });

    test('wind exceeds limit fails', () {
      final windyDay = DailyForecast(
        date: DateTime(2026, 6, 27),
        temperatureMax: 28.0,
        temperatureMin: 18.0,
        precipitationProbability: 10.0,
        windSpeedMax: 35.0,
        weatherCode: 1000,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 20.0,
      );
      expect(evaluateDayMatch(profile, windyDay), false);
    });

    test('all conditions met returns true', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 15.0,
        tempMax: 30.0,
        precipEnabled: true,
        precipLevel: PrecipLevel.avoidRain,
        windEnabled: true,
        windMax: 20.0,
      );
      expect(evaluateDayMatch(profile, day), true);
    });
  });
}
