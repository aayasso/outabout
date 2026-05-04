# Requirements — Push Notifications
# Created: 2026-05-04
# Status: draft

## Summary
Wire OneSignal push notifications into the Flutter app. The Supabase Edge
Function (`check-weather`) already detects condition matches and sends push
notifications via the OneSignal REST API, targeting users by a `user_id` tag.
The Flutter side needs to: initialize OneSignal on app start, set the
`user_id` tag after auth, and handle notification taps to navigate to the
relevant activity. A `notification_opened` behavioral event is logged when
the user taps a notification.

## User Stories

### Primary flow
- As a user, I want to receive a push notification when weather conditions
  match my activity so I don't miss a perfect opportunity.
- As a user, I want to tap the notification and go directly to the matching
  activity's detail screen.

### Secondary flows
- As a user, I want notification permission to be requested during
  onboarding (already implemented in NotificationPermissionPage).
- As a user who denied notifications, I want to be able to enable them
  later from device settings.

### Edge cases
- What happens when the user taps a notification but the activity has been
  archived?
  -> ActivityDetailScreen handles this -- shows "This activity has been
  archived" state.
- What happens when the user taps a notification while the app is already
  open?
  -> Navigate to the activity detail screen. go_router handles this via
  `context.go('/activity/$activityId')`.
- What happens when the user taps a notification but has no auth session?
  -> Router redirect catches this and sends to onboarding. The activity
  deep link is lost -- acceptable for v1.
- What happens when OneSignal initialization fails?
  -> Log error via `dart:developer`. App continues without push
  notifications. Do not crash.

## Acceptance Criteria
- [ ] `onesignal_flutter` package added to pubspec.yaml
- [ ] OneSignal initialized on app start in `main.dart` using
      `ONESIGNAL_APP_ID` from dotenv
- [ ] `user_id` tag set on OneSignal after successful auth -- for all auth
      types including anonymous (every Supabase user has a valid user_id;
      the edge function targets by this tag regardless of auth method)
- [ ] `user_id` tag cleared on sign out
- [ ] Notification tap handler extracts `activity_id` from notification
      data and navigates to `/activity/$activityId`
- [ ] `notification_opened` behavioral event logged on notification tap
- [ ] Notification permission request during onboarding already works
      (no changes needed to NotificationPermissionPage)
- [ ] App handles cold start from notification (navigate after init)
- [ ] App handles foreground notification tap (navigate immediately)
- [ ] `ONESIGNAL_APP_ID` read from dotenv -- never hardcoded

## Screens Involved
- No new screens. Modifications to:
  - `lib/main.dart` -- OneSignal initialization
  - `lib/services/notification_service.dart` -- OneSignal setup + tag
    management
  - Onboarding auth flow -- set tag after sign up/in

## Data Requirements
- Supabase tables: `behavioral_events` (insert via BehavioralEventService
  for `notification_opened`)
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none
- New env var: `ONESIGNAL_APP_ID` in `.env`

## Weather Theme Considerations
- No -- push notifications are not visual within the app. The notification
  tap navigates to a theme-adaptive screen (ActivityDetailScreen) but the
  notification itself has no theme.

## Out of Scope
- Quiet hours / do-not-disturb scheduling
- In-app notification center / inbox
- Notification preferences per activity (future -- uses
  `notification_preferences` table)
- Rich notification content (images, action buttons)
- Modifying the edge function (already built and working)

## Open Questions
- None -- all decisions made.
