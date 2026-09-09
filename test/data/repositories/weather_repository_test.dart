import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:outabout/data/repositories/weather_repository.dart';

/// Minimal valid realtime response for [WeatherData.fromJson].
String _realtimeBody() => jsonEncode({
      'data': {
        'values': {
          'weatherCode': 1000,
          'temperature': 22,
          'windSpeed': 3,
          'humidity': 40,
          'rainIntensity': 0,
          'sleetIntensity': 0,
          'snowIntensity': 0,
          'freezingRainIntensity': 0,
          'uvIndex': 5,
        },
      },
    });

/// Minimal valid forecast response for
/// [WeatherRepository.fetchForecast].
String _forecastBody() => jsonEncode({
      'timelines': {
        'daily': [
          {
            'time': '2026-09-09T00:00:00Z',
            'values': {
              'temperatureMax': 28,
              'temperatureMin': 18,
              'precipitationProbabilityMax': 10,
              'windSpeedMax': 4,
              'weatherCodeMax': 1000,
            },
          },
        ],
      },
    });

void main() {
  group('WeatherRepository buckets coordinates', () {
    test(
      'fetchCurrent sends bucketed lat/lng',
      () async {
        Uri? captured;
        final client = MockClient((request) async {
          captured = request.url;
          return http.Response(
            _realtimeBody(),
            200,
          );
        });

        final repo = WeatherRepository(
          'test-key',
          httpClient: client,
        );

        // Full-precision values that must be rounded.
        await repo.fetchCurrent(40.748817, -73.985428);

        expect(captured, isNotNull);
        final location =
            captured!.queryParameters['location']!;
        // 40.748817 → 40.75, -73.985428 → -73.99
        expect(location, '40.75,-73.99');
      },
    );

    test(
      'fetchForecast sends bucketed lat/lng',
      () async {
        Uri? captured;
        final client = MockClient((request) async {
          captured = request.url;
          return http.Response(
            _forecastBody(),
            200,
          );
        });

        final repo = WeatherRepository(
          'test-key',
          httpClient: client,
        );

        await repo.fetchForecast(40.748817, -73.985428);

        expect(captured, isNotNull);
        final location =
            captured!.queryParameters['location']!;
        expect(location, '40.75,-73.99');
      },
    );

    test(
      'already-bucketed values pass through unchanged',
      () async {
        Uri? captured;
        final client = MockClient((request) async {
          captured = request.url;
          return http.Response(
            _realtimeBody(),
            200,
          );
        });

        final repo = WeatherRepository(
          'test-key',
          httpClient: client,
        );

        await repo.fetchCurrent(40.75, -73.99);

        final location =
            captured!.queryParameters['location']!;
        expect(location, '40.75,-73.99');
      },
    );
  });
}
