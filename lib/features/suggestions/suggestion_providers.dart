// Wiring for adaptive condition suggestions: what has been offered, what was
// refused, and what happens when the user answers.
//
// The rule itself lives in `condition_suggestion.dart` and knows nothing about
// any of this. Everything here is the impure half — reading the ledger,
// persisting a refusal, writing the accepted change, logging the funnel.

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/activity.dart';
import '../../data/models/condition_profile.dart';
import '../../services/behavioral_event_service.dart';
import '../home/home_providers.dart';
import '../outcomes/outcome_providers.dart';
import 'condition_suggestion.dart';

// ---------------------------------------------------------------------------
// Event types
// ---------------------------------------------------------------------------

/// The funnel. Three types rather than one with an outcome field, so the stage
/// is a column to group by rather than a key inside the jsonb that
/// de-identification rewrites — see 20260826000100.
const String suggestionShownEvent = 'condition_suggestion_shown';
const String suggestionAcceptedEvent = 'condition_suggestion_accepted';
const String suggestionDeclinedEvent = 'condition_suggestion_declined';

// ---------------------------------------------------------------------------
// Persisted state
// ---------------------------------------------------------------------------

/// What has happened to suggestions for one activity/dimension pair.
///
/// [shownValue] is separate from the declined pair because being shown and
/// being refused are different facts: a suggestion the user scrolled past
/// should not be logged again on the next screen open, but it has not been
/// refused and must still be offered.
typedef SuggestionRecord = ({
  int? declinedSkips,
  double? declinedValue,
  double? shownValue,
});

String suggestionRecordKey(String activityId, SuggestionDimension dimension) =>
    '$activityId|${dimension.wireName}';

/// Everything the app has offered and had refused, keyed by
/// `"<activityId>|<dimension>"`.
///
/// A [StateNotifier] over SharedPreferences on the [OutcomePromptNotifier]
/// model: the whole map is small — one entry per activity per dimension the
/// user has ever been asked about — so it is held in memory and rewritten
/// whole rather than paged.
class SuggestionRecordsNotifier
    extends StateNotifier<Map<String, SuggestionRecord>> {
  SuggestionRecordsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static Map<String, SuggestionRecord> _load(SharedPreferences prefs) {
    final raw = prefs.getString(declinedSuggestionsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value case final Map<String, dynamic> value)
            entry.key: (
              declinedSkips: (value['declined_skips'] as num?)?.toInt(),
              declinedValue: (value['declined_value'] as num?)?.toDouble(),
              shownValue: (value['shown_value'] as num?)?.toDouble(),
            ),
      };
    } catch (e) {
      // A corrupt value must not stop the feature working. Starting clean
      // costs at most one re-offered suggestion, which is the mildest possible
      // failure mode — the opposite of defaulting to "everything declined",
      // which would silence the feature permanently and invisibly.
      debugPrint('SuggestionRecordsNotifier: unreadable records — $e');
      return const {};
    }
  }

  /// The refusals that apply to [activityId], in the shape the rule expects.
  Map<SuggestionDimension, DeclinedSuggestion> declinedFor(String activityId) {
    final out = <SuggestionDimension, DeclinedSuggestion>{};
    for (final entry in state.entries) {
      final separator = entry.key.lastIndexOf('|');
      if (separator == -1) continue;
      if (entry.key.substring(0, separator) != activityId) continue;
      final dimension = suggestionDimensionFromWire(
        entry.key.substring(separator + 1),
      );
      if (dimension == null) continue;
      final skips = entry.value.declinedSkips;
      final value = entry.value.declinedValue;
      if (skips == null || value == null) continue;
      out[dimension] = (qualifyingSkips: skips, suggestedValue: value);
    }
    return out;
  }

  /// Whether [suggestion] has already been logged as shown for [activityId].
  bool hasBeenShown(String activityId, ConditionSuggestion suggestion) {
    final record = state[suggestionRecordKey(activityId, suggestion.dimension)];
    return record?.shownValue == suggestion.suggestedValue;
  }

  Future<void> markShown(
    String activityId,
    ConditionSuggestion suggestion,
  ) async {
    final key = suggestionRecordKey(activityId, suggestion.dimension);
    final existing = state[key];
    await _write({
      ...state,
      key: (
        declinedSkips: existing?.declinedSkips,
        declinedValue: existing?.declinedValue,
        shownValue: suggestion.suggestedValue,
      ),
    });
  }

  Future<void> markDeclined(
    String activityId,
    ConditionSuggestion suggestion,
  ) async {
    final key = suggestionRecordKey(activityId, suggestion.dimension);
    await _write({
      ...state,
      key: (
        declinedSkips: suggestion.qualifyingSkips,
        declinedValue: suggestion.suggestedValue,
        shownValue: suggestion.suggestedValue,
      ),
    });
  }

  /// Forgets everything about one dimension, on accept.
  ///
  /// The refusal is dropped along with the shown marker. The bound has moved,
  /// so any future suggestion for it is a genuinely new question measured
  /// against a threshold the user has just endorsed — suppressing it against
  /// an old refusal would be comparing against a number that no longer exists.
  Future<void> clear(String activityId, SuggestionDimension dimension) async {
    final next = {...state}..remove(suggestionRecordKey(activityId, dimension));
    await _write(next);
  }

  Future<void> _write(Map<String, SuggestionRecord> next) async {
    state = next;
    await _prefs.setString(
      declinedSuggestionsKey,
      jsonEncode({
        for (final entry in next.entries)
          entry.key: {
            if (entry.value.declinedSkips != null)
              'declined_skips': entry.value.declinedSkips,
            if (entry.value.declinedValue != null)
              'declined_value': entry.value.declinedValue,
            if (entry.value.shownValue != null)
              'shown_value': entry.value.shownValue,
          },
      }),
    );
  }
}

