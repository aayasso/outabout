# Tasks -- Today Tab FAB
# Created: 2026-05-05
# Requires: design.md approved

## Task 1 -- Add FAB to TodayTab
Visible when done: FAB with "+" icon appears on the Today tab. Tapping it navigates to the add activity screen.

- [ ] Add `floatingActionButton` to `Scaffold` in `_TodayTabState.build()`
- [ ] Set `backgroundColor: colors.primary`
- [ ] Set `onPressed: () => context.go(AppRoutes.addActivity)`
- [ ] Set `tooltip: 'Add activity'`
- [ ] Set icon color: `isDark ? Colors.black : Colors.white`
- [ ] Add scale-in animation matching ActivitiesTab:
      `.animate().scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0), duration: OutAboutAnimations.standardDuration, curve: Curves.easeOutBack)`
- [ ] Verify `go_router` import and `AppRoutes` import already present (they are)
- [ ] Run `flutter analyze` -- zero warnings
- [ ] Run `flutter test` -- all pass

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] FAB visible on all states (data, empty, loading, error)
- [ ] FAB color matches ActivitiesTab across all 5 weather themes
- [ ] Tap target is 48x48dp minimum (standard FAB exceeds this)
- [ ] Tooltip present for accessibility
