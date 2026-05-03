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
  });

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
