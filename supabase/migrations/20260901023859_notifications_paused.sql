-- profiles.notifications_paused — the off switch the app never had.
--
-- Until now the only way to stop OutAbout notifying you was to revoke the OS
-- permission, which is a decision a user makes once and effectively never
-- reverses: the app cannot re-ask, and the path back is four levels deep in
-- Settings. So the app's only volume control was the one control it must never
-- make a user reach for.
--
-- That is a product problem before it is a compliance one, and it is the other
-- half of the cadence work in 20260831000000. A ceiling of two a day is the
-- right ceiling for someone who wants the nudges. Someone who wants a quiet
-- fortnight needs a switch, and if the only switch available is the permission
-- itself, a quiet fortnight costs the install permanently.
--
-- Boolean on profiles rather than a row in notification_preferences, because
-- that table is keyed by activity_id: expressing "pause everything" there
-- would mean writing every activity's row, and restoring it afterwards would
-- mean having remembered what each one used to say. A user-level intent
-- belongs on the user.
--
-- Deliberately not a "quiet hours" range. Quiet hours are already enforced
-- server-side for everyone (07:00-21:00 local, in scheduling.ts), and making
-- them configurable invites a user to solve "too many notifications" with a
-- narrower window, which is the wrong fix for the wrong problem.
alter table public.profiles
  add column if not exists notifications_paused boolean not null default false;

comment on column public.profiles.notifications_paused is
  'User-level pause. check-weather skips these users entirely — no push and '
  'no notification_sends row, so nothing is "caught up" on resume. Distinct '
  'from a notification_preferences row, which is per activity.';
