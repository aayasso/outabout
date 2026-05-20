# Design -- Activity Categories
# Created: 2026-05-19
# Requires: requirements.md approved

## Screens & Widgets

### FirstActivityPage (modified)
- **Route:** onboarding step 5 (existing)
- **Type:** ConsumerStatefulWidget (existing)
- **Change:** After `setBool('onboarding_complete', true)` in
  `_handleAddToWishlist`, call `CategoryRepository.seedDefaults(userId)`.
  Fire-and-forget with try/catch — seeding failure does not block
  onboarding completion or navigation to home.

### AddActivityScreen (modified)
- **Route:** `AppRoutes.addActivity` (existing)
- **Type:** ConsumerStatefulWidget (existing)
- **New widgets:** `CategoryChipPicker` inserted above "Weather
  Conditions" heading. Manages local `Set<String> _selectedCategoryIds`.
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (existing)

### ActivityDetailScreen (modified)
- **Route:** `/activity/:id` (existing)
- **Type:** ConsumerStatefulWidget (existing)
- **New widgets:** Same `CategoryChipPicker`. Pre-selects chips from
  `activity.categoryIds` during `_initializeControllers`.
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (existing)

### Shared Widgets (new)

**`CategoryChipPicker`** — `lib/widgets/category_chip_picker.dart`
- ConsumerWidget. Horizontal `SingleChildScrollView` with `Row`.
- Props: `selectedIds` (Set<String>), `onToggle(String id)` callback,
  `onCreateCategory()` callback.
- Reads `categoriesProvider` for the chip list.
- Each chip: category name + small colored dot from `category.color`.
- If a chip renders a category whose ID is in the activity's
  `category_ids` but no longer exists in the fetched categories list,
  the orphaned ID is skipped and logged via `dart:developer`.
- Last chip is "+" to trigger `onCreateCategory`.

**`CreateCategoryDialog`** — `lib/widgets/create_category_dialog.dart`
- StatefulWidget (no Riverpod needed inside dialog).
- Fields: name (required TextField), color (optional — row of 8
  preset color circles to tap).
- No icon picker — the `icon` column is stored as null. Icon rendering
  infrastructure does not exist yet (out of scope per requirements).
- Create button disabled when name is empty.
- Returns `({String name, String? color})` record on confirm, or null
  on cancel.

## Model

```dart
// lib/data/models/category.dart
class Category {
  final String? id;
  final String userId;
  final String name;
  final String? color; // hex string e.g. '#E55934'
  final String? icon;  // icon identifier string (null for now)
  final DateTime? createdAt;

  const Category({
    this.id,
    required this.userId,
    required this.name,
    this.color,
    this.icon,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

## Repository Methods

```dart
// lib/data/repositories/category_repository.dart
class CategoryRepository {
  CategoryRepository(this._client);
  final SupabaseClient _client;

  /// Pure fetch — never seeds.
  Future<List<Category>> fetchForUser(String userId) async {
    final data = await _client
        .from('categories')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    return data.map(Category.fromJson).toList();
  }

  Future<Category> insert(Category category) async {
    final data = await _client
        .from('categories')
        .insert(category.toJson())
        .select()
        .single();
    return Category.fromJson(data);
  }

  /// Batch inserts 8 default categories.
  /// Called once during onboarding completion (new users) or one-time
  /// migration (existing users). Never called from a provider.
  Future<void> seedDefaults(String userId) async {
    final defaults = [
      ('Running',      '#E55934'),
      ('Hiking',       '#43A047'),
      ('Cycling',      '#1E88E5'),
      ('Photography',  '#8E24AA'),
      ('Beach',        '#F4B942'),
      ('Skiing',       '#039BE5'),
      ('Camping',      '#8D6E63'),
      ('Picnic',       '#FB8C00'),
    ];
    final rows = defaults.map((d) => {
      'user_id': userId,
      'name': d.$1,
      'color': d.$2,
    }).toList();
    await _client.from('categories').insert(rows);
  }
}
```

## Provider Structure

```dart
// lib/features/home/home_providers.dart (add to existing file)

