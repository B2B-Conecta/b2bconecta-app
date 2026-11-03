// Sincroniza la tasa BCV global desde bcv.today (mismo criterio que la app).
// Invocada por pg_cron cada 30 min con Authorization: Bearer <service_role>.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const RATE_URL = "https://bcv.today/api/v1/rate.json";
const HISTORY_PREFIX = "https://bcv.today/api/v1/history/";
const RATE_EPSILON = 0.00005;

type Quote = {
  vesPerUsd: number;
  effectiveDate: string | null;
};

function caracasNow(utc = new Date()): Date {
  return new Date(utc.getTime() - 4 * 60 * 60 * 1000);
}

function isoDate(d: Date): string {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function nextBusinessDay(day: Date): Date {
  let next = new Date(
    Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate() + 1),
  );
  while (next.getUTCDay() === 0 || next.getUTCDay() === 6) {
    next = new Date(
      Date.UTC(next.getUTCFullYear(), next.getUTCMonth(), next.getUTCDate() + 1),
    );
  }
  return next;
}

/** Hoy (Caracas) y, tras 16:30, el siguiente día hábil. */
export function historyDatesToProbe(caracas: Date): string[] {
  const start = new Date(
    Date.UTC(caracas.getUTCFullYear(), caracas.getUTCMonth(), caracas.getUTCDate()),
  );
  const dates = [isoDate(start)];
  const afterBulletin = caracas.getUTCHours() > 16 ||
    (caracas.getUTCHours() === 16 && caracas.getUTCMinutes() >= 30);
  if (afterBulletin) dates.push(isoDate(nextBusinessDay(start)));
  return dates;
}

export function quoteFromMap(data: Record<string, unknown> | null): Quote | null {
  if (!data) return null;
  const usd = data["USD"];
  if (typeof usd !== "number" || !(usd > 0)) return null;
  const effective = String(data["effective_date"] ?? "").trim();
  const date = String(data["date"] ?? "").trim();
  return {
    vesPerUsd: usd,
    effectiveDate: effective || date || null,
  };
}

export function pickLatestPublished(quotes: Quote[]): Quote | null {
  let best: Quote | null = null;
  let bestDate: number | null = null;
  for (const q of quotes) {
    const raw = q.effectiveDate?.trim();
    const parsed = raw ? Date.parse(raw) : NaN;
    if (!Number.isFinite(parsed)) {
      best ??= q;
      continue;
    }
    if (bestDate === null || parsed > bestDate) {
      best = q;
      bestDate = parsed;
    }
  }
  return best;
}

async function fetchJson(url: string): Promise<Quote | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(12000) });
    if (!res.ok) return null;
    const decoded = await res.json();
    if (!decoded || typeof decoded !== "object") return null;
    return quoteFromMap(decoded as Record<string, unknown>);
  } catch {
    return null;
  }
}

export async function fetchPublicBcvUsdRate(
  now = new Date(),
): Promise<Quote | null> {
  const dates = historyDatesToProbe(caracasNow(now));
  const fetched = await Promise.all([
    fetchJson(RATE_URL),
    ...dates.map((d) => fetchJson(`${HISTORY_PREFIX}${d}.json`)),
  ]);
  return pickLatestPublished(fetched.filter((q): q is Quote => q != null));
}

function unauthorized(): Response {
  return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });
}

Deno.serve(async (req) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("method not allowed", { status: 405 });
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const projectUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  if (!serviceKey || !projectUrl) {
    return Response.json({ ok: false, error: "missing env" }, { status: 500 });
  }

  const auth = req.headers.get("Authorization")?.trim() ?? "";
  const bearer = auth.toLowerCase().startsWith("bearer ")
    ? auth.slice(7).trim()
    : "";
  if (!bearer || bearer !== serviceKey) return unauthorized();

  const quote = await fetchPublicBcvUsdRate();
  if (!quote) {
    return Response.json(
      { ok: false, error: "bcv_fetch_failed" },
      { status: 502 },
    );
  }

  const admin = createClient(projectUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await admin.rpc("service_upsert_tasa_bcv", {
    p_tasa: quote.vesPerUsd,
    p_effective_date: quote.effectiveDate,
  });

  if (error) {
    return Response.json(
      { ok: false, error: error.message },
      { status: 500 },
    );
  }

  const prev = typeof data?.previous === "number" ? data.previous : null;
  const changed = prev == null ||
    Math.abs(prev - quote.vesPerUsd) > RATE_EPSILON;

  return Response.json({
    ok: true,
    tasa: quote.vesPerUsd,
    effective_date: quote.effectiveDate,
    previous: prev,
    changed,
    source: "bcv.today",
  });
});
