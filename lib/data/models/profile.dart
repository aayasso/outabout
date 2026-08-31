class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final bool isPremium;

  /// User-level notification pause.
  ///
  /// The off switch that used to exist only as the OS permission — a control a
  /// user revokes once and effectively never restores, because the app cannot
  /// re-ask. check-weather skips a paused user entirely rather than queuing,
  /// so resuming brings no backlog.
  final bool notificationsPaused;

  final String temperatureUnit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.isPremium = false,
    this.notificationsPaused = false,
    this.temperatureUnit = 'F',
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      Profile(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isPremium: json['is_premium'] as bool? ?? false,
        notificationsPaused:
            json['notifications_paused'] as bool? ?? false,
        temperatureUnit:
            json['temperature_unit'] as String? ?? 'F',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'is_premium': isPremium,
        'notifications_paused': notificationsPaused,
        'temperature_unit': temperatureUnit,
        if (createdAt != null)
          'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
      };
}
