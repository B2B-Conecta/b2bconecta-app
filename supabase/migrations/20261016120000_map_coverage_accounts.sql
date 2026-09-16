-- Puente de cobertura para el mapa interno (Cloudflare Worker).
-- Solo service_role: el Worker no lee public.profiles; llama la Edge Function.

create or replace function public.map_coverage_accounts ()
returns table (
  id uuid,
  account_type text,
  status text,
  business_name text,
  state text,
  municipality text,
  city text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  location_updated_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    case p.role
      when 'aliado' then 'retailer'
      when 'importador' then 'wholesaler'
    end as account_type,
    case
      when p.deactivated_at is not null then 'deactivated'
      when coalesce(nullif(btrim(p.account_access_status), ''), 'active') = 'active'
        then 'active'
      when p.account_access_status = 'pending_review' then 'pending_review'
      when p.account_access_status = 'draft' then 'draft'
      when p.account_access_status = 'rejected' then 'rejected'
      else coalesce(nullif(btrim(p.account_access_status), ''), 'draft')
    end as status,
    nullif(btrim(p.business_name), '') as business_name,
    nullif(btrim(p.estado), '') as state,
    null::text as municipality,
    nullif(btrim(p.ciudad), '') as city,
    p.latitude,
    p.longitude,
    p.created_at,
    p.location_updated_at,
    null::timestamptz as updated_at
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.role in ('aliado', 'importador')
    and coalesce(u.email, '') not ilike '%@motoconecta.seed'
  order by p.created_at, p.id;
$$;

revoke all on function public.map_coverage_accounts () from public;
revoke all on function public.map_coverage_accounts () from anon;
revoke all on function public.map_coverage_accounts () from authenticated;
grant execute on function public.map_coverage_accounts () to service_role;

comment on function public.map_coverage_accounts () is
  'Mapa interno: minoristas/mayoristas sin PII. Solo service_role.';
