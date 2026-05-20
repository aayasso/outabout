# Tasks -- Form Validation
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- AddActivityScreen Name Validation
Visible when done: Name field shows "Activity name *" label. Inline
error appears when name exceeds 50 characters.

- [ ] Add `const int maxNameLength = 50;` at top of file
- [ ] Update `_ActivityNameField`:
  - Change `hintText: 'Activity name'` to
    `labelText: 'Activity name *'`
  - Add `labelStyle: OutAboutTypography.labelMedium(colors)`
  - Add `errorText:` that shows "Name must be 50 characters or less"
    when `controller.text.trim().length > maxNameLength`
  - Add `errorStyle: OutAboutTypography.bodySmall(colors).copyWith(
    color: OutAboutColors.errorColor)`
- [ ] Verify `onChanged: (_) => setState(() {})` is already wired
  (it is — line 159)
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- AddActivityScreen Notes Counter
Visible when done: Notes field shows "X / 200" character counter below
the field when notes are non-empty. Counter turns red when over 200.
Empty notes field shows no counter.

- [ ] Add `const int maxNotesLength = 200;` at top of file
- [ ] Update `_NotesField` to accept an `onChanged` callback and
  wire it to trigger `setState` in the parent
- [ ] Wrap `_NotesField` and counter in a Column:
  - TextField as first child
  - Counter only rendered when `_notesController.text.isNotEmpty`:
    - `SizedBox(height: OutAboutSpacing.xs)` spacer
    - Right-aligned `Text` showing
      `'${_notesController.text.length} / $maxNotesLength'`
    - Counter style: `OutAboutTypography.bodySmall(colors).copyWith(
      color: length > maxNotesLength
          ? OutAboutColors.errorColor
          : colors.textSecondary)`
  - When notes are empty: no counter, no spacer
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- AddActivityScreen Save Button Reason + Expanded Validation
Visible when done: Save button disabled with reason text only for
concrete validation errors (name too long, notes too long). Empty name
gets a quiet disabled button with no explanatory text.

- [ ] Update `_canSave` getter:
  ```
  bool get _canSave {
    if (_isSaving) return false;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > maxNameLength) return false;
    if (_notesController.text.length > maxNotesLength) return false;
    return true;
  }
  ```
- [ ] Add `_disabledReason` getter:
  ```
  String? get _disabledReason {
    if (_isSaving) return null;
    final name = _nameController.text.trim();
    // Empty name = user hasn't started yet. Quiet disabled button.
    if (name.isEmpty) return null;
    if (name.length > maxNameLength) return 'Name is too long';
    if (_notesController.text.length > maxNotesLength) {
      return 'Notes exceed $maxNotesLength characters';
    }
    return null;
  }
  ```
- [ ] Update `_SaveButton` area: add a `Text` widget below the button
  showing `_disabledReason` when non-null
  - Style: `OutAboutTypography.bodySmall(colors).copyWith(
    color: colors.textSecondary)`
  - `textAlign: TextAlign.center`
  - Wrapped in `Padding(top: OutAboutSpacing.sm)`
  - Only visible when `_disabledReason != null`
  - NOT visible when name is simply empty (returns null)
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- AddActivityScreen Slider Unit Fix
Visible when done: Temperature and wind sliders respect user's
temperature unit preference (F/C and mph/km/h). Values display
identically to ActivityDetailScreen for the same range.

- [ ] Watch `profileProvider` in `build` method to get `temperatureUnit`
  (same pattern as ActivityDetailScreen line 267)
- [ ] Add unit conversion helpers at top of file, using the exact
  formulas from `condition_profile_form.dart` lines 11-12:
  ```
  int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
  int _kmhToMph(double kmh) => (kmh * 0.621371).round();
  ```
  Both return `int` via `.round()` (Dart half-up rounding). These must
  be identical to the shared widgets so the same range (e.g. 15-30 C)
  displays as the same values (59-86 F) on both screens.
- [ ] Pass `temperatureUnit` to `_TemperatureSection`:
  - Add `temperatureUnit` parameter
  - Convert display values: if F, use `_celsiusToFahrenheit()`
  - Show labels as "59°F" / "86°F" or "15°C" / "30°C"
  - Slider still operates in Celsius (0-50 range internally)
- [ ] Pass `temperatureUnit` to `_WindSection`:
  - Add `temperatureUnit` parameter
  - Convert display: if F (imperial), show mph via `_kmhToMph()`
  - Show label as "Max 15 mph" or "Max 25 km/h"
  - Slider still operates in km/h (0-80 range internally)
