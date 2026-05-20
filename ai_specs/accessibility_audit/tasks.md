# Tasks -- Accessibility Audit
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- Add primaryInteractive Token + Fix textSecondary
Visible when done: `WeatherThemeColors` has a new `primaryInteractive`
field. Overcast and snowy `textSecondary` values are darkened. All
interactive text passes AA contrast on all five themes.

- [ ] In `lib/core/theme.dart`, add `primaryInteractive` field to
  `WeatherThemeColors`:
  - Sunny: #A05E00 (4.86:1 on bg, 5.13:1 on card)
  - Overcast: #1565C0 (5.12:1 on bg, 5.75:1 on card)
  - Rainy: #4A9EFF (same as primary — already passes)
  - Snowy: #1565C0 (5.45:1 on bg, 5.75:1 on card)
  - Night: #4A9EFF (same as primary — already passes)
- [ ] In `lib/core/theme.dart`, modify `textSecondary` for two themes:
  - Overcast: change #6B7B8D to #5A6978 (3.87:1 → 5.02:1)
  - Snowy: change #607D8B to #506A78 (4.14:1 → 5.42:1)
- [ ] Update `ai_docs/design_system.md`:
  - Overcast textSecondary hex: #5A6978
  - Snowy textSecondary hex: #506A78
  - Add `primaryInteractive` to the token documentation with all
    five theme values
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- Migrate Interactive Text to primaryInteractive
Visible when done: All TextButtons, links, and interactive text use
`colors.primaryInteractive` instead of `colors.primary` for text color.

- [ ] Grep the codebase for two patterns and update every match in a
  text/interactive context:
  - `.copyWith(color: colors.primary)` — text style overrides
  - `color: colors.primary` — in TextStyle, Text, TextButton, or
    icon-as-text contexts
  Every match must be evaluated: if it's text foreground on a light
  background, switch to `colors.primaryInteractive`. The grep is the
  source of truth — do not rely solely on the known-locations list.
- [ ] Sanity check against known locations (verify these were caught
  by the grep):
  - settings_tab.dart: "Enable location" button text (Feature 3)
  - settings_tab.dart: temperature unit trailing text
  - activities_tab.dart: "Clear filters" button (Feature 2)
  - activities_tab.dart: "Try again" error state link
  - today_tab.dart: "Enable" in `_LocationPermissionBanner`
  - activity_detail_screen.dart: "Retry" in notification error
- [ ] Do NOT update matches in non-text contexts:
  - backgroundColor, fillColor, indicatorColor, activeColor,
    thumbColor, activeTrackColor, indicator backgrounds
  - FAB backgroundColor, ElevatedButton, Switch, Slider,
    chip selected background fills, NavigationBar indicator
  - Icon tints where the icon is on a dark/contrasting surface
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- Tap Target Audit + Fixes
Visible when done: Every tappable element meets 48x48dp minimum.

- [ ] Audit every GestureDetector, InkWell, and IconButton across:
  - TodayTab, ActivitiesTab, SettingsTab
  - AddActivityScreen, ActivityDetailScreen
  - OnboardingScreen and all onboarding pages
  - CategoryChipPicker, filter chips (Feature 1+2 widgets)
- [ ] Fix: theme selector chips in settings_tab.dart — if chip height
  is under 48dp, wrap each chip in `SizedBox(height: 48)` or add
  vertical padding to meet minimum
- [ ] Fix: morning time picker in activity_detail_screen.dart:816 —
  add `constraints: BoxConstraints(minHeight: 48)` to the Container
  or increase vertical padding
- [ ] Verify: category chips (Feature 1) and filter chips (Feature 2)
  meet 48dp target
- [ ] Verify: all FABs (56dp default), all IconButtons (48dp default),
  all SettingsRow InkWells (minHeight: 48 ConstrainedBox)
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- Semantics Labels Audit + Fixes
Visible when done: Every interactive element has a meaningful
Semantics label or tooltip.

- [ ] Fix: activities_tab.dart `_ActivityListCard` Semantics label —
  add condition count. Change from `'Activity: ${activity.name}'` to
  `'Activity: ${activity.name}, ${n} conditions set'` (count enabled
  conditions from conditionProfile)
- [ ] Fix: condition_profile_form.dart `ConditionSection` Semantics —
  change label from `'$title condition toggle'` to
  `'$title condition, ${enabled ? "enabled" : "disabled"}'`
