# Design — Push Notifications
# Created: 2026-05-04
# Requires: requirements.md approved

## 1. Screens & Widgets

No new screens.

### Modifications:
- **`lib/main.dart`** -- Initialize OneSignal after Supabase init
- **`lib/services/notification_service.dart`** -- Add OneSignal setup,
  tag management, notification click handler
- **`lib/features/onboarding/pages/auth_page.dart`** -- Set OneSignal
  user_id tag after successful auth

---

## 2. Provider Structure

### Updated provider

```
notificationServiceProvider   Provider<NotificationService> (update existing)
  |-- reads: behavioralEventServiceProvider
  '-- manages OneSignal init, tags, click handling
```

The existing `NotificationService` in `lib/services/notification_service.dart`
currently only handles permission requests. It will be extended with
OneSignal-specific methods.

---

## 3. Service Methods

### NotificationService (extend existing)
**File:** `lib/services/notification_service.dart`

```dart
/// Initialize OneSignal with app ID from dotenv.
/// Call once in main.dart after Supabase init.
Future<void> initializeOneSignal(String appId) async {
  OneSignal.initialize(appId);
}

/// Set user_id tag so the edge function can target this user.
/// Called after successful auth (all auth types including anonymous).
Future<void> setUserTag(String userId) async {
  OneSignal.User.addTagWithKey('user_id', userId);
}

/// Clear user_id tag on sign out.
Future<void> clearUserTag() async {
  OneSignal.User.removeTag('user_id');
}

/// Set up notification click handler.
/// Extracts activity_id from notification data and navigates.
void setupClickHandler({
  required void Function(String activityId) onActivityTap,
  required BehavioralEventService eventService,
}) {
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    final activityId = data?['activity_id'] as String?;
    if (activityId != null) {
      eventService.log('notification_opened', extra: {
        'activity_id': activityId,
      });
      onActivityTap(activityId);
    }
  });
}
```

---

## 4. Data Flow

### Initialization flow
```
main() in main.dart
  |-- await dotenv.load()
  |-- await Supabase.initialize(...)
  |-- OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!)
  '-- runApp(ProviderScope(...))

Note: The GoRouter instance is a Riverpod provider, so it is not available
in main() before runApp. The notification click handler must be set up
INSIDE the widget tree where the ProviderScope is available. Do this in
OutAboutApp's initState (or a dedicated startup widget) where ref is
accessible. Use ref.read(routerProvider).go('/activity/$activityId') to
navigate from the click handler.
```

### Auth flow (tag setting)
```
User completes auth (sign up, sign in, anonymous)
  |-- Supabase auth success
  |-- final userId = client.auth.currentUser!.id
  '-- notificationService.setUserTag(userId)
```

### Sign out flow (tag clearing)
```
User taps Sign Out in SettingsTab
  |-- notificationService.clearUserTag()
  |-- await supabase.auth.signOut()
  '-- router redirects to onboarding
```

### Notification tap flow
```
User taps push notification
  |-- OneSignal click listener fires
  |-- Extract activity_id from notification additionalData
  |-- Log 'notification_opened' behavioral event
  '-- Navigate to /activity/$activityId via go_router
```

---

## 5. Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| OneSignal init fails | Log error, app continues without push |
| Notification tap with no activity_id | Ignore -- open app normally |
| Notification tap with archived activity | ActivityDetailScreen shows archived banner |
| Notification tap with no auth session | Router redirect to onboarding |
| Cold start from notification | OneSignal queues click, fires after init |
| ONESIGNAL_APP_ID missing from .env | Throw on init -- fail loudly |

---

## 6. Haptic Moments

No new haptic moments for this feature.

---

## 7. OneSignal Notification Data Format

The edge function sends notifications with this `data` payload:
```json
{
  "activity_id": "uuid-of-matched-activity"
}
```

The click handler extracts `activity_id` from `event.notification.additionalData`.
