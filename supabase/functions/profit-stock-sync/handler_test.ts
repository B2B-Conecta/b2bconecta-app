import { StockBatch, validateBatch } from "./contract.ts";
import { createHandler } from "./handler.ts";

function assert(value: unknown, message = "assertion failed"): asserts value { if (!value) throw new Error(message); }
const token = "a".repeat(43);
const projectUrl = "https://kdrccmqcrruixuworlmz.supabase.co";
function batch(): StockBatch { return {
  schema_version: 2, mode: "stock_only",
  installation_id: "11111111-1111-4111-8111-111111111111",
  batch_id: "22222222-2222-4222-8222-222222222222", source_sequence: 1,
  observed_at: new Date().toISOString(), source: { erp: "Profit", database: "MOTO", warehouse: "GM" },
  rows: [{ co_art: "ALIX exact / 1", unidad: "UNI", stock_actual: 20, stock_comprometido: 3 }],
}; }
function request(body: unknown = batch(), authorization = `Bearer ${token}`): Request {
  return new Request("https://local.test/profit-stock-sync", { method: "POST", headers: { "Content-Type": "application/json", Authorization: authorization }, body: JSON.stringify(body) });
}
function success(_hash: string, b: StockBatch) { return Promise.resolve({ data: { status: "applied", installation_id: b.installation_id, batch_id: b.batch_id, source_sequence: b.source_sequence } }); }
Deno.test("accepted batch hashes connector key and preserves exact code", async () => {
  let called = false;
  const handler = createHandler({ projectUrl, apply: (hash, b) => { called = true; assert(/^[a-f0-9]{64}$/.test(hash)); assert(hash !== token); assert(b.rows[0].co_art === "ALIX exact / 1"); return success(hash,b); } });
  assert((await handler(request())).status === 200); assert(called);
});
Deno.test("unauthenticated request never reaches RPC", async () => {
  const handler = createHandler({ projectUrl, apply: () => { throw new Error("must not run"); } });
  assert((await handler(request(batch(), ""))).status === 401);
});
Deno.test("other Supabase project cannot write", async () => {
  const handler = createHandler({ projectUrl: "https://fzugzjcwdzcwfxgviltw.supabase.co", apply: () => { throw new Error("must not run"); } });
  assert((await handler(request())).status === 403);
});
Deno.test("price, owner and incoming fields rejected", () => {
  for (const extra of [{ price_usd: 3 }, { owner_id: "fake" }, { stock_lle: 60 }]) {
    const b = batch(); Object.assign(b.rows[0], extra); assert(!validateBatch(b));
  }
});
Deno.test("negative, decimal, unsafe and duplicate quantities/codes rejected", () => {
  for (const qty of [-1, 1.5, 2147483648]) { const b=batch(); b.rows[0].stock_actual=qty; assert(!validateBatch(b)); }
  const b=batch(); b.rows.push({...b.rows[0]}); assert(!validateBatch(b));
});
Deno.test("wrong unit, source and partial row rejected", () => {
  for (const change of [(b: StockBatch) => Object.assign(b.rows[0],{unidad:"LTR"}), (b: StockBatch) => Object.assign(b.source,{warehouse:"A-01"}), (b: StockBatch) => Reflect.deleteProperty(b.rows[0],"stock_comprometido")]) {
    const b=batch(); change(b); assert(!validateBatch(b));
  }
});
Deno.test("large body rejected before RPC", async () => {
  const handler=createHandler({projectUrl,apply:()=>{throw new Error("must not run");}});
  assert((await handler(request({text:"x".repeat(65536)}))).status===413);
});
Deno.test("reservation conflict is explicit and retry is not claimed", async () => {
  const handler=createHandler({projectUrl,apply:()=>Promise.resolve({error:{message:"SYNC_RESERVATION_REQUIRES_RECONCILIATION"}})});
  const reply=await handler(request()); assert(reply.status===409); assert((await reply.json()).error==="SYNC_RESERVATION_REQUIRES_RECONCILIATION");
});
Deno.test("backend outage and forged acknowledgement fail", async () => {
  const h=createHandler({projectUrl,apply:()=>{throw new Error("hidden credential details");}});
  const response=await h(request()); assert(response.status===503); assert(!(await response.text()).includes("credential"));
  const h2=createHandler({projectUrl,apply:()=>Promise.resolve({data:{status:"applied",batch_id:"wrong"}})});
  assert((await h2(request())).status===503);
});
Deno.test("duplicate acknowledgement accepted", async () => {
  const handler=createHandler({projectUrl,apply:async(hash,b)=>({data:{...(await success(hash,b)).data,status:"duplicate"}})});
  const response=await handler(request()); assert(response.status===200); assert((await response.json()).status==="duplicate");
});
Deno.test("PostgreSQL canonical UUID case accepted without changing product codes", async () => {
  const b=batch(); b.installation_id="AAAA1111-1111-4111-8111-111111111111"; b.batch_id="BBBB2222-2222-4222-8222-222222222222";
  const handler=createHandler({projectUrl,apply:async(_hash,b)=>({data:{status:"applied",installation_id:b.installation_id.toLowerCase(),batch_id:b.batch_id.toLowerCase(),source_sequence:b.source_sequence}})});
  assert((await handler(request(b))).status===200);
});
Deno.test("project URL cannot contain credentials, path or another port", async () => {
  for(const project of [projectUrl+"/rpc",projectUrl+":444",projectUrl.replace("https://","https://user:password@")]) {
    const handler=createHandler({projectUrl:project,apply:()=>{throw new Error("must not run");}});
    assert((await handler(request())).status===403);
  }
});
