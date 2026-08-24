import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/activity_day_outcome.dart';
import '../data/models/daily_forecast.dart';
import '../features/home/home_providers.dart';
import '../features/home/outcome_prompt_provider.dart';
import '../features/outcomes/outcome_providers.dart';
import '../features/outcomes/outcome_stats.dart';
import '../services/behavioral_event_service.dart';
import 'outcome_celebration.dart';

// Re-exported so the many importers of this file — and its tests — keep
// resolving these three names after the move to outcome_celebration.dart.
export 'outcome_celebration.dart'
    show OutcomeCelebration, celebrationLine, outcomeCelebrationDuration;

/// The optional reasons offered after a "Not today".
///
/// Three, deliberately. The answer is already recorded before these appear, so
/// this is a bonus question — a longer list reads as a form.
const List<({String value, String label})> outcomeReasons = [
  (value: 'too_busy', label: 'Too busy'),
  (value: 'conditions_wrong', label: 'Wrong conditions'),
  (value: 'not_feeling_it', label: 'Not feeling it'),
];

enum _Phase {
  /// "Did you go?" with Yes / Not today / dismiss.
  asking,

  /// A single confirmation beat after a Yes.
  celebrating,

  /// Optional reason chips after a "Not today".
  reasons,

  /// Finished. Falls back to the normal visibility rules, which now say no.
  settled,
}

/// Asks whether the user actually did the activity the app said was on.
///
/// This is the only place in OutAbout that records an *outcome*. Everything
/// else in the funnel records intent (the user saved an activity) or delivery
/// (a notification fired); without an answer here there is no way to tell a
/// match that worked from one that did not.
///
/// The answer now goes two places: `behavioral_events`, which is the dataset,
/// and `activity_day_outcomes`, which is the user's own history and the thing
/// the streak and heat map are built from.
///
/// Deliberately restrained: it renders nothing at all unless
/// [shouldShowOutcomePrompt] says so, it is inline rather than a dialog, and
/// answering settles it for the day. The reaction is one beat — never a
/// dialog, never a blocker, never a second ask.
class OutcomePrompt extends ConsumerStatefulWidget {
  const OutcomePrompt({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.matchedDay,
    required this.matchIsConstrained,
    this.forecastDay,
  });

  final String activityId;
  final String activityName;
  final DateTime matchedDay;

  /// Whether the day matched on conditions the user actually set.
  ///
  /// [evaluateDayMatch] passes an activity with no constraining profile on
  /// every day — correct as a filter, since nothing rules it out. Asking "did
  /// you go?" about it is not: the app never claimed the weather suited it,
  /// and the schedule card right above says so in as many words. Gating on the
  /// same predicate the card uses keeps the two from contradicting each other,
  /// and keeps the streak's opportunities and this question in step.
  final bool matchIsConstrained;

  /// The forecast for [matchedDay], so the outcome carries the weather it
  /// happened under. Null only if the forecast failed to load.
  final DailyForecast? forecastDay;

  @override
  ConsumerState<OutcomePrompt> createState() => _OutcomePromptState();
}

class _OutcomePromptState extends ConsumerState<OutcomePrompt> {
  _Phase _phase = _Phase.asking;
  String _celebration = '';
  Timer? _collapse;

  @override
  void dispose() {
    _collapse?.cancel();
    super.dispose();
  }

  /// Settles the day and records the answer.
  ///
  /// Ordering is deliberate and unchanged: `markHandled` first, so a failure
  /// in either write — both of which are swallowed — still leaves the prompt
  /// settled rather than asking again forever.
  Future<void> _answer(String eventType, {String? reason}) async {
    await ref
        .read(outcomePromptProvider.notifier)
        .markHandled(widget.activityId, widget.matchedDay);

    if (eventType.isEmpty) return; // Dismissal: settled, but not an outcome.

    await ref
        .read(behavioralEventServiceProvider)
        .log(
          eventType,
          extra: {'activity_id': widget.activityId, 'reason': ?reason},
          conditions: ref.read(conditionsSnapshotProvider)(
            forecastDay: widget.forecastDay,
          ),
        );
  }

  Future<void> _onYes() async {
    OutAboutHaptics.onActivitySave();
    // The phase flips before the writes so the row does not blink out: the
    // moment markHandled lands, shouldShowOutcomePrompt goes false.
    setState(() {
      _phase = _Phase.celebrating;
      _celebration = 'Logged.';
    });

    await _answer('activity_confirmed');

    // The history write is allowed to fail — offline, or a schema that has not
    // caught up with the build. What must not happen is the failure escaping
    // this handler: the collapse timer below would never be set and the
    // confirmation would sit on the card forever, with no way to dismiss it.
    // A plain "Logged." is the honest fallback; the answer itself is already
    // recorded in behavioral_events either way.
    OutcomeMilestone? milestone;
    OutcomeStats? stats;
    try {
      final result = await ref
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: widget.activityId,
            matchedDay: widget.matchedDay,
            outcome: DayOutcome.done,
          );
      milestone = result.milestone;
      stats = result.stats;
    } catch (e) {
      debugPrint('OutcomePrompt: could not record the completed day — $e');
    }
    if (!mounted) return;

