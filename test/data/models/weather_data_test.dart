import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/weather_data.dart';

void main() {
  group('WeatherData', () {
    test(
      'fromJson parses Tomorrow.io response shape',
      () {
        final json = <String, dynamic>{
          'data': {
            'values': {
              'weatherCode': 1000,
              'temperature': 22.5,
              'windSpeed': 10.3,
              'humidity': 65.0,
              'precipitationIntensity': 0.0,
              'uvIndex': 5.0,
            },
          },
        };

        final weather = WeatherData.fromJson(json);

        expect(weather.weatherCode, 1000);
        expect(weather.temperature, 22.5);
        expect(weather.windSpeed, 10.3);
        expect(weather.humidity, 65.0);
        expect(weather.precipitationIntensity, 0.0);
        expect(weather.uvIndex, 5.0);
      },
    );

    test('fromJson handles integer values as num', () {
      final json = <String, dynamic>{
        'data': {
          'values': {
            'weatherCode': 4001,
            'temperature': 18,
            'windSpeed': 5,
            'humidity': 80,
            'precipitationIntensity': 2,
            'uvIndex': 3,
          },
        },
      };

      final weather = WeatherData.fromJson(json);

      expect(weather.weatherCode, 4001);
      expect(weather.temperature, 18.0);
      expect(weather.windSpeed, 5.0);
      expect(weather.humidity, 80.0);
      expect(weather.precipitationIntensity, 2.0);
      expect(weather.uvIndex, 3.0);
    });
  });
}
