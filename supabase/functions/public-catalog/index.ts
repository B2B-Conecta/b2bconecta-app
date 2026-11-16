import { createHandler } from './handler.mjs';

function keys(name: string): Record<string, string> {
  try { return JSON.parse(Deno.env.get(name) || '{}'); } catch { return {}; }
}

Deno.serve(createHandler({
  projectUrl: Deno.env.get('SUPABASE_URL') || '',
  secretKey: keys('SUPABASE_SECRET_KEYS').default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '',
  publicKeys: [...Object.values(keys('SUPABASE_PUBLISHABLE_KEYS')), Deno.env.get('SUPABASE_ANON_KEY')].filter(Boolean),
}));
