import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, projectPublicProduct, selectPublicSample, PRODUCTION_ORIGIN } from './handler.mjs';

const row = (n = 1) => ({
  id: `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`, name: 'Producto ' + n,
  is_active: true, stock_covers_min_order: true, price_usd: 52, sale_price_usd: 48, stock: 100, owner_id: 'private',
  image_url: PRODUCTION_ORIGIN + '/storage/v1/object/public/product-images/owner/product.jpg', min_order_qty: 5,
  profiles: { business_name: 'Proveedor ' + n % 4, role: 'importador', account_access_status: 'active', deactivated_at: null, rif: 'private', phone: 'private' },
});
const options = { projectUrl: PRODUCTION_ORIGIN, publicKeys: ['public-test'], secretKey: 'server-test' };
const request = (extra = '') => new Request('https://example.test/public-catalog' + extra, { headers: { apikey: 'public-test' } });

test('only the explicitly allowed fields leave the server', () => {
  const p = projectPublicProduct(row());
  assert.deepEqual(Object.keys(p).sort(), ['id','name','sku','description','compatibility','category','supplier','minimum','warranty','images'].sort());
  assert.doesNotMatch(JSON.stringify(p), /price_usd|sale_price_usd|owner_id|private|"stock"|"rif"|"phone"/);
});
test('inactive, unavailable, pending or deactivated suppliers never enter the sample', () => {
  for (const bad of [{ is_active: false }, { stock_covers_min_order: false }, { profiles: { ...row().profiles, account_access_status: 'pending_review' } }, { profiles: { ...row().profiles, deactivated_at: '2026-01-01' } }, { profiles: { ...row().profiles, role: 'aliado' } }, { image_url: 'https://kdrccmqcrruixuworlmz.supabase.co/storage/v1/object/public/product-images/a.jpg' }]) {
    assert.equal(projectPublicProduct({ ...row(), ...bad }), null);
  }
});
test('sample is capped at 12 distinct names and includes multiple providers', () => {
  const rows = Array.from({length:30}, (_,i) => row(i + 1));
  rows.push({...row(40), name:' PRODUCTO 1 '});
  const selected = selectPublicSample(rows);
  assert.equal(selected.length, 12);
  assert.equal(new Set(selected.map(p => p.name.toLowerCase().trim())).size, 12);
  assert.equal(new Set(selected.map(p => p.supplier)).size, 4);
});
test('API key and method checks happen before any database read', async () => {
  let calls = 0;
  const handler = createHandler({...options, fetcher: () => {calls++; throw Error();}});
  assert.equal((await handler(new Request('https://example.test'))).status, 401);
  assert.equal((await handler(new Request('https://example.test', {method:'POST'}))).status, 405);
  assert.equal((await handler(request('?select=price_usd'))).status, 400);
  assert.equal(calls, 0);
});
test('returns current production projection and never forwards server credentials', async () => {
  const handler = createHandler({...options, fetcher: async (url) => {assert.equal(new URL(url).searchParams.get('is_active'), 'eq.true'); return Response.json([row()]);}});
  const result = await handler(request());
  assert.equal(result.status, 200);
  const data = await result.json();
  assert.equal(data.source, 'production');
  assert.equal(data.products.length, 1);
  assert.doesNotMatch(JSON.stringify(data), /server-test|public-test/);
});
test('wrong environment and upstream failures never fall back to test products', async () => {
  const wrong = createHandler({...options, projectUrl:'https://czswojzpekcsisudgfsg.supabase.co'});
  assert.equal((await wrong(request())).status, 503);
  const failed = createHandler({...options, fetcher: async () => new Response('private error', {status:500})});
  const result = await failed(request());
  assert.equal(result.status, 503);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await result.json(), {message:'Catalog unavailable'});
});
