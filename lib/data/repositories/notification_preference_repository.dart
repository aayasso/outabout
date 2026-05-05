import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_preference.dart';

class NotificationPreferenceRepository {
  NotificationPreferenceRepository(this._client);
  final SupabaseClient _client;

  Future<NotificationPreference?> fetchByActivityId(
    String activityId,
  ) async {
    final data = await _client
        .from('notification_preferences')
        .select()
        .eq('activity_id', activityId)
        .maybeSingle();
    if (data == null) return null;
    return NotificationPreference.fromJson(data);
  }

  Future<void> upsert(NotificationPreference pref) async {
    final json = pref.toJson();
    json.remove('id');
    json.remove('created_at');
    json.remove('updated_at');
    json['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from('notification_preferences')
        .upsert(json, onConflict: 'activity_id');
  }
}
