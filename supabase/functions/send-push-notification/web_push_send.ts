import webpush from "npm:web-push@3.6.7";

export type WebPushKeys = {
  endpoint: string;
  p256dh: string;
  auth: string;
};

export type WebPushPayload = {
  title: string;
  body: string;
  type: string;
  related_id: string;
  notification_id: string;
};

export function vapidConfigured(): boolean {
  const pub = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY")?.trim();
  const priv = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY")?.trim();
  return !!pub && !!priv;
}

function vapidDetails(): {
  subject: string;
  publicKey: string;
  privateKey: string;
} | null {
  const publicKey = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY")?.trim();
  const privateKey = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY")?.trim();
  if (!publicKey || !privateKey) return null;
  const subject = Deno.env.get("WEB_PUSH_VAPID_SUBJECT")?.trim() ||
    "mailto:b2bconecta.ve@gmail.com";
  return { subject, publicKey, privateKey };
}

export async function sendWebPush(
  sub: WebPushKeys,
  payload: WebPushPayload,
): Promise<"ok" | "gone"> {
  const vapid = vapidDetails();
  if (!vapid) throw new Error("WEB_PUSH_VAPID keys are not set");

  webpush.setVapidDetails(vapid.subject, vapid.publicKey, vapid.privateKey);

  try {
    await webpush.sendNotification(
      {
        endpoint: sub.endpoint,
        keys: { p256dh: sub.p256dh, auth: sub.auth },
      },
      JSON.stringify(payload),
      {
        TTL: 86400,
        urgency: "high",
        headers: {
          Urgency: "high",
        },
      },
    );
    return "ok";
  } catch (e) {
    const status = (e as { statusCode?: number }).statusCode;
    if (status === 404 || status === 410) return "gone";
    throw e;
  }
}
