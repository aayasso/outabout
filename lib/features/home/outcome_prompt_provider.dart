import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/weather_theme_provider.dart';
import 'home_providers.dart';

// ---------------------------------------------------------------------------
// Eligibility
// ---------------------------------------------------------------------------

/// The hour, local time, from which "Did you go?" is a fair question.
///
/// Asking at 08:00 about a day that has not happened yet produces an answer
/// that means nothing, and reads as nagging. 16:00 is late enough that most of
/// the day is behind the user and early enough that they still remember it.
const int outcomePromptHourThreshold = 16;

/// Identity of one prompt: one activity, one day.
///
/// The day is part of the key so a recurring match asks again tomorrow, and
/// only tomorrow — answering or dismissing settles that activity for that
/// calendar day and nothing more.
///
/// Normalises to local time first. Forecast dates arrive from Tomorrow.io as
/// UTC instants — a day reads as `2026-08-23T13:00:00Z` — so reading `.day`
/// off one directly gives the UTC calendar day, which is not the day the user
/// is living in. Every caller goes through here, so the key the prompt checks
/// and the key [OutcomePromptNotifier.markHandled] writes cannot drift apart.
String outcomePromptKey(String activityId, DateTime day) {
  final local = day.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final dayOfMonth = local.day.toString().padLeft(2, '0');
  return '$activityId|${local.year}-$month-$dayOfMonth';
}

bool _isSameDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

/// Whether the outcome prompt should be visible for this activity right now.
///
/// Pure so the rules are testable without a widget tree or a clock override.
/// All three conditions must hold:
///   - the match being asked about is *today's* (never a past or future day),
///   - it is at or past [outcomePromptHourThreshold],
///   - this activity/day pair has not already been answered or dismissed.
bool shouldShowOutcomePrompt({
  required String activityId,
  required DateTime matchedDay,
  required DateTime now,
  required Set<String> handled,
}) {
  if (!_isSameDay(matchedDay, now)) return false;
  if (now.toLocal().hour < outcomePromptHourThreshold) return false;
  // Keyed on matchedDay, which is what markHandled writes. Keying one side on
  // `now` instead would silently disagree whenever the two land on different
  // local days.
  return !handled.contains(outcomePromptKey(activityId, matchedDay));
}

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------

/// Drops entries older than [now] minus one day.
///
/// Without this the set grows without bound for the life of the install. Two
/// days is all that is ever consulted — today's entries suppress today's
/// prompts, and yesterday's are kept only so an app open either side of
/// midnight cannot resurrect a prompt the user already dealt with.
Set<String> pruneHandledKeys(Set<String> keys, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.subtract(const Duration(days: 1));

  return keys.where((key) {
    final separator = key.lastIndexOf('|');
    if (separator == -1) return false;
    final parsed = DateTime.tryParse(key.substring(separator + 1));
    if (parsed == null) return false;
    return !parsed.isBefore(cutoff);
  }).toSet();
}

/// The set of `"<activityId>|<yyyy-MM-dd>"` prompts already handled.
///
/// Shared by the schedule card and the activity detail screen so answering in
/// one place suppresses the prompt in the other.
class OutcomePromptNotifier extends StateNotifier<Set<String>> {
  OutcomePromptNotifier(this._prefs, this._now) : super(_load(_prefs, _now()));

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static Set<String> _load(SharedPreferences prefs, DateTime now) {
    final raw = prefs.getString(outcomePromptHandledKey);
    if (raw == null) return <String>{};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return pruneHandledKeys(decoded.cast<String>().toSet(), now);
    } catch (e) {
      // A corrupt value must not stop the app from asking. Start clean.
      debugPrint('OutcomePromptNotifier: unreadable handled set — $e');
      return <String>{};
    }
  }

  /// Records that this activity's prompt for today is settled.
  ///
  /// Called for all three outcomes — yes, not today, and dismiss — because the
  /// rule is once per activity per day regardless of the answer.
  Future<void> markHandled(String activityId, DateTime day) async {
    final next = pruneHandledKeys({
      ...state,
      outcomePromptKey(activityId, day),
    }, _now());
    state = next;
    await _prefs.setString(outcomePromptHandledKey, jsonEncode(next.toList()));
  }
}

final outcomePromptProvider =
    StateNotifierProvider<OutcomePromptNotifier, Set<String>>((ref) {
      return OutcomePromptNotifier(
        ref.watch(sharedPreferencesProvider),
        ref.watch(nowProvider),
      );
    });
