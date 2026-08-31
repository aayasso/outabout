// Tests for the notification scheduler.
//
// Run: deno test supabase/functions/check-weather/scheduling_test.ts
//
// The behaviour under test is a cadence ceiling, and a ceiling is only ever
// observable as an absence — the push that did not arrive. That is the same
// shape of bug as the embed defect matching_test.ts covers, and it is why
// every rule here is asserted directly rather than inferred from a run.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

import {
  alreadyNotifiedKey,
  applyQuietHours,
  type Candidate,
  defaultNotifyPrefs,
  dueAtFor,
  effectiveNotifyPrefs,
  fallbackZoneFromLongitude,
  localDateOf,
  matchMargin,
  maxPushesPerUserPerDay,
  type NotifyPrefs,
  parseWallTime,
  resolveZone,
  selectSendable,
  shiftLocalDate,
  zonedTimeToInstant,
  zoneOffsetMinutes,
} from "./scheduling.ts";

const NY = "America/New_York";

function candidate(over: Partial<Candidate> = {}): Candidate {
  return {
    activityId: "a1",
    activityName: "Hike",
    forecastDate: "2026-09-05",
    daysAhead: 0,
    kind: "morning_of",
    dueAt: new Date("2026-09-05T11:00:00Z"),
    margin: 1,
    ...over,
  };
}

// ---------------------------------------------------------------------------
// Preferences
// ---------------------------------------------------------------------------

Deno.test("an activity with no preferences row still notifies", () => {
  // The regression this guards: reading the table's all-false column defaults
  // as the runtime default would mean every activity created before the
  // preferences UI shipped goes silent forever.
  const prefs = effectiveNotifyPrefs(null);
  assertEquals(prefs.notifyMorningOf, true);
  assertEquals(prefs, defaultNotifyPrefs);
});

Deno.test("a row with everything off is obeyed, not overridden", () => {
  const prefs = effectiveNotifyPrefs({
    notify_morning_of: false,
    notify_night_before: false,
    notify_days_before: false,
  });
  assertEquals(prefs.notifyMorningOf, false);
  assertEquals(dueAtFor("morning_of", "2026-09-05", prefs, NY), null);
  assertEquals(dueAtFor("night_before", "2026-09-05", prefs, NY), null);
  assertEquals(dueAtFor("days_before", "2026-09-05", prefs, NY), null);
});

Deno.test("days_before_count is clamped to a usable forecast range", () => {
  assertEquals(effectiveNotifyPrefs({ days_before_count: -3 }).daysBeforeCount, 1);
  assertEquals(effectiveNotifyPrefs({ days_before_count: 99 }).daysBeforeCount, 7);
  assertEquals(effectiveNotifyPrefs({ days_before_count: 3 }).daysBeforeCount, 3);
  assertEquals(effectiveNotifyPrefs({ days_before_count: null }).daysBeforeCount, 2);
});

Deno.test("a malformed morning_time falls back rather than scheduling at NaN", () => {
  assertEquals(parseWallTime("not-a-time"), { hour: 7, minute: 0 });
  assertEquals(parseWallTime("07:30:00"), { hour: 7, minute: 30 });
  assertEquals(parseWallTime("23:59"), { hour: 23, minute: 59 });
});

// ---------------------------------------------------------------------------
// Timezone
// ---------------------------------------------------------------------------

Deno.test("zone offset follows DST rather than a fixed guess", () => {
  // EDT in September, EST in January. A fixed offset would get one of them
  // wrong by an hour and move a 07:00 nudge to 06:00 for half the year.
  assertEquals(zoneOffsetMinutes(new Date("2026-09-05T12:00:00Z"), NY), -240);
  assertEquals(zoneOffsetMinutes(new Date("2026-01-05T12:00:00Z"), NY), -300);
});

Deno.test("local wall-clock times round-trip through their instant", () => {
  const summer = zonedTimeToInstant("2026-09-05", 7, 0, NY);
  assertEquals(summer.toISOString(), "2026-09-05T11:00:00.000Z");
  assertEquals(localDateOf(summer, NY), "2026-09-05");

  const winter = zonedTimeToInstant("2026-01-05", 7, 0, NY);
  assertEquals(winter.toISOString(), "2026-01-05T12:00:00.000Z");
});

