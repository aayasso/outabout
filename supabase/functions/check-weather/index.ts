// check-weather — the cron that turns a forecast into a nudge.
//
// What changed, and why it reads as a rewrite rather than a patch:
//
// The previous version had no memory and no ceiling. It looped every user by
// every activity, checked forecast[0] only, and pushed on every match. Nothing
// recorded what a previous run had already said, so the cadence a user
// actually received was (matching activities x cron frequency). Eight
// activities on a good Saturday was eight pushes, and eight more on the next
// run, indefinitely. It also fetched the weather once per user rather than
// once per place, ran every user in a single unguarded sequence so one
// Tomorrow.io hiccup aborted everybody's notifications for that run, and
// passed country: "" into geographic_context, overriding the "US" the schema
// specifies and writing an empty string into every server-side event.
//
// The cadence rules now live in scheduling.ts, where they are pure and
// tested. This file is the I/O around them: read, decide via that module,
// write. Its own rules of engagement:
//
//   - One user's failure is that user's failure. Every per-user step is inside
//     a try/catch, and the run continues.
//   - The weather is fetched per *place*, not per user. Two users in the same
//     bucket share one call.
//   - The ledger row is written before the push. A push we are unsure about is
//     recorded as sent; see the migration for why that asymmetry is correct.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  conditionProfileOf,
  conditionsMatch,
  windKmh,
} from "./matching.ts";
import {
  alreadyNotifiedKey,
  type Candidate,
  dueAtFor,
  effectiveNotifyPrefs,
  localDateOf,
  matchMargin,
  maxPushesPerUserPerDay,
  type NudgeKind,
  resolveZone,
  selectSendable,
  zonedTimeToInstant,
} from "./scheduling.ts";

