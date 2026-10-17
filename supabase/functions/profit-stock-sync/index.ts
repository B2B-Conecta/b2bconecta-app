import { createHandler } from "./handler.ts";

const projectUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serverKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// Solo el servidor posee la service role. El core usa una clave distinta por instalación.
Deno.serve(createHandler({
  projectUrl,
  apply: async (tokenHash, batch) => {
    if (!serverKey) throw new Error("Server key missing");
    const response = await fetch(`${projectUrl}/rest/v1/rpc/profit_sync_apply_stock`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "apikey": serverKey, "Authorization": `Bearer ${serverKey}` },
      body: JSON.stringify({ p_token_hash: tokenHash, p_batch: batch }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) return { error: await response.json() };
    return { data: await response.json() };
  },
}));
