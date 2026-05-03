class WeatherData {
  final int weatherCode;
  final double temperature;
  final double windSpeed;
  final double humidity;
  final double precipitationIntensity;
  final double uvIndex;

  const WeatherData({
    required this.weatherCode,
    required this.temperature,
    required this.windSpeed,
    required this.humidity,
    required this.precipitationIntensity,
    required this.uvIndex,
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
}
