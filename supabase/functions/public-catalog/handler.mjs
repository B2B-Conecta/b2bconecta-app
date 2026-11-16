export const PRODUCTION_ORIGIN = 'https://fzugzjcwdzcwfxgviltw.supabase.co';
export const PUBLIC_SAMPLE_LIMIT = 12;
const normalize = (value) => String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('es').trim();
const text = (value, max = 300) => typeof value === 'string' ? value.trim().slice(0, max) : '';
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

export function projectPublicProduct(row) {
  const provider = row.profiles;
  if (!row.is_active || !row.stock_covers_min_order || !uuid.test(row.id)
    || provider?.role !== 'importador' || provider.account_access_status !== 'active'
    || provider.deactivated_at || !text(provider.business_name) || !text(row.name)) return null;
  const images = [...new Set([...(Array.isArray(row.image_urls) ? row.image_urls : []), row.image_url])]
    .filter((value) => {
      if (typeof value !== 'string') return false;
      try {
        const url = new URL(value);
        return url.origin === PRODUCTION_ORIGIN && url.pathname.startsWith('/storage/v1/object/public/product-images/')
          && /\.(png|jpe?g|webp)$/i.test(url.pathname);
      } catch { return false; }
    }).slice(0, 5);
  if (!images.length) return null;
  const category = text(row.category, 80);
  // Explicit public contract. Never return a raw product or profile row.
  return {
    id: row.id, name: text(row.name, 180), sku: text(row.sku, 100),
    description: text(row.description, 2500), compatibility: text(row.compatibility, 600),
    category: category || 'Otros repuestos', supplier: text(provider.business_name, 140),
    minimum: Math.max(1, Number.isFinite(Number(row.min_order_qty)) ? Math.floor(Number(row.min_order_qty)) : 1),
    warranty: row.has_warranty === true, images,
  };
}

export function selectPublicSample(rows) {
  const candidates = rows.map(projectPublicProduct).filter(Boolean)
    .sort((a, b) => a.name.localeCompare(b.name, 'es') || a.id.localeCompare(b.id));
  const names = new Set();
  const remaining = candidates.filter((p) => {
    const name = normalize(p.name).replace(/\s+/g, ' ');
    if (names.has(name)) return false;
    names.add(name); return true;
  });
  const result = [];
  const providers = new Map(), categories = new Map();
  const score = (p) => (providers.has(p.supplier) ? 0 : 100) + (categories.has(p.category) ? 0 : 50)
    - (providers.get(p.supplier) || 0) * 5 - (categories.get(p.category) || 0) * 3;
  while (remaining.length && result.length < PUBLIC_SAMPLE_LIMIT) {
    let best = 0;
    for (let i = 1; i < remaining.length; i++) if (score(remaining[i]) > score(remaining[best])) best = i;
    const [product] = remaining.splice(best, 1);
    result.push(product);
    providers.set(product.supplier, (providers.get(product.supplier) || 0) + 1);
    categories.set(product.category, (categories.get(product.category) || 0) + 1);
  }
  return result;
}

export function createHandler({ projectUrl, secretKey, publicKeys, fetcher = fetch }) {
  return async (request) => {
    const respond = (data, status = 200) => new Response(request.method === 'HEAD' ? null : JSON.stringify(data), {
      status,
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': status === 200 ? 'public, max-age=60' : 'no-store', 'X-Content-Type-Options': 'nosniff', 'Allow': 'GET, HEAD' },
    });
    if (!['GET', 'HEAD'].includes(request.method)) return respond({ message: 'Method not allowed' }, 405);
    if (projectUrl !== PRODUCTION_ORIGIN || !secretKey || !publicKeys.length) return respond({ message: 'Catalog unavailable' }, 503);
    // Gateway JWT verification is disabled because publishable keys are not JWTs.
    // This endpoint validates its own publishable/legacy public API key.
    if (!publicKeys.includes(request.headers.get('apikey'))) return respond({ message: 'Unauthorized' }, 401);
    if (new URL(request.url).search) return respond({ message: 'This endpoint only exposes the fixed public sample' }, 400);
    try {
      const url = new URL('/rest/v1/products', projectUrl);
      url.search = new URLSearchParams({
        select: 'id,name,sku,description,compatibility,category,image_url,image_urls,min_order_qty,has_warranty,is_active,stock_covers_min_order,profiles!products_owner_id_fkey!inner(business_name,role,account_access_status,deactivated_at)',
        is_active: 'eq.true', stock_covers_min_order: 'eq.true',
        'profiles.role': 'eq.importador', 'profiles.account_access_status': 'eq.active', 'profiles.deactivated_at': 'is.null',
        order: 'id.asc', limit: '240',
      }).toString();
      const headers = { apikey: secretKey };
      // Secret API keys are sent only on apikey. Legacy service-role JWTs also
      // need Authorization to select with their database role.
      if (!secretKey.startsWith('sb_secret_')) headers.Authorization = `Bearer ${secretKey}`;
      const response = await fetcher(url, { headers, signal: AbortSignal.timeout(8000) });
      if (!response.ok) return respond({ message: 'Catalog unavailable' }, 503);
      const rows = await response.json();
      if (!Array.isArray(rows)) return respond({ message: 'Catalog unavailable' }, 503);
      return respond({ source: 'production', updatedAt: new Date().toISOString(), products: selectPublicSample(rows) });
    } catch { return respond({ message: 'Catalog unavailable' }, 503); }
  };
}
