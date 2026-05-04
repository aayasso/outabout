import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_data.dart';

class WeatherFetchException implements Exception {
  final int statusCode;
  final String body;

  const WeatherFetchException(this.statusCode, this.body);

  @override
  String toString() =>
      'WeatherFetchException($statusCode): $body';
}

class WeatherRepository {
  WeatherRepository(this._apiKey);
  final String _apiKey;

  Future<WeatherData> fetchCurrent(
    double lat,
    double lng,
  ) async {
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
      throw WeatherFetchException(
        response.statusCode,
        response.body,
      );
    }
    return WeatherData.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
