import 'daily_forecast.dart';
import 'weather_data.dart';

// ---------------------------------------------------------------------------
// BehavioralEvent model with 4 jsonb context classes
// ---------------------------------------------------------------------------

/// Coordinate bucketing helper — reduces precision to ~1 mile radius.
double bucket(double coord) => (coord * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// ConditionsAtEvent
// ---------------------------------------------------------------------------

class ConditionsAtEvent {
  final double tempC;
  final double tempF;
  final int precipitationProbability;
  final double windKph;
  final int uvIndex;
  final int airQualityIndex;
  final String weatherTheme;
  final int forecastWindowHours;

  /// The four fields below mirror `buildConditionsSnapshot` in
  /// `supabase/functions/check-weather/index.ts`, which writes rows into the
  /// same table from the server. They are nullable and omitted from
  /// [toJson] when absent, so a client row written without live weather is
  /// still exactly the original eight keys — the two shapes coexist in the
  /// table rather than a third one being invented.
  final int? weatherCode;
  final double? tempMaxC;
  final double? tempMinC;
  final DateTime? forecastDate;

  const ConditionsAtEvent({
    required this.tempC,
    required this.tempF,
    required this.precipitationProbability,
    required this.windKph,
    required this.uvIndex,
    required this.airQualityIndex,
    required this.weatherTheme,
    required this.forecastWindowHours,
    this.weatherCode,
    this.tempMaxC,
    this.tempMinC,
    this.forecastDate,
  });

  Map<String, dynamic> toJson() => {
        'temp_c': tempC,
        'temp_f': tempF,
        'precipitation_probability': precipitationProbability,
        'wind_kph': windKph,
        'uv_index': uvIndex,
        'air_quality_index': airQualityIndex,
        'weather_theme': weatherTheme,
        'forecast_window_hours': forecastWindowHours,
        if (weatherCode != null) 'weather_code': weatherCode,
        if (tempMaxC != null) 'temp_max_c': tempMaxC,
        if (tempMinC != null) 'temp_min_c': tempMinC,
        if (forecastDate != null)
          'forecast_date': forecastDate!.toIso8601String(),
      };
}

/// Celsius to Fahrenheit, kept here so the snapshot is self-contained.
double _toFahrenheit(double celsius) => celsius * 9 / 5 + 32;

/// Builds a real weather snapshot for a behavioral event.
///
/// Every client-logged event before this existed carried a snapshot of
/// hardcoded zeros, which made the dataset's weather dimension worthless for
/// anything logged from the app. [current] supplies live conditions and
/// [forecastDay] the day being acted on; either may be absent, in which case
/// the other fills in and the remaining fields fall back to zero rather than
/// inventing a value.
///
/// Pure by design — no Riverpod, no I/O — so it is directly testable and so
/// `services/` never has to reach into `features/` for weather.
ConditionsAtEvent buildConditionsSnapshot({
  required String weatherTheme,
  WeatherData? current,
  DailyForecast? forecastDay,
  int forecastWindowHours = 0,
}) {
  // Prefer live conditions for "right now" fields; fall back to the day's
  // midpoint, which is the best available estimate when only a forecast is on
  // hand.
  final double tempC = current?.temperature ??
      (forecastDay != null
          ? (forecastDay.temperatureMax + forecastDay.temperatureMin) / 2
          : 0.0);

  return ConditionsAtEvent(
    tempC: tempC,
    tempF: _toFahrenheit(tempC),
    precipitationProbability:
        forecastDay?.precipitationProbability.round() ?? 0,
    windKph: current?.windSpeed ?? forecastDay?.windSpeedMax ?? 0.0,
    uvIndex: current?.uvIndex.round() ?? 0,
    // Tomorrow.io's air quality lives behind a separate endpoint this app has
    // never called, so there is nothing to report. Zero here means "not
    // collected", the same as it has always meant on this field.
    airQualityIndex: 0,
    weatherTheme: weatherTheme,
    forecastWindowHours: forecastWindowHours,
    weatherCode: forecastDay?.weatherCode ?? current?.weatherCode,
    tempMaxC: forecastDay?.temperatureMax,
    tempMinC: forecastDay?.temperatureMin,
    forecastDate: forecastDay?.date,
  );
}

// ---------------------------------------------------------------------------
// GeographicContext
// ---------------------------------------------------------------------------

class GeographicContext {
  final String metro;
  final String city;
  final String state;
  final String country;
  final double latBucketed;
  final double lngBucketed;
  final String timezone;

  const GeographicContext({
    required this.metro,
    required this.city,
    required this.state,
    required this.country,
    required this.latBucketed,
    required this.lngBucketed,
    required this.timezone,
  });

  Map<String, dynamic> toJson() => {
        'metro': metro,
        'city': city,
        'state': state,
        'country': country,
        'lat_bucketed': latBucketed,
        'lng_bucketed': lngBucketed,
        'timezone': timezone,
      };
}

// ---------------------------------------------------------------------------
// TemporalContext
// ---------------------------------------------------------------------------

class TemporalContext {
  final int hourOfDay;
  final int dayOfWeek;
  final int weekOfMonth;
  final int monthOfYear;
  final String season;
  final int weekOfSeason;
  final int daysSinceLastMatch;
  final int daysSinceActivityCreated;
  final int consecutiveMatchCount;

  const TemporalContext({
    required this.hourOfDay,
    required this.dayOfWeek,
    required this.weekOfMonth,
    required this.monthOfYear,
    required this.season,
    required this.weekOfSeason,
    required this.daysSinceLastMatch,
    required this.daysSinceActivityCreated,
    required this.consecutiveMatchCount,
  });

  Map<String, dynamic> toJson() => {
        'hour_of_day': hourOfDay,
        'day_of_week': dayOfWeek,
        'week_of_month': weekOfMonth,
        'month_of_year': monthOfYear,
        'season': season,
        'week_of_season': weekOfSeason,
        'days_since_last_match': daysSinceLastMatch,
        'days_since_activity_created': daysSinceActivityCreated,
        'consecutive_match_count': consecutiveMatchCount,
      };
}

// ---------------------------------------------------------------------------
// SessionContext
// ---------------------------------------------------------------------------

class SessionContext {
  final String platform;
  final String appVersion;
  final String activeTheme;

  const SessionContext({
    required this.platform,
    required this.appVersion,
    required this.activeTheme,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'app_version': appVersion,
        'active_theme': activeTheme,
      };
}

// ---------------------------------------------------------------------------
// BehavioralEvent
// ---------------------------------------------------------------------------

class BehavioralEvent {
  final String eventType;
  final String userId;
  final DateTime createdAt;
  final ConditionsAtEvent conditionsAtEvent;
  final GeographicContext geographicContext;
  final TemporalContext temporalContext;
  final SessionContext sessionContext;

  const BehavioralEvent({
    required this.eventType,
    required this.userId,
    required this.createdAt,
    required this.conditionsAtEvent,
    required this.geographicContext,
    required this.temporalContext,
    required this.sessionContext,
  });
}
