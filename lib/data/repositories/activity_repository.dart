import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/condition_profile.dart';
import '../models/activity.dart';

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
        .map((row) => Activity.fromJson(row as Map<String, dynamic>))
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

    final profilePayload = {
      'activity_id': savedActivity.id,
      if (profile.tempEnabled) 'temp_enabled': true,
      if (profile.tempMin != null) 'temp_min': profile.tempMin,
      if (profile.tempMax != null) 'temp_max': profile.tempMax,
      if (profile.precipEnabled) 'precip_enabled': true,
      if (profile.precipLevel != null) 'precip_level': profile.precipLevel,
      if (profile.windEnabled) 'wind_enabled': true,
      if (profile.windMax != null) 'wind_max': profile.windMax,
    };

    final profileData = await _client
        .from('condition_profiles')
        .insert(profilePayload)
        .select()
        .single();

    // copyWith, not a fresh constructor call: the previous version listed the
    // fields by hand and omitted url, location and isArchived, so a newly
    // created activity came back missing whatever the user had just typed
    // into those two fields.
    return savedActivity.copyWith(
      conditionProfile: ConditionProfile.fromJson(profileData),
    );
  }

  /// One activity by id, scoped to [userId].
  ///
  /// The owner filter is defence in depth, not decoration. RLS makes a foreign
  /// id return nothing anyway — but this query is reachable from a
  /// notification deep link, `/activity/<uuid>`, where the id is attacker
  /// supplied, and while the app held a key that bypassed RLS it rendered
  /// whatever row that id named regardless of who owned it. A filter here
  /// keeps that closed independently of how the key is configured.
  Future<Activity?> fetchById(String activityId, String userId) async {
    final data = await _client
        .from('activities')
        .select('*, condition_profiles(*)')
        .eq('id', activityId)
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Activity.fromJson(data);
  }

  Future<Activity> updateWithConditions(
    Activity activity,
    ConditionProfile? profile,
  ) async {
    final now = DateTime.now().toIso8601String();

    await _client
        .from('activities')
        .update({
          'name': activity.name,
          'notes': activity.notes,
          'url': activity.url,
          'location': activity.location,
          'category_ids': activity.categoryIds,
          'updated_at': now,
        })
        .eq('id', activity.id!);

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
    } else {
      // Clearing every condition has to delete the row, not skip the write.
      // Without this the old profile survives, `fetchForUser`'s join hands it
      // straight back, and the app keeps matching on constraints the user
      // explicitly cleared — while the edit form repopulates its sliders from
      // them on re-entry. The save reports success either way, so nothing
      // tells the user their change was discarded.
      await _client
          .from('condition_profiles')
          .delete()
          .eq('activity_id', activity.id!);
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
