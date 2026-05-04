# Tasks — Push Notifications
# Created: 2026-05-04
# Requires: design.md approved

## Task 1 — Add onesignal_flutter package
Visible when done: Package installed, `flutter analyze` passes.

Files:
- `pubspec.yaml` (update)
- `.env` (update — add ONESIGNAL_APP_ID placeholder)
- `.env.example` (update — add ONESIGNAL_APP_ID)

Subtasks:
- [ ] Add `onesignal_flutter` to pubspec.yaml dependencies
- [ ] Add `ONESIGNAL_APP_ID=your_app_id_here` to `.env.example`
- [ ] Add `ONESIGNAL_APP_ID` to `.env`
- [ ] Run `flutter pub get`
- [ ] Run `flutter analyze` — must pass before Task 2

---

## Task 2 — NotificationService OneSignal methods
Visible when done: `NotificationService` has `initializeOneSignal`,
`setUserTag`, `clearUserTag`, `setupClickHandler` methods.
`flutter analyze` passes.

Files:
- `lib/services/notification_service.dart` (update)

Subtasks:
- [ ] Add `initializeOneSignal(String appId)` method
- [ ] Add `setUserTag(String userId)` method
- [ ] Add `clearUserTag()` method
- [ ] Add `setupClickHandler(onActivityTap, eventService)` method
- [ ] Run `flutter analyze` — must pass before Task 3

---

## Task 3 — Wire initialization + click handler
Visible when done: OneSignal initializes on app start. Notification
click handler set up with navigation to activity detail.

Files:
- `lib/main.dart` (update)

Subtasks:
- [ ] In `main()`, after Supabase init and before `runApp()`, call
      `OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!)`
      wrapped in try-catch — log error on failure, don't crash
- [ ] Set up the notification click handler INSIDE `OutAboutApp`'s
      `initState` (where `ref` is available via ConsumerStatefulWidget).
      The GoRouter is a Riverpod provider and is NOT available in `main()`
      before `runApp`. Use `ref.read(routerProvider).go('/activity/$id')`
      to navigate from the click callback.
- [ ] Pass `behavioralEventServiceProvider` to the click handler so it
      can log `notification_opened`
- [ ] Run `flutter analyze` — must pass before Task 4

---

## Task 4 — Wire user tag on auth + sign out
Visible when done: After auth (all types including anonymous), OneSignal
user_id tag is set. On sign out, tag is cleared.

Files:
- `lib/features/onboarding/pages/auth_page.dart` (update — set tag after auth)
- `lib/features/home/tabs/settings_tab.dart` (update — clear tag on sign out)

Subtasks:
- [ ] After successful auth in `auth_page.dart`, call
      `notificationService.setUserTag(userId)` for all auth types
      (email sign up, email sign in, anonymous)
- [ ] In SettingsTab sign out flow, call
      `notificationService.clearUserTag()` before `auth.signOut()`
- [ ] Run `flutter analyze` — must pass before Task 5

---

## Task 5 — Tests + polish
Visible when done: Tests pass, pre-flight clean.

Files:
- `test/services/notification_service_test.dart` (update)

Subtasks:
- [ ] Verify `ONESIGNAL_APP_ID` is in `.env.example`
- [ ] Verify notification click handler logs `notification_opened` event
      (unit test with mocked OneSignal — may need to skip if OneSignal
      doesn't support test mocking; document limitation)
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Pre-flight checklist from CLAUDE.md

---

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] `.env.example` has `ONESIGNAL_APP_ID` entry
- [ ] `ai_docs/` updated if architecture changed
