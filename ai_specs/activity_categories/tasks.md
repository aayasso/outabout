# Tasks -- Activity Categories
# Created: 2026-05-19
# Requires: design.md approved

## Task 1a -- Category Model
Visible when done: `Category` class exists with fromJson/toJson. Tests pass.

- [ ] Create `lib/data/models/category.dart`
  - Fields: `id` (String?), `userId` (String), `name` (String),
    `color` (String?), `icon` (String?), `createdAt` (DateTime?)
  - `factory Category.fromJson(Map<String, dynamic> json)`
    with snake_case keys
  - `Map<String, dynamic> toJson()` with snake_case keys
- [ ] Write unit test `test/data/models/category_test.dart`
  - `fromJson` parses all fields correctly
  - `toJson` produces correct snake_case keys
  - `fromJson` → `toJson` round trip preserves values
  - `fromJson` handles null `color` and `icon` gracefully
- [ ] Run `flutter analyze` — must pass before Task 1b

## Task 1b -- CategoryRepository
Visible when done: Repository can fetch, insert, and seed categories.

- [ ] Create `lib/data/repositories/category_repository.dart`
  - `fetchForUser(String userId)` — select from `categories` table,
    order by `created_at`, return `List<Category>`
  - `insert(Category category)` — insert, select, return created row
  - `seedDefaults(String userId)` — batch insert 8 rows with locked
    colors from requirements.md:
    - Running #E55934, Hiking #43A047, Cycling #1E88E5,
      Photography #8E24AA, Beach #F4B942, Skiing #039BE5,
      Camping #8D6E63, Picnic #FB8C00
    - `icon` column set to null for all rows
- [ ] Run `flutter analyze` — must pass before Task 1c

## Task 1c -- Providers
Visible when done: `categoriesProvider` fetches categories for the
current user. `categoryRepositoryProvider` provides the repository.

- [ ] Add `categoryRepositoryProvider` to `home_providers.dart`
  - `Provider<CategoryRepository>` wrapping `supabaseClientProvider`
- [ ] Add `categoriesProvider` to `home_providers.dart`
  - `FutureProvider<List<Category>>` — pure fetch, no seeding
  - Returns empty list if no authenticated user
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- CategoryChipPicker Shared Widget
Visible when done: Reusable chip picker widget exists and renders
categories from the provider. Not yet integrated into any screen.

- [ ] Create `lib/widgets/category_chip_picker.dart`
  - ConsumerWidget
  - Props: `selectedIds` (Set<String>), `onToggle(String id)`,
    `onCreateCategory()` callback
  - Reads `categoriesProvider` for chip data
  - `SingleChildScrollView` + `Row` for horizontal scroll
  - Each chip: colored dot (8px circle) + category name (labelMedium)
  - Dot color: parse `category.color` hex; fallback
    `colors.textSecondary` when null
  - Selected: `colors.primary` alpha background + primary border
  - Unselected: `colors.surface` + `colors.divider` border
  - Last chip: "+" icon, `colors.surface` bg, dashed `colors.divider`
    border, triggers `onCreateCategory`
  - Loading state: 4 shimmer placeholder chips
  - Error state: inline "Couldn't load categories" + retry text button
  - Orphaned ID handling: skip IDs not found in fetched list, log via
    `dart:developer` with name `CategoryChipPicker`
  - Haptic on toggle: `OutAboutHaptics.onConditionToggle()`
  - Chip spacing: `OutAboutSpacing.sm`
  - Chip padding: horizontal `OutAboutSpacing.sm`, vertical
    `OutAboutSpacing.xs`
  - Chip border radius: `OutAboutRadius.full`
  - Row wrapped in SizedBox or ConstrainedBox ensuring 48dp tap targets
- [ ] All colors from `weatherThemeColorsProvider`
- [ ] All spacing from `OutAboutSpacing`, radius from `OutAboutRadius`
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- CreateCategoryDialog
Visible when done: Tapping "+" chip opens a dialog. Creating a category
inserts it into Supabase and the chip appears in the picker.

