-- Sellos de proveedor (admin), independientes de la vitrina (estándar):
--   catalog_verified_at  → Verificado (registro completo / oficial)
--   catalog_featured_until → Destacado (alto volumen; máx. 3 activos)

alter table public.profiles
  add column if not exists catalog_verified_at timestamptz;

comment on column public.profiles.catalog_verified_at is
  'Admin: sello Verificado (registro completo/oficial). Null = sin sello.';

comment on column public.profiles.catalog_featured_until is
  'Admin: sello Destacado (volumen de ventas) hasta esta fecha. Máx. 3 activos. Independiente de la vitrina.';

create index if not exists profiles_catalog_verified_at_idx
  on public.profiles (catalog_verified_at)
  where catalog_verified_at is not null;

-- Guard: solo admin cambia verified
create or replace function public.mc_guard_catalog_verified_at ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.catalog_verified_at is not distinct from old.catalog_verified_at then
    return new;
  end if;
  perform public._assert_administrador ();
  return new;
end;
$$;

drop trigger if exists mc_tr_guard_catalog_verified_at on public.profiles;

create trigger mc_tr_guard_catalog_verified_at
before update of catalog_verified_at on public.profiles
for each row
execute function public.mc_guard_catalog_verified_at ();

create or replace function public.admin_set_importer_catalog_verified (
  p_importador_id uuid,
  p_verified boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz;
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Importador requerido' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_importador_id
      and p.role = 'importador'
      and p.deactivated_at is null
  ) then
    raise exception 'Importador no válido' using errcode = 'P0002';
  end if;

  if coalesce(p_verified, false) then
    v_at := now();
  else
    v_at := null;
  end if;

  update public.profiles
  set catalog_verified_at = v_at
  where id = p_importador_id;

  return v_at;
end;
$$;

comment on function public.admin_set_importer_catalog_verified (uuid, boolean) is
  'Admin: activa/quita sello Verificado. No controla la vitrina.';

revoke all on function public.admin_set_importer_catalog_verified (uuid, boolean)
  from public;
grant execute on function public.admin_set_importer_catalog_verified (uuid, boolean)
  to authenticated;

comment on function public.admin_set_importer_catalog_featured (uuid, integer) is
  'Admin: sello Destacado 7/15/30 días (máx. 3) o p_days=0 para quitar. No controla la vitrina.';

-- Ficha de vitrina: incluir verified
drop function if exists public.aliado_importer_store_profile (uuid);

