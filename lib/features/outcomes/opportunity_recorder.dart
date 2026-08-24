import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/models/activity_day_outcome.dart';
import '../../data/models/schedule_day.dart';
import '../../data/repositories/activity_day_outcome_repository.dart';
import '../home/outcome_prompt_provider.dart';
import 'outcome_stats.dart';

/// The opportunity rows today's schedule implies, if any.
///
/// Pure, so "which days count" is testable without a network or a clock.
///
/// Two rules, both load bearing:
///
/// 1. Only today. The forecast window runs five days forward, but a day that
///    has not happened cannot be an opportunity the user missed, and yesterday
///    has already left the window. Matched on the *local* calendar day —
///    Tomorrow.io hands back UTC instants, so comparing `.day` directly is
///    wrong for most of the world for part of every day.
///
/// 2. Only activities whose profile actually constrains something.
///    [evaluateDayMatch] returns true for a null or empty profile, which is
///    right for a filter — nothing rules the activity out — but would make
///    every profile-less activity a matched day, every day. Those days would
///    go unanswered, expire, and destroy the streak of the one activity the
///    user never expressed a weather preference for.
///    [ConditionProfile.isConstraining] is the predicate the schedule card
///    already uses to decide whether to claim "conditions match", so reusing it
///    keeps what the UI calls a match and what the streak counts identical.
///
/// Every row carries the day's forecast in [ActivityDayOutcome.conditions].
/// This is the only moment the weather behind a matched day is in hand — the
/// forecast window is five days wide and moves, so by the time the user
/// answers, the day that prompted the question may already have fallen out of
/// it. Recording the observation with the claim is what makes the ledger
/// something the app can later reason about rather than merely count.
///
/// All rows from one day share one snapshot object, which is both honest — it
/// is one day's weather — and required: the batch upsert sends these together,
/// and PostgREST takes the union of keys across a batch.
List<ActivityDayOutcome> matchedOpportunitiesForToday({
  required List<ScheduleDay> days,
  required DateTime now,
  required String userId,
}) {
  final today = localDateKeyOf(now);
  for (final day in days) {
    if (localDateKeyOf(day.forecast.date) != today) continue;
    final conditions = day.forecast.toJson();
    return [
      for (final activity in day.matchedActivities)
        if (activity.id case final id?)
          if (activity.conditionProfile?.isConstraining ?? false)
            ActivityDayOutcome(
              userId: userId,
              activityId: id,
              localDate: today,
              conditions: conditions,
            ),
    ];
  }
  return const [];
}

/// Writes today's opportunities, at most once each per app run.
///
/// Idempotent three times over, because the schedule recomputes on every
/// forecast refresh, activity edit and app resume:
///   * [_written] makes a repeat within one run cost nothing at all,
///   * the repository's `ignoreDuplicates` is the backstop across restarts,
///   * and an empty selection issues no request.
class OpportunityRecorder {
  OpportunityRecorder({
    required ActivityDayOutcomeRepository repository,
    required String? userId,
    required DateTime Function() now,
  }) : _repository = repository,
       _userId = userId,
       _now = now;

  final ActivityDayOutcomeRepository _repository;
  final String? _userId;
  final DateTime Function() _now;

  /// `'<activityId>|<yyyy-MM-dd>'` — [outcomePromptKey]'s shape, so the ledger
  /// and the prompt cannot disagree about which day they mean.
  final Set<String> _written = <String>{};

  Future<void> record(List<ScheduleDay> days) async {
    final userId = _userId;
    if (userId == null) return;

    final candidates = matchedOpportunitiesForToday(
      days: days,
      now: _now(),
      userId: userId,
    );
    final fresh = [
      for (final row in candidates)
        if (!_written.contains(_key(row))) row,
    ];
    if (fresh.isEmpty) return;

    try {
      await _repository.recordMatchedDays(fresh);
      _written.addAll(fresh.map(_key));
    } catch (e) {
      // Swallowed like BehavioralEventService.log: a history write must never
      // take down the schedule the user came here to read. The keys are
      // deliberately *not* marked written, so the next resume retries.
      debugPrint('OpportunityRecorder: could not record matched days — $e');
    }
  }

  String _key(ActivityDayOutcome row) => '${row.activityId}|${row.localDate}';
}
