import 'package:outabout/data/models/condition_profile.dart';

class Activity {
  final String? id;
  final String userId;
  final String name;
  final String? notes;
  final String? url;
  final String? location;
  final List<String> categoryIds;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> geographicContext;
  final ConditionProfile? conditionProfile;

  const Activity({
    this.id,
    required this.userId,
    required this.name,
    this.notes,
    this.url,
    this.location,
    this.categoryIds = const [],
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
    this.geographicContext = const {},
    this.conditionProfile,
  });

  /// This activity with the given fields replaced.
  ///
  /// Exists because the alternative — rebuilding an Activity by listing its
  /// fields at the call site — is a list that can be incomplete, and was:
  /// `insertWithConditions` reconstructed the saved activity to attach its
  /// profile and silently dropped url, location and isArchived on the way.
  ///
  /// Nullable fields cannot be *cleared* through this method, since a null
  /// argument is indistinguishable from an omitted one. Nothing needs to clear
  /// them, and the sentinel-object trick that would allow it costs more
  /// clarity than it buys here.
  Activity copyWith({
    String? id,
    String? userId,
    String? name,
    String? notes,
    String? url,
    String? location,
    List<String>? categoryIds,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? geographicContext,
    ConditionProfile? conditionProfile,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      url: url ?? this.url,
      location: location ?? this.location,
      categoryIds: categoryIds ?? this.categoryIds,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      geographicContext: geographicContext ?? this.geographicContext,
      conditionProfile: conditionProfile ?? this.conditionProfile,
    );
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    final rawCategoryIds = json['category_ids'];
    return Activity(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      url: json['url'] as String?,
      location: json['location'] as String?,
      categoryIds: rawCategoryIds is List
          ? rawCategoryIds.cast<String>()
          : const [],
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      geographicContext:
          json['geographic_context'] as Map<String, dynamic>? ??
              const {},
      conditionProfile:
          json['condition_profiles'] is Map<String, dynamic>
              ? ConditionProfile.fromJson(
                  json['condition_profiles']
                      as Map<String, dynamic>,
                )
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        if (notes != null) 'notes': notes,
        if (url != null) 'url': url,
        if (location != null) 'location': location,
        'category_ids': categoryIds,
        'is_archived': isArchived,
        if (createdAt != null)
          'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null)
          'updated_at': updatedAt!.toIso8601String(),
        'geographic_context': geographicContext,
      };
}
