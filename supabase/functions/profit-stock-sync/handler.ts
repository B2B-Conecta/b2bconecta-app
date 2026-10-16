import { expectedProjectRef, maxBodyBytes, StockBatch, validateBatch } from "./contract.ts";

export interface RpcReply { data?: Record<string, unknown>; error?: { code?: string; message?: string } }
export interface Dependencies {
  projectUrl: string;
  apply: (tokenHash: string, batch: StockBatch) => Promise<RpcReply>;
}
function reply(status: number, body: unknown): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}
async function boundedJson(request: Request): Promise<unknown> {
  const body = request.body;
  if (!body) throw new Error("invalid");
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  // Límite total de lectura, también para clientes que envían el cuerpo a cuentagotas.
  let timer: ReturnType<typeof setTimeout>;
  const deadline = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => { void reader.cancel(); reject(new Error("timeout")); }, 10000);
  });
  try {
    while (true) {
      const { value, done } = await Promise.race([reader.read(), deadline]);
      if (done) break;
      size += value.byteLength;
      if (size > maxBodyBytes) { await reader.cancel(); throw new Error("size"); }
      chunks.push(value);
    }
  } finally { clearTimeout(timer!); reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}
export function createHandler(deps: Dependencies): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
    // Primera entrega limitada a DEV. Un despliegue accidental en MAIN no escribe.
    let url: URL;
    try { url = new URL(deps.projectUrl); } catch { return reply(503, { error: "SYNC_ENVIRONMENT_NOT_CONFIGURED" }); }
    if (url.origin !== `https://${expectedProjectRef}.supabase.co` || url.pathname !== "/" ||
      url.username || url.password || url.search || url.hash) {
      return reply(403, { error: "SYNC_ENVIRONMENT_MISMATCH" });
    }
    const authorization = request.headers.get("Authorization") ?? "";
    const match = /^Bearer ([A-Za-z0-9_-]{43,128})$/.exec(authorization);
    if (!match) return reply(401, { error: "SYNC_UNAUTHORIZED" });
    if ((request.headers.get("Content-Type") ?? "").split(";", 1)[0].trim().toLowerCase() !== "application/json") {
      return reply(415, { error: "JSON_REQUIRED" });
    }
    const length = request.headers.get("Content-Length");
    if (length !== null && (!/^\d+$/.test(length) || Number(length) > maxBodyBytes)) return reply(413, { error: "BODY_TOO_LARGE" });
    let batch: unknown;
    try { batch = await boundedJson(request); } catch (error) {
      return reply(error instanceof Error && error.message === "size" ? 413 : 400, { error: "INVALID_JSON_OR_SIZE" });
    }
    if (!validateBatch(batch)) return reply(422, { error: "SYNC_INVALID_BATCH" });
    const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(match[1])));
    const tokenHash = Array.from(hash, (b) => b.toString(16).padStart(2, "0")).join("");
    let result: RpcReply;
    try { result = await deps.apply(tokenHash, batch); } catch {
      return reply(503, { error: "SYNC_BACKEND_UNAVAILABLE" });
    }
    if (result.error) {
      const message = result.error.message ?? "";
      const allowed = new Set(["SYNC_UNAUTHORIZED", "SYNC_OWNER_INVALID", "SYNC_SOURCE_MISMATCH", "SYNC_BATCH_CONFLICT", "SYNC_STALE_SEQUENCE", "SYNC_STALE_OBSERVATION", "SYNC_INVALID_BATCH", "SYNC_INVALID_ROWS", "SYNC_INCOMPLETE_SNAPSHOT", "SYNC_DUPLICATE_CODE", "SYNC_UNKNOWN_CODE", "SYNC_PRODUCT_OWNER_MISMATCH", "SYNC_RESERVATION_REQUIRES_RECONCILIATION", "SYNC_LOCAL_STOCK_CHANGED"]);
      if (!allowed.has(message)) return reply(503, { error: "SYNC_BACKEND_UNAVAILABLE" });
      const status = message === "SYNC_UNAUTHORIZED" || message === "SYNC_OWNER_INVALID" || message === "SYNC_PRODUCT_OWNER_MISMATCH" ? 403 :
        /CONFLICT|STALE|RESERVATION|LOCAL_STOCK/.test(message) ? 409 : 422;
      return reply(status, { error: message });
    }
    if (!result.data || !["applied", "duplicate"].includes(String(result.data.status)) ||
      typeof result.data.batch_id !== "string" || result.data.batch_id.toLowerCase() !== batch.batch_id.toLowerCase() ||
      typeof result.data.installation_id !== "string" || result.data.installation_id.toLowerCase() !== batch.installation_id.toLowerCase() ||
      result.data.source_sequence !== batch.source_sequence) return reply(503, { error: "SYNC_INVALID_ACKNOWLEDGEMENT" });
    return reply(200, result.data);
  };
}
