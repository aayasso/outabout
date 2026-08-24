// Learning a user's real thresholds from what they actually did.
//
// Pure, on the model of `outcome_stats.dart`: no Flutter, no Supabase, no
// `DateTime.now()`. Every rule below is a function of its arguments, so the
// whole of "when do we suggest something, and what" is testable without a
// widget tree, a network, or a clock — which matters more here than anywhere
// else in the app, because this is the one feature that edits the user's own
// settings on the strength of an inference.
//
// ---------------------------------------------------------------------------
// Why every suggestion tightens
// ---------------------------------------------------------------------------
//
// The ledger only ever records days that *matched*. A day the conditions
// excluded is never written, never answered, and leaves no trace. So the
// evidence available is entirely one-sided:
//
//   * "you keep skipping your windiest matches" is provable — those days are
//     in the ledger, with their wind speeds and the user's own answers;
//   * "you would have gone out on windier days" is not, and cannot be. There
//     is no row for a day at 30 km/h under a 25 km/h limit, so no amount of
//     history can speak to it.
//
// Suggesting a loosening would therefore mean presenting a guess as a learned
// preference. This file will not do it, and the type system helps: each rule
// below computes a bound in one fixed direction and the tests assert that no
// input produces a widening.
//
// ---------------------------------------------------------------------------
// Why precipitation is absent
// ---------------------------------------------------------------------------
//
// `precip_level` is a direction (avoid_rain / rain_only), not a threshold, and
// the 20% cut it turns on is `PrecipLevel.dryThreshold` — a global constant,
// identical for every activity and every user. There is no per-activity number
// to move. Flipping the direction would be a reversal of what the user asked
// for rather than an adjustment to it, which is exactly the kind of change
// this feature is not permitted to propose.

import 'dart:math' as math;

import '../../data/models/activity_day_outcome.dart';
import '../../data/models/condition_profile.dart';
import '../../data/models/daily_forecast.dart';
import '../outcomes/outcome_stats.dart';

// ---------------------------------------------------------------------------
// Thresholds
// ---------------------------------------------------------------------------

/// Decided days an activity needs before anything is suggested.
///
/// Below this, one bad week is the entire sample. Eight is roughly a month of
/// a twice-weekly activity — enough that a pattern has had a chance to be
/// contradicted, and still reachable inside a season.
const int suggestionMinimumDecidedDays = 8;

/// Skips that must share a signal before it counts as a pattern.
///
/// Two is a coincidence; the second data point is the one that makes the first
/// look meaningful, which is precisely when a human is most likely to be
/// wrong. Also the increment a declined suggestion must clear to come back.
const int suggestionMinimumQualifyingSkips = 3;

/// Wind limits are suggested in whole multiples of this, in km/h.
const double windSuggestionStep = 5.0;

/// A wind suggestion smaller than this is cosmetic and is not made.
const double windSuggestionMinDelta = 5.0;

/// Temperature limits are suggested in whole degrees Celsius.
const double tempSuggestionStep = 1.0;

/// A temperature suggestion smaller than this is cosmetic and is not made.
const double tempSuggestionMinDelta = 2.0;

// ---------------------------------------------------------------------------
// Vocabulary
// ---------------------------------------------------------------------------

/// The bounds this engine is allowed to move.
///
/// Three, and only ever these three. Each names a column that already exists
/// on `condition_profiles` and is only ever considered when the user has both
/// enabled it and put a number behind it.
enum SuggestionDimension {
  /// Lower the wind ceiling.
  windMax('wind_max'),

  /// Lower the warm end of the temperature range.
  tempMax('temp_max'),

  /// Raise the cold end of the temperature range.
  tempMin('temp_min');

  const SuggestionDimension(this.wireName);

  /// The `condition_profiles` column name. Persisted in the declined-suggestion
  /// record and logged in `session_context`, so it is a stable contract in two
  /// directions and must not be renamed casually.
  final String wireName;
}

/// [SuggestionDimension] for a stored [wireName], or null if unrecognised.
///
/// Null rather than a throw: a declined record written by a newer build naming
/// a dimension this one has never heard of is a forward-compatibility case, not
/// a crash. It reads as "nothing declined", which at worst re-offers one
/// suggestion.
SuggestionDimension? suggestionDimensionFromWire(String wireName) {
  for (final dimension in SuggestionDimension.values) {
    if (dimension.wireName == wireName) return dimension;
  }
  return null;
}

