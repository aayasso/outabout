// Reads and writes notification_preferences — the table that has been in the
// schema, and in CLAUDE.md's list of core tables, since the beginning without
// a single call site on either side of the wire.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../models/notification_preference.dart';

class NotificationPreferenceRepository {
  NotificationPreferenceRepository(this._client);

  final SupabaseClient _client;

  /// This activity's row, or a default-valued one when it has none.
  ///
  /// Never null. An activity with no row behaves exactly as one with the
  /// defaults — which is what `effectiveNotifyPrefs` decides server-side too,
  /// so the screen and the scheduler cannot disagree about what an absent row
  /// means.
  Future<NotificationPreference> forActivity(String activityId) async {
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('activity_id', activityId)
        .maybeSingle();

    if (row == null) return NotificationPreference(activityId: activityId);
    return NotificationPreference.fromJson(row);
  }

  /// Creates or updates the row.
  ///
  /// Upsert on activity_id, which the table's unique constraint already
  /// enforces. The first time a user touches any switch this writes the row
  /// that never existed; afterwards it updates in place.
  Future<void> save(NotificationPreference preference) async {
    await _client
        .from('notification_preferences')
        .upsert(preference.toJson(), onConflict: 'activity_id');
  }
}

final notificationPreferenceRepositoryProvider =
    Provider<NotificationPreferenceRepository>((ref) {
  return NotificationPreferenceRepository(ref.watch(supabaseClientProvider));
});

/// One activity's preferences.
///
/// Falls back to the defaults on any read failure rather than surfacing an
/// error state. The screen this feeds is a section inside the activity detail
/// page, and a settings card that renders an error where three switches should
/// be reads as the whole page being broken — when the actual consequence is
/// only that the user sees the defaults, which are also what the server will
/// apply.
final notificationPreferenceProvider =
    FutureProvider.family<NotificationPreference, String>((ref, activityId) async {
  try {
    return await ref
        .watch(notificationPreferenceRepositoryProvider)
        .forActivity(activityId);
  } catch (e) {
    debugPrint('notificationPreferenceProvider: defaulting — $e');
    return NotificationPreference(activityId: activityId);
  }
});
