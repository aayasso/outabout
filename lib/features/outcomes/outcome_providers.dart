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

  /// Writes [outcome] for [matchedDay] and reports what it changed.
  ///
  /// Returns the refreshed stats alongside the milestone, so the caller can
  /// show the new streak without a second round trip. The milestone is derived
  /// from the completion count either side of the write rather than from the
  /// new total, so a refetch that recomputes the same number celebrates
  /// nothing.
  Future<({OutcomeMilestone? milestone, OutcomeStats? stats})> submit({
    required String activityId,
    required DateTime matchedDay,
    required String outcome,
    String? reason,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return (milestone: null, stats: null);

    // Fetched, not read from cache. On the schedule tab nothing has ever read
    // this activity's stats, so a cached read returns null — and defaulting
    // that to zero would make the first answer of every session look like a
    // crossing of the "first completion" threshold, re-announcing a milestone
    // the user passed months ago.
    final now = _ref.read(nowProvider);
    final beforeRows = await _ref.read(
      activityOutcomesProvider(activityId).future,
    );
    final before = computeOutcomeStats(beforeRows, now: now()).totalCompleted;

    await _ref
        .read(activityDayOutcomeRepositoryProvider)
        .answer(
          userId: userId,
          activityId: activityId,
          localDate: localDateKeyOf(matchedDay),
          outcome: outcome,
          answeredAt: now(),
          reason: reason,
        );

    _ref.invalidate(activityOutcomesProvider(activityId));
    final rows = await _ref.read(activityOutcomesProvider(activityId).future);
    final stats = computeOutcomeStats(rows, now: now());

    final crossed = milestoneCrossed(
      previousCompleted: before,
      currentCompleted: stats.totalCompleted,
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
    return (milestone: crossed, stats: stats);
  }
}

final outcomeAnswerControllerProvider = Provider<OutcomeAnswerController>(
  (ref) => OutcomeAnswerController(ref),
);