- [ ] Create `lib/widgets/create_category_dialog.dart`
  - StatefulWidget (local TextEditingController state)
  - Name TextField (required, labelText "Category name")
  - Optional color picker: row of 8 preset color circles. Tapping a
    circle selects it (outlined ring). Presets use the same 8 default
    category colors from requirements.md plus a "no color" option.
  - No icon picker — `icon` is stored as null (out of scope per
    requirements.md; icon rendering infrastructure doesn't exist yet)
  - Create button disabled when name is empty
  - Returns `({String name, String? color})` record on confirm,
    or null on cancel
  - Dialog background: `colors.cardBackground`
  - All typography via `OutAboutTypography` with `colors`
- [ ] Wire dialog into `CategoryChipPicker.onCreateCategory`:
  - Show dialog → on result, call `CategoryRepository.insert`
  - Invalidate `categoriesProvider` to refresh chip list
  - Fire `OutAboutHaptics.onActivitySave()` on success
- [ ] Handle insert error: show snackbar "Couldn't create category"
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- Seed on Onboarding Completion
Visible when done: Completing onboarding seeds 8 default categories.

- [ ] In `first_activity_page.dart` `_handleAddToWishlist`:
  - After `setBool('onboarding_complete', true)` (line 107)
  - Add try block: `await CategoryRepository(supabase).seedDefaults(userId);`
  - Inside try, after seedDefaults succeeds:
    `await prefs.setBool('categories_seeded', true);`
  - Catch block: `log('Category seed failed', error: e);`
    Do NOT set `categories_seeded` flag on failure — the existing-user
    migration (Task 5) will retry on next home screen load
  - Navigation to /home happens after the try/catch regardless —
    seed failure never blocks onboarding
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- One-Time Migration for Existing Users
Visible when done: Existing users who already completed onboarding get
default categories seeded once on first home screen load.

- [ ] In `home_screen.dart` (or a dedicated init provider):
  - Check `SharedPreferences` key `categories_seeded`
  - If `true`: skip entirely
  - If `false` (or absent):
    - Fetch categories for user via `CategoryRepository.fetchForUser`
    - If 0 rows: call `seedDefaults(userId)`, then set
      `categories_seeded = true`
    - If >0 rows: skip seeding, still set `categories_seeded = true`
      — respect existing user content; they already have categories
      and should not receive unwanted defaults
  - Wrap seed path in try/catch — failure leaves flag unset so it
    retries on next launch. The >0 rows path always sets the flag
    since no seeding was attempted.
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Integrate into AddActivityScreen
Visible when done: Category chip row appears on Add Activity screen.
Selected categories are saved with the activity.

- [ ] Add `Set<String> _selectedCategoryIds = {}` state field
- [ ] Insert `CategoryChipPicker` above "Weather Conditions" heading
  - Pass `selectedIds: _selectedCategoryIds`
  - `onToggle: (id) => setState(() { toggle id in set })`
  - `onCreateCategory:` show `CreateCategoryDialog`
- [ ] Update `_save()`: pass `categoryIds: _selectedCategoryIds.toList()`
  to `Activity` constructor
- [ ] Verify `ActivityRepository.insertWithConditions` already sends
  `category_ids` in the insert payload (it does via `activity.toJson()`)
- [ ] Add `const SizedBox(height: OutAboutSpacing.md)` between chip row
  and weather conditions heading
- [ ] Run `flutter analyze` — must pass before Task 7

## Task 7 -- Integrate into ActivityDetailScreen
Visible when done: Category chip row on Activity Detail screen with
existing categories pre-selected. Edits persist on save.

- [ ] Add `Set<String> _selectedCategoryIds = {}` state field
- [ ] In `_initializeControllers`: set
  `_selectedCategoryIds = activity.categoryIds.toSet()`
- [ ] Insert `CategoryChipPicker` in `_buildForm` above
  "Weather Conditions" heading
  - Pass `selectedIds: _selectedCategoryIds`
  - `onToggle: (id) => setState(() { toggle id in set })`
  - `onCreateCategory:` show `CreateCategoryDialog`
- [ ] Update `_onSave`: pass `categoryIds: _selectedCategoryIds.toList()`
  to the `updatedActivity` constructor
- [ ] Verify `ActivityRepository.updateWithConditions` already sends
  `category_ids` in the update payload (it does — line 99)
- [ ] Add `const SizedBox(height: OutAboutSpacing.md)` between chip row
  and weather conditions heading
- [ ] Run `flutter analyze` — must pass before Task 8

## Task 8 -- Widget Tests + Final Verification
Visible when done: Tests pass. Feature is complete.

- [ ] Write widget test: `CategoryChipPicker` renders chips from
  mocked `categoriesProvider`
- [ ] Write widget test: tapping a chip calls `onToggle` with correct ID
- [ ] Write widget test: "+" chip triggers `onCreateCategory` callback
- [ ] Write widget test: selected chips have primary-colored border
- [ ] Write widget test: orphaned category ID is not rendered as a chip
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors — all from `weatherThemeColorsProvider`
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`, radius from `OutAboutRadius`
- [ ] Haptics fire on chip toggle and category creation
- [ ] `categories_seeded` SharedPreferences flag set correctly in both
  onboarding and migration paths
- [ ] `ai_docs/` does not need updating (schema unchanged)
