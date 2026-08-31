// When a matched day is allowed to become a push, and which matches win when
// more of them qualify than the user should ever receive.
//
// Split out of index.ts for the same reason matching.ts was: none of this is
// reachable from a test once it is tangled with a Supabase client and four
// environment variables, and the failure mode here is identical to the embed
// bug — silence, or its opposite, with nothing in the logs either way.
//
// The rule this file exists to enforce: a user is never notified twice about
// the same activity on the same forecast day, and never more than
// [maxPushesPerUserPerDay] times in one local day. Before this file, neither
// held. The function looped every user by every activity and pushed on every
// match, every run, with no memory of the previous run — so the cadence a user
// actually experienced was (matching activities x cron frequency), unbounded.
//
// Everything here is pure. The clock, the timezone, the preferences and the
// already-sent ledger all arrive as arguments.

// ---------------------------------------------------------------------------
// Cadence ceiling
// ---------------------------------------------------------------------------

/// Hard ceiling on pushes to one user in one local day.
///
/// Two, not one: a user with a hiking activity and a dining activity on the
/// same good Saturday has two genuinely different intents, and collapsing them
/// loses the second. Two, not more: the permission to interrupt is the one
/// asset in this app that cannot be re-earned once spent, and every additional
/// push per day buys less engagement than it costs in uninstalls.
export const maxPushesPerUserPerDay = 2;

/// Hard ceiling on pushes about one activity in one local day. Combined with
/// [alreadyNotifiedKey] this is what makes a re-run of the cron idempotent.
export const maxPushesPerActivityPerDay = 1;

// ---------------------------------------------------------------------------
// Quiet hours
// ---------------------------------------------------------------------------

/// No push before this local hour, ever, whatever a preference says.
export const quietHoursEndHour = 7;

/// No push at or after this local hour, ever.
///
/// A push that lands at 23:40 about tomorrow morning is not a nudge, it is a
/// reason to turn notifications off. Anything falling after this hour is held
/// to [quietHoursEndHour] the next morning rather than dropped, because the
/// information is still good — it was only the delivery time that was wrong.
export const quietHoursStartHour = 21;

/// The local hour the night-before and days-before nudges aim for.
///
/// Evening, because both exist to let the user act — book the court, tell the
/// friend, set the alarm — and an evening nudge is the last moment that is
/// still the day before rather than a scramble.
export const eveningNudgeHour = 18;

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

/// The subset of a `notification_preferences` row this scheduler reads.
export type NotifyPrefs = {
  notifyMorningOf: boolean;
  notifyNightBefore: boolean;
  notifyDaysBefore: boolean;
  daysBeforeCount: number;
  /// Local wall-clock time, "HH:MM:SS".
  morningTime: string;
};

/// What an activity with no `notification_preferences` row gets.
///
/// Deliberately not the table's column defaults, which are all `false`. Those
/// describe a row somebody has already opened and switched off; they were
/// never meant to describe the absence of a row. Reading them as the runtime
/// default would mean an activity created before the preferences UI existed
/// silently never notifies — the exact failure this whole file is here to
/// prevent, arrived at from the other direction.
///
/// The migration that ships with this file changes the column defaults to
/// match, so that "everything off" can only ever be a thing the user chose.
export const defaultNotifyPrefs: NotifyPrefs = {
  notifyMorningOf: true,
  notifyNightBefore: false,
  notifyDaysBefore: false,
  daysBeforeCount: 2,
  morningTime: "07:00:00",
};

