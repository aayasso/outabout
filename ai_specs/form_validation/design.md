# Design -- Form Validation
# Created: 2026-05-19
# Requires: requirements.md approved

## Screens & Widgets

### AddActivityScreen (modified)
- **Route:** `AppRoutes.addActivity` (existing)
- **Type:** ConsumerStatefulWidget (existing)
- **Changes:**
  - Name field: add labelText with asterisk, add errorText for >50 chars
  - Notes field: add character counter (visible only when notes non-empty),
    track length via onChanged
  - Save button: add `_disabledReason` helper text for concrete validation
    errors only (not for empty-name initial state)
  - Sliders: update private `_TemperatureSection` and `_WindSection` to
    respect user's temperature unit (watch `profileProvider`)
  - `_canSave` getter: expanded to check name 1-50 and notes <=200
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (existing)

### ActivityDetailScreen (modified)
- **Route:** `/activity/:id` (existing)
- **Type:** ConsumerStatefulWidget (existing)
- **Changes:**
  - Name field: add errorText for >50 chars, add asterisk to label
  - Notes field: add character counter (visible only when notes non-empty)
  - Save button: add `_disabledReason` helper text for concrete validation
    errors only
  - `_canSave` equivalent: expanded to check name 1-50 and notes <=200
  - Sliders: already use shared widgets with unit support — no change
- **Colors source:** `ref.watch(weatherThemeColorsProvider)` (existing)

### No New Widgets
All changes are modifications to existing private sub-widgets within
AddActivityScreen and ActivityDetailScreen. No new shared widgets needed.

## Validation Constants

```dart
// Defined as static constants in each screen file. No new file needed
// for two int constants.
const int maxNameLength = 50;
const int maxNotesLength = 200;
```

## Validation Logic

### _canSave getter (both screens)

```dart
bool get _canSave {
  if (_isSaving) return false;
  final name = _nameController.text.trim();
  if (name.isEmpty || name.length > maxNameLength) return false;
  if (_notesController.text.length > maxNotesLength) return false;
  return true;
}
```

### _disabledReason getter (both screens)

```dart
/// Returns a reason string ONLY for concrete validation errors —
/// cases where the user has actively entered invalid content.
/// Returns null when the form is in its initial empty state (quiet
/// disabled button, no nagging) or when saving.
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

The key distinction: empty fields get a quiet disabled button (user
hasn't done anything wrong). Concrete validation errors (name too long,
notes too long) get an explanatory line because the user has actively
entered something invalid and needs to know what to fix.

## Field-Level Changes

### Name field (both screens)

```dart
TextField(
  controller: _nameController,
  onChanged: (_) => setState(() {}),
  style: OutAboutTypography.bodyLarge(colors),
  decoration: InputDecoration(
    labelText: 'Activity name *',
    labelStyle: OutAboutTypography.labelMedium(colors),
    errorText: _nameController.text.trim().length > maxNameLength
        ? 'Name must be $maxNameLength characters or less'
        : null,
    errorStyle: OutAboutTypography.bodySmall(colors)
        .copyWith(color: OutAboutColors.errorColor),
    // existing border styles unchanged
  ),
)
```

### Notes field (both screens)

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    TextField(
      controller: _notesController,
      onChanged: (_) => setState(() {}),
      style: OutAboutTypography.bodyMedium(colors),
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes (optional)',
        // existing styles unchanged
      ),
    ),
    if (_notesController.text.isNotEmpty) ...[
      const SizedBox(height: OutAboutSpacing.xs),
      Text(
        '${_notesController.text.length} / $maxNotesLength',
        style: OutAboutTypography.bodySmall(colors).copyWith(
          color: _notesController.text.length > maxNotesLength
              ? OutAboutColors.errorColor
              : colors.textSecondary,
        ),
      ),
    ],
  ],
)
```

The counter is only visible when the notes field is non-empty. An
empty notes field on a fresh screen shows nothing beneath it. Once the
user types anything, the counter appears. Color switches to errorColor
when the count exceeds maxNotesLength.

### Save button area (both screens)

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _canSave ? _save : null,
        child: _isSaving
            ? /* existing spinner */
            : const Text('Save'),
      ),
    ),
    if (_disabledReason case final reason?)
      Padding(
        padding: const EdgeInsets.only(top: OutAboutSpacing.sm),
        child: Text(
          reason,
          style: OutAboutTypography.bodySmall(colors).copyWith(
            color: colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
  ],
)
```

The disabled reason text appears below the button in `textSecondary`
color only for concrete validation errors. When the name is empty
(initial state), the button is disabled but no reason text is shown.

## Slider Unit Fix (AddActivityScreen only)

AddActivityScreen has private slider widgets (`_TemperatureSection`,
`_WindSection`) that hardcode "C" and "km/h". ActivityDetailScreen
already uses shared widgets from `condition_profile_form.dart` that
respect the user's temperature unit.

### Conversion formulas (must match existing shared widgets exactly)

The shared widgets in `condition_profile_form.dart` (lines 11-12) and
`activities_tab.dart` (lines 18-19) both use identical conversion logic:

```dart
int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
int _kmhToMph(double kmh) => (kmh * 0.621371).round();
```

Both return `int` via Dart's `.round()` (rounds half-up). These exact
formulas must be replicated in AddActivityScreen's private slider
widgets. The same temperature range (e.g. 15-30 C) must display as
identical values (59-86 F) on both Add Activity and Activity Detail.

### Fix approach
- AddActivityScreen already watches `weatherThemeColorsProvider`. Add
  a watch on `profileProvider` to get `temperatureUnit`.
- Pass `temperatureUnit` to `_TemperatureSection` and `_WindSection`.
- Update `_TemperatureSection`:
  - Display values as F or C based on unit
  - Slider still operates in Celsius internally (0-50 range)
  - Labels show converted int values with unit symbol
- Update `_WindSection`:
  - Display as mph or km/h based on unit
  - Slider still operates in km/h internally (0-80 range)
  - Label shows converted int value with unit
- `_UvSection`: no unit conversion needed, already shows "0" to "11"

## Data Flow

No new data flow. All validation is client-side, synchronous, and
computed from TextEditingController values on each setState.

```
User types → onChanged → setState
  → _canSave recomputed
  → _disabledReason recomputed (null for empty name, non-null for errors)
  → Name errorText recomputed
  → Notes counter visibility + color recomputed
  → Build rebuilds with updated validation state
```

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Fresh screen, name empty | Button disabled, no reason text shown (quiet) |
| Name is only whitespace | trim() yields empty. Button disabled, no reason text (same as empty) |
| Name is exactly 50 chars | Valid. No error. _canSave true. |
| Name is 51 chars | errorText shows inline. Button disabled. Reason: "Name is too long" |
| Notes empty | No counter visible. |
| Notes at exactly 200 | Counter shows "200 / 200" in textSecondary. Valid. |
| Notes at 201 | Counter shows "201 / 200" in errorColor. Button disabled. Reason: "Notes exceed 200 characters" |
| User pastes long text | Counter and errors update immediately via onChanged + setState |
| Both name and notes invalid | First concrete error wins in _disabledReason (name checked first) |
| Name empty AND notes >200 | Button disabled, reason shows "Notes exceed 200 characters" (name-empty returns null, so notes error surfaces) |
| Profile not loaded yet (temperatureUnit) | Falls back to 'F' (existing behavior in both screens) |

## Haptic Moments

- No new haptic events. Existing save haptic unchanged.