const TOMORROW_API_KEY = Deno.env.get("TOMORROW_API_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

/// Every nudge kind, in the order a day is offered to the user. The first that
/// is enabled and due wins the day — see [candidatesForActivity].
const NUDGE_KINDS: NudgeKind[] = ["days_before", "night_before", "morning_of"];

// ---------------------------------------------------------------------------
// Weather
// ---------------------------------------------------------------------------

/// Fetches the daily forecast, or null when Tomorrow.io cannot answer.
///
/// Null rather than a throw: one place failing must cost only that place's
/// users their run. The previous version let the rejection propagate to the
/// top-level catch, which returned 500 and abandoned every user not yet
/// reached — so a single upstream blip silently cancelled the whole cadence
/// for everyone whose row happened to sort later.
async function getWeatherForecast(
  lat: number,
  lon: number,
): Promise<any[] | null> {
  const url =
    `https://api.tomorrow.io/v4/weather/forecast?location=${lat},${lon}` +
    `&apikey=${TOMORROW_API_KEY}&timesteps=1d` +
    `&fields=temperatureMax,temperatureMin,precipitationProbabilityMax,windSpeedMax,uvIndexMax,weatherCodeMax`;
  try {
    const res = await fetch(url);
    if (!res.ok) {
      // 429 is the one worth naming: the previous per-user fetching made it
      // reachable on a few hundred users, and its symptom was identical to
      // "no day matched".
      console.error(`tomorrow.io ${res.status} for ${lat},${lon}`);
      return null;
    }
    const data = await res.json();
    return data.timelines?.daily ?? [];
  } catch (err) {
    console.error(`tomorrow.io fetch failed for ${lat},${lon}:`, err);
    return null;
  }
}

/// Rounds a coordinate to the bucket the forecast is shared across.
///
/// Two decimals, ~1.1km — the same precision geographic_context is bucketed
/// to, so the cache key can never be finer than what we are willing to store.
/// Weather does not vary meaningfully inside a bucket, so two users in one
/// neighbourhood are one API call rather than two.
function forecastBucket(lat: number, lon: number): string {
  return `${Math.round(lat * 100) / 100},${Math.round(lon * 100) / 100}`;
}

// ---------------------------------------------------------------------------
// Event context builders
// ---------------------------------------------------------------------------

function buildConditionsSnapshot(
  forecastDay: any,
  daysAhead: number,
): Record<string, any> {
  const day = forecastDay.values;
  return {
    temp_max_c: day.temperatureMax,
    temp_min_c: day.temperatureMin,
    precipitation_probability: day.precipitationProbabilityMax ??
      day.precipitationProbability,
    wind_kph: windKmh(day),
    uv_index: day.uvIndexMax ?? day.uvIndex ?? null,
    weather_code: day.weatherCodeMax ?? day.weatherCode ?? null,
    forecast_window_hours: daysAhead * 24,
    forecast_date: forecastDay.time,
  };
}

function buildTemporalContext(
  now: Date,
  daysAhead: number,
  tz: string,
  activityCreatedAt?: string | null,
): Record<string, any> {
  // Read in the user's zone, not the server's. The previous version used the
  // container's clock, which is UTC: hour_of_day was up to eight hours out for
  // US users, and day_of_week and season flipped at the wrong moment. Those
  // columns are the ones the intelligence platform correlates against, so a
  // shifted hour is not a cosmetic defect — it is a wrong answer to "when do
  // people go outside".
  const parts: Record<string, number> = {};
  for (
    const p of new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour12: false,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      weekday: undefined,
    }).formatToParts(now)
  ) {
    if (p.type !== "literal") parts[p.type] = Number(p.value);
  }
  const month = parts.month;
  const dayOfMonth = parts.day;
  const hour = parts.hour === 24 ? 0 : parts.hour;

  const season = month >= 3 && month <= 5
    ? "spring"
    : month >= 6 && month <= 8
    ? "summer"
    : month >= 9 && month <= 11
    ? "fall"
    : "winter";

  // Day of week in the user's zone, derived from the local calendar date
  // rather than the server's getDay().
  const dayOfWeek = new Date(Date.UTC(parts.year, month - 1, dayOfMonth))
    .getUTCDay();

  const seasonStart = Date.UTC(parts.year, Math.floor((month - 1) / 3) * 3, 1);
  const weekOfSeason = Math.ceil(
    (Date.UTC(parts.year, month - 1, dayOfMonth) - seasonStart) /
      (7 * 24 * 60 * 60 * 1000),
  );

  // days_since_activity_created is exact: activities.created_at is right
  // there. The other two are written as explicit nulls rather than omitted.
  //
  // TemporalContext in behavioral_event.dart always writes all three, and
  // CLAUDE.md requires every event to carry the full object. Before this, the
  // server's condition_match_notified rows simply lacked the keys — so a query
  // grouping on days_since_last_match had a hole at precisely the event type
  // the notification funnel is measured by, and a missing key is
  // indistinguishable from a bug that dropped it.
  //
  // Null, not a number, because the server genuinely does not know. It tracks
  // notifications, not matches: notification_sends records what was *sent*,
  // and a day can match without ever being sent once the cap is spent.
  // Deriving "days since last match" from sends would put a number in a column
  // that means something else, which is worse than an honest absence — the
  // client fills both correctly, and mixing the two definitions in one column
  // would quietly corrupt every cohort built on it.
  const daysSinceCreated = activityCreatedAt == null
    ? null
    : Math.max(
      0,
      Math.floor(
        (now.getTime() - new Date(activityCreatedAt).getTime()) / 86400000,
      ),
    );

  return {
    hour_of_day: hour,
    day_of_week: dayOfWeek,
    week_of_month: Math.ceil(dayOfMonth / 7),
    month_of_year: month,
    season,
    week_of_season: weekOfSeason,
    days_since_last_match: null,
    days_since_activity_created: daysSinceCreated,
    consecutive_match_count: null,
    days_ahead: daysAhead,
    notification_sent_at: now.toISOString(),
  };
}

function buildGeographicContext(
  lat: number,
  lon: number,
  city: string | undefined,
  state: string | undefined,
  timezone: string,
): Record<string, any> {
  // Two decimal places (~1.1 km), matching bucket() in
  // lib/data/models/behavioral_event.dart and what the privacy policy states.
  // 1000 gave three decimals (~110 m), which is effectively a home address
  // once joined to created_at — the exact risk 20260823000000 cites when it
  // nulls these keys on deletion.
  const precision = 100;
  return {
    lat_bucketed: Math.round(lat * precision) / precision,
    lng_bucketed: Math.round(lon * precision) / precision,
    metro: city ?? null,
    city: city ?? null,
    state: state ?? null,
    // "US", not "". The previous version passed an empty string positionally,
    // which overrode the parameter default and wrote "" into every
    // server-logged event — a column the schema documents as "US" and that the
    // client fills correctly, so the two halves of the dataset disagreed on
    // the same field.
    country: "US",
    timezone,
  };
}

