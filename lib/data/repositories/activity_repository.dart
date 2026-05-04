import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  Future<List<Activity>> fetchForUser(String userId) async {
    final data = await _client
        .from('activities')
        .select('*, condition_profiles(*)')
        .eq('user_id', userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) =>
            Activity.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Activity> insert(Activity activity) async {
    final data = await _client
        .from('activities')
        .insert(activity.toJson())
        .select('*, condition_profiles(*)')
        .single();
    return Activity.fromJson(data);
  }

  Future<void> archive(String activityId) async {
    await _client
        .from('activities')
        .update({
          'is_archived': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', activityId);
  }
}