final suggestionRecordsProvider =
    StateNotifierProvider<
      SuggestionRecordsNotifier,
      Map<String, SuggestionRecord>
    >((ref) {
      return SuggestionRecordsNotifier(ref.watch(sharedPreferencesProvider));
    });

// ---------------------------------------------------------------------------
// The suggestion for one activity
// ---------------------------------------------------------------------------

/// The one change worth proposing for [activityId] right now, or null.
///
/// A synchronous provider over two async ones, the [activityOutcomeStatsProvider]
/// shape. The derivation is pure, so it recomputes for free when the clock is
/// overridden, when a day is answered, or when a suggestion is refused — the
/// last of which is what makes a dismissal take effect immediately without the
/// card having to hide itself.
final conditionSuggestionProvider =
    Provider.family<AsyncValue<ConditionSuggestion?>, String>((
      ref,
      activityId,
    ) {
      final now = ref.watch(nowProvider);
      // Watched, not read: dismissing rebuilds this, which is how the card
      // disappears.
      ref.watch(suggestionRecordsProvider);
      final declined = ref
          .read(suggestionRecordsProvider.notifier)
          .declinedFor(activityId);

      final activityAsync = ref.watch(activityDetailProvider(activityId));
      final outcomesAsync = ref.watch(activityOutcomesProvider(activityId));

      return activityAsync.when(
        loading: AsyncValue<ConditionSuggestion?>.loading,
        error: AsyncValue<ConditionSuggestion?>.error,
        data: (activity) => outcomesAsync.whenData(
          (rows) => suggestConditionChange(
            profile: activity?.conditionProfile,
            rows: rows,
            now: now(),
            declined: declined,
          ),
        ),
      );
    });

// ---------------------------------------------------------------------------
// Answering
// ---------------------------------------------------------------------------

/// Applies or refuses a suggestion, and logs either way.
class SuggestionController {
  SuggestionController(this._ref);
  final Ref _ref;

  /// Logs that [suggestion] was put in front of the user, at most once.
  ///
  /// Deduplicated on the suggested value rather than fired per render: the
  /// card is rebuilt on every theme change, every scroll that changes a
  /// constraint, and every screen re-entry, and a `shown` count inflated by
  /// those would make the accept rate of this feature unreadable.
  Future<void> markShown(
    String activityId,
    ConditionSuggestion suggestion,
  ) async {
    final records = _ref.read(suggestionRecordsProvider.notifier);
    if (records.hasBeenShown(activityId, suggestion)) return;
    await records.markShown(activityId, suggestion);
    await _log(suggestionShownEvent, activityId, suggestion);
  }