/// Reads a `notification_preferences` row, or falls back to
/// [defaultNotifyPrefs] when the activity has none.
///
/// A row that exists is obeyed exactly, including a row with every flag off:
/// that is a user who opened the screen and turned this activity down, and
/// overriding it would be the app arguing with them.
export function effectiveNotifyPrefs(
  row: Record<string, unknown> | null | undefined,
): NotifyPrefs {
  if (row == null) return defaultNotifyPrefs;

  const count = Number(row.days_before_count ?? defaultNotifyPrefs.daysBeforeCount);
  return {
    notifyMorningOf: row.notify_morning_of === true,
    notifyNightBefore: row.notify_night_before === true,
    notifyDaysBefore: row.notify_days_before === true,
    // Clamped rather than trusted. A negative count would schedule a nudge
    // after the day it is about, and an unbounded one would reach past the
    // forecast window into days the matcher never evaluated.
    daysBeforeCount: Number.isFinite(count)
      ? Math.min(Math.max(Math.trunc(count), 1), 7)
      : defaultNotifyPrefs.daysBeforeCount,
    morningTime: typeof row.morning_time === "string" && row.morning_time.length >= 4
      ? row.morning_time
      : defaultNotifyPrefs.morningTime,
  };
}

// ---------------------------------------------------------------------------
// Timezone
// ---------------------------------------------------------------------------

/// Minutes [tz] is ahead of UTC at [instant].
///
/// Derived by formatting the instant in the zone and reading the wall clock
/// back, because that is the only way to get a zone's offset out of `Intl`
/// without a tz database of our own. DST is handled for free: the answer is
/// the offset in effect at that instant, not a fixed one for the zone.
export function zoneOffsetMinutes(instant: Date, tz: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts: Record<string, number> = {};
  for (const p of dtf.formatToParts(instant)) {
    if (p.type !== "literal") parts[p.type] = Number(p.value);
  }
  // `hour: "2-digit"` with hour12:false renders midnight as 24 in some ICU
  // versions. Left as 24 it rolls Date.UTC into the next day and puts the
  // offset out by 24 hours exactly once a day, at the worst possible moment.
  const hour = parts.hour === 24 ? 0 : parts.hour;
  const asUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    hour,
    parts.minute,
    parts.second,
  );
  return (asUtc - instant.getTime()) / 60000;
}

/// A coarse zone for a user whose `user_locations` row predates the timezone
/// column.
///
/// Fifteen degrees of longitude to the hour. Wrong wherever a political
/// boundary disagrees with the sun, and blind to DST, which is why the app now
/// writes the real IANA identifier and this is only ever the fallback. It is
/// still much better than UTC: an hour or two of error moves a 07:00 nudge
/// within the morning, where UTC would move it to the middle of the night for
/// every user in the Americas.
export function fallbackZoneFromLongitude(longitude: number): string {
  const hours = Math.max(Math.min(Math.round(longitude / 15), 14), -12);
  // Etc/GMT signs are inverted from the offsets they name: Etc/GMT+5 is
  // UTC-5. This is IANA's convention, not a mistake here.
  if (hours === 0) return "Etc/GMT";
  return hours > 0 ? `Etc/GMT-${hours}` : `Etc/GMT+${Math.abs(hours)}`;
}

/// The zone to schedule [location] in.
export function resolveZone(
  timezone: string | null | undefined,
  longitude: number,
): string {
  const candidate = (timezone ?? "").trim();
  if (candidate.length > 0) {
    try {
      // Cheapest way to ask ICU whether it has ever heard of this zone. A
      // stored identifier the runtime cannot resolve throws here rather than
      // at the first format call deep inside a loop.
      new Intl.DateTimeFormat("en-US", { timeZone: candidate });
      return candidate;
    } catch {
      // Fall through. A bad stored value is not worth failing a user's whole
      // notification run over.
    }
  }
  return fallbackZoneFromLongitude(longitude);
}

/// The local calendar date at [instant], as "YYYY-MM-DD".
export function localDateOf(instant: Date, tz: string): string {
  const dtf = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  // en-CA renders ISO order natively, which avoids reassembling parts by hand.
  return dtf.format(instant);
}

/// The instant at which local wall-clock [hour]:[minute] occurs on
/// [localDate] ("YYYY-MM-DD") in [tz].
///
/// Two passes, because the offset used to convert depends on the instant being
/// converted to. The first pass gets within an hour under DST; the second
/// lands on it. A time that does not exist (the spring-forward gap) resolves
/// to the instant the clock jumps to, which is the next moment the user could
/// possibly see it — the right answer for a nudge.
export function zonedTimeToInstant(
  localDate: string,
  hour: number,
  minute: number,
  tz: string,
): Date {
  const [y, m, d] = localDate.split("-").map(Number);
  const wall = Date.UTC(y, m - 1, d, hour, minute, 0);
  let instant = new Date(wall - zoneOffsetMinutes(new Date(wall), tz) * 60000);
  instant = new Date(wall - zoneOffsetMinutes(instant, tz) * 60000);
  return instant;
}

