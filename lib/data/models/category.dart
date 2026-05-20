class Category {
  final String? id;
  final String userId;
  final String name;
  final String? color;
  final String? icon;
  final DateTime? createdAt;

  const Category({
    this.id,
    required this.userId,
    required this.name,
    this.color,
    this.icon,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        if (createdAt != null)
          'created_at': createdAt!.toIso8601String(),
      };
}