// ---------------------------------------------------------------------------
// Writes
// ---------------------------------------------------------------------------

async function logBehavioralEvent(
  userId: string,
  activityId: string,
  eventType: string,
  conditionsSnapshot: Record<string, any>,
  geographicContext: Record<string, any>,
  temporalContext: Record<string, any>,
  notificationId?: string,
): Promise<void> {
  const { error } = await supabase
    .from("behavioral_events")
    .insert({
      user_id: userId,
      activity_id: activityId,
      event_type: eventType,
      conditions_at_event: conditionsSnapshot,
      geographic_context: geographicContext,
      temporal_context: temporalContext,
      session_context: {
        platform: "edge_function",
        app_version: "server",
        notification_id: notificationId ?? null,
      },
    });

  if (error) {
    // Log but never let a logging failure break notification delivery. This is
    // exactly why the cap reads notification_sends instead of this table.
    console.error("behavioral_event logging failed:", error.message);
  }
}

/// Claims the right to send. Returns false when another run already has it.
///
/// The unique index on (activity_id, forecast_date) is the actual guard: two
/// overlapping cron runs can both read an empty ledger and both decide to
/// send, and only the insert can break that tie. 23505 is therefore an
/// expected outcome here, not an error.
async function claimSend(
  userId: string,
  activityId: string,
  forecastDate: string,
  nudgeKind: NudgeKind,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("notification_sends")
    .insert({
      user_id: userId,
      activity_id: activityId,
      forecast_date: forecastDate,
      nudge_kind: nudgeKind,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code !== "23505") {
      console.error("notification_sends claim failed:", error.message);
    }
    return null;
  }
  return data?.id ?? null;
}

