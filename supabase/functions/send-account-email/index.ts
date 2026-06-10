import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import nodemailer from "nodemailer";
import {
  type AccountEmailEvent,
  buildAccountEmailTemplate,
} from "./templates.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-email-webhook-secret",
};

interface RequestBody {
  event?: AccountEmailEvent;
  profile_id?: string;
  recipient_email?: string;
  source?: string;
}

type AuthUserLike = {
  email?: string | null;
  new_email?: string | null;
  user_metadata?: Record<string, unknown>;
  identities?: Array<{ identity_data?: Record<string, unknown> }>;
};

function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || !trimmed.includes("@")) return null;
  return trimmed;
}

function collectEmailsFromAuthUser(user: AuthUserLike | null | undefined): string[] {
  const out: string[] = [];
  const push = (value: unknown) => {
    const email = normalizeEmail(value);
    if (email && !out.includes(email)) out.push(email);
  };
  if (!user) return out;
  push(user.email);
  push(user.new_email);
  push(user.user_metadata?.email);
  push(user.user_metadata?.email_address);
  for (const identity of user.identities ?? []) {
    push(identity.identity_data?.email);
  }
  return out;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function loadLogoBytes(): Promise<Uint8Array | null> {
  try {
    const url = new URL("./assets/logo.png", import.meta.url);
    return await Deno.readFile(url);
  } catch {
    return null;
  }
}

const DEFAULT_SMTP_USER = "motolink.admin@gmail.com";
const DEFAULT_SMTP_FROM = "MotoLink <motolink.admin@gmail.com>";

function smtpHost(): string {
  return Deno.env.get("SMTP_HOST")?.trim() || "smtp.gmail.com";
}

/** Mailpit/Inbucket del stack local de Supabase (sin TLS ni auth). */
function isLocalSmtpRelay(host: string): boolean {
  const h = host.toLowerCase();
  return (
    h.includes("inbucket") ||
    h.includes("mailpit") ||
    h === "127.0.0.1" ||
    h === "localhost" ||
    h === "host.docker.internal"
  );
}

function smtpConfigured(): boolean {
  if (isLocalSmtpRelay(smtpHost())) return true;
  return Boolean(Deno.env.get("SMTP_PASS")?.trim());
}

function smtpUser(): string {
  return Deno.env.get("SMTP_USER")?.trim() || DEFAULT_SMTP_USER;
}

function smtpFrom(): string {
  return Deno.env.get("SMTP_FROM")?.trim() || DEFAULT_SMTP_FROM;
}

async function sendViaSmtp(params: {
  to: string;
  template: ReturnType<typeof buildAccountEmailTemplate>;
  logoBytes: Uint8Array | null;
}): Promise<void> {
  const host = smtpHost();
  const port = Number(Deno.env.get("SMTP_PORT")?.trim() || "587");
  const user = smtpUser();
  const pass = Deno.env.get("SMTP_PASS")?.trim() ?? "";
  const from = smtpFrom();
  const localRelay = isLocalSmtpRelay(host);

  const transporter = nodemailer.createTransport(
    localRelay
      ? {
          host,
          port,
          secure: false,
          ignoreTLS: true,
          tls: { rejectUnauthorized: false },
        }
      : {
          host,
          port,
          secure: port === 465,
          auth: { user, pass },
          requireTLS: port === 587,
          connectionTimeout: 20_000,
          greetingTimeout: 20_000,
          // Evita ECONNREFUSED intermitente por IPv6 en algunos runtimes Edge.
          family: 4,
          tls: port === 465 ? { servername: host } : undefined,
        },
  );

  const attachments = params.logoBytes
    ? [
        {
          filename: "motolink-logo.png",
          content: params.logoBytes,
          cid: "motolink-logo",
          contentDisposition: "inline" as const,
        },
      ]
    : [];

  await transporter.sendMail({
    from,
    to: params.to,
    subject: params.template.subject,
    text: params.template.text,
    html: params.template.html,
    attachments,
  });
}

async function resolveRecipientEmail(
  supabase: ReturnType<typeof createClient>,
  profileId: string,
  authUser: AuthUserLike | null | undefined,
  options: {
    sessionEmail?: string | null;
    bodyEmail?: string | null;
    allowSessionFallback: boolean;
  },
): Promise<string | null> {
  for (const email of collectEmailsFromAuthUser(authUser)) {
    return email;
  }

  const { data: dbEmail, error: dbError } = await supabase.rpc(
    "resolve_notification_email",
    { p_user_id: profileId },
  );
  if (dbError) {
    console.warn("resolve_notification_email:", dbError.message);
  }
  const fromDb = normalizeEmail(dbEmail);
  if (fromDb) return fromDb;

  if (!options.allowSessionFallback) return null;

  const sessionEmail = normalizeEmail(options.sessionEmail);
  const bodyEmail = normalizeEmail(options.bodyEmail);
  if (sessionEmail && bodyEmail && sessionEmail !== bodyEmail) {
    return null;
  }
  return sessionEmail ?? bodyEmail;
}

async function resolveCallerRole(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();
  if (error) return null;
  return data?.role?.trim().toLowerCase() ?? null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!smtpConfigured()) {
    return jsonResponse({
      ok: true,
      skipped: true,
      reason:
        "SMTP no configurado: falta SMTP_PASS (contraseña de aplicación Gmail).",
    });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "JSON inválido" }, 400);
  }

  const event = body.event;
  if (event !== "registration_submitted" && event !== "profile_approved") {
    return jsonResponse({ error: "event no soportado" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const webhookSecret = Deno.env.get("EMAIL_WEBHOOK_SECRET")?.trim();
  const headerSecret = req.headers.get("x-email-webhook-secret")?.trim();
  const isWebhook = Boolean(
    webhookSecret && headerSecret && webhookSecret === headerSecret,
  );

  const authHeader = req.headers.get("Authorization");
  let callerId: string | null = null;
  let sessionEmail: string | null = null;
  if (!isWebhook && authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice("Bearer ".length);
    const { data, error } = await supabase.auth.getUser(token);
    if (!error && data.user?.id) {
      callerId = data.user.id;
      sessionEmail = normalizeEmail(data.user.email);
    }
  }

  if (!isWebhook && !callerId) {
    return jsonResponse({ error: "No autorizado" }, 401);
  }

  const profileId = body.profile_id?.trim() || callerId;
  if (!profileId) {
    return jsonResponse({ error: "profile_id requerido" }, 400);
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select(
      "id, role, business_name, kyc_status, account_access_status",
    )
    .eq("id", profileId)
    .maybeSingle();

  if (profileError || !profile) {
    return jsonResponse({ error: "Perfil no encontrado" }, 404);
  }

  if (profile.role?.trim().toLowerCase() !== "aliado") {
    return jsonResponse({ error: "Solo aplica a aliados" }, 400);
  }

  if (event === "registration_submitted") {
    if (!isWebhook) {
      if (callerId !== profileId) {
        return jsonResponse({ error: "No autorizado" }, 403);
      }
    }
    if (profile.account_access_status !== "pending_review") {
      return jsonResponse({
        error: "El perfil no está en revisión inicial",
      }, 409);
    }
  }

  if (event === "profile_approved") {
    if (!isWebhook) {
      const callerRole = callerId
        ? await resolveCallerRole(supabase, callerId)
        : null;
      if (callerRole !== "administrador") {
        return jsonResponse({ error: "Solo administradores" }, 403);
      }
    }
    if (
      profile.kyc_status !== "aprobado" ||
      profile.account_access_status !== "active"
    ) {
      return jsonResponse({ error: "El perfil no está aprobado" }, 409);
    }
  }

  const { data: authUser, error: authError } = await supabase.auth.admin
    .getUserById(profileId);
  if (authError) {
    console.warn("getUserById:", authError.message);
  }

  const allowSessionFallback = isWebhook || callerId === profileId;

  const recipientEmail = await resolveRecipientEmail(
    supabase,
    profileId,
    authUser.user,
    {
      sessionEmail,
      bodyEmail: body.recipient_email,
      allowSessionFallback,
    },
  );

  if (!recipientEmail) {
    return jsonResponse({
      error:
        "No encontramos el correo del usuario en Auth. Cierre sesión, vuelva a entrar y reintente.",
      hint:
        "Verifique que inició sesión con correo (no solo teléfono) y que el perfil usa el mismo usuario.",
    }, 404);
  }

  const { data: recentLog } = await supabase
    .from("account_email_log")
    .select("id")
    .eq("profile_id", profileId)
    .eq("event", event)
    .gte("sent_at", new Date(Date.now() - 120_000).toISOString())
    .limit(1)
    .maybeSingle();

  if (recentLog?.id) {
    return jsonResponse({
      ok: true,
      deduplicated: true,
      event,
      profile_id: profileId,
    });
  }

  const businessName = profile.business_name?.trim() || "Aliado MotoLink";
  const template = buildAccountEmailTemplate(event, businessName);
  const logoBytes = await loadLogoBytes();

  try {
    await sendViaSmtp({
      to: recipientEmail,
      template,
      logoBytes,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("send-account-email smtp error:", message);
    return jsonResponse({ error: `No se pudo enviar el correo: ${message}` }, 502);
  }

  await supabase.from("account_email_log").insert({
    profile_id: profileId,
    event,
  });

  return jsonResponse({
    ok: true,
    event,
    profile_id: profileId,
    to: recipientEmail,
  });
});
