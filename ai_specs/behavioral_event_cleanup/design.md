# Design -- Behavioral Event Cleanup
# Created: 2026-05-05
# Requires: requirements.md approved

## Screens & Widgets

No screens or widgets are modified. This is a file-move refactor only.

## Provider Structure

No new providers. No provider changes.

## Repository Methods

No new repository methods. No repository changes.

## Data Flow

No data flow changes. The model file moves from `lib/models/` to `lib/data/models/`. Import paths update accordingly.

### Files to modify

1. **Move file:**
   - `lib/models/behavioral_event.dart` -> `lib/data/models/behavioral_event.dart`

2. **Update imports (4 files):**
   - `lib/services/behavioral_event_service.dart`
     - `import '../models/behavioral_event.dart'` -> `import '../data/models/behavioral_event.dart'`
   - `lib/services/location_service.dart`
     - `import '../models/behavioral_event.dart'` -> `import '../data/models/behavioral_event.dart'`
   - `test/services/behavioral_event_service_test.dart`
     - `import 'package:outabout/models/behavioral_event.dart'` -> `import 'package:outabout/data/models/behavioral_event.dart'`
   - `test/services/location_service_test.dart`
     - `import 'package:outabout/models/behavioral_event.dart'` -> `import 'package:outabout/data/models/behavioral_event.dart'`

3. **Cleanup:**
   - Remove `lib/models/` directory if empty after move

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Missed import update | `flutter analyze` fails -- caught immediately |
| `lib/models/` has other files | Directory preserved; only `behavioral_event.dart` moves |

## Haptic Moments
- None

## Open Questions Resolved
- None