  /// Writes the accepted bound to the activity's condition profile.
  ///
  /// Returns the profile that was saved, so the caller can put the new value
  /// into the form it is showing. That matters more than it looks: the edit
  /// form holds its condition state locally and initialises it once, so a
  /// screen that persisted the change without also updating its own fields
  /// would show the old number and then write it straight back on the next
  /// Save.
  ///
  /// Throws on a failed write. Unlike a history write, this one must not be
  /// swallowed — the user asked for a change and has to be told if it did not
  /// happen.
  Future<ConditionProfile> accept({
    required Activity activity,
    required ConditionSuggestion suggestion,
  }) async {
    final activityId = activity.id;
    final current = activity.conditionProfile;
    if (activityId == null || current == null) {
      throw StateError('Cannot apply a suggestion to an unsaved activity');
    }

    final updated = applySuggestion(current, suggestion);
    await _ref
        .read(activityRepositoryProvider)
        .updateWithConditions(activity, updated);

    await _ref
        .read(suggestionRecordsProvider.notifier)
        .clear(activityId, suggestion.dimension);
    await _log(suggestionAcceptedEvent, activityId, suggestion);

    _ref.invalidate(activityDetailProvider(activityId));
    _ref.invalidate(activitiesProvider);
    return updated;
  }

  /// Records a refusal. The suggestion does not come back until the pattern
  /// behind it strengthens materially.
  Future<void> decline(
    String activityId,
    ConditionSuggestion suggestion,
  ) async {
    await _ref
        .read(suggestionRecordsProvider.notifier)
        .markDeclined(activityId, suggestion);
    await _log(suggestionDeclinedEvent, activityId, suggestion);
  }

  /// The stated threshold, the revealed one, and the evidence between them.
  ///
  /// The most valuable rows this app writes: everywhere else records what the
  /// user did, and these record what they said they wanted next to what they
  /// actually did about it. A decline is the more interesting of the two — it
  /// is a rejected hypothesis, and nothing else in the app collects one.
  Future<void> _log(
    String eventType,
    String activityId,
    ConditionSuggestion suggestion,
  ) async {
    await _ref
        .read(behavioralEventServiceProvider)
        .log(
          eventType,
          extra: {
            'activity_id': activityId,
            'dimension': suggestion.dimension.wireName,
            'current_value': suggestion.currentValue,
            'suggested_value': suggestion.suggestedValue,
            'qualifying_skips': suggestion.qualifyingSkips,
            'eligible_days': suggestion.eligibleDays,
          },
        );
  }
}

/// [profile] with the one bound named by [suggestion] moved, and nothing else.
///
/// Pure and exported so a test can assert the bounding property directly: one
/// field changes, every other field — including the enabled flags and the
/// precipitation level — comes through untouched.
ConditionProfile applySuggestion(
  ConditionProfile profile,
  ConditionSuggestion suggestion,
) => ConditionProfile(
  id: profile.id,
  activityId: profile.activityId,
  tempEnabled: profile.tempEnabled,
  tempMin: suggestion.dimension == SuggestionDimension.tempMin
      ? suggestion.suggestedValue
      : profile.tempMin,
  tempMax: suggestion.dimension == SuggestionDimension.tempMax
      ? suggestion.suggestedValue
      : profile.tempMax,
  precipEnabled: profile.precipEnabled,
  precipLevel: profile.precipLevel,
  windEnabled: profile.windEnabled,
  windMax: suggestion.dimension == SuggestionDimension.windMax
      ? suggestion.suggestedValue
      : profile.windMax,
  createdAt: profile.createdAt,
  updatedAt: profile.updatedAt,
);

final suggestionControllerProvider = Provider<SuggestionController>(
  (ref) => SuggestionController(ref),
);
