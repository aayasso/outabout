// The one beat of acknowledgement an answer earns, and the sentence it says.
//
// Lifted out of `outcome_prompt.dart` when the heat map's retroactive sheet
// needed the same beat. Answering a day from the record and answering it from
// the prompt are the same act, and a milestone crossed on one path but silent
// on the other would make the reaction look arbitrary — the user would learn
// that some answers count and some do not, which is the opposite of true.
//
// `outcome_prompt.dart` re-exports all three symbols, so existing importers
// are unaffected.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../features/outcomes/outcome_stats.dart';

/// How long the confirmation stays up before it goes away.
///
/// Long enough to read a short sentence, short enough that it never becomes
/// something to dismiss. Unaffected by Reduce Motion: the sentence is
/// information, and hiding it faster would be worse, not calmer.
const Duration outcomeCelebrationDuration = Duration(milliseconds: 2200);

/// What to say back when the user says they went.
///
/// A milestone outranks a streak: crossing 10 is the more interesting fact,
/// and saying both would be two sentences where the moment wants one.
///
/// 'Logged.' is the floor, and it is also the honest fallback when the history
/// write failed — the answer went to `behavioral_events` either way, and
/// claiming a streak we could not read back would be worse than saying little.
String celebrationLine({
  required OutcomeMilestone? milestone,
  required int currentStreak,
}) {
  switch (milestone) {
    case OutcomeMilestone.first:
      return 'First one in the books.';
    case OutcomeMilestone.five:
      return "That's five times out.";
    case OutcomeMilestone.ten:
      return 'Ten times out — this one has stuck.';
    case OutcomeMilestone.twentyFive:
      return 'Twenty-five. Call it a habit.';
    case null:
      break;
  }
  if (currentStreak >= 2) return '$currentStreak matched days in a row.';
  return 'Logged.';
}

/// One beat of acknowledgement. No confetti, no dialog, no dismiss control —
/// it takes itself away.
class OutcomeCelebration extends StatelessWidget {
  const OutcomeCelebration({
    super.key,
    required this.text,
    required this.colors,
  });

  final String text;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
          // The text is announced explicitly on arrival; leaving it as a live
          // label as well would say it twice.
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
              vertical: OutAboutSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                      Icons.check_circle,
                      size: 18,
                      color: colors.primaryInteractive,
                    )
                    .animateSafely(context)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: OutAboutAnimations.standardDuration,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(width: OutAboutSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: OutAboutTypography.labelMedium(
                      colors,
                    ).copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        )
        .animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration);
  }
}
