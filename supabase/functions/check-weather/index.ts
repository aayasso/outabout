import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TOMORROW_API_KEY = Deno.env.get("TOMORROW_API_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Fetch weather forecast for a location
async function getWeatherForecast(lat: number, lon: number) {
  const url = `https://api.tomorrow.io/v4/weather/forecast?location=${lat},${lon}&apikey=${TOMORROW_API_KEY}&timesteps=1d&fields=temperatureMax,temperatureMin,precipitationProbabilityMax,windSpeedMax,uvIndexMax,weatherCodeMax`;
  const res = await fetch(url);
  const data = await res.json();
  return data.timelines?.daily || [];
}

// Check if weather conditions match an activity's profile
function conditionsMatch(forecast: any, profile: any): boolean {
  const day = forecast.values;

  if (profile.temp_enabled) {
    if (profile.temp_min !== null && day.temperatureMax < profile.temp_min) return false;
    if (profile.temp_max !== null && day.temperatureMin > profile.temp_max) return false;
  }

  if (profile.precip_enabled) {
    const precip = day.precipitationProbabilityMax ??
      day.precipitationProbability;
    if (profile.precip_level === "none" && precip > 20) return false;
    if (profile.precip_level === "light_ok" && precip > 60) return false;
  }

  if (profile.wind_enabled) {
    if (profile.wind_max !== null && day.windSpeedMax > profile.wind_max) return false;
  }

  return true;
}

// Build full weather snapshot for behavioral event logging
function buildConditionsSnapshot(forecastDay: any, daysAhead: number): Record<string, any> {
  const day = forecastDay.values;
  return {
    temp_max_c: day.temperatureMax,
    temp_min_c: day.temperatureMin,
    precipitation_probability: day.precipitationProbabilityMax ??
      day.precipitationProbability,
    wind_kph: day.windSpeedMax,
    uv_index: day.uvIndexMax ?? day.uvIndex ?? null,
    weather_code: day.weatherCodeMax ?? day.weatherCode ?? null,
    forecast_window_hours: daysAhead * 24,
    forecast_date: forecastDay.time,
  };
}

// Build temporal context for behavioral event logging
function buildTemporalContext(now: Date, daysAhead: number): Record<string, any> {
  const month = now.getMonth() + 1;
  const season =
    month >= 3 && month <= 5 ? "spring" :
    month >= 6 && month <= 8 ? "summer" :
    month >= 9 && month <= 11 ? "fall" : "winter";

  const weekOfSeason = Math.ceil(
    ((now.getTime() - new Date(now.getFullYear(), (Math.floor((month - 1) / 3)) * 3, 1).getTime())
    / (7 * 24 * 60 * 60 * 1000))
  );

  return {
    hour_of_day: now.getHours(),
    day_of_week: now.getDay(),
    week_of_month: Math.ceil(now.getDate() / 7),
    month_of_year: month,
    season,
    week_of_season: weekOfSeason,
    days_ahead: daysAhead,
    notification_sent_at: now.toISOString(),
  };
}

// Build geographic context — bucketed to ~1 mile radius
function buildGeographicContext(
  lat: number,
  lon: number,
  metro?: string,
  city?: string,
  state?: string,
  country = "US"
): Record<string, any> {
  // Bucket to ~1 mile radius (0.015 degrees ≈ 1 mile)
  const precision = 1000;
  const lat_bucketed = Math.round(lat * precision) / precision;
  const lng_bucketed = Math.round(lon * precision) / precision;

  return {
    lat_bucketed,
    lng_bucketed,
    metro: metro ?? null,
    city: city ?? null,
    state: state ?? null,
    country,
    timezone: null, // populated by app when available
  };
}

// Log behavioral event to Supabase
async function logBehavioralEvent(
  userId: string,
  activityId: string,
  eventType: string,
  conditionsSnapshot: Record<string, any>,
  geographicContext: Record<string, any>,
  temporalContext: Record<string, any>,
  notificationId?: string
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
    // Log error but never let logging failure break notification delivery
    console.error("behavioral_event logging failed:", error.message);
  }
}

// Send push notification via OneSignal
async function sendNotification(
  userId: string,
  activityName: string,
  date: string
): Promise<string | null> {
  const message = `🌤 Conditions are right for: ${activityName} on ${date}`;
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
      headings: { en: "Weather Activity Alert" },
    }),
  });

  const data = await res.json();
  // Return OneSignal notification ID for logging
  return data.id ?? null;
}

serve(async (_req) => {
  try {
    const now = new Date();

    // Get all users with a saved location
    const { data: locations, error: locError } = await supabase
      .from("user_locations")
      .select("user_id, latitude, longitude, metro, city, state, country");

    if (locError) throw locError;

    for (const location of locations ?? []) {
      const forecast = await getWeatherForecast(
        location.latitude,
        location.longitude
      );

      const geoContext = buildGeographicContext(
        location.latitude,
        location.longitude,
        location.metro,
        location.city,
        location.state,
        location.country ?? "US"
      );

      // Get all activities with condition profiles
      const { data: activities } = await supabase
        .from("activities")
        .select(`
          id, name, user_id,
          condition_profiles(*)
        `)
        .eq("user_id", location.user_id)
        .eq("is_archived", false);

      for (const activity of activities ?? []) {
        const profile = activity.condition_profiles?.[0];
        if (!profile) continue;

        // Check today's forecast only (index 0) — fire immediately on match
        const forecastDay = forecast[0];
        if (!forecastDay) continue;

        const daysAhead = 0;
        const forecastDate = new Date(forecastDay.time);
        const dateLabel = forecastDate.toLocaleDateString("en-US", {
          weekday: "long",
          month: "short",
          day: "numeric",
        });

        if (!conditionsMatch(forecastDay, profile)) continue;

        const conditionsSnapshot = buildConditionsSnapshot(forecastDay, daysAhead);
        const temporalContext = buildTemporalContext(now, daysAhead);

        const notifId = await sendNotification(
          location.user_id,
          activity.name,
          dateLabel
        );
        await logBehavioralEvent(
          location.user_id,
          activity.id,
          "condition_match_notified",
          conditionsSnapshot,
          geoContext,
          { ...temporalContext, trigger: "immediate" },
          notifId ?? undefined
        );
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});