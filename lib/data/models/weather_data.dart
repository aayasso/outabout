import 'json_number.dart';

class WeatherData {
  final int weatherCode;
  final double temperature;
  /// Wind speed in **km/h** (converted from the API's m/s), matching
  /// [DailyForecast.windSpeedMax].
  final double windSpeed;
  final double humidity;

  /// Combined precipitation intensity in mm/hr.
  ///
  /// The realtime endpoint has no `precipitationIntensity` field — it
  /// reports rain, sleet, snow and freezing rain separately — so this is the
  /// strongest of those.
  final double precipitationIntensity;
  final double uvIndex;
  final DateTime? fetchedAt;

  const WeatherData({
    required this.weatherCode,
    required this.temperature,
    required this.windSpeed,
    required this.humidity,
    required this.precipitationIntensity,
    required this.uvIndex,
    this.fetchedAt,
  });

  static const _label = 'WeatherData';

  /// The realtime endpoint splits precipitation by type. Verified against a
  /// live response: it returns rainIntensity, sleetIntensity, snowIntensity
  /// and freezingRainIntensity, and no bare precipitationIntensity — casting
  /// that missing key is what threw
  /// "type 'Null' is not a subtype of type 'num'" and left the
  /// weather-adaptive theme stuck on its default.
  static double _precipitationIntensity(Map<String, dynamic> values) {
    // A cached payload already holds the combined value.
    final cached = firstNum(values, const ['precipitationIntensity']);
    if (cached != null) return cached.toDouble();

    final byType = const [
      'rainIntensity',
      'sleetIntensity',
      'snowIntensity',
      'freezingRainIntensity',
    ].map((key) => firstNum(values, [key])?.toDouble() ?? 0.0);

    return byType.reduce((a, b) => a > b ? a : b);
  }

  /// Parses from the full Tomorrow.io realtime response:
  /// `{ "data": { "values": { ... } } }`
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final values =
        (json['data'] as Map<String, dynamic>)['values']
            as Map<String, dynamic>;
    return WeatherData(
      // 1000 is Tomorrow.io's "Clear" code — a neutral default.
      weatherCode: numOr(values, const ['weatherCode'], 1000, label: _label)
          .toInt(),
      temperature:
          numOr(values, const ['temperature'], 0, label: _label).toDouble(),
      windSpeed: numOr(values, const ['windSpeed'], 0, label: _label)
              .toDouble() *
          metersPerSecondToKmh,
      humidity: numOr(values, const ['humidity'], 0, label: _label).toDouble(),
      precipitationIntensity: _precipitationIntensity(values),
      uvIndex: numOr(values, const ['uvIndex'], 0, label: _label).toDouble(),
    );
  }

  /// Parses from flat cache JSON stored in SharedPreferences.
  ///
  /// [toJson] writes wind already converted under `windSpeedKmh`; a cache
  /// written before that split holds raw m/s under `windSpeed` and converts
  /// correctly on read.
  factory WeatherData.fromCacheJson(
    Map<String, dynamic> json,
    DateTime fetchedAt,
  ) {
    final cachedWind = firstNum(json, const ['windSpeedKmh']);
    return WeatherData(
      weatherCode:
          numOr(json, const ['weatherCode'], 1000, label: _label).toInt(),
      temperature:
          numOr(json, const ['temperature'], 0, label: _label).toDouble(),
      windSpeed: cachedWind?.toDouble() ??
          numOr(json, const ['windSpeed'], 0, label: _label).toDouble() *
              metersPerSecondToKmh,
      humidity: numOr(json, const ['humidity'], 0, label: _label).toDouble(),
      precipitationIntensity:
          numOr(json, const ['precipitationIntensity'], 0, label: _label)
              .toDouble(),
      uvIndex: numOr(json, const ['uvIndex'], 0, label: _label).toDouble(),
      fetchedAt: fetchedAt,
    );
  }

  /// Serializes to flat JSON for cache storage.
  Map<String, dynamic> toJson() => {
        'weatherCode': weatherCode,
        'temperature': temperature,
        'windSpeedKmh': windSpeed,
        'humidity': humidity,
        'precipitationIntensity': precipitationIntensity,
        'uvIndex': uvIndex,
      };
}
