import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/features/home/outcome_prompt_provider.dart';

void main() {
  // A fixed clock: 2026-08-23 at 18:00, comfortably past the threshold.
  final evening = DateTime(2026, 8, 23, 18);
  final morning = DateTime(2026, 8, 23, 9);
  final today = DateTime(2026, 8, 23);

  group('outcomePromptKey', () {
    test('zero-pads month and day so keys sort and compare as text', () {
      expect(outcomePromptKey('a1', DateTime(2026, 1, 5)), 'a1|2026-01-05');
      expect(outcomePromptKey('a1', DateTime(2026, 12, 31)), 'a1|2026-12-31');
    });

    test('the same activity on different days gets different keys', () {
      expect(
        outcomePromptKey('a1', DateTime(2026, 8, 23)),
        isNot(outcomePromptKey('a1', DateTime(2026, 8, 24))),
      );
    });
  });

  group('shouldShowOutcomePrompt', () {
    test('shows for today after the threshold hour', () {
      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: evening,
          handled: const {},
        ),
        isTrue,
      );
    });

    test('stays hidden before the threshold hour', () {
      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: morning,
          handled: const {},
        ),
        isFalse,
      );
    });

    test('appears exactly at the threshold hour, not a minute earlier', () {
      DateTime at(int hour, int minute) =>
          DateTime(2026, 8, 23, hour, minute);

      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: at(outcomePromptHourThreshold - 1, 59),
          handled: const {},
        ),
        isFalse,
      );
      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: at(outcomePromptHourThreshold, 0),
          handled: const {},
        ),
        isTrue,
      );
    });

    test('never asks about a day that is not today', () {
      for (final day in [
        DateTime(2026, 8, 22), // yesterday
        DateTime(2026, 8, 24), // tomorrow
        DateTime(2025, 8, 23), // same date, wrong year
      ]) {
        expect(
          shouldShowOutcomePrompt(
            activityId: 'a1',
            matchedDay: day,
            now: evening,
            handled: const {},
          ),
          isFalse,
          reason: '$day',
        );
      }
    });

    test('stays hidden once answered or dismissed', () {
      final handled = {outcomePromptKey('a1', today)};

      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: evening,
          handled: handled,
        ),
        isFalse,
      );
    });

    test('handling one activity does not suppress another', () {
      final handled = {outcomePromptKey('a1', today)};

      expect(
        shouldShowOutcomePrompt(
          activityId: 'a2',
          matchedDay: today,
          now: evening,
          handled: handled,
        ),
        isTrue,
      );
    });

    test('yesterday\'s answer does not suppress today\'s prompt', () {
      final handled = {outcomePromptKey('a1', DateTime(2026, 8, 22))};

      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: today,
          now: evening,
          handled: handled,
        ),
        isTrue,
      );
    });
  });

  group('UTC forecast dates', () {
    // Tomorrow.io returns each day as a UTC instant — `2026-08-23T13:00:00Z`,
    // not a local midnight. Reading .day off one of those directly gives the
    // UTC calendar day, which is not the day the user is in. Caught on the
    // simulator, where the raw value arrives as 13:00Z.
    final utcDay = DateTime.utc(2026, 8, 23, 13);

    test('a UTC instant is matched against the local day', () {
      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: utcDay,
          now: utcDay.toLocal().add(const Duration(hours: 8)),
          handled: const {},
        ),
        isTrue,
      );
    });

    test('the key is built from the local day, not the UTC one', () {
      expect(
        outcomePromptKey('a1', utcDay),
        outcomePromptKey('a1', utcDay.toLocal()),
      );
    });

    test('the key checked matches the key markHandled would write', () {
      // shouldShow keys on matchedDay and markHandled is called with the same
      // value. Keying one side on `now` instead let the two disagree whenever
      // the local and UTC days differed.
      final written = outcomePromptKey('a1', utcDay);

      expect(
        shouldShowOutcomePrompt(
          activityId: 'a1',
          matchedDay: utcDay,
          now: utcDay.toLocal().add(const Duration(hours: 8)),
          handled: {written},
        ),
        isFalse,
      );
    });
  });

  group('pruneHandledKeys', () {
    test('keeps today and yesterday, drops anything older', () {
      final keys = {
        'a1|2026-08-23', // today
        'a2|2026-08-22', // yesterday
        'a3|2026-08-21', // too old
        'a4|2026-01-01', // much too old
      };

      expect(
        pruneHandledKeys(keys, evening),
        {'a1|2026-08-23', 'a2|2026-08-22'},
      );
    });

    test('prunes by calendar day, not by elapsed hours', () {
      // 00:30 today: yesterday's entries are ~30 minutes old but must survive,
      // which a naive Duration cutoff would get wrong.
      final justAfterMidnight = DateTime(2026, 8, 23, 0, 30);

      expect(
        pruneHandledKeys({'a1|2026-08-22'}, justAfterMidnight),
        {'a1|2026-08-22'},
      );
    });

    test('drops malformed entries rather than carrying them forever', () {
      final keys = {
        'a1|2026-08-23',
        'no-separator',
        'a2|not-a-date',
        'a3|',
      };

      expect(pruneHandledKeys(keys, evening), {'a1|2026-08-23'});
    });

    test('an activity id containing a pipe still parses by the last one', () {
      // lastIndexOf is what makes this safe.
      final key = outcomePromptKey('weird|id', today);
      expect(pruneHandledKeys({key}, evening), {key});
    });

    test('is a no-op on an empty set', () {
      expect(pruneHandledKeys(const {}, evening), isEmpty);
    });
  });
}
