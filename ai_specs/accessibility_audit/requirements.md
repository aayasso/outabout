# Requirements -- Accessibility Audit
# Created: 2026-05-19
# Status: draft

## Summary

Audit and fix accessibility across the entire app to meet WCAG 2.1 AA
standards. This covers tap targets, semantic labels, color contrast
across all five weather themes, text scaling support, form field labels,
and logical screen reader navigation order.

## User Stories

### Primary flow
- As a user with a screen reader, I want every interactive element to
  have a meaningful label so that I can navigate the app independently.
- As a user with low vision, I want sufficient color contrast on all
  text and interactive elements across all weather themes.

### Secondary flows
- As a user with motor impairments, I want all tappable elements to be
  at least 48x48dp so that I can reliably tap them.
- As a user who increases system text size, I want layouts to remain
  functional at 1.5x text scale factor.
- As a user with a screen reader, I want form fields to announce their
  labels and hints so that I know what to enter.

### Edge cases
- What happens when a theme has low contrast between textSecondary and
  background? Adjust the specific color or add a contrast-safe fallback
  for that text usage.
- What happens when text scaling causes overflow? Adjust layouts to
  accommodate -- use Flexible/Expanded, allow text wrapping, or cap
  maxLines with ellipsis.

## Acceptance Criteria

### Tap targets
- [ ] Every IconButton, GestureDetector, InkWell, and tappable widget
      has a minimum touch area of 48x48dp.
- [ ] Audit all screens: TodayTab, ActivitiesTab, SettingsTab,
      AddActivityScreen, ActivityDetailScreen, OnboardingScreen.

### Semantics labels
- [ ] Every icon-only button has a `tooltip` property.
- [ ] Every interactive card (GestureDetector wrapping a card) has a
      `Semantics` widget with a descriptive `label`.
- [ ] The theme override selector chips have Semantics labels including
      selected state. (Already exists -- verify.)
- [ ] Activity cards include activity name and match status in
      Semantics label. (Partially exists -- verify completeness.)
- [ ] Condition section toggles have Semantics labels describing the
      condition name and current state.

### Color contrast (WCAG AA)
- [ ] Normal text (under 18pt): 4.5:1 minimum contrast ratio against
      its background, on all five themes.
- [ ] Large text (18pt+ or 14pt bold): 3:1 minimum contrast ratio.
- [ ] Interactive elements: 3:1 against adjacent colors.
- [ ] Audit high-risk combinations:
  - Sunny: `textSecondary` (#6B5B3E) on `background` (#FFF8EE)
  - Snowy: `primary` (#90CAF9) on `background` (#F7F9FC)
  - Any theme: disabled/muted text on card backgrounds
- [ ] Document any color adjustments made.

### Text scaling
- [ ] App remains functional at `textScaleFactor` 1.5x on all screens.
- [ ] No text overflow or layout breakage at 1.5x.
- [ ] Sliders and compact UI elements gracefully handle enlarged text.

### Form fields
- [ ] All TextField widgets have proper `labelText` or `hintText`.
- [ ] TextFields use `InputDecoration` with `semanticCounterText` where
      applicable (character counters).

### Screen reader navigation order
- [ ] Tab order follows visual layout top-to-bottom, left-to-right on
      all screens.
- [ ] No orphaned focusable elements or focus traps.
- [ ] Bottom navigation bar items are reachable and labeled.

## Screens Involved

- All screens in the app (comprehensive audit).
- Primary focus on: TodayTab, ActivitiesTab, SettingsTab,
  AddActivityScreen, ActivityDetailScreen.

## Data Requirements

- Supabase tables: none
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? Yes -- contrast
  ratios must be verified per theme. Dark themes (rainy, night) and
  light themes (sunny, overcast, snowy) have different risk areas.

## Dependencies

- Should ship after Features 1-4 so the audit covers the category
  picker chips, filter chips, empty states, and form validation UI.
  Can technically run in parallel on the existing codebase, but a
  second pass would be needed for new widgets.

## Out of Scope

- Full VoiceOver/TalkBack end-to-end testing (manual QA)
- RTL language support
- Dynamic type support beyond 1.5x
- Custom accessibility themes or high-contrast mode

## Open Questions

- If Snowy theme's `primary` (#90CAF9) on `background` (#F7F9FC) fails
  contrast for interactive elements, should we darken the primary for
  snowy or add a border/underline? Recommendation: add a subtle border
  for interactive elements on snowy theme.
