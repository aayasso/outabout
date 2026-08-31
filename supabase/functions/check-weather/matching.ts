// The pure half of check-weather: reading a profile off an activity, and
// deciding whether a forecast day suits it.
//
// Split out of index.ts so it can be tested without a Deno server, a Supabase
// client, or four environment variables. That mattered: the embed-shape bug
// below sat in production undetected because nothing here was reachable from a
// test, and its only symptom was silence.
//
// This file is the server twin of `evaluateDayMatch` in
// lib/features/home/home_providers.dart. The two must agree — the app tells the
// user a day matches and the server decides whether to notify about it, so a
// divergence shows up as a notification for a day the schedule never claimed,
// or the reverse.

export const METERS_PER_SECOND_TO_KMH = 3.6;

/// Probability (%) at or below which a day counts as dry. Mirrors
/// PrecipLevel.dryThreshold in lib/data/models/condition_profile.dart.
export const PRECIP_DRY_THRESHOLD = 20;
export const PRECIP_RAIN_ONLY = "rain_only";

/// Tomorrow.io reports wind in m/s with units=metric, but condition profiles
/// store wind_max in km/h (the slider is 0-80 km/h). Convert before comparing.
export function windKmh(day: any): number {
  return (day.windSpeedMax ?? 0) * METERS_PER_SECOND_TO_KMH;
}

/// The condition profile embedded in an `activities` row, or null.
///
/// PostgREST decides the *shape* of an embed from the constraints on the
/// foreign table: with `condition_profiles_activity_id_key UNIQUE
/// (activity_id)` it detects a to-one relationship and returns a bare object.
/// Without that constraint it would return an array.
///
/// This function accepts both, deliberately. The previous code indexed
/// `[0]` unconditionally, which on the object shape yields `undefined` — so
/// every activity was skipped, no notification was ever sent, and no
/// `condition_match_notified` row was ever written. Nothing failed loudly; the
/// feature simply did not happen. Pinning the reader to whichever shape is
/// correct today would leave the same trap armed for whoever next changes a
/// constraint on that table.
export function conditionProfileOf(activity: any): any | null {
  const embedded = activity?.condition_profiles;
  if (embedded == null) return null;
  if (Array.isArray(embedded)) return embedded[0] ?? null;
  return embedded;
}

/// Whether `forecast` suits `profile`.
///
/// Bound comparisons use `!= null` rather than `!== null` so an absent key and
/// a JSON null are treated alike. Both mean "no bound", which is what Dart's
/// `!= null` already expresses; `!== null` let an absent key through to a
/// comparison against `undefined` that was always false, arriving at the same
/// answer by accident rather than on purpose.
export function conditionsMatch(forecast: any, profile: any): boolean {
  if (profile == null) return true;
  const day = forecast.values;

  if (profile.temp_enabled) {
    if (profile.temp_min != null && day.temperatureMax < profile.temp_min) {
      return false;
    }
    if (profile.temp_max != null && day.temperatureMin > profile.temp_max) {
      return false;
    }
  }

  if (profile.precip_enabled) {
    const precip = day.precipitationProbabilityMax ??
      day.precipitationProbability;
    const isDry = precip <= PRECIP_DRY_THRESHOLD;
    const wantsRain = profile.precip_level === PRECIP_RAIN_ONLY;
    // Wanting rain on a dry day fails, and avoiding rain on a wet day fails.
    // Exhaustive by construction: anything that is not rain_only reads as
    // avoid_rain. Must stay identical to evaluateDayMatch in the Flutter app.
    if (wantsRain === isDry) return false;
  }

  if (profile.wind_enabled) {
    if (profile.wind_max != null && windKmh(day) > profile.wind_max) {
      return false;
    }
  }

  return true;
}
