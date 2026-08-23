import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_day_outcome.dart';

/// Reads and writes the user's per-day activity history.
class ActivityDayOutcomeRepository {
  ActivityDayOutcomeRepository(this._client);
  final SupabaseClient _client;

  static const String _table = 'activity_day_outcomes';
  static const String _conflictKey = 'user_id,activity_id,local_date';

  Future<List<ActivityDayOutcome>> fetchForActivity(
    String userId,
    String activityId,
  ) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('activity_id', activityId)
        .order('local_date', ascending: true);
    return (data as List)
        .map((row) => ActivityDayOutcome.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Records that these days were opportunities for their activities.
  ///
  /// `ignoreDuplicates` is the whole point. The app re-observes today's matches
  /// on every launch and every resume, and an existing row for that day may
  /// already carry the user's answer. Upserting without it would rewrite the
  /// row back to unanswered, so a completed day would quietly become pending
  /// and then expire — the streak would decay for the most engaged users.
  Future<void> recordMatchedDays(List<ActivityDayOutcome> rows) async {
    if (rows.isEmpty) return;
    await _client
        .from(_table)
        .upsert(
          [for (final row in rows) row.toJson()],
          onConflict: _conflictKey,
          ignoreDuplicates: true,
        );
  }

  /// Records the user's answer for one day.
  ///
  /// An upsert rather than an update, and deliberately *without*
  /// `ignoreDuplicates`.
  ///
  /// Upsert because the opportunity row is not guaranteed to exist: the app can
  /// be offline the day a match happens and online only that evening, and a
  /// retroactive answer from the heat map can reach back further still. An
  /// `.update()` that matches no row succeeds while writing nothing, so the
  /// answer would vanish with no error — the same silent loss
  /// `ActivityRepository.updateWithConditions` had to be fixed for.
  ///
  /// Without `ignoreDuplicates` because this write must win: every answer is
  /// for a day that usually already has a row, and ignoring the conflict would
  /// discard the answer instead of recording it.
  Future<void> answer({
    required String userId,
    required String activityId,
    required String localDate,
    required String outcome,
    required DateTime answeredAt,
    String? reason,
  }) async {
    final row = ActivityDayOutcome(
      userId: userId,
      activityId: activityId,
      localDate: localDate,
      outcome: outcome,
      reason: reason,
      answeredAt: answeredAt,
    );
    await _client.from(_table).upsert(row.toJson(), onConflict: _conflictKey);
  }
}
