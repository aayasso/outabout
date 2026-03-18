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
  const url = `https://api.tomorrow.io/v4/forecast?location=${lat},${lon}&apikey=${TOMORROW_API_KEY}&timesteps=1d&fields=temperatureMax,temperatureMin,precipitationProbability,windSpeedMax,uvIndex`;
  const res = await fetch(url);
  const data = await res.json();
  return data.timelines?.daily || [];
}

// Check if weather conditions match an activity's profile
function conditionsMatch(forecast: any, profile: any): boolean {
  const day = forecast.values;

  if (profile.temp_enabled) {
    const avgTemp = (day.temperatureMax + day.temperatureMin) / 2;
    if (profile.temp_min !== null && avgTemp < profile.temp_min) return false;
    if (profile.temp_max !== null && avgTemp > profile.temp_max) return false;
  }

  if (profile.precip_enabled) {
    const precip = day.precipitationProbability;
    if (profile.precip_level === "none" && precip > 20) return false;
    if (profile.precip_level === "light_ok" && precip > 60) return false;
  }

  if (profile.wind_enabled) {
    if (profile.wind_max !== null && day.windSpeedMax > profile.wind_max) return false;
  }

  if (profile.uv_enabled) {
    if (profile.uv_min !== null && day.uvIndex < profile.uv_min) return false;
    if (profile.uv_max !== null && day.uvIndex > profile.uv_max) return false;
  }

  return true;
}

// Send push notification via OneSignal
async function sendNotification(userId: string, activityName: string, date: string) {
  const message = `🌤 Conditions are right for: ${activityName} on ${date}`;
  await fetch("https://api.onesignal.com/notifications", {
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
}

serve(async (_req) => {
  try {
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday
    const currentHour = now.getHours();

    // Get all users with a saved location
    const { data: locations, error: locError } = await supabase
      .from("user_locations")
      .select("user_id, latitude, longitude");

    if (locError) throw locError;

    for (const location of locations ?? []) {
      const forecast = await getWeatherForecast(location.latitude, location.longitude);

      // Get all activities with condition profiles and notification prefs for this user
      const { data: activities } = await supabase
        .from("activities")
        .select(`
          id, name, user_id,
          condition_profiles(*),
          notification_preferences(*)
        `)
        .eq("user_id", location.user_id)
        .eq("is_archived", false);

      for (const activity of activities ?? []) {
        const profile = activity.condition_profiles?.[0];
        const prefs = activity.notification_preferences?.[0];
        if (!profile || !prefs) continue;

        for (let i = 0; i < forecast.length; i++) {
          const forecastDay = forecast[i];
          const forecastDate = new Date(forecastDay.time);
          const daysAhead = i;
          const dateLabel = forecastDate.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" });

          if (!conditionsMatch(forecastDay, profile)) continue;

          // Morning of
          if (prefs.notify_morning_of && daysAhead === 0) {
            const [hours] = (prefs.morning_time || "07:00:00").split(":").map(Number);
            if (currentHour === hours) {
              await sendNotification(location.user_id, activity.name, dateLabel);
            }
          }

          // Night before
          if (prefs.notify_night_before && daysAhead === 1 && currentHour === 20) {
            await sendNotification(location.user_id, activity.name, dateLabel);
          }

          // Sunday digest
          if (prefs.notify_sunday_digest && dayOfWeek === 0 && currentHour === 18 && daysAhead <= 7) {
            await sendNotification(location.user_id, activity.name, dateLabel);
          }

          // Days before
          if (prefs.notify_days_before && daysAhead === prefs.days_before_count) {
            await sendNotification(location.user_id, activity.name, dateLabel);
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});