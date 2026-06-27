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

    test('precip none passes when probability <= 20', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: 'none',
      );
      // precipitationProbability is 10 => passes
      expect(evaluateDayMatch(profile, day), true);
    });

    test('precip none fails when probability > 20', () {
      final rainyDay = DailyForecast(
        date: DateTime(2026, 6, 27),
        temperatureMax: 28.0,
        temperatureMin: 18.0,
        precipitationProbability: 25.0,
        windSpeedMax: 15.0,
        weatherCode: 4001,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: 'none',
      );
      expect(evaluateDayMatch(profile, rainyDay), false);
    });

    test('precip light_ok passes when probability <= 60', () {
      final day55 = DailyForecast(
        date: DateTime(2026, 6, 27),
        temperatureMax: 28.0,
        temperatureMin: 18.0,
        precipitationProbability: 55.0,
        windSpeedMax: 15.0,
        weatherCode: 4001,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: 'light_ok',
      );
      expect(evaluateDayMatch(profile, day55), true);
    });

    test('precip light_ok fails when probability > 60', () {
      final day65 = DailyForecast(
        date: DateTime(2026, 6, 27),
        temperatureMax: 28.0,
        temperatureMin: 18.0,
        precipitationProbability: 65.0,
        windSpeedMax: 15.0,
        weatherCode: 4001,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: 'light_ok',
      );
      expect(evaluateDayMatch(profile, day65), false);
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
        precipLevel: 'none',
        windEnabled: true,
        windMax: 20.0,
      );
      expect(evaluateDayMatch(profile, day), true);
    });
  });
}
