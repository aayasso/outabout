# Tasks -- Behavioral Event Cleanup
# Created: 2026-05-05
# Requires: design.md approved

## Task 1 -- Move file and update imports
Visible when done: No user-facing change. Build succeeds with model in canonical location.

- [ ] Copy `lib/models/behavioral_event.dart` to `lib/data/models/behavioral_event.dart`
- [ ] Delete `lib/models/behavioral_event.dart`
- [ ] Update import in `lib/services/behavioral_event_service.dart`:
      `'../models/behavioral_event.dart'` -> `'../data/models/behavioral_event.dart'`
- [ ] Update import in `lib/services/location_service.dart`:
      `'../models/behavioral_event.dart'` -> `'../data/models/behavioral_event.dart'`
- [ ] Update import in `test/services/behavioral_event_service_test.dart`:
      `'package:outabout/models/behavioral_event.dart'` -> `'package:outabout/data/models/behavioral_event.dart'`
- [ ] Update import in `test/services/location_service_test.dart`:
      `'package:outabout/models/behavioral_event.dart'` -> `'package:outabout/data/models/behavioral_event.dart'`
- [ ] Remove `lib/models/` directory if empty
- [ ] Run `flutter analyze` -- zero warnings
- [ ] Run `flutter test` -- all pass

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] `ai_docs/architecture.md` folder structure section updated if it references `lib/models/`