/// [localDate] shifted by [days], staying a "YYYY-MM-DD" string.
export function shiftLocalDate(localDate: string, days: number): string {
  const [y, m, d] = localDate.split("-").map(Number);
  const shifted = new Date(Date.UTC(y, m - 1, d + days));
  return shifted.toISOString().slice(0, 10);
}

/// Parses "HH:MM:SS" (or "HH:MM") into hour and minute, clamped to a real
/// clock face. A malformed stored value falls back to the default morning
/// rather than scheduling at hour NaN, which compares false against every
/// bound and would silently never fire.
export function parseWallTime(value: string): { hour: number; minute: number } {
  const [rawHour, rawMinute] = value.split(":");
  const hour = Number(rawHour);
  const minute = Number(rawMinute);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
    return { hour: quietHoursEndHour, minute: 0 };
  }
  return {
    hour: Math.min(Math.max(Math.trunc(hour), 0), 23),
    minute: Math.min(Math.max(Math.trunc(minute), 0), 59),
  };
}

// ---------------------------------------------------------------------------
// Candidates
// ---------------------------------------------------------------------------

/// Why a candidate is being sent. Carried through to the behavioral event so
/// the dataset can tell a morning-of nudge from a three-days-out one without
/// re-deriving it from timestamps.
export type NudgeKind = "morning_of" | "night_before" | "days_before";

/// One matched (activity, forecast day) pair that has cleared its schedule.
export type Candidate = {
  activityId: string;
  activityName: string;

  /// activities.created_at, carried so the behavioral event can report
  /// days_since_activity_created without a second query. Optional because
  /// nothing in the scheduling decision depends on it.
  activityCreatedAt?: string | null;

  /// The day the conditions are good, "YYYY-MM-DD".
  forecastDate: string;
  /// Calendar days from the local today to [forecastDate]. Zero is today.
  daysAhead: number;
  kind: NudgeKind;
  /// Instant this became sendable. Kept for ordering and for the event.
  dueAt: Date;
  /// How comfortably the day cleared the profile's bounds. Ties break on it.
  margin: number;
};

/// The dedupe key for "this activity, this forecast day".
///
/// Deliberately keyed on the day the conditions are good rather than the day
/// the push goes out. A night-before nudge and a morning-of nudge are about
/// the same Saturday, and the user experiences a second one as the app
/// repeating itself, not as new information.
export function alreadyNotifiedKey(
  activityId: string,
  forecastDate: string,
): string {
  return `${activityId}|${forecastDate}`;
}

/// When a nudge of [kind] about [forecastDate] should first be sendable.
///
/// Returns null when the preference for that kind is off, or when the schedule
/// would land outside the days the forecast covers.
export function dueAtFor(
  kind: NudgeKind,
  forecastDate: string,
  prefs: NotifyPrefs,
  tz: string,
): Date | null {
  switch (kind) {
    case "morning_of": {
      if (!prefs.notifyMorningOf) return null;
      const { hour, minute } = parseWallTime(prefs.morningTime);
      return applyQuietHours(forecastDate, hour, minute, tz);
    }
    case "night_before": {
      if (!prefs.notifyNightBefore) return null;
      return applyQuietHours(
        shiftLocalDate(forecastDate, -1),
        eveningNudgeHour,
        0,
        tz,
      );
    }
    case "days_before": {
      if (!prefs.notifyDaysBefore) return null;
      return applyQuietHours(
        shiftLocalDate(forecastDate, -prefs.daysBeforeCount),
        eveningNudgeHour,
        0,
        tz,
      );
    }
  }
}

