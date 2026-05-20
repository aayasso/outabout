# Tasks -- Category Filtering
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- Filter Logic Function
Visible when done: Pure filter function exists in its own file with
unit tests. No UI changes yet.

- [ ] Create `lib/features/home/category_filter.dart`:
  ```dart
  List<Activity> filterActivitiesByCategories(
    List<Activity> activities,
    Set<String> selectedCategoryIds,
  ) {
    if (selectedCategoryIds.isEmpty) return activities;
    return activities.where((a) {
      return a.categoryIds.any(selectedCategoryIds.contains);
    }).toList();
  }
  ```
- [ ] Write unit tests `test/features/home/category_filter_test.dart`:
  - Empty selectedCategoryIds returns all activities
  - One selected category returns only matching activities
  - Multiple selected categories uses OR logic
  - Activity with empty category_ids excluded when filter active
  - Activity with multiple category_ids matches if any one is in set
  - Single activity matching multiple selected categories appears once
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- Convert ActivitiesTab to ConsumerStatefulWidget
Visible when done: ActivitiesTab is a ConsumerStatefulWidget with
filter state. Behavior is identical to before (no UI changes yet).

- [ ] Convert `ActivitiesTab` from `ConsumerWidget` to
  `ConsumerStatefulWidget`
  - Create `_ActivitiesTabState extends ConsumerState<ActivitiesTab>`
  - Move `build` method body into state class
  - `ref` access changes from parameter to `ref` on state
- [ ] Add `Set<String> _selectedCategoryIds = {}` state field
- [ ] Verify all existing behavior unchanged — no visual diff
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- Category Filter Chip Row
Visible when done: Horizontal chip row appears below the SliverAppBar
with "All" chip and category chips. Tapping chips updates local state.
Activity list not yet filtered.

- [ ] Create `_CategoryFilterChipRow` private widget in
  `activities_tab.dart`:
  - Props: `selectedCategoryIds` (Set<String>),
    `onToggle(String id)` callback,
    `onClearAll()` callback
  - Reads `categoriesProvider` for chip labels
  - Loading: 4 shimmer placeholder chips in a horizontal row
  - Error: return `SizedBox.shrink()` (hidden) AND log via
    `dart:developer`:
    `log('Categories failed to load, hiding filter row', error: error, name: 'ActivitiesTab')`
  - 0 categories: return `SizedBox.shrink()` (hidden, no log)
  - "All" chip first:
    - Selected when `selectedCategoryIds.isEmpty`
    - Solid `colors.primary` bg when selected
    - `colors.surface` bg + `colors.divider` border when unselected
    - Text: "All" in `OutAboutTypography.labelMedium(colors)`
    - onTap: calls `onClearAll`
  - Category chips after "All":
    - Selected: `colors.primary.withValues(alpha: 0.15)` bg +
      `colors.primary` border
    - Unselected: `colors.surface` bg + `colors.divider` border
    - Text: category name in `OutAboutTypography.labelMedium(colors)`
    - onTap: calls `onToggle(category.id!)`
  - All chips: `OutAboutRadius.full` border radius,
    `OutAboutSpacing.sm` horizontal padding + `OutAboutSpacing.xs`
    vertical padding, `OutAboutSpacing.sm` spacing between chips
  - Row: `SingleChildScrollView(scrollDirection: Axis.horizontal)`
    with `EdgeInsets.symmetric(horizontal: OutAboutSpacing.md)`
  - 48dp minimum tap target per chip
  - Haptic: `OutAboutHaptics.onConditionToggle()` on every tap
- [ ] Insert `_CategoryFilterChipRow` as `SliverToBoxAdapter` between
  `SliverAppBar` and `SliverPadding` containing the activity list
  - Wire `onToggle` to add/remove from `_selectedCategoryIds` + setState
    // Feature 5 hook: filter_applied fires here
  - Wire `onClearAll` to set `_selectedCategoryIds = {}` + setState
    // Feature 5 hook: filter_cleared fires here
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- Wire Filter to Activity List
Visible when done: Selecting category chips filters the activity list
in real time. "All" shows everything.

- [ ] Import `filterActivitiesByCategories` from
  `lib/features/home/category_filter.dart`
- [ ] In the `data:` branch of `activitiesAsync.when`:
  - After checking `activities.isEmpty` (existing empty state),
    compute filtered list:
    `final filtered = filterActivitiesByCategories(
      activities, _selectedCategoryIds);`
  - Pass `filtered` to `SliverChildBuilderDelegate` instead of
    `activities`
  - Update `childCount` to `filtered.length`
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- Filtered Empty State
Visible when done: When active filters yield zero results, a dedicated
empty state appears with a "Clear filters" button.

- [ ] Create `_FilteredEmptyState` private widget:
  - Icon: `Icons.filter_list_off`, size 48, `colors.textSecondary`
  - Heading: "No activities in these categories"
    (`OutAboutTypography.headingMedium(colors)`)
  - "Clear filters" TextButton:
    - Style: `OutAboutTypography.labelLarge(colors).copyWith(
      color: colors.primary)`
    - onPressed: callback to clear `_selectedCategoryIds`
  - Centered, padded with `OutAboutSpacing.xl`
  - Entrance: `.animate().fadeIn(
    duration: OutAboutAnimations.standardDuration)`
- [ ] In build, after computing `filtered`:
  - If `filtered.isEmpty && _selectedCategoryIds.isNotEmpty`:
    show chip row + `SliverFillRemaining(hasScrollBody: false,
    child: _FilteredEmptyState(...))` — `hasScrollBody: false` is
    required so the static empty state centers correctly without
    unwanted scrollable behavior
  - Else: show chip row + filtered SliverList
- [ ] Wire "Clear filters" onPressed to
  `setState(() => _selectedCategoryIds = {})`
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Widget Tests + Final Verification
Visible when done: Tests pass. Feature complete.

- [ ] Widget test: chip row renders "All" + category chips from
  mocked `categoriesProvider`
- [ ] Widget test: tapping a category chip adds it to selection
  (chip visually changes)
- [ ] Widget test: tapping "All" clears selection
- [ ] Widget test: chip row hidden when categories list is empty
- [ ] Widget test: chip row hidden when categoriesProvider errors
- [ ] Widget test: `_FilteredEmptyState` appears when filter yields
  zero results
- [ ] Widget test: "Clear filters" button resets to unfiltered list
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors — all from `weatherThemeColorsProvider`
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`, radius from `OutAboutRadius`
- [ ] Haptics fire on every chip toggle
- [ ] Filter resets when leaving and returning to the tab
- [ ] Categories error logged via dart:developer when chip row hidden
- [ ] `ai_docs/` does not need updating (no schema changes)