- [ ] `_UvSection`: no change needed — already shows "0" to "11"
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- ActivityDetailScreen Name Validation
Visible when done: Name field shows asterisk and inline error when
name exceeds 50 characters.

- [ ] Add `const int maxNameLength = 50;` at top of file
- [ ] Update name TextField in `_buildForm`:
  - Change `labelText: 'Activity Name'` to `'Activity name *'`
  - Add `errorText:` showing "Name must be 50 characters or less"
    when `_nameController.text.trim().length > maxNameLength`
  - Add `errorStyle: OutAboutTypography.bodySmall(colors).copyWith(
    color: OutAboutColors.errorColor)`
- [ ] `_nameController.addListener(() => setState(() {}))` already
  exists (line 63) — verify it triggers rebuild
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- ActivityDetailScreen Notes Counter
Visible when done: Notes field shows "X / 200" character counter when
notes are non-empty. Empty notes field shows no counter.

- [ ] Add `const int maxNotesLength = 200;` at top of file
- [ ] Add `_notesController.addListener(() => setState(() {}))` in
  `initState` (currently only `_nameController` has a listener)
- [ ] Wrap notes TextField and counter in a Column:
  - Existing TextField as first child
  - Counter only rendered when `_notesController.text.isNotEmpty`:
    - `SizedBox(height: OutAboutSpacing.xs)` spacer
    - Right-aligned counter text:
      `'${_notesController.text.length} / $maxNotesLength'`
    - Style: `OutAboutTypography.bodySmall(colors).copyWith(
      color: length > maxNotesLength
          ? OutAboutColors.errorColor
          : colors.textSecondary)`
  - When notes are empty: no counter, no spacer
- [ ] Run `flutter analyze` — must pass before Task 7

## Task 7 -- ActivityDetailScreen Save Button Reason + Expanded Validation
Visible when done: Save button disabled with reason text only for
concrete validation errors. Empty name gets quiet disabled button.

- [ ] Add `_canSave` getter (same logic as AddActivityScreen):
  - Check `_isSaving`, name empty, name >50, notes >200
- [ ] Add `_disabledReason` getter (same logic as AddActivityScreen):
  - Empty name returns null (quiet disabled button)
  - Name >50: "Name is too long"
  - Notes >200: "Notes exceed 200 characters"
- [ ] Update save button `onPressed`:
  - Replace inline `_nameController.text.trim().isEmpty || _isSaving`
    check with `_canSave`
- [ ] Add disabled-reason text below save button:
  - Same pattern as AddActivityScreen Task 3
  - Style: `OutAboutTypography.bodySmall(colors).copyWith(
    color: colors.textSecondary)`
  - `textAlign: TextAlign.center`
  - Only visible when `_disabledReason != null`
- [ ] Run `flutter analyze` — must pass before Task 8

## Task 8 -- Widget Tests
Visible when done: Tests cover validation behavior on both screens.

- [ ] AddActivityScreen tests (`test/features/add_activity/`):
  - Test: empty name disables save button with NO reason text visible
  - Test: whitespace-only name disables save button with NO reason text
  - Test: name with 51 chars shows inline error
    "Name must be 50 characters or less" AND reason text "Name is too
    long" beneath button
  - Test: notes at 201 chars shows counter "201 / 200" in error color
    and reason text "Notes exceed 200 characters" below button
  - Test: valid name (1-50) and valid notes (<=200) enables save button
    with no reason text
  - Test: empty notes field shows no counter
  - Test: non-empty notes field shows counter
- [ ] ActivityDetailScreen tests (`test/features/activity_detail/`):
  - Test: name over 50 chars shows inline error
  - Test: notes counter displays correct count when non-empty
  - Test: empty notes shows no counter
  - Test: save button disabled when name exceeds limit, with reason text
  - Test: save button disabled when name is empty, with NO reason text
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] No hardcoded colors — error color uses `OutAboutColors.errorColor`,
  counter uses `colors.textSecondary`
- [ ] All typography passes `colors` argument
- [ ] All spacing from `OutAboutSpacing`
- [ ] Slider values display with correct units on both screens
- [ ] Same temperature range displays identical values on Add Activity
  and Activity Detail (conversion formulas match exactly)
- [ ] `ai_docs/` does not need updating (no schema changes)
