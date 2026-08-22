import 'package:flutter/foundation.dart';

/// Tomorrow.io reports wind in metres per second when `units=metric`.
/// OutAbout stores wind in km/h everywhere — the condition sliders, the
/// matcher and the UI all speak km/h — so the conversion happens once, at
/// parse time, in [DailyForecast.fromJson].
const double _metersPerSecondToKmh = 3.6;

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

  /// Returns the first numeric value present among [keys], or null.
  static num? _firstNum(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is num) return value;
    }
    return null;
  }

  /// Reads a numeric field, logging and falling back when none of [keys]
  /// is present. Never casts a nullable lookup directly.
  static num _numOr(
    Map<String, dynamic> values,
    List<String> keys,
    num fallback,
  ) {
    final value = _firstNum(values, keys);
    if (value != null) return value;
    debugPrint(
      'DailyForecast: none of $keys present in forecast values — '
      'defaulting to $fallback.',
    );
    return fallback;
  }

  /// Returns max wind in km/h.
  ///
  /// [toJson] writes the already-converted value under `windSpeedMaxKmh`, so
  /// a cached entry is used as-is. The API's `windSpeedMax` is m/s and gets
  /// converted. A cache written before this distinction existed holds raw
  /// m/s under `windSpeedMax`, so it converts correctly too.
  static double _windKmh(Map<String, dynamic> values) {
    final cached = _firstNum(values, const ['windSpeedMaxKmh']);
    if (cached != null) return cached.toDouble();
    return _numOr(values, const ['windSpeedMax'], 0).toDouble() *
        _metersPerSecondToKmh;
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
      temperatureMax:
          _numOr(values, const ['temperatureMax'], 0).toDouble(),
      temperatureMin:
          _numOr(values, const ['temperatureMin'], 0).toDouble(),
      precipitationProbability: _numOr(
        values,
        const ['precipitationProbabilityMax', 'precipitationProbability'],
        0,
      ).toDouble(),
      windSpeedMax: _windKmh(values),
      // 1000 is Tomorrow.io's "Clear" code — a neutral default that keeps
      // the schedule rendering if the code is ever missing.
      weatherCode:
          _numOr(values, const ['weatherCodeMax', 'weatherCode'], 1000)
              .toInt(),
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
