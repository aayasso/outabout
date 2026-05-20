# Design -- Accessibility Audit
# Created: 2026-05-19
# Requires: requirements.md approved

## Audit Methodology

This is a code-level audit, not a runtime test. Each task reads the
relevant screen files, checks against WCAG 2.1 AA criteria, and fixes
violations. The audit covers widgets that exist after Features 1-4 ship
(category chips, filter chips, form validation, empty states).

## Contrast Ratio Analysis

The Sunny primary color (#F5A623) and Overcast primary (#4A9EFF) have
been failing WCAG AA contrast as text foreground for the entire history
of the app. This audit surfaces those pre-existing failures and fixes
them via the new `primaryInteractive` token. No regression — these
widgets were never compliant.

Computed using the WCAG relative luminance formula:
```
L = 0.2126 * R_linear + 0.7152 * G_linear + 0.0722 * B_linear
contrast = (L_lighter + 0.05) / (L_darker + 0.05)
```
where each sRGB channel is gamma-corrected per the sRGB spec.

### Full Contrast Table (computed, not estimated)

| Theme | Pair | FG | BG | Ratio | AA Normal (4.5:1) | AA Large (3:1) |
|---|---|---|---|---|---|---|
| **sunny** | text on bg | #1A1A1A | #FFF8EE | 16.50:1 | PASS | PASS |
| sunny | text on card | #1A1A1A | #FFFFFF | 17.40:1 | PASS | PASS |
| sunny | textSecondary on bg | #6B5B3E | #FFF8EE | 6.24:1 | PASS | PASS |
| sunny | textSecondary on card | #6B5B3E | #FFFFFF | 6.58:1 | PASS | PASS |
| **sunny** | **primary on bg** | **#F5A623** | **#FFF8EE** | **1.92:1** | **FAIL** | **FAIL** |
| **sunny** | **primary on card** | **#F5A623** | **#FFFFFF** | **2.03:1** | **FAIL** | **FAIL** |
| **overcast** | text on bg | #2C3E50 | #F0F2F5 | 9.79:1 | PASS | PASS |
| overcast | text on card | #2C3E50 | #FFFFFF | 10.98:1 | PASS | PASS |
| **overcast** | **textSecondary on bg** | **#6B7B8D** | **#F0F2F5** | **3.87:1** | **FAIL** | PASS |
| **overcast** | **textSecondary on card** | **#6B7B8D** | **#FFFFFF** | **4.34:1** | **FAIL** | PASS |
| **overcast** | **primary on bg** | **#4A9EFF** | **#F0F2F5** | **2.46:1** | **FAIL** | **FAIL** |
| **overcast** | **primary on card** | **#4A9EFF** | **#FFFFFF** | **2.75:1** | **FAIL** | **FAIL** |
| **rainy** | text on bg | #E8EDF2 | #1A2332 | 13.40:1 | PASS | PASS |
| rainy | text on card | #E8EDF2 | #243447 | 10.76:1 | PASS | PASS |
| rainy | textSecondary on bg | #9EACBA | #1A2332 | 6.81:1 | PASS | PASS |
| rainy | textSecondary on card | #9EACBA | #243447 | 5.47:1 | PASS | PASS |
| rainy | primary on bg | #4A9EFF | #1A2332 | 5.73:1 | PASS | PASS |
| rainy | primary on card | #4A9EFF | #243447 | 4.60:1 | PASS | PASS |
| **snowy** | text on bg | #263238 | #F7F9FC | 12.48:1 | PASS | PASS |
| snowy | text on card | #263238 | #FFFFFF | 13.16:1 | PASS | PASS |
| **snowy** | **textSecondary on bg** | **#607D8B** | **#F7F9FC** | **4.14:1** | **FAIL** | PASS |
| **snowy** | **textSecondary on card** | **#607D8B** | **#FFFFFF** | **4.37:1** | **FAIL** | PASS |
| **snowy** | **primary on bg** | **#90CAF9** | **#F7F9FC** | **1.66:1** | **FAIL** | **FAIL** |
| **snowy** | **primary on card** | **#90CAF9** | **#FFFFFF** | **1.75:1** | **FAIL** | **FAIL** |
| **night** | text on bg | #E8EDF2 | #0D1117 | 16.07:1 | PASS | PASS |
| night | text on card | #E8EDF2 | #161B22 | 14.68:1 | PASS | PASS |
| night | textSecondary on bg | #8B949E | #0D1117 | 6.15:1 | PASS | PASS |
| night | textSecondary on card | #8B949E | #161B22 | 5.62:1 | PASS | PASS |
| night | primary on bg | #4A9EFF | #0D1117 | 6.87:1 | PASS | PASS |
| night | primary on card | #4A9EFF | #161B22 | 6.28:1 | PASS | PASS |

### Summary of Failures

| Theme | Token | Issue | Severity |
|---|---|---|---|
| Sunny | primary (#F5A623) | 1.92-2.03:1 on light backgrounds | Critical — fails AA Large too |
| Overcast | primary (#4A9EFF) | 2.46-2.75:1 on light backgrounds | Critical — fails AA Large too |
| Overcast | textSecondary (#6B7B8D) | 3.87-4.34:1 on light backgrounds | Moderate — passes AA Large, fails Normal |
| Snowy | primary (#90CAF9) | 1.66-1.75:1 on light backgrounds | Critical — fails AA Large too |
| Snowy | textSecondary (#607D8B) | 4.14-4.37:1 on light backgrounds | Moderate — passes AA Large, fails Normal |

## Color Fixes

### Fix 1: New token `primaryInteractive`

Add a new `primaryInteractive` field to `WeatherThemeColors` in
`lib/core/theme.dart`. This token is used for all interactive text
(TextButtons, links, "Enable location", "Clear filters", "Try again")
that currently use `colors.primary` as foreground text color against
light backgrounds. The `primary` color itself is NOT changed — it
continues to be used for backgrounds (chip fills, button fills, FAB
fill, slider active track, switch active track) where contrast against
the foreground text is not the issue.

| Theme | primary (unchanged) | primaryInteractive (new) | vs background | vs card |
|---|---|---|---|---|
| Sunny | #F5A623 | #A05E00 | 4.86:1 PASS | 5.13:1 PASS |
| Overcast | #4A9EFF | #1565C0 | 5.12:1 PASS | 5.75:1 PASS |
| Rainy | #4A9EFF | #4A9EFF (same) | 5.73:1 PASS | 4.60:1 PASS |
| Snowy | #90CAF9 | #1565C0 | 5.45:1 PASS | 5.75:1 PASS |
| Night | #4A9EFF | #4A9EFF (same) | 6.87:1 PASS | 6.28:1 PASS |

Widgets that must switch from `colors.primary` to
`colors.primaryInteractive` for text color:
- All `TextButton` child text using `.copyWith(color: colors.primary)`
- "Enable location" in settings_tab.dart
- "Clear filters" in activities_tab.dart `_FilteredEmptyState`
- "Try again" / "Retry" links in error states
- "Enable" in `_LocationPermissionBanner`
- Filter chip selected text (if using primary as text — verify)
- Any `OutAboutTypography.labelLarge(colors).copyWith(color: colors.primary)`

Widgets that keep `colors.primary` (no change needed):
- FAB `backgroundColor`
- ElevatedButton (uses primary as background, text is white/black)
- Switch `activeTrackColor`
- Slider `activeColor`
- Chip selected background (alpha fill, not text)
- NavigationBar `indicatorColor`

### Fix 2: Darken textSecondary on Overcast and Snowy

Modify existing `textSecondary` values in `WeatherThemeColors` for
two themes. This is a color value adjustment within the existing token
system, not a structural refactor.

| Theme | textSecondary (before) | textSecondary (after) | vs background | vs card |
|---|---|---|---|---|
| Overcast | #6B7B8D | #5A6978 | 5.02:1 PASS | 5.64:1 PASS |
| Snowy | #607D8B | #506A78 | 5.42:1 PASS | 5.72:1 PASS |

These darkened values maintain the same blue-grey hue family as the
originals, just shifted darker to clear the 4.5:1 threshold. The visual
change is subtle — body captions and labels will be slightly darker on
these two themes.

### Fix 3: Update ai_docs/design_system.md

After modifying theme.dart, update the hex values in
`ai_docs/design_system.md` to match the new overcast textSecondary
(#5A6978) and snowy textSecondary (#506A78). Add `primaryInteractive`
to the token documentation.

## Audit — Tap Targets

### Current State

| Widget | File:Line | Current Size | Status |
|---|---|---|---|
| Close IconButton (AddActivity) | add_activity_screen.dart:138 | 48dp (default) | OK |
| Back IconButton (ActivityDetail) | activity_detail_screen.dart:284 | 48dp (default) | OK |
| Activity list card GestureDetector | activities_tab.dart:179 | Full card width x ~80dp | OK |
| Today matched card GestureDetector | today_tab.dart:601 | Full card width x ~60dp | OK |
| Today unmatched card GestureDetector | today_tab.dart:725 | Full card width x ~60dp | OK |
| Theme selector chips | settings_tab.dart:371 | Variable — **audit needed** |
| Morning time picker GestureDetector | activity_detail_screen.dart:816 | Padding gives ~40dp height — **needs fix** |
| Decrease/Increase days IconButtons | activity_detail_screen.dart:888-914 | 48x48 SizedBox wrapping | OK |
| Settings row InkWell | settings_tab.dart:243 | ConstrainedBox minHeight 48 | OK |
| Sign out InkWell | settings_tab.dart:485 | ConstrainedBox minHeight 48 | OK |
| Category chips (Feature 1) | category_chip_picker.dart | Design spec says 48dp target | Verify |
| Filter chips (Feature 2) | activities_tab.dart | Design spec says 48dp target | Verify |
| FABs (Today + Activities) | Both tabs | 56dp (default FAB) | OK |

### Fixes Needed
- Theme selector chips: verify each chip meets 48dp minimum. If under,
  wrap in `SizedBox(height: 48)` or add vertical padding.
- Morning time picker: add `constraints: BoxConstraints(minHeight: 48)`
  to the Container, or increase vertical padding.

## Audit — Semantics Labels

### Current State

| Widget | File:Line | Has Semantics? | Status |
|---|---|---|---|
| Activity card (ActivitiesTab) | activities_tab.dart:176 | Yes: "Activity: {name}" | **Missing condition info** |
| Matched card (TodayTab) | today_tab.dart:597 | Yes: "Activity: {name}, conditions met" | OK |
| Unmatched card (TodayTab) | today_tab.dart:721 | Yes: "Activity: {name}, conditions not met" | OK |
| Theme chips (Settings) | settings_tab.dart:380 | Yes: "Theme: {label}, selected" | OK |
| Condition toggle (shared) | condition_profile_form.dart:60 | Yes: "{title} condition toggle" | **Missing state** |
| Morning time picker | activity_detail_screen.dart:824 | Yes: "Notification time: {time}. Tap to change." | OK |
| Days before stepper | activity_detail_screen.dart:888-914 | Yes: tooltip on both buttons | OK |
| Onboarding category chips | first_activity_page.dart:167 | Yes: "{label} category, selected" | OK |
| Onboarding buttons | onboarding_button.dart:27 | Yes: label + button | OK |
| Navigation bar items | home_screen.dart:38-73 | Yes: tooltip on each | OK |
| FABs (Today + Activities) | Both tabs | Yes: tooltip "Add activity" | OK |
| Close button (AddActivity) | add_activity_screen.dart:139 | Yes: tooltip "Close" | OK |
| Back button (ActivityDetail) | activity_detail_screen.dart:290 | Yes: tooltip "Go back" | OK |
| Dismiss swipe (ActivitiesTab) | activities_tab.dart:148 | No explicit semantics | **Needs fix** |
| Category chips (Feature 1) | category_chip_picker.dart | Not yet built | Verify |
| Filter chips (Feature 2) | activities_tab.dart | Not yet built | Verify |

### Fixes Needed
- Activities tab card: add condition count to Semantics label.
- Condition toggle: add enabled/disabled state to label.
- Dismissible: add Semantics label for swipe action.
- Category chips (Feature 1): verify name + selected state.
- Filter chips (Feature 2): verify name + selected state.

## Audit — Form Fields

### Current State

| Field | File | Has label/hint? | Status |
|---|---|---|---|
| Name (AddActivity) | add_activity_screen.dart:299 | hintText only (pre-Feature 4) | Feature 4 adds labelText — verify |
| Notes (AddActivity) | add_activity_screen.dart:324 | hintText only (pre-Feature 4) | Feature 4 adds labelText — verify |
| Name (ActivityDetail) | activity_detail_screen.dart:338 | labelText "Activity Name" | OK |
| Notes (ActivityDetail) | activity_detail_screen.dart:356 | labelText "Notes (optional)" | OK |
| Email (AuthPage) | auth_page.dart:170 | Semantics label "Email address" | OK |
| Password (AuthPage) | auth_page.dart:190 | Semantics label "Password" | OK |
| Activity name (FirstActivity) | first_activity_page.dart:217 | Semantics label "Activity name" | OK |

### Fixes Needed
- Verify Feature 4 added `labelText` to AddActivity fields.
- Add `semanticCounterText` to notes fields with character counters.

## Audit — Text Scaling

Text scaling at 1.5x cannot be verified by Claude Code — it requires
visual inspection in a simulator. The approach is split:
- **Claude Code:** applies preemptive fixes to known risk areas
- **User:** manually verifies in simulator at 1.5x

Known risk areas for preemptive fixes:
- Slider label rows (temperature min/max, wind value) — Row may overflow
- Category/filter chip text — may clip in constrained chips
- Settings rows — trailing widget may collide with label
- Weather summary card — temperature display in Row
- Condition chip Wrap — verify it wraps, not overflows
- Days before stepper — count text + buttons in Row

Fix patterns:
- Replace `Row` with `Wrap` where horizontal overflow is possible
- Add `Flexible` wrapping on text in tight Rows
- Add `maxLines: 1` + `overflow: TextOverflow.ellipsis` on constrained
  single-line labels
- Chip rows already use `SingleChildScrollView` — verify text isn't
  clipped within individual chips

## Audit — Navigation Order

Flutter's default focus traversal follows widget tree order, which
matches visual order in all OutAbout screens. No custom
`FocusTraversalGroup` or `FocusOrder` needed unless the audit discovers
a specific problem.

Navigation bar items are already labeled with tooltips and use Flutter's
built-in NavigationBar accessibility support.

## Contrast Fixes Log

Document every color adjustment during implementation:

| Location | Token | Before | After | Ratio Before | Ratio After | Reason |
|---|---|---|---|---|---|---|
| theme.dart: overcast | textSecondary | #6B7B8D | #5A6978 | 3.87:1 | 5.02:1 | AA Normal fail on bg |
| theme.dart: snowy | textSecondary | #607D8B | #506A78 | 4.14:1 | 5.42:1 | AA Normal fail on bg |
| theme.dart: all themes | primaryInteractive | (new) | see table above | N/A | all ≥4.86:1 | primary fails as text color on light themes |
| design_system.md | overcast textSecondary | #6B7B8D | #5A6978 | — | — | Doc sync |
| design_system.md | snowy textSecondary | #607D8B | #506A78 | — | — | Doc sync |

## Text Scaling Fixes Log

Document every layout fix for text scaling during implementation:

| Location | Widget | Fix Applied | Reason |
|---|---|---|---|
| (filled during implementation) | | | |

## Edge Cases

| Scenario | Behavior |
|---|---|
| Primary used as text on light theme | Use `primaryInteractive` instead |
| Primary used as background fill | Keep `primary` — text on fill is white/black, not the issue |
| textSecondary darkened on overcast/snowy | Subtle visual shift; same hue family |
| Text scaling 1.5x causes overflow | Preemptive fixes applied; user manually verifies |
| Screen reader on Dismissible | Add accessible label or confirmDismiss dialog |

## Haptic Moments

- No new haptic events.
