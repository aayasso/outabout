import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

/// Default category definitions used by [CategoryRepository.seedDefaults].
/// Exposed as a constant for testability — tests verify these values
/// match the locked colors in requirements.md.
const defaultCategories = <(String name, String color)>[
  ('Running', '#E55934'),
  ('Hiking', '#43A047'),
  ('Cycling', '#1E88E5'),
  ('Photography', '#8E24AA'),
  ('Beach', '#F4B942'),
  ('Skiing', '#039BE5'),
  ('Camping', '#8D6E63'),
  ('Picnic', '#FB8C00'),
];

class CategoryRepository {
  CategoryRepository(this._client);
  final SupabaseClient _client;

  Future<List<Category>> fetchForUser(String userId) async {
    final data = await _client
        .from('categories')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    return (data as List)
        .map((row) =>
            Category.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Category> insert(Category category) async {
    final data = await _client
        .from('categories')
        .insert(category.toJson())
        .select()
        .single();
    return Category.fromJson(data);
  }

  Future<void> seedDefaults(String userId) async {
    final rows = defaultCategories
        .map((d) => {
              'user_id': userId,
              'name': d.$1,
              'color': d.$2,
            })
        .toList();
    await _client.from('categories').insert(rows);
  }
}
