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

  const ConditionsAtEvent({
    required this.tempC,
    required this.tempF,
    required this.precipitationProbability,
    required this.windKph,
    required this.uvIndex,
    required this.airQualityIndex,
    required this.weatherTheme,
    required this.forecastWindowHours,
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
      };
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
