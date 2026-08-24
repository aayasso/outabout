// Streaks, completion rate and milestones over a single activity's history.
//
// Pure: no Flutter, no Supabase, no `DateTime.now()`. The clock arrives as a
// parameter so every rule below is testable without a widget tree, and so the
// same row set can be evaluated at two different instants — which is the only
// way to test that an unanswered day expires.

import '../../data/models/activity_day_outcome.dart';

/// How long an unanswered matched day stays answerable before it counts
/// against the user.
///
/// The prompt is a same-day affordance, so most matched days go unanswered
/// simply because the app was not opened after 16:00. A week is long enough to
/// come back to it and short enough that the streak still means something: a
/// number only an explicit "No" could ever dent would be unfalsifiable.
const int defaultOutcomeGraceDays = 7;

/// What one matched day contributes.
enum OutcomeDayState {
  /// The app never claimed this day suited the activity. Transparent: skipped
  /// by every calculation. This is the core rule — a day that did not match
  /// can never break a streak.
  notMatched,

  /// Unanswered and dated after today. Transparent, so a clock that moved
  /// backwards cannot manufacture an expiry.
  future,

  /// Unanswered, still inside the grace window. Transparent to the streak, and
  /// excluded from the completion rate's numerator *and* denominator — the
  /// user can still resolve it, so it must not drag the number down meanwhile.
  pending,

  done,
  skipped,

  /// Unanswered past the grace window. Counts against the completion rate and
  /// breaks the streak: silence is an answer once it is old enough.
  expired,
}

/// A completion count worth marking.
enum OutcomeMilestone {
  first(1),
  five(5),
  ten(10),
  twentyFive(25);

  const OutcomeMilestone(this.completions);
  final int completions;
}

/// One classified day. Ascending by [localDate], deduplicated.
typedef OutcomeDayCell = ({String localDate, OutcomeDayState state});

/// The whole picture for one activity.
///
/// A record rather than a class so tests can assert on the lot in one
/// `expect`, with structural equality for free.
typedef OutcomeStats = ({
  int currentStreak,
  int bestStreak,
  int totalCompleted,
  int totalSkipped,
  int totalExpired,
  int totalPending,

  /// done + skipped + expired: the completion-rate denominator.
  int decidedDays,

  /// Null — never 0.0 — when nothing has been decided yet. A user with no
  /// resolved day has no rate, and rendering "0%" for them is a lie the UI
  /// must not be able to tell by accident.
  double? completionRate,

  /// Set only when [totalCompleted] lands exactly on a threshold. For display;
  /// use [milestoneCrossed] to decide whether to log one.
  OutcomeMilestone? milestone,
});

// ---------------------------------------------------------------------------
// Civil dates
// ---------------------------------------------------------------------------

