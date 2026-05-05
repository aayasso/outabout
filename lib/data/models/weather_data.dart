class WeatherData {
  final int weatherCode;
  final double temperature;
  final double windSpeed;
  final double humidity;
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

  /// Parses from the full Tomorrow.io realtime response:
  /// `{ "data": { "values": { ... } } }`
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final values =
        (json['data'] as Map<String, dynamic>)['values']
            as Map<String, dynamic>;
    return WeatherData(
      weatherCode: values['weatherCode'] as int,
      temperature: (values['temperature'] as num).toDouble(),
      windSpeed: (values['windSpeed'] as num).toDouble(),
      humidity: (values['humidity'] as num).toDouble(),
      precipitationIntensity:
          (values['precipitationIntensity'] as num)
              .toDouble(),
      uvIndex: (values['uvIndex'] as num).toDouble(),
    );
  }

  /// Parses from flat cache JSON stored in SharedPreferences.
  factory WeatherData.fromCacheJson(
    Map<String, dynamic> json,
    DateTime fetchedAt,
  ) {
    return WeatherData(
      weatherCode: json['weatherCode'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      precipitationIntensity:
          (json['precipitationIntensity'] as num).toDouble(),
      uvIndex: (json['uvIndex'] as num).toDouble(),
      fetchedAt: fetchedAt,
    );
  }

  /// Serializes to flat JSON for cache storage.
  Map<String, dynamic> toJson() => {
        'weatherCode': weatherCode,
        'temperature': temperature,
        'windSpeed': windSpeed,
        'humidity': humidity,
        'precipitationIntensity': precipitationIntensity,
        'uvIndex': uvIndex,
      };
}
