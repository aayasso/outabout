// Tests for the server-side matcher.
//
// Run: deno test supabase/functions/check-weather/matching_test.ts
//
// These exist because the embed-shape bug they cover reached production and
// stayed there. Its only symptom was an absence — no notifications, and no
// condition_match_notified rows — which no amount of reading the logs would
// surface, because nothing errored.

import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

import {
  conditionProfileOf,
  conditionsMatch,
  isAuthorized,
  NOTIFY_SUPPRESSION_HOURS,
  PRECIP_DRY_THRESHOLD,
  PRECIP_RAIN_ONLY,
  shouldNotify,
  windKmh,
} from "./matching.ts";

const profile = {
  temp_enabled: false,
  precip_enabled: false,
  wind_enabled: false,
  temp_min: null,
  temp_max: null,
  wind_max: null,
  precip_level: null,
};

/// A Tomorrow.io daily entry. Wind is m/s, as the API sends it.
function day(values: Record<string, unknown> = {}) {
  return {
    time: "2026-08-23T13:00:00Z",
    values: {
      temperatureMax: 22,
      temperatureMin: 12,
      precipitationProbabilityMax: 5,
      windSpeedMax: 3,
      weatherCodeMax: 1000,
      ...values,
    },
  };
}

Deno.test("conditionProfileOf reads the to-one object PostgREST returns", () => {
  // The shape produced by `condition_profiles(*)` while
  // condition_profiles_activity_id_key UNIQUE (activity_id) exists — verified
  // against the live schema. This is the case the old `[0]` indexing got
  // wrong, and getting it wrong meant every activity was skipped.
  const activity = { id: "a1", condition_profiles: { ...profile, id: "p1" } };
  assertEquals(conditionProfileOf(activity)?.id, "p1");
});

Deno.test("conditionProfileOf still reads the to-many array shape", () => {
  // What PostgREST would return if the unique constraint were ever dropped.
  // Supporting both is what stops a constraint change from silently
  // disabling notifications a second time.
  const activity = { id: "a1", condition_profiles: [{ ...profile, id: "p1" }] };
  assertEquals(conditionProfileOf(activity)?.id, "p1");
});

Deno.test("conditionProfileOf returns null for an activity with no profile", () => {
  assertEquals(conditionProfileOf({ id: "a1", condition_profiles: null }), null);
  assertEquals(conditionProfileOf({ id: "a1", condition_profiles: [] }), null);
  assertEquals(conditionProfileOf({ id: "a1" }), null);
  assertEquals(conditionProfileOf(null), null);
});

Deno.test("regression: the object shape must not read as absent", () => {
  // The bug in one line. `activity.condition_profiles?.[0]` on an object is
  // undefined, so `if (!profile) continue` skipped every activity and the
  // function sent nothing, ever.
  const activity = { id: "a1", condition_profiles: { ...profile, id: "p1" } };
  assertEquals((activity.condition_profiles as any)?.[0], undefined);
  assertNotEquals(conditionProfileOf(activity), null);
});

Deno.test("windKmh converts m/s to km/h", () => {
  assertEquals(windKmh({ windSpeedMax: 10 }), 36);
  assertEquals(windKmh({}), 0);
});

Deno.test("an unconstrained profile matches anything", () => {
  assertEquals(conditionsMatch(day(), profile), true);
  assertEquals(conditionsMatch(day(), null), true);
});

Deno.test("temperature bounds compare against the opposite extreme", () => {
  // A day matches when its range overlaps the profile's, so temp_min is
  // checked against the day's max and temp_max against the day's min. Same
  // rule as evaluateDayMatch.
  const warm = { ...profile, temp_enabled: true, temp_min: 15, temp_max: 30 };
  assertEquals(conditionsMatch(day({ temperatureMax: 22 }), warm), true);
  assertEquals(conditionsMatch(day({ temperatureMax: 14 }), warm), false);
  assertEquals(conditionsMatch(day({ temperatureMin: 31 }), warm), false);
});

Deno.test("an absent bound reads the same as a null one", () => {
  // `!== null` let an absent key reach a comparison against undefined, which
  // was always false — the right answer by accident. `!= null` says it.
  const noKeys = { temp_enabled: true } as any;
  assertEquals(conditionsMatch(day({ temperatureMax: -40 }), noKeys), true);
});

Deno.test("precipitation is bidirectional", () => {
  const avoid = { ...profile, precip_enabled: true, precip_level: "avoid_rain" };
  const wants = {
    ...profile,
    precip_enabled: true,
    precip_level: PRECIP_RAIN_ONLY,
  };

  assertEquals(
    conditionsMatch(day({ precipitationProbabilityMax: 5 }), avoid),
    true,
  );
  assertEquals(
    conditionsMatch(day({ precipitationProbabilityMax: 80 }), avoid),
    false,
  );
  assertEquals(
    conditionsMatch(day({ precipitationProbabilityMax: 80 }), wants),
    true,
  );
  assertEquals(
    conditionsMatch(day({ precipitationProbabilityMax: 5 }), wants),
    false,
  );
});

Deno.test("the dry threshold is inclusive, and matches the client's", () => {
  const avoid = { ...profile, precip_enabled: true, precip_level: "avoid_rain" };
  assertEquals(PRECIP_DRY_THRESHOLD, 20);
  assertEquals(
    conditionsMatch(
      day({ precipitationProbabilityMax: PRECIP_DRY_THRESHOLD }),
      avoid,
    ),
    true,
  );
  assertEquals(
    conditionsMatch(
      day({ precipitationProbabilityMax: PRECIP_DRY_THRESHOLD + 1 }),
      avoid,
    ),
    false,
  );
});

