import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/daily_forecast.dart';
import '../features/home/home_providers.dart';
import '../features/home/outcome_prompt_provider.dart';
import '../services/behavioral_event_service.dart';

/// Asks whether the user actually did the activity the app said was on.
///
/// This is the only place in OutAbout that records an *outcome*. Everything
/// else in the funnel records intent (the user saved an activity) or delivery
/// (a notification fired); without an answer here there is no way to tell a
/// match that worked from one that did not.
///
/// Deliberately restrained: it renders nothing at all unless
/// [shouldShowOutcomePrompt] says so, it is inline rather than a dialog, and
/// answering or dismissing settles it for the day. See
/// `outcome_prompt_provider.dart` for the rules.
class OutcomePrompt extends ConsumerWidget {
  const OutcomePrompt({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.matchedDay,
    this.forecastDay,
  });

  final String activityId;
  final String activityName;
  final DateTime matchedDay;

  /// The forecast for [matchedDay], so the outcome carries the weather it
  /// happened under. Null only if the forecast failed to load.
  final DailyForecast? forecastDay;

  Future<void> _answer(WidgetRef ref, String eventType) async {
    OutAboutHaptics.onConditionToggle();

    // Recorded before the event so a logging failure — which log() swallows by
    // design — still leaves the prompt settled rather than re-asking forever.
    await ref
        .read(outcomePromptProvider.notifier)
        .markHandled(activityId, matchedDay);

    if (eventType.isEmpty) return; // Dismissal: settled, but not an outcome.

    await ref
        .read(behavioralEventServiceProvider)
        .log(
          eventType,
          extra: {'activity_id': activityId},
          conditions: ref.read(conditionsSnapshotProvider)(
            forecastDay: forecastDay,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final handled = ref.watch(outcomePromptProvider);
    final now = ref.watch(nowProvider)();

    final visible = shouldShowOutcomePrompt(
      activityId: activityId,
      matchedDay: matchedDay,
      now: now,
      handled: handled,
    );
    if (!visible) return const SizedBox.shrink();

    // `explicitChildNodes`, because the three controls below must stay
    // individually focusable — a plain label wrapper merges them into one
    // node and the answer becomes unreachable.
    return Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Did you go to $activityName today?',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
              vertical: OutAboutSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      'Did you go?',
                      style: OutAboutTypography.labelMedium(colors),
                    ),
                  ),
                ),
                _OutcomeChip(
                  label: 'Yes',
                  semanticLabel: 'Yes, I went to $activityName',
                  colors: colors,
                  emphasised: true,
                  onTap: () => _answer(ref, 'activity_confirmed'),
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                _OutcomeChip(
                  label: 'Not today',
                  semanticLabel: 'No, I did not go to $activityName',
                  colors: colors,
                  emphasised: false,
                  onTap: () => _answer(ref, 'condition_match_ignored'),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    tooltip: 'Dismiss the question about $activityName',
                    onPressed: () => _answer(ref, ''),
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

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({
    required this.label,
    required this.semanticLabel,
    required this.colors,
    required this.emphasised,
    required this.onTap,
  });

  final String label;

  /// What the screen reader says. The visible label is a bare "Yes"; on its
  /// own node that gives no clue what is being answered.
  final String semanticLabel;
  final WeatherThemeColors colors;
  final bool emphasised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      // The chip's own Text is excluded so the announcement is the sentence
      // above and not "Yes, I went to X. Yes." The tap has to be declared
      // alongside it: excluding the subtree drops the InkWell's action.
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OutAboutRadius.full),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: emphasised ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(OutAboutRadius.full),
            border: Border.all(color: colors.divider),
          ),
          child: Text(
            label,
            style: OutAboutTypography.labelLarge(
              colors,
            ).copyWith(color: emphasised ? colors.onPrimary : colors.text),
          ),
        ),
      ),
    );
  }
}
