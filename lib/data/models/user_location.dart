class UserLocation {
  final String? id;
  final String userId;
  final String? city;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  const UserLocation({
    this.id,
    required this.userId,
    this.city,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      UserLocation(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        city: json['city'] as String?,
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
        'latitude': latitude,
        'longitude': longitude,
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
      };
}
