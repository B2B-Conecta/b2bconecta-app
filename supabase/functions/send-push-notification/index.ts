import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

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

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
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

function parseServiceAccount(raw: string): ServiceAccount | null {
  try {
    const sa = JSON.parse(raw) as ServiceAccount;
    if (!sa.project_id || !sa.client_email || !sa.private_key) return null;
    return sa;
  } catch {
    return null;
  }
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const pem = sa.private_key.replace(/\\n/g, "\n");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth2:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OAuth token HTTP ${res.status}: ${text}`);
  }

  const payload = await res.json();
  const token = payload.access_token as string | undefined;
  if (!token) throw new Error("OAuth token missing access_token");
  return token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
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
      notification: { title, body },
      data,
      priority: "high",
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`FCM legacy HTTP ${res.status}: ${text}`);
  }

  const payload = await res.json();
  return {
    success: Number(payload.success ?? 0),
    failure: Number(payload.failure ?? 0),
  };
}

async function sendFcmV1(
  projectId: string,
  accessToken: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ success: number; failure: number }> {
  let success = 0;
  let failure = 0;

  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "motolink_alerts",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                },
              },
            },
          },
        }),
      },
    );

    if (res.ok) {
      success += 1;
    } else {
      failure += 1;
      const text = await res.text();
      console.error(`FCM v1 token error: ${text}`);
    }
  }

  return { success, failure };
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

  const fcmLegacyKey = Deno.env.get("FCM_SERVER_KEY")?.trim();
  const fcmServiceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")?.trim();
  const serviceAccount = fcmServiceAccountRaw
    ? parseServiceAccount(fcmServiceAccountRaw)
    : null;

  if (!fcmLegacyKey && !serviceAccount) {
    return jsonResponse({
      ok: true,
      skipped: true,
      reason: "FCM_SERVER_KEY or FCM_SERVICE_ACCOUNT_JSON not set",
    });
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
    let result: { success: number; failure: number };
    if (serviceAccount) {
      const accessToken = await getFcmAccessToken(serviceAccount);
      result = await sendFcmV1(
        serviceAccount.project_id,
        accessToken,
        tokens,
        title,
        body,
        data,
      );
      return jsonResponse({
        ok: true,
        api: "v1",
        tokens: tokens.length,
        success: result.success,
        failure: result.failure,
      });
    }

    result = await sendFcmLegacy(fcmLegacyKey!, tokens, title, body, data);
    return jsonResponse({
      ok: true,
      api: "legacy",
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
