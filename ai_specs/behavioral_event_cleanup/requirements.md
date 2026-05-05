# Requirements -- Behavioral Event Cleanup
# Created: 2026-05-05
# Status: draft

## Summary
Move `lib/models/behavioral_event.dart` to `lib/data/models/behavioral_event.dart` and update all import paths. This aligns the behavioral event model with the project's standard data layer folder structure (`lib/data/models/`), matching the recent `activity.dart` move.

## User Stories

### Primary flow
- As a developer, I want all model classes under `lib/data/models/` so that the folder structure matches the architecture documented in CLAUDE.md.

### Secondary flows
- None. This is a pure refactor with no user-facing change.

### Edge cases
- What happens when imports are missed? Build fails immediately -- caught by `flutter analyze`.

## Acceptance Criteria
- [ ] `lib/models/behavioral_event.dart` no longer exists
- [ ] `lib/data/models/behavioral_event.dart` exists with identical content
- [ ] All imports updated (4 files import the model directly):
  - `lib/services/behavioral_event_service.dart`
  - `lib/services/location_service.dart`
  - `test/services/behavioral_event_service_test.dart`
  - `test/services/location_service_test.dart`
- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes with no regressions
- [ ] `lib/models/` directory is empty or removed if no other files remain

## Screens Involved
- None -- no UI changes.

## Data Requirements
- Supabase tables: none
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations
- Does this feature behave differently across themes? No

## Out of Scope
- Refactoring the BehavioralEvent class internals
- Moving behavioral_event_service.dart (it stays in lib/services/)
- Moving any other model files

## Open Questions
- None
