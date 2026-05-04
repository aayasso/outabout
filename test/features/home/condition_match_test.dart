import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';

void main() {
  const weather = WeatherData(
    weatherCode: 1000,
    temperature: 22.0,
    windSpeed: 10.0,
    humidity: 50.0,
    precipitationIntensity: 0.0,
    uvIndex: 5.0,
  );

  group('evaluateMatch', () {
    test(
      'null profile (no conditions) returns true',
      () {
        expect(evaluateMatch(null, weather), true);
      },
    );

    test(
      'all conditions disabled returns true',
      () {
        const profile = ConditionProfile(
          id: 'cp-1',
          activityId: 'act-1',
          tempEnabled: false,
          precipEnabled: false,
          windEnabled: false,
          uvEnabled: false,
        );
        expect(evaluateMatch(profile, weather), true);
      },
    );

    test('temp too low returns false', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 25.0,
        tempMax: 35.0,
      );
      expect(evaluateMatch(profile, weather), false);
    });

    test('temp too high returns false', () {
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 10.0,
        tempMax: 20.0,
      );
      expect(evaluateMatch(profile, weather), false);
    });

    test(
      'precip enabled with none + rain returns false',
      () {
        const rainyWeather = WeatherData(
          weatherCode: 4001,
          temperature: 22.0,
          windSpeed: 10.0,
          humidity: 80.0,
          precipitationIntensity: 2.5,
          uvIndex: 1.0,
        );
        const profile = ConditionProfile(
          id: 'cp-1',
          activityId: 'act-1',
          precipEnabled: true,
          precipLevel: 'none',
        );
        expect(
          evaluateMatch(profile, rainyWeather),
          false,
        );
      },
    );

    test('wind too high returns false', () {
      const windyWeather = WeatherData(
        weatherCode: 1000,
        temperature: 22.0,
        windSpeed: 30.0,
        humidity: 50.0,
        precipitationIntensity: 0.0,
        uvIndex: 5.0,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 20.0,
      );
      expect(
        evaluateMatch(profile, windyWeather),
        false,
      );
    });

    test('uv too low returns false', () {
      const lowUvWeather = WeatherData(
        weatherCode: 1000,
        temperature: 22.0,
        windSpeed: 10.0,
        humidity: 50.0,
        precipitationIntensity: 0.0,
        uvIndex: 1.0,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        uvEnabled: true,
        uvMin: 3.0,
        uvMax: 8.0,
      );
      expect(
        evaluateMatch(profile, lowUvWeather),
        false,
      );
    });

    test('uv too high returns false', () {
      const highUvWeather = WeatherData(
        weatherCode: 1000,
        temperature: 22.0,
        windSpeed: 10.0,
        humidity: 50.0,
        precipitationIntensity: 0.0,
        uvIndex: 10.0,
      );
      const profile = ConditionProfile(
        id: 'cp-1',
        activityId: 'act-1',
        uvEnabled: true,
        uvMin: 3.0,
        uvMax: 8.0,
      );
      expect(
        evaluateMatch(profile, highUvWeather),
        false,
      );
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
        uvEnabled: true,
        uvMin: 3.0,
        uvMax: 8.0,
      );
      expect(evaluateMatch(profile, weather), true);
    });
  });
}