Deno.test("a date near local midnight is not attributed to the wrong day", () => {
  // 23:30 in New York is already tomorrow in UTC. Reading the UTC date here is
  // what would make a "sent today" count reset at 20:00 local.
  const instant = new Date("2026-09-06T03:30:00Z");
  assertEquals(localDateOf(instant, NY), "2026-09-05");
});

Deno.test("longitude is a coarse fallback but never leaves the user on UTC", () => {
  // Etc/GMT signs are inverted; Pittsburgh at -80 lands on UTC-5.
  assertEquals(fallbackZoneFromLongitude(-80), "Etc/GMT+5");
  assertEquals(fallbackZoneFromLongitude(0), "Etc/GMT");
  assertEquals(fallbackZoneFromLongitude(139), "Etc/GMT-9");
});

Deno.test("an unresolvable stored zone falls back instead of throwing", () => {
  assertEquals(resolveZone("Mars/Olympus_Mons", -80), "Etc/GMT+5");
  assertEquals(resolveZone("", -80), "Etc/GMT+5");
  assertEquals(resolveZone(null, -80), "Etc/GMT+5");
  assertEquals(resolveZone(NY, -80), NY);
});

Deno.test("shiftLocalDate crosses months and years", () => {
  assertEquals(shiftLocalDate("2026-09-01", -1), "2026-08-31");
  assertEquals(shiftLocalDate("2026-12-31", 1), "2027-01-01");
  assertEquals(shiftLocalDate("2026-09-05", -2), "2026-09-03");
});

// ---------------------------------------------------------------------------
// Quiet hours
// ---------------------------------------------------------------------------

Deno.test("a late-evening nudge is held to the next morning, not dropped", () => {
  const due = applyQuietHours("2026-09-05", 22, 30, NY);
  assertEquals(localDateOf(due, NY), "2026-09-06");
  assertEquals(due.toISOString(), "2026-09-06T11:00:00.000Z");
});

Deno.test("a pre-dawn nudge waits for 07:00 the same day", () => {
  const due = applyQuietHours("2026-09-05", 5, 0, NY);
  assertEquals(due.toISOString(), "2026-09-05T11:00:00.000Z");
});

Deno.test("a daytime nudge is left exactly where it was asked for", () => {
  const due = applyQuietHours("2026-09-05", 9, 15, NY);
  assertEquals(due.toISOString(), "2026-09-05T13:15:00.000Z");
});

Deno.test("the evening nudge lands the day before, inside waking hours", () => {
  const prefs: NotifyPrefs = { ...defaultNotifyPrefs, notifyNightBefore: true };
  const due = dueAtFor("night_before", "2026-09-05", prefs, NY)!;
  assert(due != null);
  assertEquals(localDateOf(due, NY), "2026-09-04");
  assertEquals(due.toISOString(), "2026-09-04T22:00:00.000Z");
});

Deno.test("days_before counts back by the user's own number", () => {
  const prefs: NotifyPrefs = {
    ...defaultNotifyPrefs,
    notifyDaysBefore: true,
    daysBeforeCount: 3,
  };
  const due = dueAtFor("days_before", "2026-09-05", prefs, NY)!;
  assertEquals(localDateOf(due, NY), "2026-09-02");
});

// ---------------------------------------------------------------------------
// The cap
// ---------------------------------------------------------------------------

Deno.test("a good Saturday with eight matches still sends only two", () => {
  // This is the defect that made the fix necessary, stated as a test.
  const many = Array.from({ length: 8 }, (_, i) =>
    candidate({ activityId: `a${i}`, margin: i }));
  const chosen = selectSendable(many, new Set(), 0);
  assertEquals(chosen.length, maxPushesPerUserPerDay);
});

Deno.test("a re-run of the cron sends nothing the first run already sent", () => {
  // Idempotence. Without it the cadence a user experiences is the cron
  // frequency, not the cap.
  const candidates = [candidate({ activityId: "a1" }), candidate({ activityId: "a2" })];
  const first = selectSendable(candidates, new Set(), 0);
  assertEquals(first.length, 2);

  const sent = new Set(first.map((c) => alreadyNotifiedKey(c.activityId, c.forecastDate)));
  const second = selectSendable(candidates, sent, 2);
  assertEquals(second.length, 0);
});

