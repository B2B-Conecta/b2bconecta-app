-- Pedido mínimo por importador (REF) + destacado manual en catálogo (admin).
-- El checkout valida el subtotal por dueño con el mismo precio aliado que el RPC.

alter table public.profiles
  add column if not exists min_order_amount_ref numeric not null default 0;

alter table public.profiles
  drop constraint if exists profiles_min_order_amount_ref_nonneg;

alter table public.profiles
  add constraint profiles_min_order_amount_ref_nonneg
  check (min_order_amount_ref >= 0);

alter table public.profiles
  add column if not exists catalog_featured_until timestamptz;

comment on column public.profiles.min_order_amount_ref is
  'Piso de compra por importador (REF). 0 = sin mínimo de monto.';

comment on column public.profiles.catalog_featured_until is
  'Hasta cuándo el admin destaca este importador en el catálogo aliado.';

create index if not exists profiles_catalog_featured_until_idx
  on public.profiles (catalog_featured_until)
  where catalog_featured_until is not null;

-- Solo admin / service_role puede cambiar el destacado.
create or replace function public.mc_guard_catalog_featured_until ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.catalog_featured_until is not distinct from old.catalog_featured_until then
    return new;
  end if;
  perform public._assert_administrador ();
  return new;
end;
$$;

drop trigger if exists mc_tr_guard_catalog_featured_until on public.profiles;

create trigger mc_tr_guard_catalog_featured_until
before update of catalog_featured_until on public.profiles
for each row
execute function public.mc_guard_catalog_featured_until ();

create or replace function public.mc_assert_cart_min_order_amounts (p_lines jsonb)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r record;
begin
  if p_lines is null
     or jsonb_typeof (p_lines) <> 'array'
     or jsonb_array_length (p_lines) = 0 then
    return;
  end if;

  for r in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        greatest (1, coalesce((elem ->> 'cantidad')::integer, 1)) as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    ),
    priced as (
      select
        pr.owner_id,
        coalesce(pf.min_order_amount_ref, 0)::numeric as min_ref,
        coalesce(nullif(trim(pf.business_name), ''), 'Importador') as importer_name,
        round(
          (
            public.motoconecta_aliado_unit_price_usd (
              pr.price_usd,
              pr.sale_price_usd,
              pr.discount_rules,
              a.cantidad,
              false
            ) * a.cantidad
          )::numeric,
          4
        ) as line_total
      from agg a
      join public.products pr on pr.id = a.product_id
      join public.profiles pf on pf.id = pr.owner_id
    )
    select
      owner_id,
      min_ref,
      importer_name,
      sum(line_total) as subtotal
    from priced
    group by owner_id, min_ref, importer_name
  loop
    if r.min_ref > 0 and r.subtotal < r.min_ref then
      raise exception
        'min_order_amount:%:%:%:%',
        r.owner_id::text,
        r.min_ref::text,
        r.subtotal::text,
        r.importer_name
        using errcode = 'P0001';
    end if;
  end loop;
end;
$$;

comment on function public.mc_assert_cart_min_order_amounts (jsonb) is
  'Rechaza el carrito si algún importador queda bajo su min_order_amount_ref.';

revoke all on function public.mc_assert_cart_min_order_amounts (jsonb)
  from public, anon, authenticated;

alter function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) rename to aliado_checkout_multi_importador_impl;

revoke all on function public.aliado_checkout_multi_importador_impl (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) from public, anon, authenticated;

create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}'::jsonb,
  p_carriers_by_importador jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.mc_assert_cart_min_order_amounts (p_lines);
  return public.aliado_checkout_multi_importador_impl (
    p_lines,
    p_destino_entrega_usa_perfil,
    p_destino_entrega_texto,
    p_destino_entrega_maps_url,
    p_promo_by_importador,
    p_carriers_by_importador
  );
end;
$$;

comment on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) is
  'Checkout aliado: valida pedido mínimo por importador y delega en la implementación.';

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) to authenticated;

create or replace function public.admin_set_importer_catalog_featured (
  p_importador_id uuid,
  p_days integer
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_until timestamptz;
  v_n integer;
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Importador requerido' using errcode = '22023';
  end if;

  if p_days is null or p_days not in (0, 7, 15, 30) then
    raise exception 'featured_days:7,15,30' using errcode = '22023';
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

  if p_days = 0 then
    update public.profiles
    set catalog_featured_until = null
    where id = p_importador_id;
    return null;
  end if;

  select count(*)::integer
    into v_n
  from public.profiles p
  where p.role = 'importador'
    and p.deactivated_at is null
    and p.catalog_featured_until is not null
    and p.catalog_featured_until > now()
    and p.id <> p_importador_id;

  if coalesce(v_n, 0) >= 3 then
    raise exception 'featured_limit:3' using errcode = 'P0001';
  end if;

  v_until := now() + make_interval(days => p_days);

  update public.profiles
  set catalog_featured_until = v_until
  where id = p_importador_id;

  return v_until;
end;
$$;

comment on function public.admin_set_importer_catalog_featured (uuid, integer) is
  'Admin: destaca un importador 7/15/30 días (máx. 3 activos) o p_days=0 para quitar.';

revoke all on function public.admin_set_importer_catalog_featured (uuid, integer)
  from public;
grant execute on function public.admin_set_importer_catalog_featured (uuid, integer)
  to authenticated;

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
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_from timestamptz;
  v_orders integer := 0;
  v_units integer := 0;
  v_revenue numeric := 0;
  v_top jsonb := '[]'::jsonb;
  v_low jsonb := '[]'::jsonb;
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

  v_from := now() - make_interval(days => v_days);

  select
    coalesce(count(distinct tr.id), 0)::integer,
    coalesce(sum(tr.cantidad), 0)::integer,
    coalesce(sum(tr.precio_total), 0)::numeric
    into v_orders, v_units, v_revenue
  from public.transaction_requests tr
  where tr.owner_id = v_uid
    and tr.created_at >= v_from
    and tr.status is distinct from 'rechazado';

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
    where tr.owner_id = v_uid
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
      where tr.owner_id = v_uid
        and tr.created_at >= v_from
        and tr.status is distinct from 'rechazado'
      group by tr.product_id
    ) x on x.product_id = p.id
    where p.owner_id = v_uid
      and coalesce(p.is_active, true)
    order by coalesce(x.units, 0) asc, p.name asc
    limit 5
  ) s;

  return jsonb_build_object (
    'days', v_days,
    'orders_count', v_orders,
    'units_sold', v_units,
    'revenue_ref', v_revenue,
    'top_products', v_top,
    'low_rotation', v_low
  );
end;
$$;

comment on function public.importador_sales_snapshot (integer) is
  'Snapshot 30d (máx. 90) de pedidos, unidades, REF, top 5 y baja rotación.';

revoke all on function public.importador_sales_snapshot (integer) from public;
grant execute on function public.importador_sales_snapshot (integer) to authenticated;
