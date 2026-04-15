class Activity {
  final String? id;
  final String userId;
  final String name;
  final String category;
  final DateTime createdAt;

  const Activity({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'created_at': createdAt.toIso8601String(),
      };

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