    final line = celebrationLine(
      milestone: milestone,
      currentStreak: stats?.currentStreak ?? 0,
    );
    setState(() => _celebration = line);

    // VoiceOver gets the reaction too. Without this the row simply vanishes
    // and the answer appears to have done nothing.
    SemanticsService.sendAnnouncement(
      View.of(context),
      line,
      Directionality.of(context),
    );

    _collapse = Timer(outcomeCelebrationDuration, () {
      if (mounted) setState(() => _phase = _Phase.settled);
    });
  }

  Future<void> _onNo() async {
    OutAboutHaptics.onConditionToggle();
    setState(() => _phase = _Phase.reasons);

    // Recorded before the chips are even offered. The reason is a bonus; the
    // answer must never depend on the user engaging with the follow-up.
    await _answer('condition_match_ignored');
    await _record(DayOutcome.skipped);
  }

  Future<void> _onReason(String value) async {
    OutAboutHaptics.onConditionToggle();
    setState(() => _phase = _Phase.settled);

    await ref
        .read(behavioralEventServiceProvider)
        .log(
          'condition_match_ignored',
          extra: {'activity_id': widget.activityId, 'reason': value},
          conditions: ref.read(conditionsSnapshotProvider)(
            forecastDay: widget.forecastDay,
          ),
        );
    await _record(DayOutcome.skipped, reason: value);
  }

  /// Writes an outcome, swallowing failures.
  ///
  /// Symmetric with the Yes path and with `BehavioralEventService.log`: a
  /// history write that fails must never surface as a red screen over a card
  /// the user has already answered.
  Future<void> _record(String outcome, {String? reason}) async {
    try {
      await ref
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: widget.activityId,
            matchedDay: widget.matchedDay,
            outcome: outcome,
            reason: reason,
          );
    } catch (e) {
      debugPrint('OutcomePrompt: could not record the outcome — $e');
    }
  }

  Future<void> _onDismiss() async {
    OutAboutHaptics.onConditionToggle();
    // Read before the setState: dismissing the *question* has to settle the
    // day, while dismissing the reason chips must not — the "Not today" is
    // already recorded by then, and re-running _answer would be a second
    // event for one answer.
    final wasAsking = _phase == _Phase.asking;
    setState(() => _phase = _Phase.settled);
    if (wasAsking) await _answer('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final handled = ref.watch(outcomePromptProvider);
    final now = ref.watch(nowProvider)();

    // An in-flight reaction outranks the visibility rules, which went false the
    // instant markHandled landed.
    switch (_phase) {
      case _Phase.celebrating:
        return OutcomeCelebration(text: _celebration, colors: colors);
      case _Phase.reasons:
        return _ReasonRow(
          colors: colors,
          activityName: widget.activityName,
          onSelected: _onReason,
          onDismiss: _onDismiss,
        );
      case _Phase.asking:
      case _Phase.settled:
        break;
    }

    if (!widget.matchIsConstrained) return const SizedBox.shrink();

    final visible = shouldShowOutcomePrompt(
      activityId: widget.activityId,
      matchedDay: widget.matchedDay,
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
          label: 'Did you go to ${widget.activityName} today?',
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
                  semanticLabel: 'Yes, I went to ${widget.activityName}',
                  colors: colors,
                  emphasised: true,
                  onTap: _onYes,
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                _OutcomeChip(
                  label: 'Not today',
                  semanticLabel: 'No, I did not go to ${widget.activityName}',
                  colors: colors,
                  emphasised: false,
                  onTap: _onNo,
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
                    tooltip:
                        'Dismiss the question about ${widget.activityName}',
                    onPressed: _onDismiss,
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

/// Optional "why not?" chips. Skippable by ignoring them entirely.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.colors,
    required this.activityName,
    required this.onSelected,
    required this.onDismiss,
  });

  final WeatherThemeColors colors;
  final String activityName;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Optional: why not? Skip by ignoring this.',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
              vertical: OutAboutSpacing.sm,
            ),
            // A Wrap, not a Row: three chips plus a close button overflow at
            // large text sizes, and the reasons are the last thing that should
            // be clipped.
            child: Wrap(
              spacing: OutAboutSpacing.sm,
              runSpacing: OutAboutSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final reason in outcomeReasons)
                  // IntrinsicWidth, because a Wrap hands its children loose
                  // constraints and _OutcomeChip's Container centres its text
                  // — which makes it expand to the full width on offer. Three
                  // full-bleed stacked buttons read as a form, which is the
                  // one thing this follow-up must not be.
                  IntrinsicWidth(
                    child: _OutcomeChip(
                      label: reason.label,
                      semanticLabel:
                          '${reason.label} — why I did not go to $activityName',
                      colors: colors,
                      emphasised: false,
                      onTap: () => onSelected(reason.value),
                    ),
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
                    tooltip: 'Skip saying why',
                    onPressed: onDismiss,
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