/// Pure fetch — returns categories for the current user.
/// Does NOT seed. Seeding is a lifecycle event handled elsewhere.
final categoriesProvider =
    FutureProvider<List<Category>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.fetchForUser(userId);
});

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});
```

## Seeding Strategy

Seeding is a lifecycle event, not a provider-read event. This prevents
re-seeding if a user ever deletes all their categories via a future
category management feature.

### New users (onboarding)
```
first_activity_page.dart → _handleAddToWishlist()
  → setBool('onboarding_complete', true)
  → try:
      → CategoryRepository.seedDefaults(userId)  // NEW
      → setBool('categories_seeded', true)        // NEW — only on success
    catch: log error, do NOT set flag
  → navigate to /home (always, regardless of seed outcome)
```
Seed failure is caught and logged but never blocks onboarding. The
`categories_seeded` flag is only set after a successful seed. If seeding
fails, the existing-user migration (Task 5) will retry on next home
screen load.

### Existing users (one-time migration)
```
home_screen.dart → initState or first build
  → Check SharedPreferences: 'categories_seeded' == true? → skip
  → If false:
    → CategoryRepository.fetchForUser(userId)
    → If 0 rows: seedDefaults(userId), then set flag
    → If >0 rows: skip seeding, set flag anyway
      (respect existing user content — they already have categories)
  → Done (never runs again)
```
This runs once, gated by the `categories_seeded` flag. If seeding fails,
the flag is not set, so it retries on next app launch. If the user
already has categories (created manually or via a previous version of
the app), seeding is skipped and the flag is set — their existing
content is respected, they never receive unwanted defaults.

## Data Flow

### Category selection on Add Activity
```
User taps chip → onToggle callback
  → setState: add/remove ID in _selectedCategoryIds
  → Haptics.onConditionToggle()
  → On save: Activity constructor receives categoryIds
  → ActivityRepository.insertWithConditions sends category_ids in payload
```

### Category selection on Activity Detail
```
Activity loads → _initializeControllers sets
  _selectedCategoryIds = activity.categoryIds.toSet()
  → Chips pre-selected
  → On save: updatedActivity includes categoryIds
  → ActivityRepository.updateWithConditions sends category_ids in update
```

### Custom category creation
```
User taps "+" chip → showDialog(CreateCategoryDialog)
  → User enters name, optional color → taps Create
  → CategoryRepository.insert(category)
  → ref.invalidate(categoriesProvider)
  → New chip appears in picker
  → Haptics.onActivitySave()
```

### Orphaned category references
```
CategoryChipPicker builds chip list from categoriesProvider
  → For each activity.categoryId, check if it exists in fetched list
  → If not found: skip (don't render chip), log warning via dart:developer
    log('Orphaned category reference: $id', name: 'CategoryChipPicker')
```

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Seed fails during onboarding | Caught, logged. User reaches home with empty categories. Can create manually. |
| Seed fails for existing user migration | Flag not set. Retries on next app launch. |
| Network failure fetching categories | categoriesProvider error state. Chip row shows inline error with retry. |
| Network failure creating custom category | Dialog shows error message. User can retry or cancel. |
| No categories loaded yet | Chip row shows shimmer placeholder. |
| Category color is null | Dot indicator uses `colors.textSecondary` as fallback. |
| Activity has orphaned category_ids | Chip for unknown ID skipped, warning logged via dart:developer. |

## Haptic Moments

- Chip toggle (select/deselect) → `OutAboutHaptics.onConditionToggle()`
- Custom category created → `OutAboutHaptics.onActivitySave()`

## Chip Visual Spec

```
[ (dot) Running ]  [ (dot) Hiking ]  [ + ]

Unselected chip:
  background: colors.surface
  border: 1px colors.divider
  text: colors.text (labelMedium)
  dot: category.color parsed as Color (8px circle, left of text)
  dot fallback: colors.textSecondary when color is null

Selected chip:
  background: colors.primary.withValues(alpha: 0.15)
  border: 1px colors.primary
  text: colors.text (labelMedium)
  dot: category.color parsed as Color (8px circle, left of text)

"+" chip:
  background: colors.surface
  border: 1px dashed colors.divider
  icon: Icons.add, size 16, colors.textSecondary

All chips:
  padding: horizontal OutAboutSpacing.sm, vertical OutAboutSpacing.xs
  border radius: OutAboutRadius.full
  min height: 32 (chip content), row height accommodates 48dp tap target
  spacing between chips: OutAboutSpacing.sm
```
