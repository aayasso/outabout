import 'json_number.dart';

class DailyForecast {
  final DateTime date;
  final double temperatureMax;
  final double temperatureMin;
  final double precipitationProbability;

  /// Maximum wind speed in **km/h** (converted from the API's m/s).
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

  static const _label = 'DailyForecast';

  /// Returns max wind in km/h.
  ///
  /// [toJson] writes the already-converted value under `windSpeedMaxKmh`, so
  /// a cached entry is used as-is. The API's `windSpeedMax` is m/s and gets
  /// converted. A cache written before this distinction existed holds raw
  /// m/s under `windSpeedMax`, so it converts correctly too.
  static double _windKmh(Map<String, dynamic> values) {
    final cached = firstNum(values, const ['windSpeedMaxKmh']);
    if (cached != null) return cached.toDouble();
    return numOr(values, const ['windSpeedMax'], 0, label: _label).toDouble() *
        metersPerSecondToKmh;
  }

  /// Parses one entry of Tomorrow.io's `timelines.daily` array.
  ///
  /// The daily timestep reports aggregates rather than bare field names —
  /// `precipitationProbabilityMax` and `weatherCodeMax` instead of
  /// `precipitationProbability` and `weatherCode`. The bare spellings are
  /// still accepted as a fallback because [toJson] writes them into the
  /// local cache, which this same factory reads back.
  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>;
    return DailyForecast(
      date: DateTime.parse(json['time'] as String),
      temperatureMax: numOr(
        values,
        const ['temperatureMax'],
        0,
        label: _label,
      ).toDouble(),
      temperatureMin: numOr(
        values,
        const ['temperatureMin'],
        0,
        label: _label,
      ).toDouble(),
      precipitationProbability: numOr(
        values,
        const ['precipitationProbabilityMax', 'precipitationProbability'],
        0,
        label: _label,
      ).toDouble(),
      windSpeedMax: _windKmh(values),
      // 1000 is Tomorrow.io's "Clear" code — a neutral default that keeps
      // the schedule rendering if the code is ever missing.
      weatherCode: numOr(
        values,
        const ['weatherCodeMax', 'weatherCode'],
        1000,
        label: _label,
      ).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'time': date.toIso8601String(),
    'values': {
      'temperatureMax': temperatureMax,
      'temperatureMin': temperatureMin,
      'precipitationProbability': precipitationProbability,
      'windSpeedMaxKmh': windSpeedMax,
      'weatherCode': weatherCode,
    },
  };
}

/// A forecast together with where it came from.
///
/// The cache is served on any fetch failure, and without this the UI cannot
/// tell a live forecast from one saved days ago — which is how a Monday
/// forecast came to be captioned "Today" on a Wednesday.
class ForecastSnapshot {
  const ForecastSnapshot({required this.days, this.servedFromCacheAt});

  final List<DailyForecast> days;

  /// When the served data was originally fetched, if it came from the cache.
  /// Null means it was fetched live just now.
  final DateTime? servedFromCacheAt;

  bool get isFromCache => servedFromCacheAt != null;
}
