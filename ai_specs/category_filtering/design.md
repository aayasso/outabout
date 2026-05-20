# Design -- Category Filtering
# Created: 2026-05-19
# Requires: requirements.md approved

## Screens & Widgets

### ActivitiesTab (modified)
- **Route:** home tab (existing, no named route)
- **Type:** changes from ConsumerWidget to ConsumerStatefulWidget.
  Filter state (`Set<String> _selectedCategoryIds`) is local ephemeral
  state that resets when the widget is disposed (leaving the tab).
- **New widgets:**
  - `_CategoryFilterChipRow` — private widget rendering the horizontal
    filter chip row. Inserted as a SliverToBoxAdapter between the
    SliverAppBar and the SliverList of activity cards.
  - `_FilteredEmptyState` — private widget for the "No activities in
    these categories" empty state with clear button.
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (existing)

## StatefulWidget Conversion

ActivitiesTab is currently a ConsumerWidget. It must become a
ConsumerStatefulWidget to hold `_selectedCategoryIds` as ephemeral
local state. The conversion is mechanical:
- Move `build` body into `ConsumerState<ActivitiesTab>.build`
- Add `Set<String> _selectedCategoryIds = {}` state field
- Empty set = "All" selected (no filter active)

## Filter Logic

```dart
// lib/features/home/category_filter.dart

/// Pure function for filtering activities by category.
/// Exported for unit testing.
List<Activity> filterActivitiesByCategories(
  List<Activity> activities,
  Set<String> selectedCategoryIds,
) {
  // Empty set = All — return everything
  if (selectedCategoryIds.isEmpty) return activities;
  // Return activities where category_ids overlaps with selected set
  return activities.where((a) {
    return a.categoryIds.any(selectedCategoryIds.contains);
  }).toList();
}
```

This is a pure function in its own file
(`lib/features/home/category_filter.dart`). It takes the full activities
list and the selected filter set, returns filtered results. Imported
by `activities_tab.dart` and by the unit test.

Activities with empty `category_ids` are excluded when any filter is
active (they don't match any category). They appear when "All" is
selected (empty filter set returns all activities).

## Provider Reuse

No new providers. Reuses:
- `categoriesProvider` (from Feature 1) — provides the chip labels
- `activitiesProvider` (existing) — provides the unfiltered list

## Chip Row Design

```
[ All ]  [ Running ]  [ Hiking ]  [ Cycling ]  ...

"All" chip (first):
  Selected (default): colors.primary bg, white/black text
  Unselected: colors.surface bg, colors.divider border, colors.text

Category chips:
  Selected: colors.primary.withValues(alpha: 0.15) bg, colors.primary border
  Unselected: colors.surface bg, colors.divider border, colors.text
  Text style: OutAboutTypography.labelMedium(colors)

All chips:
  padding: horizontal OutAboutSpacing.sm, vertical OutAboutSpacing.xs
  border radius: OutAboutRadius.full
  spacing between chips: OutAboutSpacing.sm
  row padding: horizontal OutAboutSpacing.md
  48dp tap target via SizedBox min height on each chip
```

The "All" chip uses a solid `colors.primary` background when selected
(visually distinct from category chips which use alpha). Category chips
use the same selected/unselected pattern as the CategoryChipPicker from
Feature 1, but without the colored dot (filter chips show name only).

## Chip Interaction

```
Tap "All":
  → _selectedCategoryIds = {} (empty set)
  → setState → rebuild → unfiltered list shown
  → Haptics.onConditionToggle()
  // Feature 5 hook: filter_cleared fires here on "All" tap.

Tap a category chip:
  → If already selected: remove from _selectedCategoryIds
  → If not selected: add to _selectedCategoryIds
  → If _selectedCategoryIds becomes empty: effectively "All"
  → setState → rebuild → filtered list shown
  → Haptics.onConditionToggle()
  // Feature 5 hook: filter_applied fires here on category chip toggle.
```

"All" is not stored in the set. "All" is the visual representation of
an empty set. Tapping "All" clears the set. Tapping the last remaining
category chip removes it, making the set empty, which shows "All".

When Feature 5 (behavioral_event_audit) ships, `filter_applied` fires
in the category chip toggle handler with `category_id` and
`active_filter_count` in extra. `filter_cleared` fires in the "All"
tap handler with `previous_filter_count` in extra. These are the exact
wiring points — no other location is needed.

## Widget Tree (modified ActivitiesTab build)

```
Scaffold
  └─ CustomScrollView
       ├─ SliverAppBar (existing, pinned)
       ├─ SliverToBoxAdapter
       │    └─ _CategoryFilterChipRow (NEW)
       │         reads categoriesProvider
       │         shows shimmer if loading, nothing if error/empty
       ├─ SliverPadding
       │    └─ SliverList (existing activity cards, now filtered)
       │
       ├─ OR (when filtered list is empty and filters active):
       │  SliverFillRemaining(hasScrollBody: false)
       │    └─ _FilteredEmptyState
       │
       └─ SliverPadding (bottom spacing)
```

## Chip Row Visibility

| categoriesProvider state | Chip row behavior |
|---|---|
| Loading | Shimmer placeholder (4 small rectangles) |
| Error | Hidden (`SizedBox.shrink`). Error logged via `dart:developer`: `log('Categories failed to load, hiding filter row', error: error, name: 'ActivitiesTab')` |
| Data, 0 categories | Hidden (`SizedBox.shrink`). No log needed — expected state for users without categories. |
| Data, 1+ categories | Show "All" + category chips |

## Empty States

The existing `_ActivitiesEmptyState` ("Your wishlist is empty" / "No
activities yet") remains for when the user has zero activities total.

A new `_FilteredEmptyState` handles the case where activities exist
but the active filter yields zero results:
- Icon: `Icons.filter_list_off`, 48px, `colors.textSecondary`
- Heading: "No activities in these categories"
  (`OutAboutTypography.headingMedium(colors)`)
- Body: not needed — the heading is self-explanatory
- CTA: "Clear filters" TextButton
  - onPressed: clears `_selectedCategoryIds` via callback
  - Style: `OutAboutTypography.labelLarge(colors).copyWith(
    color: colors.primary)`
- Entrance animation: fadeIn at `OutAboutAnimations.standardDuration`
- Wrapped in `SliverFillRemaining(hasScrollBody: false)` so it
  centers correctly without scrollable behavior.

Decision logic in build:
```
if (activities.isEmpty) → _ActivitiesEmptyState (no activities at all)
else:
  filteredList = filterActivitiesByCategories(activities, _selectedCategoryIds)
  if (filteredList.isEmpty && _selectedCategoryIds.isNotEmpty)
    → show chip row + SliverFillRemaining(hasScrollBody: false, child: _FilteredEmptyState)
  else
    → show chip row + filtered SliverList
```

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| User has no categories | Chip row hidden. Activity list unfiltered. |
| Categories loading | Chip row shows shimmer. Activity list unfiltered. |
| Categories error | Chip row hidden, error logged via dart:developer. Activity list unfiltered. |
| Filter yields 0 results | _FilteredEmptyState with "Clear filters" |
| Activity has empty category_ids | Excluded from filtered results, visible under "All" |
| All category chips deselected manually | Set becomes empty = "All" state |
| User leaves and returns to tab | Filter resets (widget disposed and recreated) |

## Haptic Moments

- Any chip toggle (including "All") → `OutAboutHaptics.onConditionToggle()`
