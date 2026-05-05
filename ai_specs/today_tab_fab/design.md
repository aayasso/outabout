# Design -- Today Tab FAB
# Created: 2026-05-05
# Requires: requirements.md approved

## Screens & Widgets

### TodayTab
- **Route:** Home tab (no standalone route)
- **Type:** ConsumerStatefulWidget (unchanged)
- **New widgets:** None -- FAB added directly to Scaffold
- **Colors source:** `ref.watch(weatherThemeColorsProvider)`

## Provider Structure

No new providers.

## Repository Methods

No new repository methods.

## Data Flow

FAB is a static UI element. No data flow changes.

```
User taps FAB -> context.go(AppRoutes.addActivity)
```

## Implementation

Add `floatingActionButton` to the existing `Scaffold` in `_TodayTabState.build()`. Copy the exact pattern from `ActivitiesTab` (lines 43-60 of `activities_tab.dart`):

```dart
Scaffold(
  backgroundColor: colors.background,
  floatingActionButton: FloatingActionButton(
    backgroundColor: colors.primary,
    onPressed: () => context.go(AppRoutes.addActivity),
    tooltip: 'Add activity',
    child: Icon(
      Icons.add,
      color: isDark ? Colors.black : Colors.white,
    ),
  )
      .animate()
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.0, 1.0),
        duration: OutAboutAnimations.standardDuration,
        curve: Curves.easeOutBack,
      ),
  body: RefreshIndicator(...),  // existing
)
```

The `colors`, `isDark`, and `context` variables are already available in `_TodayTabState.build()`.

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Empty state (no activities) | FAB visible alongside "Add Activity" button |
| No matches state | FAB visible |
| Loading (shimmer) | FAB visible |
| Error state | FAB visible |

## Haptic Moments
- None. Navigation to add activity screen handles its own haptics.

## Open Questions Resolved
- None