/// The device's local calendar day for an instant, as `YYYY-MM-DD`.
///
/// The only timezone-aware function in this library. Everything downstream
/// works on the resulting text, which cannot be wrong about a DST transition
/// because it never measures elapsed time.
String localDateKeyOf(DateTime instant) {
  final local = instant.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Calendar days from [from] to [to], both `YYYY-MM-DD`. Negative when [to] is
/// the earlier date.
///
/// Anchored on [DateTime.utc], which has no DST, so this is exact in every
/// zone. Parsing the two dates as *local* instants and subtracting — the
/// obvious implementation — is wrong twice over: local midnight to local
/// midnight across a spring-forward day is 23 hours, which `inDays` truncates
/// to 0, and the error accumulates over longer spans. Worse, it is invisible
/// on a UTC machine, so the whole suite passes until someone runs it somewhere
/// that observes DST. See the civil-date tests.
int daysBetweenIsoDates(String from, String to) =>
    _utcMidnight(to).difference(_utcMidnight(from)).inDays;

DateTime _utcMidnight(String isoDate) {
  final parts = isoDate.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

/// What [row] contributes, as of [now].
///
/// An answer always wins over a date: a row carrying an outcome is classified
/// by that outcome alone, so clock skew can never discard something the user
/// actually told us.
OutcomeDayState stateFor(
  ActivityDayOutcome row, {
  required DateTime now,
  int graceDays = defaultOutcomeGraceDays,
}) {
  if (!row.matched) return OutcomeDayState.notMatched;
  if (row.outcome == DayOutcome.done) return OutcomeDayState.done;
  if (row.outcome == DayOutcome.skipped) return OutcomeDayState.skipped;

  // Anything else in `outcome` reads as unanswered. The database CHECK is a
  // deliberate superset of what this client writes, exactly as the event-type
  // constraint is a superset of `approvedEventTypes`, so an unrecognised value
  // is a forward-compatibility case and not a crash.
  final daysAgo = daysBetweenIsoDates(row.localDate, localDateKeyOf(now));
  if (daysAgo < 0) return OutcomeDayState.future;
  if (daysAgo > graceDays) return OutcomeDayState.expired;
  return OutcomeDayState.pending;
}

/// [rows], one per day, sorted oldest first.
///
/// The unique index on (user_id, activity_id, local_date) makes duplicates
/// impossible in the database, but this must not assume that: rows can arrive
/// merged from two fetches, or hand-built in a test. Resolution is total and
/// deterministic — an answered row beats an unanswered one, a later
/// `answeredAt` beats an earlier one, and a remaining tie goes to whichever
/// came last in the input.
///
/// Split out of [classifyOutcomeDays] so the suggestion engine resolves
/// duplicates by exactly the same rule. It needs the rows themselves rather
/// than their states — the weather snapshot rides on the row — and two
/// independent resolutions could disagree about which of two rows for one day
/// is the real one, which would put the record and the inference drawn from it
/// out of step.
List<ActivityDayOutcome> dedupeOutcomeRowsByDay(List<ActivityDayOutcome> rows) {
  final byDate = <String, ActivityDayOutcome>{};
  for (final row in rows) {
    final existing = byDate[row.localDate];
    if (existing == null || _supersedes(row, existing)) {
      byDate[row.localDate] = row;
    }
  }

  final dates = byDate.keys.toList()..sort();
  return [for (final date in dates) byDate[date]!];
}

/// [rows], deduplicated by day, classified, and sorted oldest first.
List<OutcomeDayCell> classifyOutcomeDays(
  List<ActivityDayOutcome> rows, {
  required DateTime now,
  int graceDays = defaultOutcomeGraceDays,
}) {
  return [
    for (final row in dedupeOutcomeRowsByDay(rows))
      (
        localDate: row.localDate,
        state: stateFor(row, now: now, graceDays: graceDays),
      ),
  ];
}

bool _supersedes(ActivityDayOutcome candidate, ActivityDayOutcome existing) {
  if (candidate.isAnswered != existing.isAnswered) return candidate.isAnswered;
  final candidateAt = candidate.answeredAt;
  final existingAt = existing.answeredAt;
  if (candidateAt != null && existingAt != null) {
    return !candidateAt.isBefore(existingAt);
  }
  return true;
}

// ---------------------------------------------------------------------------
// Streaks
// ---------------------------------------------------------------------------

/// Current and best run of completed days over an ordered state sequence.
///
/// Takes states rather than dates because the gaps between them are irrelevant
/// by definition: the sequence is already only the days that mattered.
/// Transparent states are skipped rather than ending the walk, which is what
/// lets a run survive both a rainy fortnight and an unanswered day the user
/// can still come back to.
({int current, int best}) computeStreaks(List<OutcomeDayState> ordered) {
  var run = 0;
  var best = 0;
  for (final state in ordered) {
    switch (state) {
      case OutcomeDayState.notMatched:
      case OutcomeDayState.future:
      case OutcomeDayState.pending:
        continue;
      case OutcomeDayState.done:
        run += 1;
        if (run > best) best = run;
      case OutcomeDayState.skipped:
      case OutcomeDayState.expired:
        run = 0;
    }
  }
  return (current: run, best: best);
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

OutcomeStats computeOutcomeStats(
  List<ActivityDayOutcome> rows, {
  required DateTime now,
  int graceDays = defaultOutcomeGraceDays,
}) {
  final cells = classifyOutcomeDays(rows, now: now, graceDays: graceDays);
  final states = [for (final cell in cells) cell.state];
  final streaks = computeStreaks(states);

  var completed = 0;
  var skipped = 0;
  var expired = 0;
  var pending = 0;
  for (final state in states) {
    switch (state) {
      case OutcomeDayState.done:
        completed += 1;
      case OutcomeDayState.skipped:
        skipped += 1;
      case OutcomeDayState.expired:
        expired += 1;
      case OutcomeDayState.pending:
        pending += 1;
      case OutcomeDayState.notMatched:
      case OutcomeDayState.future:
        break;
    }
  }

  final decided = completed + skipped + expired;
  return (
    currentStreak: streaks.current,
    bestStreak: streaks.best,
    totalCompleted: completed,
    totalSkipped: skipped,
    totalExpired: expired,
    totalPending: pending,
    decidedDays: decided,
    completionRate: decided == 0 ? null : completed / decided,
    milestone: _exactMilestone(completed),
  );
}

OutcomeMilestone? _exactMilestone(int completed) {
  for (final milestone in OutcomeMilestone.values) {
    if (milestone.completions == completed) return milestone;
  }
  return null;
}

/// The highest threshold strictly crossed going from [previousCompleted] to
/// [currentCompleted], or null.
///
/// Edge-triggered on purpose. A refetch that recomputes the same total must log
/// nothing, or every pull-to-refresh would re-celebrate; and a count that jumps
/// two thresholds at once — a backfill, a burst of retroactive answers — should
/// still mark the higher one rather than silently skipping both.
OutcomeMilestone? milestoneCrossed({
  required int previousCompleted,
  required int currentCompleted,
}) {
  OutcomeMilestone? crossed;
  for (final milestone in OutcomeMilestone.values) {
    final target = milestone.completions;
    if (previousCompleted < target && target <= currentCompleted) {
      crossed = milestone;
    }
  }
  return crossed;
}
