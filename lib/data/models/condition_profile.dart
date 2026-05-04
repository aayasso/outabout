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
  final bool uvEnabled;
  final double? uvMin;
  final double? uvMax;
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
    this.uvEnabled = false,
    this.uvMin,
    this.uvMax,
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
        uvEnabled: json['uv_enabled'] as bool? ?? false,
        uvMin: (json['uv_min'] as num?)?.toDouble(),
        uvMax: (json['uv_max'] as num?)?.toDouble(),
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
        'uv_enabled': uvEnabled,
        if (uvMin != null) 'uv_min': uvMin,
        if (uvMax != null) 'uv_max': uvMax,
        if (createdAt != null)
          'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
      };
}