Deno.test("a legacy precip_level reads as avoid_rain", () => {
  // 20260822120000 migrated the vocabulary, but a row written by an older
  // client must not silently stop filtering.
  const legacy = { ...profile, precip_enabled: true, precip_level: "light" };
  assertEquals(
    conditionsMatch(day({ precipitationProbabilityMax: 80 }), legacy),
    false,
  );
});

Deno.test("wind is compared in km/h, not m/s", () => {
  // The profile stores km/h and the API sends m/s. Comparing raw would let a
  // 20 km/h limit accept a 72 km/h day.
  const calm = { ...profile, wind_enabled: true, wind_max: 20 };
  assertEquals(conditionsMatch(day({ windSpeedMax: 3 }), calm), true);
  assertEquals(conditionsMatch(day({ windSpeedMax: 20 }), calm), false);
});

Deno.test("precipitationProbability is accepted as a fallback spelling", () => {
  const avoid = { ...profile, precip_enabled: true, precip_level: "avoid_rain" };
  const d = day();
  delete (d.values as any).precipitationProbabilityMax;
  (d.values as any).precipitationProbability = 80;
  assertEquals(conditionsMatch(d, avoid), false);
});

// ---------------------------------------------------------------------------
// Notification throttling
// ---------------------------------------------------------------------------

const NOW = new Date("2026-08-31T12:00:00Z");

/// `hours` before NOW, as the ISO string Postgres hands back.
function hoursAgo(hours: number): string {
  return new Date(NOW.getTime() - hours * 3_600_000).toISOString();
}

Deno.test("the first ever match notifies", () => {
  assertEquals(shouldNotify(null, NOW), true);
  assertEquals(shouldNotify(undefined, NOW), true);
});

Deno.test("a rerun an hour later stays silent", () => {
  // The cron is hourly. Without this, one matching day is up to 24 pushes.
  assertEquals(shouldNotify(hoursAgo(1), NOW), false);
});

Deno.test("the second day of a run stays silent", () => {
  // The point of the streak rule: told once when the good weather starts.
  assertEquals(shouldNotify(hoursAgo(24), NOW), false);
});

Deno.test("a run that breaks and recovers notifies again", () => {
  // One non-matching day puts the next match at least 48h after the last
  // notification, which is outside the window.
  assertEquals(shouldNotify(hoursAgo(48), NOW), true);
});

Deno.test("the window boundary is exact and inclusive", () => {
  assertEquals(NOTIFY_SUPPRESSION_HOURS, 36);
  assertEquals(shouldNotify(hoursAgo(35.9), NOW), false);
  assertEquals(shouldNotify(hoursAgo(36), NOW), true);
  assertEquals(shouldNotify(hoursAgo(36.1), NOW), true);
});

Deno.test("the window sits strictly between the two gaps that matter", () => {
  // Stated as a property rather than a constant, so changing the window to
  // something that cannot express the rule fails here rather than in
  // production.
  assertEquals(NOTIFY_SUPPRESSION_HOURS > 24, true);
  assertEquals(NOTIFY_SUPPRESSION_HOURS < 48, true);
});

Deno.test("a future timestamp suppresses rather than sends", () => {
  // Clock skew between Postgres and the function host. Failing open here
  // sends a push to a real device on the strength of a timestamp we know is
  // wrong; failing closed costs at most one delayed notification.
  assertEquals(shouldNotify(new Date(NOW.getTime() + 3_600_000), NOW), false);
});

Deno.test("an unreadable timestamp suppresses rather than sends", () => {
  assertEquals(shouldNotify("not a date", NOW), false);
});

Deno.test("accepts both the ISO string and a Date", () => {
  assertEquals(shouldNotify(new Date(NOW.getTime() - 48 * 3_600_000), NOW), true);
  assertEquals(shouldNotify(hoursAgo(48), NOW), true);
});

// ---------------------------------------------------------------------------
// Authorization
// ---------------------------------------------------------------------------

const KEY = "service-role-key-value";

Deno.test("the service role key is accepted", () => {
  assertEquals(isAuthorized(`Bearer ${KEY}`, KEY), true);
});

Deno.test("anything other than the service role key is refused", () => {
  // The anon key is a valid project JWT and ships inside the app binary, so
  // "has a token" is not authorization for a function that pushes to every
  // user on the platform.
  assertEquals(isAuthorized("Bearer anon-key-from-the-app", KEY), false);
  assertEquals(isAuthorized("Bearer ", KEY), false);
  assertEquals(isAuthorized(KEY, KEY), false); // no Bearer prefix
  assertEquals(isAuthorized(null, KEY), false);
  assertEquals(isAuthorized(undefined, KEY), false);
});

Deno.test("a misconfigured deployment refuses everything", () => {
  // Must not fall open into "no auth required" — that is the state this
  // replaces.
  assertEquals(isAuthorized(`Bearer ${KEY}`, ""), false);
  assertEquals(isAuthorized(`Bearer ${KEY}`, null), false);
  assertEquals(isAuthorized("Bearer ", ""), false);
});

Deno.test("a near-miss key is refused", () => {
  assertEquals(isAuthorized(`Bearer ${KEY}x`, KEY), false);
  assertEquals(isAuthorized(`Bearer ${KEY.slice(0, -1)}`, KEY), false);
});
