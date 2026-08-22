// Hard-deletes the calling user's account and all of their data.
//
// Required by App Store Review Guideline 5.1.1(v): any app offering account
// creation must offer in-app account deletion.
//
// The caller is identified solely from their verified JWT — never from the
// request body — so this cannot be used to delete someone else's account.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
// check-weather uses the custom SERVICE_ROLE_KEY name; fall back to the name
// Supabase auto-injects into deployed functions.
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * Deletes every row this user owns, then the auth user itself.
 *
 * Ordering is child-to-parent and deliberate: the schema's ON DELETE
 * behaviour is not defined anywhere in this repo, so nothing here relies on
 * a cascade existing. Each delete is a no-op when the rows are already gone,
 * which also makes the whole function idempotent on retry.
 */
async function deleteUserData(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};

  const del = async (
    table: string,
    apply: (q: any) => any,
  ): Promise<void> => {
    const { data, error } = await apply(
      admin.from(table).delete(),
    ).select("id");
    if (error) throw new Error(`${table}: ${error.message}`);
    counts[table] = data?.length ?? 0;
  };

  // 1. The user's activities are the parent of several tables below.
  const { data: activities, error: actErr } = await admin
    .from("activities")
    .select("id")
    .eq("user_id", userId);
  if (actErr) throw new Error(`activities lookup: ${actErr.message}`);
  const activityIds = (activities ?? []).map((a: { id: string }) => a.id);

  // 2. Audit trail of condition changes — carries user_id directly.
  await del("condition_profile_history", (q) => q.eq("user_id", userId));

  // 3-4. Linked to the user only through activity_id.
  if (activityIds.length > 0) {
    await del("condition_profiles", (q) => q.in("activity_id", activityIds));
    await del("notification_preferences", (q) =>
      q.in("activity_id", activityIds));
  } else {
    counts["condition_profiles"] = 0;
    counts["notification_preferences"] = 0;
  }

  // 5. The one intentional exception to "delete everything": monetization_events
  // belongs to the intelligence platform. Its rows are de-identified rather
  // than destroyed, which removes every personal linkage while leaving the
  // anonymised revenue record intact. This also has to happen BEFORE steps 6
  // and 9, because its activity_id / behavioral_event_id foreign keys point at
  // rows those steps delete.
  const { data: deIdentified, error: monErr } = await admin
    .from("monetization_events")
    .update({
      user_id: null,
      activity_id: null,
      behavioral_event_id: null,
    })
    .eq("user_id", userId)
    .select("id");
  if (monErr) throw new Error(`monetization_events: ${monErr.message}`);
  counts["monetization_events_deidentified"] = deIdentified?.length ?? 0;

  // 6. Must precede activities — behavioral_events.activity_id references it.
  await del("behavioral_events", (q) => q.eq("user_id", userId));

  // 7-9.
  await del("user_locations", (q) => q.eq("user_id", userId));
  await del("categories", (q) => q.eq("user_id", userId));
  await del("activities", (q) => q.eq("user_id", userId));

  // 10. No-op for anonymous users, who may never have had a profiles row.
  await del("profiles", (q) => q.eq("id", userId));

  return counts;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  // Identify the caller from their own JWT. getUser() validates the token
  // against GoTrue server-side; the id is taken from the verified user only.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (authHeader === "") {
    return json(401, { ok: false, error: "unauthorized" });
  }

  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await caller.auth.getUser();
  if (authError || !user) {
    return json(401, { ok: false, error: "unauthorized" });
  }

  const userId = user.id;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const counts = await deleteUserData(admin, userId);

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      // Already gone — a retry after a partial failure, or a double tap.
      // Treat as success so the flow is idempotent.
      const message = deleteError.message.toLowerCase();
      const alreadyGone = message.includes("not found") ||
        message.includes("user_not_found");
      if (!alreadyGone) {
        throw new Error(`auth user: ${deleteError.message}`);
      }
    }

    return json(200, { ok: true, deleted: counts });
  } catch (e) {
    // Logged server-side with the user id; the response body deliberately
    // carries no row data back to the client.
    console.error(`delete-account failed for ${userId}:`, e);
    return json(500, { ok: false, error: "deletion_failed" });
  }
});