async function sendNotification(
  userId: string,
  activityId: string,
  activityName: string,
  dateLabel: string,
  daysAhead: number,
): Promise<string | null> {
  // Lead time is the whole reason days_before exists, so the copy has to carry
  // it. "Conditions are right for Hiking on Saturday" sent on Thursday is
  // actionable — you can book the court, tell the friend. The same sentence
  // with no day in it is not.
  const message = daysAhead === 0
    ? `🌤 Conditions are right today for: ${activityName}`
    : `🌤 ${dateLabel} looks right for: ${activityName}`;

  try {
    const res = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        filters: [{ field: "tag", key: "user_id", relation: "=", value: userId }],
        contents: { en: message },
        headings: { en: "OutAbout" },
        // Read by NotificationService.parseActivityId on the client. Without it
        // a tap routed nowhere and neither notification_opened nor
        // app_opened_post_notification was ever logged — the deep-link replay in
        // router.dart was unreachable code.
        data: { activity_id: activityId },
      }),
    });
    const data = await res.json();
    return data.id ?? null;
  } catch (err) {
    console.error("OneSignal send failed:", err);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Candidate construction
// ---------------------------------------------------------------------------

/// Every (day, nudge kind) this activity has earned and is due for.
///
/// At most one candidate per forecast day: NUDGE_KINDS is ordered
/// earliest-first and the first due kind takes the day, because a
/// days-before and a morning-of nudge about the same Saturday are the same
/// information twice. The per-activity dedupe in selectSendable would collapse
/// them anyway; doing it here keeps the reason legible.
function candidatesForActivity(
  activity: any,
  profile: any,
  prefs: ReturnType<typeof effectiveNotifyPrefs>,
  forecast: any[],
  today: string,
  now: Date,
  tz: string,
): Candidate[] {
  const out: Candidate[] = [];

  for (const forecastDay of forecast) {
    const forecastDate = localDateOf(new Date(forecastDay.time), tz);
    // Never nudge about a day that has already gone.
    if (forecastDate < today) continue;
    if (!conditionsMatch(forecastDay, profile)) continue;

    const daysAhead = Math.round(
      (zonedTimeToInstant(forecastDate, 12, 0, tz).getTime() -
        zonedTimeToInstant(today, 12, 0, tz).getTime()) / 86400000,
    );

    for (const kind of NUDGE_KINDS) {
      const dueAt = dueAtFor(kind, forecastDate, prefs, tz);
      if (dueAt == null) continue;
      // Not yet due is the common case for a far-off day, and it is why the
      // cron has to keep running rather than deciding everything once.
      if (dueAt.getTime() > now.getTime()) continue;

      out.push({
        activityId: activity.id,
        activityName: activity.name,
        activityCreatedAt: activity.created_at ?? null,
        forecastDate,
        daysAhead,
        kind,
        dueAt,
        margin: matchMargin(forecastDay, profile),
      });
      break;
    }
  }

  return out;
}

// ---------------------------------------------------------------------------
// Authorization
// ---------------------------------------------------------------------------

/// Constant-time string comparison.
///
/// A plain `===` on a secret leaks its prefix through timing: an attacker who
/// can measure the difference between a first-byte mismatch and a
/// twentieth-byte mismatch can recover the key a byte at a time. Cheap to
/// avoid, so avoided.
function timingSafeEqual(a: string, b: string): boolean {
  const ab = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  // Length is compared without an early return, but an unequal length is still
  // detectable; that is accepted, since the key's length is not the secret.
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

/// Whether this request carries the service role key.
///
/// The platform's own `verify_jwt` is not sufficient here, and the reason is
/// the same one 20260831212826 gives for the intelligence tables: the anon key
/// ships inside the app binary, so "a valid JWT" includes a key that every
/// installed copy of OutAbout is carrying and that anyone can read out of it.
///
/// This endpoint is not a read. It sends push notifications to real people and
/// spends metered Tomorrow.io quota, and the cadence ceiling — two per user per
/// day — only bounds the damage per user, not the number of users an attacker
/// could walk through by hammering it. Only the caller that is supposed to run
/// it, the cron job in 20260831213632, holds the service role key.
///
/// That migration already states this contract in its comments. It was
/// describing behaviour that did not exist yet; this is it.
function isServiceRole(req: Request): boolean {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (token.length === 0 || !SERVICE_ROLE_KEY) return false;
  return timingSafeEqual(token, SERVICE_ROLE_KEY);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/// Runs one user. Never throws: the caller must reach every other user.
async function processUser(
  location: any,
  forecastCache: Map<string, any[] | null>,
  now: Date,
): Promise<number> {
  const tz = resolveZone(location.timezone, location.longitude);
  const today = localDateOf(now, tz);

  // The user-level pause, checked before anything else costs a query or an
  // API call. Skipped entirely rather than queued: no push and no
  // notification_sends row, so resuming brings no backlog. A pause that
  // delivered a fortnight of caught-up nudges on resume would teach the user
  // that the switch is not to be trusted.
  const { data: profile } = await supabase
    .from("profiles")
    .select("notifications_paused")
    .eq("id", location.user_id)
    .maybeSingle();
  if (profile?.notifications_paused === true) return 0;

  // Activities first, weather second. A user with nothing on their wishlist
  // costs no Tomorrow.io call at all — which matters because the quota is per
  // account and the previous version spent one per user unconditionally.
  const { data: activities, error: actErr } = await supabase
    .from("activities")
    .select("id, name, user_id, created_at, condition_profiles(*)")
    .eq("user_id", location.user_id)
    .eq("is_archived", false);

  if (actErr) throw actErr;
  if (!activities || activities.length === 0) return 0;

  const bucket = forecastBucket(location.latitude, location.longitude);
  if (!forecastCache.has(bucket)) {
    forecastCache.set(
      bucket,
      await getWeatherForecast(location.latitude, location.longitude),
    );
  }
  const forecast = forecastCache.get(bucket);
  // Null means Tomorrow.io could not answer for this place. Skip, and let the
  // next run try again — a missing forecast is not a matched day.
  if (forecast == null || forecast.length === 0) return 0;

  const activityIds = activities.map((a: any) => a.id);

  const { data: prefRows } = await supabase
    .from("notification_preferences")
    .select("*")
    .in("activity_id", activityIds);
  const prefsByActivity = new Map<string, any>(
    (prefRows ?? []).map((r: any) => [r.activity_id, r]),
  );

  // The two things the cap needs, both from the ledger: what this user has
  // already been told about, and how many they have had since local midnight.
  const localMidnight = zonedTimeToInstant(today, 0, 0, tz);
  const { data: sends } = await supabase
    .from("notification_sends")
    .select("activity_id, forecast_date, sent_at")
    .eq("user_id", location.user_id)
    .gte("sent_at", localMidnight.toISOString());

  const sentTodayCount = sends?.length ?? 0;
  if (sentTodayCount >= maxPushesPerUserPerDay) return 0;

  // Forward-looking dedupe has to reach past today: a day nudged about on
  // Thursday must stay silent on Friday and Saturday too.
  const { data: windowSends } = await supabase
    .from("notification_sends")
    .select("activity_id, forecast_date")
    .eq("user_id", location.user_id)
    .gte("forecast_date", today);

  const notifiedKeys = new Set(
    (windowSends ?? []).map((r: any) =>
      alreadyNotifiedKey(r.activity_id, String(r.forecast_date).slice(0, 10))
    ),
  );

  const candidates: Candidate[] = [];
  for (const activity of activities) {
    const profile = conditionProfileOf(activity);
    if (!profile) continue;
    candidates.push(
      ...candidatesForActivity(
        activity,
        profile,
        effectiveNotifyPrefs(prefsByActivity.get(activity.id) ?? null),
        forecast,
        today,
        now,
        tz,
      ),
    );
  }

  const chosen = selectSendable(candidates, notifiedKeys, sentTodayCount);
  if (chosen.length === 0) return 0;

  const cityParts = (location.city ?? "").split(",");
  const cityName = cityParts[0]?.trim() || undefined;
  const stateName = cityParts[1]?.trim() || undefined;
  const geoContext = buildGeographicContext(
    location.latitude,
    location.longitude,
    cityName,
    stateName,
    tz,
  );

  let sent = 0;
  for (const candidate of chosen) {
    // Claim before sending. If another run took this day, skip it rather than
    // sending a duplicate.
    const claimId = await claimSend(
      location.user_id,
      candidate.activityId,
      candidate.forecastDate,
      candidate.kind,
    );
    if (claimId == null) continue;

    const forecastDay = forecast.find(
      (d: any) => localDateOf(new Date(d.time), tz) === candidate.forecastDate,
    );
    if (!forecastDay) continue;

    const dateLabel = new Date(forecastDay.time).toLocaleDateString("en-US", {
      weekday: "long",
      month: "short",
      day: "numeric",
      timeZone: tz,
    });

    const notifId = await sendNotification(
      location.user_id,
      candidate.activityId,
      candidate.activityName,
      dateLabel,
      candidate.daysAhead,
    );

    if (notifId != null) {
      await supabase
        .from("notification_sends")
        .update({ onesignal_id: notifId })
        .eq("id", claimId);
    }

    await logBehavioralEvent(
      location.user_id,
      candidate.activityId,
      "condition_match_notified",
      buildConditionsSnapshot(forecastDay, candidate.daysAhead),
      geoContext,
      {
        ...buildTemporalContext(
          now,
          candidate.daysAhead,
          tz,
          candidate.activityCreatedAt,
        ),
        trigger: candidate.kind,
      },
      notifId ?? undefined,
    );
    sent += 1;
  }

  return sent;
}

serve(async (req) => {
  if (!isServiceRole(req)) {
    // Deliberately terse. A 401 that explains what it wanted is a 401 that
    // helps whoever is probing.
    return new Response(
      JSON.stringify({ error: "unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const now = new Date();
  const forecastCache = new Map<string, any[] | null>();
  let usersProcessed = 0;
  let usersFailed = 0;
  let notificationsSent = 0;

  try {
    const { data: locations, error: locError } = await supabase
      .from("user_locations")
      .select("user_id, latitude, longitude, city, timezone");

    if (locError) throw locError;

    for (const location of locations ?? []) {
      try {
        notificationsSent += await processUser(location, forecastCache, now);
        usersProcessed += 1;
      } catch (err) {
        // The isolation that was missing. One user's bad row, missing profile
        // or transient query failure used to abort the entire run from here.
        usersFailed += 1;
        const message = err instanceof Error ? err.message : String(err);
        console.error(`user ${location.user_id} failed:`, message);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        users_processed: usersProcessed,
        users_failed: usersFailed,
        notifications_sent: notificationsSent,
        forecast_calls: forecastCache.size,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    // `err` is `unknown` under Deno's strict checking, and a thrown non-Error
    // — which `fetch` and the Supabase client can both produce — would make
    // `err.message` undefined and hide the cause behind an empty 500.
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message, users_processed: usersProcessed }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
