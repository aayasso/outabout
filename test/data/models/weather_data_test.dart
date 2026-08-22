import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/weather_data.dart';

void main() {
  group('WeatherData.fromJson', () {
    /// The field set verified against a live /v4/weather/realtime response:
    /// precipitation is split by type, with no bare precipitationIntensity.
    Map<String, dynamic> realtime(Map<String, dynamic> values) => {
          'data': {'values': values},
        };

    test('parses the realtime shape and combines precipitation by type', () {
      final weather = WeatherData.fromJson(realtime({
        'weatherCode': 1000,
        'temperature': 22.88,
        'windSpeed': 3.5, // m/s
        'humidity': 59,
        'rainIntensity': 0.4,
        'sleetIntensity': 0,
        'snowIntensity': 0,
        'freezingRainIntensity': 0,
        'uvIndex': 3,
      }));

      expect(weather.weatherCode, 1000);
      expect(weather.temperature, 22.88);
      // 3.5 m/s becomes 12.6 km/h in storage.
      expect(weather.windSpeed, closeTo(12.6, 0.001));
      expect(weather.humidity, 59.0);
      expect(weather.precipitationIntensity, 0.4);
      expect(weather.uvIndex, 3.0);
    });

    test('takes the strongest precipitation type', () {
      final weather = WeatherData.fromJson(realtime({
        'weatherCode': 5000,
        'temperature': -2,
        'windSpeed': 1,
        'humidity': 90,
        'rainIntensity': 0.1,
        'sleetIntensity': 0.9,
        'snowIntensity': 2.4,
        'freezingRainIntensity': 0.3,
        'uvIndex': 0,
      }));

      expect(weather.precipitationIntensity, 2.4);
    });

    test('does not throw when precipitation fields are absent', () {
      // Regression: casting the missing precipitationIntensity key threw
      // "type 'Null' is not a subtype of type 'num'", which took down
      // weatherDataProvider and left the theme stuck on its default.
      final weather = WeatherData.fromJson(realtime({
        'weatherCode': 1001,
        'temperature': 15,
        'windSpeed': 2,
        'humidity': 70,
        'uvIndex': 1,
      }));

      expect(weather.precipitationIntensity, 0.0);
      expect(weather.weatherCode, 1001);
    });

    test('falls back rather than throwing on a wholly unexpected shape', () {
      final weather = WeatherData.fromJson(realtime({}));

      expect(weather.weatherCode, 1000); // "Clear"
      expect(weather.temperature, 0.0);
      expect(weather.windSpeed, 0.0);
      expect(weather.uvIndex, 0.0);
    });

    test('accepts integer values as num', () {
      final weather = WeatherData.fromJson(realtime({
        'weatherCode': 4001,
        'temperature': 18,
        'windSpeed': 5,
        'humidity': 80,
        'rainIntensity': 2,
        'uvIndex': 3,
      }));

      expect(weather.temperature, 18.0);
      expect(weather.windSpeed, closeTo(18.0, 0.001));
      expect(weather.precipitationIntensity, 2.0);
    });
  });

  group('WeatherData cache round-trip', () {
    final fetchedAt = DateTime.parse('2026-08-22T18:00:00Z');

    test('does not re-convert wind when reading its own cache', () {
      const original = WeatherData(
        weatherCode: 1000,
        temperature: 22.0,
        windSpeed: 12.6, // already km/h
        humidity: 59,
        precipitationIntensity: 0.4,
        uvIndex: 3,
      );

      var restored =
          WeatherData.fromCacheJson(original.toJson(), fetchedAt);
      expect(restored.windSpeed, closeTo(12.6, 0.001));

      // Stable across repeated round-trips.
      restored = WeatherData.fromCacheJson(restored.toJson(), fetchedAt);
      expect(restored.windSpeed, closeTo(12.6, 0.001));
      expect(restored.precipitationIntensity, 0.4);
      expect(restored.fetchedAt, fetchedAt);
    });

    test('converts a legacy cache that stored raw m/s', () {
      final legacy = <String, dynamic>{
        'weatherCode': 1000,
        'temperature': 22.0,
        'windSpeed': 3.5,
        'humidity': 59,
        'precipitationIntensity': 0.0,
        'uvIndex': 3,
      };

      expect(
        WeatherData.fromCacheJson(legacy, fetchedAt).windSpeed,
        closeTo(12.6, 0.001),
      );
    });
  });
}
