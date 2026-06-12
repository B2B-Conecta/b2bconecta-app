import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-push-webhook-secret",
};

interface PushRequest {
  user_id?: string;
  title?: string;
  body?: string;
  type?: string;
  related_id?: string | null;
  notification_id?: string | null;
  source?: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isAuthorized(req: Request): boolean {
  const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET")?.trim();
  if (webhookSecret) {
    const header = req.headers.get("x-push-webhook-secret")?.trim();
    if (header === webhookSecret) return true;
  }

  const auth = req.headers.get("Authorization") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (serviceKey && auth === `Bearer ${serviceKey}`) return true;

  return false;
}

async function sendFcmLegacy(
  serverKey: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ success: number; failure: number }> {
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify({
      registration_ids: tokens,
      notification: {
        title,
        body,
      },
      data,
      priority: "high",
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`FCM HTTP ${res.status}: ${text}`);
  }

  const payload = await res.json();
  return {
    success: Number(payload.success ?? 0),
    failure: Number(payload.failure ?? 0),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!isAuthorized(req)) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const fcmKey = Deno.env.get("FCM_SERVER_KEY")?.trim();
  if (!fcmKey) {
    return jsonResponse({ ok: true, skipped: true, reason: "FCM_SERVER_KEY not set" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Missing Supabase env" }, 500);
  }

  let payload: PushRequest;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const userId = payload.user_id?.trim();
  if (!userId) {
    return jsonResponse({ error: "user_id required" }, 400);
  }

  const title = payload.title?.trim() || "MotoLink";
  const body = payload.body?.trim() || title;
  const type = payload.type?.trim() || "mensaje";
  const relatedId = payload.related_id?.trim() ?? "";

  const supabase = createClient(supabaseUrl, serviceKey);
  const { data: rows, error } = await supabase
    .from("device_push_tokens")
    .select("token")
    .eq("user_id", userId);

  if (error) {
    console.error("send-push-notification token query:", error.message);
    return jsonResponse({ error: error.message }, 500);
  }

  const tokens = (rows ?? [])
    .map((r) => (r as { token?: string }).token?.trim())
    .filter((t): t is string => !!t);

  if (tokens.length === 0) {
    return jsonResponse({ ok: true, skipped: true, reason: "no_device_tokens" });
  }

  const data: Record<string, string> = {
    type,
    related_id: relatedId,
  };
  if (payload.notification_id?.trim()) {
    data.notification_id = payload.notification_id.trim();
  }

  try {
    const result = await sendFcmLegacy(fcmKey, tokens, title, body, data);
    return jsonResponse({
      ok: true,
      tokens: tokens.length,
      success: result.success,
      failure: result.failure,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("send-push-notification fcm error:", message);
    return jsonResponse({ error: message }, 502);
  }
});