- [ ] Fix: activities_tab.dart `Dismissible` — add
  `Semantics(label: 'Swipe left to archive ${activity.name}')` or
  add a `confirmDismiss` callback with an accessible dialog
- [ ] Verify: category chips (Feature 1) have Semantics with name +
  selected/unselected state + button: true
- [ ] Verify: filter chips (Feature 2) have Semantics with name +
  selected/unselected state + button: true
- [ ] Verify: all TodayTab cards, theme chips, nav bar items, FABs,
  and IconButtons already have labels/tooltips
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- Form Field Labels Audit
Visible when done: All TextFields announce properly to screen readers.

- [ ] Verify: AddActivityScreen name field has `labelText`
  (Feature 4 adds "Activity name *")
- [ ] Verify: AddActivityScreen notes field has `labelText`
  (Feature 4 adds "Notes (optional)")
- [ ] Verify: ActivityDetailScreen name and notes fields have `labelText`
- [ ] Add `semanticCounterText` to notes fields where character
  counters exist (Feature 4):
  `semanticCounterText: '${count} of $maxNotesLength characters used'`
  in InputDecoration
- [ ] Verify: auth_page.dart email and password fields have Semantics
  labels (they do — lines 170, 190)
- [ ] Verify: first_activity_page.dart name field has Semantics label
  (it does — line 217)
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Text Scaling Preemptive Fixes
Visible when done: Known risk areas have Flexible/Wrap/ellipsis
applied. User manually verifies at 1.5x in simulator.

Claude Code applies preemptive layout fixes. User manually verifies
in simulator at 1.5x `textScaleFactor` and reports any remaining
overflow issues.

- [ ] Slider label rows (condition_profile_form.dart):
  - Temperature min/max Row: wrap each Text in `Flexible` with
    `overflow: TextOverflow.ellipsis`
  - Wind value label: same treatment
  - UV min/max Row: same treatment
- [ ] AddActivityScreen private slider widgets (if not yet migrated
  to shared widgets by Feature 4):
  - Same Flexible + ellipsis treatment on label Rows
- [ ] Weather summary card (today_tab.dart `_WeatherSummaryCard`):
  - Temperature display Text: add `maxLines: 1` +
    `overflow: TextOverflow.ellipsis`
  - Location Row: already has `Flexible` — verify
- [ ] Settings rows (settings_tab.dart):
  - `_SettingsRow`: label Text already in `Expanded` — OK
  - `_TemperatureUnitRow`: trailing text — verify doesn't collide
- [ ] Days before stepper (activity_detail_screen.dart):
  - Count text in Row with icon buttons: wrap text in `Flexible`
- [ ] Category/filter chip rows:
  - Already use `SingleChildScrollView` — verify individual chip
    text isn't clipped by adding `maxLines: 1` +
    `overflow: TextOverflow.ellipsis` to chip Text widgets
- [ ] Document each fix in the Text Scaling Fixes Log in design.md
- [ ] Run `flutter analyze` — must pass before Task 7

## Task 7 -- Navigation Order Verification
Visible when done: Screen reader navigates all screens in logical
top-to-bottom order.

- [ ] Verify focus traversal order on each main screen:
  - TodayTab: weather card -> activity cards -> FAB
  - ActivitiesTab: filter chips -> activity cards -> FAB
  - SettingsTab: profile -> location -> appearance -> notifications ->
    account -> version
  - AddActivityScreen: close -> name -> notes -> categories ->
    conditions -> save
  - ActivityDetailScreen: back -> name -> notes -> categories ->
    conditions -> notifications -> save -> archive
- [ ] Verify bottom navigation bar items are reachable and labeled
- [ ] Verify no focus traps
- [ ] If ordering issues found, fix with `FocusTraversalGroup` or
  widget reordering
- [ ] Run `flutter analyze` — must pass before Task 8

## Task 8 -- Final Verification
Visible when done: All accessibility fixes pass. Feature complete.

- [ ] Re-verify all fixes from Tasks 1-7 are in place
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Fill in Contrast Fixes Log in design.md with actual changes
- [ ] Fill in Text Scaling Fixes Log in design.md with actual changes

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors — all from `weatherThemeColorsProvider`
- [ ] All interactive text uses `colors.primaryInteractive` (not
  `colors.primary`) for text color
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`
- [ ] Every tappable element >= 48x48dp
- [ ] Every interactive element has tooltip or Semantics label
- [ ] `ai_docs/design_system.md` updated with new token values
- [ ] CLAUDE.md does NOT need updating — the token system structure
  is unchanged, only values are adjusted
