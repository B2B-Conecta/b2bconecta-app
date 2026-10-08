import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { sendWebPush, vapidConfigured } from "./web_push_send.ts";

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
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
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

type FcmSendResult = {
  success: number;
  failure: number;
  dropTokens: string[];
};

function fcmErrorCode(body: string): string {
  try {
    const json = JSON.parse(body) as {
      error?: { status?: string; details?: Array<{ errorCode?: string }> };
    };
    const details = json.error?.details;
    if (Array.isArray(details)) {
      for (const detail of details) {
        if (detail?.errorCode) return detail.errorCode;
      }
    }
    if (json.error?.status) return json.error.status;
  } catch {
    // body is not JSON
  }
  const lower = body.toLowerCase();
  if (lower.includes("notregistered")) return "NotRegistered";
  if (lower.includes("invalidregistration")) return "InvalidRegistration";
  if (lower.includes("unregistered")) return "UNREGISTERED";
  return "unknown";
}

function fcmTokenShouldDrop(status: number, body: string): boolean {
  const code = fcmErrorCode(body);
  const normalized = code.toUpperCase();
  if (
    normalized === "UNREGISTERED" ||
    normalized === "NOT_FOUND" ||
    normalized === "NOTREGISTERED" ||
    normalized === "INVALIDREGISTRATION"
  ) {
    return true;
  }
  if (status === 404 && normalized === "NOT_FOUND") return true;
  const lower = body.toLowerCase();
  return lower.includes("registration token") && lower.includes("not a valid");
}

async function sendFcmLegacy(
  serverKey: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
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
      android_channel_id: "motolink_alerts",
    }),
  });

  if (!res.ok) {
    throw new Error(`FCM legacy HTTP ${res.status}`);
  }

  const payload = await res.json();
  const results = Array.isArray(payload.results) ? payload.results : [];
  const dropTokens: string[] = [];
  results.forEach((result: { error?: string }, index: number) => {
    const error = (result?.error ?? "").toLowerCase();
    if (error === "notregistered" || error === "invalidregistration") {
      const token = tokens[index];
      if (token) dropTokens.push(token);
    }
  });
  return {
    success: Number(payload.success ?? 0),
    failure: Number(payload.failure ?? 0),
    dropTokens,
  };
}

async function sendFcmV1(
  projectId: string,
  accessToken: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<FcmSendResult> {
  let success = 0;
  let failure = 0;
  const dropTokens: string[] = [];

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
                sound: "default",
                default_vibrate_timings: true,
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
      const code = fcmErrorCode(text);
      console.error(`FCM v1 rejected status=${res.status} code=${code}`);
      if (fcmTokenShouldDrop(res.status, text)) dropTokens.push(token);
    }
  }

  return { success, failure, dropTokens };
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
  const canFcm = !!(fcmLegacyKey || serviceAccount);
  const canWebPush = vapidConfigured();

  if (!canFcm && !canWebPush) {
    return jsonResponse({
      ok: true,
      skipped: true,
      reason: "FCM and Web Push VAPID are not configured",
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

  const title = payload.title?.trim() || "B2B Conecta";
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

  const { data: webRows, error: webError } = await supabase
    .from("web_push_subscriptions")
    .select("endpoint, p256dh, auth")
    .eq("user_id", userId)
    .eq("is_active", true);

  if (webError) {
    console.error("send-push-notification web push query:", webError.message);
    return jsonResponse({ error: webError.message }, 500);
  }

  const webSubs = (webRows ?? [])
    .map((r) => r as { endpoint?: string; p256dh?: string; auth?: string })
    .filter((r) => r.endpoint?.trim() && r.p256dh?.trim() && r.auth?.trim())
    .map((r) => ({
      endpoint: r.endpoint!.trim(),
      p256dh: r.p256dh!.trim(),
      auth: r.auth!.trim(),
    }));

  if (tokens.length === 0 && webSubs.length === 0) {
    console.log(JSON.stringify({
      notification_id: payload.notification_id?.trim() ?? "",
      user_id: userId,
      skipped: "no_device_tokens",
    }));
    return jsonResponse({ ok: true, skipped: true, reason: "no_device_tokens" });
  }

  const data: Record<string, string> = {
    type,
    related_id: relatedId,
  };
  if (payload.notification_id?.trim()) {
    data.notification_id = payload.notification_id.trim();
  }

  const webPayload = {
    title,
    body,
    type,
    related_id: relatedId,
    notification_id: payload.notification_id?.trim() ?? "",
  };

  let fcmResult: FcmSendResult = { success: 0, failure: 0, dropTokens: [] };
  let webResult = { success: 0, failure: 0, gone: 0 };

  try {
    if (canFcm && tokens.length > 0) {
      if (serviceAccount) {
        const accessToken = await getFcmAccessToken(serviceAccount);
        fcmResult = await sendFcmV1(
          serviceAccount.project_id,
          accessToken,
          tokens,
          title,
          body,
          data,
        );
      } else {
        fcmResult = await sendFcmLegacy(fcmLegacyKey!, tokens, title, body, data);
      }
      for (const dead of fcmResult.dropTokens) {
        const { error: dropError } = await supabase.rpc(
          "deactivate_device_push_token",
          { p_token: dead },
        );
        if (dropError) {
          console.error(
            `deactivate_device_push_token failed: ${dropError.code ?? ""}`,
          );
        }
      }
    }

    if (canWebPush && webSubs.length > 0) {
      for (const sub of webSubs) {
        try {
          const status = await sendWebPush(sub, webPayload);
          if (status === "gone") {
            webResult.gone += 1;
            await supabase.rpc("deactivate_web_push_endpoint", {
              p_endpoint: sub.endpoint,
            });
          } else {
            webResult.success += 1;
          }
        } catch (e) {
          webResult.failure += 1;
          const message = e instanceof Error ? e.message : String(e);
          console.error(`web push error: ${message}`);
        }
      }
    }

    console.log(JSON.stringify({
      notification_id: payload.notification_id?.trim() ?? "",
      user_id: userId,
      tokens: tokens.length,
      fcm_success: fcmResult.success,
      fcm_failure: fcmResult.failure,
      fcm_dropped: fcmResult.dropTokens.length,
      web_success: webResult.success,
      web_failure: webResult.failure,
    }));

    return jsonResponse({
      ok: true,
      api: serviceAccount ? "v1" : (canFcm ? "legacy" : "web-push"),
      tokens: tokens.length,
      success: fcmResult.success,
      failure: fcmResult.failure,
      dropped: fcmResult.dropTokens.length,
      web_push: {
        subscriptions: webSubs.length,
        ...webResult,
      },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error("send-push-notification fcm error:", message);
    return jsonResponse({ error: message }, 502);
  }
});
