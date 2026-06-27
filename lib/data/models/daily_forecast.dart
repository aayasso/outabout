class DailyForecast {
  final DateTime date;
  final double temperatureMax;
  final double temperatureMin;
  final double precipitationProbability;
  final double windSpeedMax;
  final int weatherCode;

  const DailyForecast({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.precipitationProbability,
    required this.windSpeedMax,
    required this.weatherCode,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>;
    return DailyForecast(
      date: DateTime.parse(json['time'] as String),
      temperatureMax: (values['temperatureMax'] as num).toDouble(),
      temperatureMin: (values['temperatureMin'] as num).toDouble(),
      precipitationProbability: (values['precipitationProbability'] as num)
          .toDouble(),
      windSpeedMax: (values['windSpeedMax'] as num).toDouble(),
      weatherCode: values['weatherCode'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'time': date.toIso8601String(),
    'values': {
      'temperatureMax': temperatureMax,
      'temperatureMin': temperatureMin,
      'precipitationProbability': precipitationProbability,
      'windSpeedMax': windSpeedMax,
      'weatherCode': weatherCode,
    },
  };
}