create function public.aliado_importer_store_profile (p_importador_id uuid)
returns table (
  id uuid,
  business_name text,
  rif text,
  phone text,
  estado text,
  ciudad text,
  direccion text,
  fiscal_maps_url text,
  logo_storage_path text,
  rating_avg_received_rolling100 numeric,
  rating_count_received_rolling100 integer,
  min_order_amount_ref numeric,
  min_order_currency text,
  catalog_featured_until timestamptz,
  catalog_verified_at timestamptz,
  pago_solo_divisas boolean,
  accepted_pago_metodos text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public._assert_importer_store_viewer ();

  if p_importador_id is null or not public._importer_store_is_public (p_importador_id) then
    return;
  end if;

  return query
  select
    p.id,
    p.business_name,
    p.rif,
    p.phone,
    p.estado,
    p.ciudad,
    p.direccion,
    p.fiscal_maps_url,
    p.logo_storage_path,
    p.rating_avg_received_rolling100,
    p.rating_count_received_rolling100,
    p.min_order_amount_ref,
    p.min_order_currency,
    p.catalog_featured_until,
    p.catalog_verified_at,
    coalesce(p.pago_solo_divisas, false),
    p.accepted_pago_metodos
  from public.profiles p
  where p.id = p_importador_id;
end;
$$;

revoke all on function public.aliado_importer_store_profile (uuid) from public, anon;
grant execute on function public.aliado_importer_store_profile (uuid) to authenticated;

comment on function public.aliado_importer_store_profile (uuid) is
  'Tienda minorista: ficha pública de un mayorista activo (incl. sellos Verificado/Destacado).';

-- Snapshot JSON: incluir verified para el panel admin
create or replace function public.mc_importer_sales_snapshot_json (
  p_importador_id uuid,
  p_days integer default 30,
  p_product_limit integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_limit integer := least (greatest (coalesce(p_product_limit, 5), 1), 500);
  v_from timestamptz;
  v_name text := 'Importador';
  v_until timestamptz;
  v_verified timestamptz;
  v_orders integer := 0;
  v_active integer := 0;
  v_done integer := 0;
  v_units integer := 0;
  v_revenue numeric := 0;
  v_prod_active integer := 0;
  v_prod_paused integer := 0;
  v_top jsonb := '[]'::jsonb;
  v_low jsonb := '[]'::jsonb;
begin
  if p_importador_id is null then
    return '{}'::jsonb;
  end if;

  select
    coalesce(nullif(trim(p.business_name), ''), 'Importador'),
    p.catalog_featured_until,
    p.catalog_verified_at
    into v_name, v_until, v_verified
  from public.profiles p
  where p.id = p_importador_id;

  v_from := now() - make_interval(days => v_days);

  select
    coalesce(count(*) filter (
      where tr.status is distinct from 'rechazado'
    ), 0)::integer,
    coalesce(count(*) filter (
      where tr.status not in ('entregado', 'rechazado')
    ), 0)::integer,
    coalesce(count(*) filter (
      where tr.status = 'entregado'
    ), 0)::integer,
    coalesce(sum(tr.cantidad) filter (
      where tr.status is distinct from 'rechazado'
    ), 0)::integer,
    coalesce(sum(tr.precio_total_usd) filter (
      where tr.status is distinct from 'rechazado'
    ), 0)::numeric
    into v_orders, v_active, v_done, v_units, v_revenue
  from public.transaction_requests tr
  where tr.importador_id = p_importador_id
    and tr.created_at >= v_from;

  select
    coalesce(count(*) filter (where coalesce(p.is_active, true)), 0)::integer,
    coalesce(count(*) filter (where not coalesce(p.is_active, true)), 0)::integer
    into v_prod_active, v_prod_paused
  from public.products p
  where p.owner_id = p_importador_id;

  select coalesce(
    jsonb_agg (
      jsonb_build_object (
        'product_id', s.product_id,
        'name', s.product_name,
        'units', s.units,
        'revenue', s.revenue
      )
      order by s.units desc, s.revenue desc
    ),
    '[]'::jsonb
  )
    into v_top
  from (
    select
      tr.product_id,
      coalesce(nullif(trim(pr.name), ''), 'Producto') as product_name,
      sum(tr.cantidad)::integer as units,
      sum(tr.precio_total_usd)::numeric as revenue
    from public.transaction_requests tr
    left join public.products pr on pr.id = tr.product_id
    where tr.importador_id = p_importador_id
      and tr.created_at >= v_from
      and tr.status is distinct from 'rechazado'
    group by tr.product_id, pr.name
    order by units desc, revenue desc
    limit v_limit
  ) s;

  select coalesce(
    jsonb_agg (
      jsonb_build_object (
        'product_id', s.product_id,
        'name', s.product_name,
        'units', s.units
      )
      order by s.units asc, s.product_name asc
    ),
    '[]'::jsonb
  )
    into v_low
  from (
    select
      p.id as product_id,
      coalesce(nullif(trim(p.name), ''), 'Producto') as product_name,
      coalesce(x.units, 0)::integer as units
    from public.products p
    left join (
      select tr.product_id, sum(tr.cantidad)::integer as units
      from public.transaction_requests tr
      where tr.importador_id = p_importador_id
        and tr.created_at >= v_from
        and tr.status is distinct from 'rechazado'
      group by tr.product_id
    ) x on x.product_id = p.id
    where p.owner_id = p_importador_id
      and coalesce(p.is_active, true)
    order by coalesce(x.units, 0) asc, p.name asc
    limit v_limit
  ) s;

  return jsonb_build_object (
    'importador_id', p_importador_id,
    'business_name', v_name,
    'catalog_featured_until', v_until,
    'catalog_verified_at', v_verified,
    'days', v_days,
    'orders_count', v_orders,
    'orders_active', v_active,
    'orders_entregados', v_done,
    'units_sold', v_units,
    'revenue_ref', v_revenue,
    'products_active', v_prod_active,
    'products_paused', v_prod_paused,
    'top_products', v_top,
    'low_rotation', v_low
  );
end;
$$;