/// Moves a scheduled time out of quiet hours, forward to the next morning.
///
/// Forward, never backward: pulling a 23:00 nudge back to 20:59 the same
/// evening would fire it before the user asked for it, and for a days-before
/// nudge that is a day early. Pushing it to 07:00 is late by a few hours and
/// never wrong by a day.
export function applyQuietHours(
  localDate: string,
  hour: number,
  minute: number,
  tz: string,
): Date {
  if (hour >= quietHoursStartHour) {
    return zonedTimeToInstant(shiftLocalDate(localDate, 1), quietHoursEndHour, 0, tz);
  }
  if (hour < quietHoursEndHour) {
    return zonedTimeToInstant(localDate, quietHoursEndHour, 0, tz);
  }
  return zonedTimeToInstant(localDate, hour, minute, tz);
}

/// Picks which of [candidates] to actually send.
///
/// [sentTodayCount] is how many pushes this user has already received in the
/// current local day, and [notifiedKeys] the (activity, forecast day) pairs
/// already covered — both read from behavioral_events, which is the only
/// durable record of what was sent and is therefore the source of truth the
/// cron cannot lose by restarting.
///
/// Ordering is soonest-first, then by margin. Soonest first because a nudge
/// about today expires today, while one about Saturday keeps until Friday; a
/// cap that spent its slots on the far day would drop the urgent one. Margin
/// breaks the tie because a day that clears the bounds comfortably is a better
/// bet than one that scrapes past them, and activity id breaks that, so the
/// choice is stable across runs rather than dependent on row order.
export function selectSendable(
  candidates: Candidate[],
  notifiedKeys: Set<string>,
  sentTodayCount: number,
): Candidate[] {
  const remaining = maxPushesPerUserPerDay - sentTodayCount;
  if (remaining <= 0) return [];

  const seenActivities = new Set<string>();
  const eligible = candidates
    .filter((c) => !notifiedKeys.has(alreadyNotifiedKey(c.activityId, c.forecastDate)))
    .sort((a, b) =>
      a.daysAhead - b.daysAhead ||
      b.margin - a.margin ||
      a.activityId.localeCompare(b.activityId)
    );

  const perActivity = new Map<string, number>();
  const chosen: Candidate[] = [];
  for (const candidate of eligible) {
    if (chosen.length >= remaining) break;
    // maxPushesPerActivityPerDay, enforced within this run. Across runs the
    // same job is done by notifiedKeys, which outlives the process.
    const already = perActivity.get(candidate.activityId) ?? 0;
    if (already >= maxPushesPerActivityPerDay) continue;
    perActivity.set(candidate.activityId, already + 1);
    seenActivities.add(candidate.activityId);
    chosen.push(candidate);
  }
  return chosen;
}

/// How comfortably [forecastDay] clears [profile], in a unit that is only ever
/// compared against other margins from the same run.
///
/// Each enabled bound contributes its slack, normalised by the span the slider
/// offers, so a 3-degree cushion on temperature and a 3-km/h one on wind do
/// not pretend to be the same size. A profile with nothing enabled scores
/// zero: it matches every day, so no day is a better instance of it.
export function matchMargin(forecastDay: any, profile: any): number {
  if (profile == null) return 0;
  const day = forecastDay?.values ?? {};
  let total = 0;

  if (profile.temp_enabled) {
    // The slider spans roughly -20..45C; 65 degrees is the normaliser.
    if (profile.temp_min != null && day.temperatureMax != null) {
      total += (day.temperatureMax - profile.temp_min) / 65;
    }
    if (profile.temp_max != null && day.temperatureMin != null) {
      total += (profile.temp_max - day.temperatureMin) / 65;
    }
  }

  if (profile.precip_enabled) {
    const precip = day.precipitationProbabilityMax ?? day.precipitationProbability ?? 0;
    // Distance from the dry threshold, in either direction depending on what
    // the user wanted, over the 0..100 the probability spans.
    total += (profile.precip_level === "rain_only" ? precip : 100 - precip) / 100;
  }

  if (profile.wind_enabled && profile.wind_max != null) {
    const wind = (day.windSpeedMax ?? 0) * 3.6;
    total += (profile.wind_max - wind) / 80;
  }

  return total;
}
