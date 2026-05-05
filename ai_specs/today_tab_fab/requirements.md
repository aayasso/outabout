# Requirements -- Today Tab FAB
# Created: 2026-05-05
# Status: draft

## Summary
Add a floating action button (FAB) to the Today tab so users can create a new activity directly from the Today tab. Currently the FAB only exists on the Activities tab. This mirrors the same FAB style, animation, and navigation target used in ActivitiesTab.

## User Stories

### Primary flow
- As a user viewing the Today tab, I want to tap a FAB to add a new activity so that I don't have to switch tabs first.

### Secondary flows
- None.

### Edge cases
- What happens when user is on the empty state? The FAB is visible alongside the existing "Add Activity" button in the empty state. Both paths lead to the same destination.
- What happens on the "no matches" state? FAB is visible.

## Acceptance Criteria
- [ ] FAB appears on TodayTab with `Icons.add` icon
- [ ] FAB background color is `colors.primary`
- [ ] FAB icon color is `Colors.black` on dark themes, `Colors.white` on light themes (matches ActivitiesTab pattern)
- [ ] FAB navigates to `AppRoutes.addActivity` on tap
- [ ] FAB has `tooltip: 'Add activity'` for accessibility
- [ ] FAB uses scale-in animation: `.animate().scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0), duration: standardDuration, curve: Curves.easeOutBack)`
- [ ] FAB does not overlap content -- standard Material FAB positioning
- [ ] All colors from `weatherThemeColorsProvider` -- no hardcoded colors
- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes

## Screens Involved
- TodayTab (`lib/features/home/tabs/today_tab.dart`) -- modified

## Data Requirements
- Supabase tables: none
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations
- Does this feature behave differently across themes? Yes -- FAB icon color flips between black/white based on theme brightness (same as ActivitiesTab).

## Out of Scope
- Adding FAB to any other tabs
- Changing the ActivitiesTab FAB
- Adding a speed dial or multi-action FAB

## Open Questions
- None
