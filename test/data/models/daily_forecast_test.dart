import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/daily_forecast.dart';

void main() {
  group('DailyForecast.fromJson', () {
    test('parses the Tomorrow.io daily shape (aggregate field names)', () {
      // The 1d timestep returns precipitationProbabilityMax / weatherCodeMax
      // rather than the bare field names.
      final json = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': {
          'temperatureMax': 21.61,
          'temperatureMin': 14.94,
          'precipitationProbabilityMax': 25,
          'windSpeedMax': 4.4,
          'weatherCodeMax': 1101,
        },
      };

      final forecast = DailyForecast.fromJson(json);

      expect(forecast.date, DateTime.parse('2026-08-22T13:00:00Z'));
      expect(forecast.temperatureMax, 21.61);
      expect(forecast.temperatureMin, 14.94);
      expect(forecast.precipitationProbability, 25.0);
      // 4.4 m/s from the API becomes 15.84 km/h in storage.
      expect(forecast.windSpeedMax, closeTo(15.84, 0.001));
      expect(forecast.weatherCode, 1101);
    });

    test('round-trips through toJson (the local cache shape)', () {
      final original = DailyForecast(
        date: DateTime.parse('2026-08-22T13:00:00Z'),
        temperatureMax: 21.61,
        temperatureMin: 14.94,
        precipitationProbability: 25.0,
        windSpeedMax: 4.4,
        weatherCode: 1101,
      );

      final restored = DailyForecast.fromJson(original.toJson());

      expect(restored.date, original.date);
      expect(restored.temperatureMax, original.temperatureMax);
      expect(restored.temperatureMin, original.temperatureMin);
      expect(
        restored.precipitationProbability,
        original.precipitationProbability,
      );
      expect(restored.windSpeedMax, original.windSpeedMax);
      expect(restored.weatherCode, original.weatherCode);
    });

    test('accepts integer values as num', () {
      final json = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': {
          'temperatureMax': 22,
          'temperatureMin': 15,
          'precipitationProbabilityMax': 0,
          'windSpeedMax': 5,
          'weatherCodeMax': 1000,
        },
      };

      final forecast = DailyForecast.fromJson(json);

      expect(forecast.temperatureMax, 22.0);
      expect(forecast.temperatureMin, 15.0);
      expect(forecast.precipitationProbability, 0.0);
      expect(forecast.windSpeedMax, closeTo(18.0, 0.001));
      expect(forecast.weatherCode, 1000);
    });

    test('falls back instead of throwing when fields are absent', () {
      // Previously a bare `as num` cast on a missing key threw a TypeError
      // and took down the whole schedule.
      final json = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': <String, dynamic>{'temperatureMax': 20.0},
      };

      final forecast = DailyForecast.fromJson(json);

      expect(forecast.temperatureMax, 20.0);
      expect(forecast.temperatureMin, 0.0);
      expect(forecast.precipitationProbability, 0.0);
      expect(forecast.windSpeedMax, 0.0);
      expect(forecast.weatherCode, 1000); // Tomorrow.io "Clear"
    });

    test('converts the API m/s wind into stored km/h', () {
      final json = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': {
          'temperatureMax': 20.0,
          'temperatureMin': 12.0,
          'precipitationProbabilityMax': 0,
          'windSpeedMax': 10.0, // m/s
          'weatherCodeMax': 1000,
        },
      };

      expect(DailyForecast.fromJson(json).windSpeedMax, closeTo(36.0, 0.001));
    });

    test('does not re-convert wind when reading its own cache', () {
      // toJson writes km/h under windSpeedMaxKmh; a naive round-trip that
      // reused the API key name would multiply by 3.6 on every read.
      final original = DailyForecast(
        date: DateTime.parse('2026-08-22T13:00:00Z'),
        temperatureMax: 20.0,
        temperatureMin: 12.0,
        precipitationProbability: 0.0,
        windSpeedMax: 36.0, // already km/h
        weatherCode: 1000,
      );

      var restored = DailyForecast.fromJson(original.toJson());
      expect(restored.windSpeedMax, closeTo(36.0, 0.001));

      // Stable across repeated cache round-trips.
      restored = DailyForecast.fromJson(restored.toJson());
      expect(restored.windSpeedMax, closeTo(36.0, 0.001));
    });

    test('converts a legacy cache that stored raw m/s', () {
      // Caches written before the km/h split hold m/s under windSpeedMax.
      final legacy = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': {
          'temperatureMax': 20.0,
          'temperatureMin': 12.0,
          'precipitationProbability': 0.0,
          'windSpeedMax': 4.4,
          'weatherCode': 1000,
        },
      };

      expect(
        DailyForecast.fromJson(legacy).windSpeedMax,
        closeTo(15.84, 0.001),
      );
    });

    test('ignores non-numeric values and falls back', () {
      final json = <String, dynamic>{
        'time': '2026-08-22T13:00:00Z',
        'values': <String, dynamic>{
          'temperatureMax': 20.0,
          'temperatureMin': 12.0,
          'precipitationProbabilityMax': null,
          'windSpeedMax': 3.0,
          'weatherCodeMax': null,
        },
      };

      final forecast = DailyForecast.fromJson(json);

      expect(forecast.precipitationProbability, 0.0);
      expect(forecast.weatherCode, 1000);
    });
  });
}
