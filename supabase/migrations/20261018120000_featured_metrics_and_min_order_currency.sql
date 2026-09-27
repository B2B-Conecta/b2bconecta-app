-- Destacados con métricas de mayorista + pedido mínimo en REF o divisa (USD).

alter table public.profiles
  add column if not exists min_order_currency text not null default 'ref';

alter table public.profiles
  drop constraint if exists profiles_min_order_currency_chk;

alter table public.profiles
  add constraint profiles_min_order_currency_chk
  check (min_order_currency in ('ref', 'usd'));

comment on column public.profiles.min_order_currency is
  'Unidad de presentación del piso de compra: ref o usd (divisa). El monto se guarda en REF.';

create or replace function public.mc_importer_sales_snapshot_json (
  p_importador_id uuid,
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_from timestamptz;
  v_name text := 'Importador';
  v_until timestamptz;
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
    p.catalog_featured_until
    into v_name, v_until
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
    coalesce(sum(tr.precio_total) filter (
      where tr.status is distinct from 'rechazado'
    ), 0)::numeric
    into v_orders, v_active, v_done, v_units, v_revenue
  from public.transaction_requests tr
  where tr.owner_id = p_importador_id
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
      sum(tr.precio_total)::numeric as revenue
    from public.transaction_requests tr
    left join public.products pr on pr.id = tr.product_id
    where tr.owner_id = p_importador_id
      and tr.created_at >= v_from
      and tr.status is distinct from 'rechazado'
    group by tr.product_id, pr.name
    order by units desc, revenue desc
    limit 5
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
      where tr.owner_id = p_importador_id
        and tr.created_at >= v_from
        and tr.status is distinct from 'rechazado'
      group by tr.product_id
    ) x on x.product_id = p.id
    where p.owner_id = p_importador_id
      and coalesce(p.is_active, true)
    order by coalesce(x.units, 0) asc, p.name asc
    limit 5
  ) s;

  return jsonb_build_object (
    'importador_id', p_importador_id,
    'business_name', v_name,
    'catalog_featured_until', v_until,
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

revoke all on function public.mc_importer_sales_snapshot_json (uuid, integer)
  from public, anon, authenticated;

create or replace function public.importador_sales_snapshot (p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid
    and p.deactivated_at is null;

  if v_role is distinct from 'importador' then
    raise exception 'Solo importadores' using errcode = '42501';
  end if;

  return public.mc_importer_sales_snapshot_json (v_uid, p_days);
end;
$$;

create or replace function public.admin_list_importer_sales_snapshots (
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_out jsonb := '[]'::jsonb;
  r record;
begin
  perform public._assert_administrador ();

  for r in
    select p.id
    from public.profiles p
    where p.role = 'importador'
      and p.deactivated_at is null
    order by coalesce(nullif(trim(p.business_name), ''), 'Importador')
  loop
    v_out := v_out || jsonb_build_array (
      public.mc_importer_sales_snapshot_json (r.id, v_days)
    );
  end loop;

  return v_out;
end;
$$;

comment on function public.admin_list_importer_sales_snapshots (integer) is
  'Admin: snapshot de ventas/rotación por importador para destacar en catálogo.';

revoke all on function public.admin_list_importer_sales_snapshots (integer)
  from public;
grant execute on function public.admin_list_importer_sales_snapshots (integer)
  to authenticated;
