import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity.dart';
import '../models/condition_profile.dart';

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

  Future<Activity?> fetchById(String activityId) async {
    final data = await _client
        .from('activities')
        .select('*, condition_profiles(*)')
        .eq('id', activityId)
        .maybeSingle();
    if (data == null) return null;
    return Activity.fromJson(data);
  }

  Future<Activity> updateWithConditions(
    Activity activity,
    ConditionProfile? profile,
  ) async {
    final now = DateTime.now().toIso8601String();

    await _client.from('activities').update({
      'name': activity.name,
      'notes': activity.notes,
      'url': activity.url,
      'location': activity.location,
      'category_ids': activity.categoryIds,
      'updated_at': now,
    }).eq('id', activity.id!);

    if (profile != null) {
      final profileJson = profile.toJson();
      profileJson.remove('id');
      profileJson.remove('created_at');
      profileJson.remove('updated_at');
      profileJson['activity_id'] = activity.id;
      profileJson['updated_at'] = now;

      await _client
          .from('condition_profiles')
          .upsert(profileJson, onConflict: 'activity_id');
    }

    final data = await _client
        .from('activities')
        .select('*, condition_profiles(*)')
        .eq('id', activity.id!)
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
