import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/activity_day_outcome.dart';
import '../../data/models/schedule_day.dart';
import '../../data/repositories/activity_day_outcome_repository.dart';
import '../../services/behavioral_event_service.dart';
import '../home/home_providers.dart';
import 'opportunity_recorder.dart';
import 'outcome_stats.dart';

final activityDayOutcomeRepositoryProvider =
    Provider<ActivityDayOutcomeRepository>((ref) {
      return ActivityDayOutcomeRepository(ref.watch(supabaseClientProvider));
    });

/// Every recorded day for one activity, oldest first.
final activityOutcomesProvider =
    FutureProvider.family<List<ActivityDayOutcome>, String>((
      ref,
      activityId,
    ) async {
      final client = ref.watch(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const [];
      return ref
          .watch(activityDayOutcomeRepositoryProvider)
          .fetchForActivity(userId, activityId);
    });

/// Streaks, rate and totals for one activity.
///
/// A synchronous provider over an async one — the `scheduleMatchProvider`
/// shape. The derivation is pure, so it recomputes for free whenever the clock
/// provider is overridden, which is how the expiry rule is testable at all.
final activityOutcomeStatsProvider =
    Provider.family<AsyncValue<OutcomeStats>, String>((ref, activityId) {
      final now = ref.watch(nowProvider);
      return ref
          .watch(activityOutcomesProvider(activityId))
          .whenData((rows) => computeOutcomeStats(rows, now: now()));
    });

final opportunityRecorderProvider = Provider<OpportunityRecorder>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OpportunityRecorder(
    repository: ref.watch(activityDayOutcomeRepositoryProvider),
    userId: client.auth.currentUser?.id,
    now: ref.watch(nowProvider),
  );
});

/// Records today's matched days as they appear in the schedule.
///
/// The write lives in a `ref.listen` callback rather than in a provider body:
/// `scheduleMatchProvider` is a derived provider that recomputes on every
/// forecast refresh and every activity edit, and a side effect in its body
/// would fire unpredictably.
///
/// `fireImmediately` is load bearing. The forecast usually resolves before the
/// root widget mounts, and a change-only listener would then never fire at all
/// — the day would go unrecorded for anyone who did not happen to pull to
/// refresh.
final matchedDayRecorderProvider = Provider<void>((ref) {
  final recorder = ref.watch(opportunityRecorderProvider);
  ref.listen<AsyncValue<List<ScheduleDay>>>(scheduleMatchProvider, (_, next) {
    final days = next.valueOrNull;
    if (days != null) recorder.record(days);
  }, fireImmediately: true);
});

/// Records an answer to "Did you go?" and marks a milestone if one lands.
class OutcomeAnswerController {
  OutcomeAnswerController(this._ref);
  final Ref _ref;

  /// Writes [outcome] for [matchedDay] and returns the milestone it crossed.
  ///
  /// The milestone is computed from the completion count either side of the
  /// write rather than from the new total, so a refetch that recomputes the
  /// same number celebrates nothing.
  Future<OutcomeMilestone?> submit({
    required String activityId,
    required DateTime matchedDay,
    required String outcome,
    String? reason,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final before =
        _ref
            .read(activityOutcomeStatsProvider(activityId))
            .valueOrNull
            ?.totalCompleted ??
        0;

    await _ref
        .read(activityDayOutcomeRepositoryProvider)
        .answer(
          userId: userId,
          activityId: activityId,
          localDate: localDateKeyOf(matchedDay),
          outcome: outcome,
          answeredAt: _ref.read(nowProvider)(),
          reason: reason,
        );

    _ref.invalidate(activityOutcomesProvider(activityId));
    final rows = await _ref.read(activityOutcomesProvider(activityId).future);
    final after = computeOutcomeStats(
      rows,
      now: _ref.read(nowProvider)(),
    ).totalCompleted;

    final crossed = milestoneCrossed(
      previousCompleted: before,
      currentCompleted: after,
    );
    if (crossed != null) {
      await _ref
          .read(behavioralEventServiceProvider)
          .log(
            'activity_milestone_reached',
            extra: {
              'activity_id': activityId,
              'milestone': crossed.completions,
            },
          );
    }
    return crossed;
  }
}

final outcomeAnswerControllerProvider = Provider<OutcomeAnswerController>(
  (ref) => OutcomeAnswerController(ref),
);
