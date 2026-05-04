import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/condition_profile.dart';
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

  Future<Activity> insertWithConditions({
    required Activity activity,
    required ConditionProfile profile,
  }) async {
    final activityData = await _client
        .from('activities')
        .insert(activity.toJson())
        .select()
        .single();
    final savedActivity = Activity.fromJson(activityData);

    final profileData = await _client
        .from('condition_profiles')
        .insert({
          ...profile.toJson(),
          'activity_id': savedActivity.id,
        })
        .select()
        .single();

    return Activity(
      id: savedActivity.id,
      userId: savedActivity.userId,
      name: savedActivity.name,
      notes: savedActivity.notes,
      categoryIds: savedActivity.categoryIds,
      createdAt: savedActivity.createdAt,
      updatedAt: savedActivity.updatedAt,
      geographicContext: savedActivity.geographicContext,
      conditionProfile:
          ConditionProfile.fromJson(profileData),
    );
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
