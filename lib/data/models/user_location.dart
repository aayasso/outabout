class UserLocation {
  final String? id;
  final String userId;
  final String? city;
  final double latitude;
  final double longitude;

  /// The device's IANA timezone identifier, e.g. `America/New_York`.
  ///
  /// Stored because the server needs it and cannot derive it. check-weather
  /// schedules every nudge in local wall-clock time — "07:00" has to mean the
  /// user's 07:00 — and the edge function has only this row to go on. Without
  /// it the scheduler falls back to estimating the zone from longitude, which
  /// is blind to political boundaries and to DST.
  ///
  /// Empty when the platform lookup failed; see [deviceTimezoneProvider],
  /// which returns an empty string rather than throwing for the same reason.
  final String? timezone;

  final DateTime? updatedAt;

  const UserLocation({
    this.id,
    required this.userId,
    this.city,
    required this.latitude,
    required this.longitude,
    this.timezone,
    this.updatedAt,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      UserLocation(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        city: json['city'] as String?,
        timezone: json['timezone'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        if (city != null) 'city': city,
        // Omitted rather than sent as null when unknown, so an upsert from a
        // device whose timezone lookup failed cannot erase a good value an
        // earlier session already stored.
        if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
      };
}