/// One bounded change to one existing condition, with the evidence behind it.
typedef ConditionSuggestion = ({
  SuggestionDimension dimension,
  double currentValue,
  double suggestedValue,

  /// Skipped days this change would have excluded.
  int qualifyingSkips,

  /// Decided days with a snapshot that the whole inference rests on.
  int eligibleDays,
});

/// What was refused, and how much evidence stood behind it at the time.
///
/// Both halves are needed to decide whether a later suggestion is the same
/// question being asked again or a materially different one.
typedef DeclinedSuggestion = ({int qualifyingSkips, double suggestedValue});

// ---------------------------------------------------------------------------
// Eligibility
// ---------------------------------------------------------------------------

/// A decided day the engine can actually reason about.
typedef _EligibleDay = ({OutcomeDayState state, DailyForecast conditions});

/// The days that may be used as evidence, deduplicated.
///
/// Three filters, each load bearing:
///
/// 1. Classified by [stateFor], the same function the streak uses, so the
///    record and the inference drawn from it cannot disagree about what a day
///    contributed. A row the ledger treats as transparent — `matched: false` —
///    is invisible here too.
/// 2. Only `done` and `skipped`. `pending` and `expired` are unanswered, and
///    reading silence as "skipped because it was windy" would invent the very
///    preference the feature claims to have observed. Expiry is allowed to
///    cost the user a streak, because that is a rule they were told about; it
///    is not allowed to put words in their mouth.
/// 3. Only rows carrying a parseable snapshot. A day whose weather is unknown
///    cannot be evidence for a claim about weather, and defaulting the missing
///    numbers would manufacture an observation that never happened.
List<_EligibleDay> _eligibleDays(
  List<ActivityDayOutcome> rows, {
  required DateTime now,
  required int graceDays,
}) {
  final out = <_EligibleDay>[];
  for (final row in dedupeOutcomeRowsByDay(rows)) {
    final state = stateFor(row, now: now, graceDays: graceDays);
    if (state != OutcomeDayState.done && state != OutcomeDayState.skipped) {
      continue;
    }
    final snapshot = row.conditions;
    if (snapshot == null) continue;
    final conditions = _readSnapshot(snapshot);
    if (conditions == null) continue;
    out.add((state: state, conditions: conditions));
  }
  return out;
}

