# Requirements -- Accessibility Audit
# Created: 2026-05-19
# Reconciled and executed: 2026-08-23
# Status: complete

## Summary

Audit and fix accessibility across the app to WCAG 2.1 AA, plus the
platform-specific expectations iOS adds: VoiceOver semantics, Dynamic Type
at the accessibility sizes, and Reduce Motion.

## Reconciliation note (2026-08-23)

The 2026-05-19 draft was written before the schedule view, the animated
weather scene, the Find & book sheet, the outcome prompt, account deletion
and the shared condition form existed, and none of its fixes were ever
applied. What survived reconciliation and what did not:

**Still open and now fixed.** Every contrast figure in the original
`design.md` reproduced exactly against `lib/core/theme.dart` on 2026-08-23:
sunny `primary` 1.92:1, overcast `primary` 2.46:1, snowy `primary` 1.66:1,
overcast `textSecondary` 3.87:1, snowy `textSecondary` 4.14:1. The
`primaryInteractive` token the draft designed did not exist in the code.

**Stale, dropped.** The draft audits `today_tab.dart` and its
`_WeatherSummaryCard`; the Today tab was replaced by `schedule_tab.dart` in
commit `6f51462`. It also names two tap-target fixes on the morning time
picker and the days-before stepper, both removed in commit `3d3e4f2`. All
its line references predate commit `9cf60a1` and no longer resolve.

**Never covered.** Everything listed under Scope below apart from the
original five contrast findings.

## Scope

Every current screen and interactive surface:

- Schedule tab, both layouts (`schedule_tab.dart`)
- The animated weather scene behind it (`weather_scene/`)
- Activities tab, category filter chips (`activities_tab.dart`)
- Settings: theme override, temperature unit, schedule layout, legal links,
  sign out, delete account and its type-DELETE dialog (`settings_tab.dart`)
- Activity detail and Add activity
- The shared condition form, including the two-option precipitation picker
  (`features/shared/condition_profile_form.dart`)
- Find & book sheet (`widgets/find_and_book_sheet.dart`)
- "Did you go?" outcome prompt (`widgets/outcome_prompt.dart`)
- Category chip picker and create-category dialog
- Onboarding, all six pages, plus `ProgressDots`

## Acceptance criteria

### Colour contrast
- [x] Normal text (under 18px, or under 14px bold) at 4.5:1 in all five
      palettes, against the **rendered** background — for the Schedule tab
      that is `surface` at 0.90 over the graded veil over the scene, not the
      flat token.
- [x] Large text and non-text UI at 3:1.
- [x] Ink on a `primary` fill at 4.5:1 (FAB, ElevatedButton, selected
      segment, outcome chip, active theme chip, switch thumb).
- [x] No text anywhere in the Schedule tab painted directly on the scene.

### VoiceOver
- [x] Every interactive element has a label, and roles and states come from
      the node rather than being spelled into the label text.
- [x] No control announces a role it cannot perform: a node flagged
      `isButton` carries a tap action.
- [x] Nothing is announced twice — a container label and the text inside it
      do not both reach the user.
- [x] The weather scene contributes no semantics.
- [x] Modals are escapable and carry a named dismiss control.
- [x] The type-DELETE dialog: the destructive action states what it does and
      why it is dimmed; arming it is announced; failures are a live region.

### Touch targets
- [x] Every tappable control at least 44pt (project standard 48).

### Dynamic Type
- [x] No overflow at `textScaler` 1.0, 1.5, 2.0 and 3.0 (AX5).

### Reduce Motion
- [x] Every animation in the app honours the platform flag, not just the
      weather scene: shimmer, entrance animations, route transitions, the
      theme cross-fade, the condition cross-fade and the progress dots.

## Out of scope

RTL layout; custom high-contrast themes; Switch Control and Voice Control
beyond what the semantics tree already provides; audio transcription of
VoiceOver speech (see `design.md`, Verification).
