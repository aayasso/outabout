import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/daily_forecast.dart';
import '../models/weather_data.dart';

/// Strips any `apikey=...` query parameter from an error string so the
/// Tomorrow.io credential never reaches logs.
///
/// [WeatherFetchException] carries only a status code and body, but a
/// network-layer failure throws `http.ClientException`, whose `toString()`
/// embeds the full request URI — including the key.
String redactApiKey(Object error) => error.toString().replaceAll(
      RegExp(r'apikey=[^&\s)]*'),
      'apikey=<redacted>',
    );

class WeatherFetchException implements Exception {
  final int statusCode;
  final String body;

  const WeatherFetchException(this.statusCode, this.body);

  @override
  String toString() => 'WeatherFetchException($statusCode): $body';
}

class WeatherRepository {
  WeatherRepository(this._apiKey);
  final String _apiKey;

  Future<WeatherData> fetchCurrent(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.tomorrow.io/v4/weather/realtime'
      '?location=$lat,$lng'
      '&fields=weatherCode,temperature,windSpeed,humidity,'
      'precipitationIntensity,precipitationProbability,uvIndex'
      '&units=metric'
      '&apikey=$_apiKey',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw WeatherFetchException(response.statusCode, response.body);
    }
    return WeatherData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DailyForecast>> fetchForecast(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.tomorrow.io/v4/weather/forecast'
      '?timesteps=1d'
      '&fields=temperatureMax,temperatureMin,'
      'precipitationProbabilityMax,windSpeedMax,weatherCodeMax'
      '&units=metric'
      '&apikey=$_apiKey'
      '&location=$lat,$lng',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw WeatherFetchException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final timelines = json['timelines'] as Map<String, dynamic>;
    final daily = timelines['daily'] as List<dynamic>;
    return daily
        .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