/// Decodes a stored snapshot, or null if it is not one.
///
/// [DailyForecast.fromJson] is the reader precisely because
/// [DailyForecast.toJson] was the writer — the column holds that shape and no
/// other, so there is no second parser here to fall out of step with the
/// first. A row written by some other build, or hand-edited, is skipped rather
/// than allowed to take down the screen it appears on.
DailyForecast? _readSnapshot(Map<String, dynamic> snapshot) {
  try {
    return DailyForecast.fromJson(snapshot);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// The rule
// ---------------------------------------------------------------------------

/// The single best-supported tightening for [profile], or null.
///
/// Null is the overwhelmingly common answer and the correct default: silence
/// costs nothing, and a wrong suggestion costs the user's trust in every later
/// one.
///
/// [declined] maps a dimension to what was refused for it. A refused
/// suggestion stays refused until the pattern behind it strengthens materially
/// — see [_supersedesDecline].
///
/// Exactly one suggestion, never a list. Two changes at once are impossible to
/// evaluate: whichever one was right, the user cannot tell which, and neither
/// can we from the answer.
ConditionSuggestion? suggestConditionChange({
  required ConditionProfile? profile,
  required List<ActivityDayOutcome> rows,
  required DateTime now,
  Map<SuggestionDimension, DeclinedSuggestion> declined = const {},
  int graceDays = defaultOutcomeGraceDays,
}) {
  if (profile == null) return null;

  final eligible = _eligibleDays(rows, now: now, graceDays: graceDays);
  if (eligible.length < suggestionMinimumDecidedDays) return null;

  final candidates = <ConditionSuggestion>[
    for (final candidate in [
      _windCandidate(profile, eligible),
      _tempMaxCandidate(profile, eligible),
      _tempMinCandidate(profile, eligible),
    ])
      if (candidate != null)
        if (!_isSilencedBy(candidate, declined[candidate.dimension])) candidate,
  ];
  if (candidates.isEmpty) return null;

  candidates.sort(_byStrength);
  return candidates.first;
}

/// More evidence wins; then a bigger change; then a fixed dimension order.
///
/// Fully deterministic by construction. A ranking that could return either of
/// two answers for one input would make the feature's behaviour depend on row
/// order, which changes between fetches.
int _byStrength(ConditionSuggestion a, ConditionSuggestion b) {
  final byEvidence = b.qualifyingSkips.compareTo(a.qualifyingSkips);
  if (byEvidence != 0) return byEvidence;
  final byDelta = _delta(b).compareTo(_delta(a));
  if (byDelta != 0) return byDelta;
  return a.dimension.index.compareTo(b.dimension.index);
}

double _delta(ConditionSuggestion s) =>
    (s.currentValue - s.suggestedValue).abs();

/// Whether [candidate] is the question [declined] already answered.
///
/// It comes back only when the pattern has strengthened in a way the user
/// would recognise as new information:
///
///   * [suggestionMinimumQualifyingSkips] more qualifying skips than stood
///     behind the refused version — a whole fresh pattern's worth, not one
///     more day; or
///   * a value that has moved by at least twice the dimension's minimum delta,
///     which makes it a different ask rather than a repetition of the same one.
///
/// Anything less is nagging. The user said no to this, and "no" has to mean
/// something for longer than a week.
bool _isSilencedBy(ConditionSuggestion candidate, DeclinedSuggestion? refused) {
  if (refused == null) return false;
  final strengthened =
      candidate.qualifyingSkips >=
      refused.qualifyingSkips + suggestionMinimumQualifyingSkips;
  final moved =
      (candidate.suggestedValue - refused.suggestedValue).abs() >=
      2 * _minDeltaFor(candidate.dimension);
  return !(strengthened || moved);
}

double _minDeltaFor(SuggestionDimension dimension) => switch (dimension) {
  SuggestionDimension.windMax => windSuggestionMinDelta,
  SuggestionDimension.tempMax => tempSuggestionMinDelta,
  SuggestionDimension.tempMin => tempSuggestionMinDelta,
};

// ---------------------------------------------------------------------------
// Per-dimension candidates
// ---------------------------------------------------------------------------

/// Lower [ConditionProfile.windMax] when the windiest matches go unused.
///
/// The quantity is `windSpeedMax`, because that is the field
/// `evaluateDayMatch` compares against `wind_max`. Reasoning about any other
/// number would produce a limit that fails to exclude the very days it cites.
ConditionSuggestion? _windCandidate(
  ConditionProfile profile,
  List<_EligibleDay> eligible,
) {
  if (!profile.windEnabled) return null;
  final current = profile.windMax;
  if (current == null) return null;

  return _tightenDownward(
    dimension: SuggestionDimension.windMax,
    current: current,
    eligible: eligible,
    valueOf: (day) => day.conditions.windSpeedMax,
    step: windSuggestionStep,
    minDelta: windSuggestionMinDelta,
    // A wind ceiling of zero or less matches nothing at all, which is a way of
    // deleting the activity rather than tuning it.
    floor: windSuggestionStep,
  );
}

/// Lower [ConditionProfile.tempMax] when the hottest matches go unused.
///
/// The quantity is the day's *minimum* temperature. That reads backwards until
/// you look at the matcher: a day is rejected when `temperatureMin > tempMax`,
/// because the profile describes a range the day must overlap. So the minimum
/// is what `temp_max` actually governs, and using the maximum here would
/// suggest a limit that does not exclude the days it was derived from.
ConditionSuggestion? _tempMaxCandidate(
  ConditionProfile profile,
  List<_EligibleDay> eligible,
) {
  if (!profile.tempEnabled) return null;
  final current = profile.tempMax;
  if (current == null) return null;

  return _tightenDownward(
    dimension: SuggestionDimension.tempMax,
    current: current,
    eligible: eligible,
    valueOf: (day) => day.conditions.temperatureMin,
    step: tempSuggestionStep,
    minDelta: tempSuggestionMinDelta,
  );
}

/// Raise [ConditionProfile.tempMin] when the coldest matches go unused.
///
/// Mirror image of [_tempMaxCandidate]: a day is rejected when
/// `temperatureMax < tempMin`, so the maximum is the quantity `temp_min`
/// governs.
ConditionSuggestion? _tempMinCandidate(
  ConditionProfile profile,
  List<_EligibleDay> eligible,
) {
  if (!profile.tempEnabled) return null;
  final current = profile.tempMin;
  if (current == null) return null;

  return _tightenUpward(
    dimension: SuggestionDimension.tempMin,
    current: current,
    eligible: eligible,
    valueOf: (day) => day.conditions.temperatureMax,
    step: tempSuggestionStep,
    minDelta: tempSuggestionMinDelta,
  );
}

// ---------------------------------------------------------------------------
// The two shapes of tightening
// ---------------------------------------------------------------------------

/// Pull an upper bound down, below every skipped day it is meant to exclude
/// and above every day the user actually went out on.
///
/// The purity requirement — no completed day anywhere in the excluded band —
/// is what makes the claim behind the suggestion literally true rather than
/// merely likely. It is stated to the user as "you have never gone out above
/// this", and it has to survive that reading.
///
/// [floor] is the lowest value the bound may be given, for dimensions where a
/// small number is meaningless rather than merely strict.
ConditionSuggestion? _tightenDownward({
  required SuggestionDimension dimension,
  required double current,
  required List<_EligibleDay> eligible,
  required double Function(_EligibleDay) valueOf,
  required double step,
  required double minDelta,
  double? floor,
}) {
  final done = [
    for (final day in eligible)
      if (day.state == OutcomeDayState.done) valueOf(day),
  ];
  // Zero rather than negative infinity when nothing was ever completed: the
  // ceiling is a lower bound on the new limit, and an unbounded one would let
  // the suggestion land anywhere.
  final doneCeiling = done.isEmpty ? 0.0 : done.reduce(math.max);

  final qualifying = [
    for (final day in eligible)
      if (day.state == OutcomeDayState.skipped)
        if (valueOf(day) > doneCeiling) valueOf(day),
  ];
  if (qualifying.length < suggestionMinimumQualifyingSkips) return null;

  final lowestSkip = qualifying.reduce(math.min);
  var suggested = _floorToStep(lowestSkip, step);
  // The new bound must *exclude* the lowest qualifying skip, and the matcher
  // rejects only what is strictly above it — so landing exactly on that value
  // would leave the day matching.
  if (suggested >= lowestSkip) suggested -= step;

  // Off the grid rather than onto a fractional value: a limit of 18.3 km/h is
  // not a number anyone chose, and readability is worth losing the occasional
  // expressible suggestion.
  if (suggested < doneCeiling) return null;
  if (floor != null && suggested < floor) return null;
  if (current - suggested < minDelta) return null;

  return (
    dimension: dimension,
    currentValue: current,
    suggestedValue: suggested,
    qualifyingSkips: qualifying.length,
    eligibleDays: eligible.length,
  );
}

/// Push a lower bound up. The mirror of [_tightenDownward] in every respect.
ConditionSuggestion? _tightenUpward({
  required SuggestionDimension dimension,
  required double current,
  required List<_EligibleDay> eligible,
  required double Function(_EligibleDay) valueOf,
  required double step,
  required double minDelta,
}) {
  final done = [
    for (final day in eligible)
      if (day.state == OutcomeDayState.done) valueOf(day),
  ];
  if (done.isEmpty) return null;
  final doneFloor = done.reduce(math.min);

  final qualifying = [
    for (final day in eligible)
      if (day.state == OutcomeDayState.skipped)
        if (valueOf(day) < doneFloor) valueOf(day),
  ];
  if (qualifying.length < suggestionMinimumQualifyingSkips) return null;

  final highestSkip = qualifying.reduce(math.max);
  var suggested = _ceilToStep(highestSkip, step);
  if (suggested <= highestSkip) suggested += step;

  if (suggested > doneFloor) return null;
  if (suggested - current < minDelta) return null;

  return (
    dimension: dimension,
    currentValue: current,
    suggestedValue: suggested,
    qualifyingSkips: qualifying.length,
    eligibleDays: eligible.length,
  );
}

double _floorToStep(double value, double step) => (value / step).floor() * step;

double _ceilToStep(double value, double step) => (value / step).ceil() * step;
