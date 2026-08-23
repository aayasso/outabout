class ConditionProfile {
  final String id;
  final String activityId;
  final bool tempEnabled;
  final double? tempMin;
  final double? tempMax;
  final bool precipEnabled;
  final String? precipLevel;
  final bool windEnabled;
  final double? windMax;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConditionProfile({
    required this.id,
    required this.activityId,
    this.tempEnabled = false,
    this.tempMin,
    this.tempMax,
    this.precipEnabled = false,
    this.precipLevel,
    this.windEnabled = false,
    this.windMax,
    this.createdAt,
    this.updatedAt,
  });

  factory ConditionProfile.fromJson(Map<String, dynamic> json) =>
      ConditionProfile(
        id: json['id'] as String,
        activityId: json['activity_id'] as String,
        tempEnabled: json['temp_enabled'] as bool? ?? false,
        tempMin: (json['temp_min'] as num?)?.toDouble(),
        tempMax: (json['temp_max'] as num?)?.toDouble(),
        precipEnabled:
            json['precip_enabled'] as bool? ?? false,
        precipLevel: json['precip_level'] as String?,
        windEnabled: json['wind_enabled'] as bool? ?? false,
        windMax: (json['wind_max'] as num?)?.toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity_id': activityId,
        'temp_enabled': tempEnabled,
        if (tempMin != null) 'temp_min': tempMin,
        if (tempMax != null) 'temp_max': tempMax,
        'precip_enabled': precipEnabled,
        if (precipLevel != null) 'precip_level': precipLevel,
        'wind_enabled': windEnabled,
        if (windMax != null) 'wind_max': windMax,
        if (createdAt != null)
          'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
      };
}

/// The two precipitation preferences, stored as text in `precip_level`.
///
/// These live here rather than as bare string literals at each call site
/// because free-form strings are what broke this feature before: the pickers
/// wrote 'none' | 'light' | 'any' while both matchers only recognised
/// 'none' | 'light_ok', so "Light OK" silently applied no filtering at all.
abstract class PrecipLevel {
  /// The day fails when precipitation probability is above [dryThreshold].
  static const String avoidRain = 'avoid_rain';

  /// The day fails when precipitation probability is at or below
  /// [dryThreshold].
  static const String rainOnly = 'rain_only';

  /// Probability (%) at or below which a day counts as dry.
  static const int dryThreshold = 20;

  /// Coerces a stored value to a level the UI can render.
  ///
  /// Rows written before the bidirectional migration hold 'none', 'light' or
  /// 'any'. A SegmentedButton whose selected value matches no segment renders
  /// with nothing selected rather than throwing, so an un-normalised legacy row
  /// would show an empty toggle and quietly round-trip the stale value back on
  /// save. Anything that is not [rainOnly] reads as [avoidRain].
  static String normalize(String? stored) =>
      stored == rainOnly ? rainOnly : avoidRain;
}