Deno.test("the dedupe key is the forecast day, not the send day", () => {
  // A night-before and a morning-of nudge are about the same Saturday. The
  // user experiences the second as the app repeating itself.
  const nightBefore = candidate({ kind: "night_before", daysAhead: 1 });
  const morningOf = candidate({ kind: "morning_of", daysAhead: 0 });
  assertEquals(
    alreadyNotifiedKey(nightBefore.activityId, nightBefore.forecastDate),
    alreadyNotifiedKey(morningOf.activityId, morningOf.forecastDate),
  );

  const sent = new Set([alreadyNotifiedKey("a1", "2026-09-05")]);
  assertEquals(selectSendable([morningOf], sent, 0).length, 0);
});

Deno.test("one activity never takes both slots on the same day", () => {
  const sameActivity = [
    candidate({ activityId: "a1", forecastDate: "2026-09-05", daysAhead: 0 }),
    candidate({ activityId: "a1", forecastDate: "2026-09-06", daysAhead: 1 }),
  ];
  const chosen = selectSendable(sameActivity, new Set(), 0);
  assertEquals(chosen.length, 1);
  assertEquals(chosen[0].forecastDate, "2026-09-05");
});

Deno.test("a user already at the ceiling receives nothing further", () => {
  assertEquals(selectSendable([candidate()], new Set(), maxPushesPerUserPerDay).length, 0);
  assertEquals(selectSendable([candidate()], new Set(), 99).length, 0);
});

Deno.test("a partly-spent budget sends only what is left", () => {
  const two = [candidate({ activityId: "a1" }), candidate({ activityId: "a2" })];
  assertEquals(selectSendable(two, new Set(), 1).length, 1);
});

Deno.test("today outranks Saturday when only one slot is left", () => {
  // A nudge about today expires today; one about Saturday keeps until Friday.
  const far = candidate({ activityId: "far", daysAhead: 4, margin: 99 });
  const near = candidate({ activityId: "near", daysAhead: 0, margin: 0 });
  const chosen = selectSendable([far, near], new Set(), 1);
  assertEquals(chosen.length, 1);
  assertEquals(chosen[0].activityId, "near");
});

Deno.test("margin breaks a tie between two days equally far off", () => {
  const weak = candidate({ activityId: "weak", daysAhead: 1, margin: 0.1 });
  const strong = candidate({ activityId: "strong", daysAhead: 1, margin: 2.0 });
  const chosen = selectSendable([weak, strong], new Set(), 1);
  assertEquals(chosen[0].activityId, "strong");
});

Deno.test("selection is stable across runs given identical input", () => {
  const tied = [
    candidate({ activityId: "b", daysAhead: 0, margin: 1 }),
    candidate({ activityId: "a", daysAhead: 0, margin: 1 }),
  ];
  const first = selectSendable(tied, new Set(), 0).map((c) => c.activityId);
  const again = selectSendable([...tied].reverse(), new Set(), 0).map((c) => c.activityId);
  assertEquals(first, again);
});

// ---------------------------------------------------------------------------
// Margin
// ---------------------------------------------------------------------------

Deno.test("a day that clears the bounds comfortably outscores one that scrapes", () => {
  const profile = {
    temp_enabled: true,
    temp_min: 15,
    temp_max: 30,
    precip_enabled: false,
    wind_enabled: false,
  };
  const comfortable = { values: { temperatureMax: 24, temperatureMin: 18 } };
  const marginal = { values: { temperatureMax: 16, temperatureMin: 15 } };
  assert(matchMargin(comfortable, profile) > matchMargin(marginal, profile));
});

Deno.test("a profile with nothing enabled scores zero", () => {
  const profile = { temp_enabled: false, precip_enabled: false, wind_enabled: false };
  assertEquals(matchMargin({ values: { temperatureMax: 24 } }, profile), 0);
  assertEquals(matchMargin({ values: {} }, null), 0);
});

Deno.test("wanting rain inverts which day scores better", () => {
  const wet = { values: { precipitationProbabilityMax: 90 } };
  const dry = { values: { precipitationProbabilityMax: 5 } };
  const wantsRain = { precip_enabled: true, precip_level: "rain_only" };
  const avoidsRain = { precip_enabled: true, precip_level: "avoid_rain" };
  assert(matchMargin(wet, wantsRain) > matchMargin(dry, wantsRain));
  assert(matchMargin(dry, avoidsRain) > matchMargin(wet, avoidsRain));
});
