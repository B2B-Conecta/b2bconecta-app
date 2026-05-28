-- E4: precio oferta (columna) + tramos por unidades (discount_rules) + cascada en checkout.
-- Cascada: sale_price_usd ?? price_usd → % volumen (unidades SKU) → +10% MotoLink → -5% contado.
-- promo_campaigns: solo visibilidad; no altera precios.

alter table public.products
  add column if not exists sale_price_usd numeric(12, 4);

alter table public.products
  drop constraint if exists products_sale_price_usd_chk;

alter table public.products
  add constraint products_sale_price_usd_chk check (
    sale_price_usd is null
    or (
      sale_price_usd > 0
      and sale_price_usd < price_usd
    )
  );

comment on column public.products.sale_price_usd is
  'E4: precio mayorista promocional USD; null = sin oferta directa.';

create index if not exists products_sale_price_usd_idx
  on public.products (owner_id, sale_price_usd)
  where sale_price_usd is not null;

-- ---------------------------------------------------------------------------
-- Helpers de pricing
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_product_volume_discount_pct (
  p_discount_rules jsonb,
  p_cantidad integer
)
returns numeric
language sql
stable
as $$
  with tiers as (
    select
      (elem ->> 'min_units')::integer as min_u,
      (elem ->> 'percent_discount')::numeric as pct
    from jsonb_array_elements(
      coalesce(p_discount_rules -> 'volume_tiers', '[]'::jsonb)
    ) as elem
  ),
  picked as (
    select t.pct
    from tiers t
    where t.min_u is not null
      and t.min_u > 0
      and t.pct is not null
      and t.pct > 0
      and t.pct <= 100
      and coalesce(p_cantidad, 0) >= t.min_u
    order by t.min_u desc
    limit 1
  )
  select coalesce((select pct from picked), 0::numeric);
$$;

revoke all on function public.motoconecta_product_volume_discount_pct (jsonb, integer) from public;
grant execute on function public.motoconecta_product_volume_discount_pct (jsonb, integer) to authenticated;

create or replace function public.motoconecta_aliado_unit_price_usd (
  p_price_usd numeric,
  p_sale_price_usd numeric,
  p_discount_rules jsonb,
  p_cantidad integer,
  p_fase_contado boolean
)
returns numeric
language sql
stable
as $$
  select round(
    (
      coalesce(nullif(p_sale_price_usd, 0::numeric), p_price_usd)
      * (1 - public.motoconecta_product_volume_discount_pct (p_discount_rules, p_cantidad) / 100.0)
      * 1.10
      * (
        case
          when coalesce(p_fase_contado, false) then 0.95
          else 1.0
        end
      )
    )::numeric,
    4
  );
$$;

revoke all on function public.motoconecta_aliado_unit_price_usd (numeric, numeric, jsonb, integer, boolean) from public;
grant execute on function public.motoconecta_aliado_unit_price_usd (numeric, numeric, jsonb, integer, boolean) to authenticated;

create or replace function public.motoconecta_enrich_discount_rules_snapshot (
  p_discount_rules jsonb,
  p_cantidad integer
)
returns jsonb
language sql
stable
as $$
  with pct as (
    select public.motoconecta_product_volume_discount_pct (p_discount_rules, p_cantidad) as v
  ),
  tier as (
    select (elem ->> 'min_units')::integer as min_u
    from jsonb_array_elements(
      coalesce(p_discount_rules -> 'volume_tiers', '[]'::jsonb)
    ) as elem
    cross join pct
    where pct.v > 0
      and (elem ->> 'min_units') is not null
      and coalesce(p_cantidad, 0) >= ((elem ->> 'min_units')::integer)
    order by ((elem ->> 'min_units')::integer) desc
    limit 1
  )
  select coalesce(p_discount_rules, '{}'::jsonb)
    || case
      when (select v from pct) > 0 then
        jsonb_build_object(
          'applied_volume_discount_pct',
          (select v from pct),
          'applied_volume_min_units',
          (select min_u from tier)
        )
      else '{}'::jsonb
    end;
$$;

-- ---------------------------------------------------------------------------
-- Checkout (promo no altera precio)
-- ---------------------------------------------------------------------------
create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_rif text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_fiscal_maps text;
  v_pce integer;
  v_kyc text;
  v_psm boolean;
  v_fase_contado boolean;
  v_open_slots bigint;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_sale numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_discount_snap jsonb;
  v_comm_rate numeric;
  v_promo_id uuid;
  v_promo_raw text;
  c_entregas_req constant int := 3;
  v_group_id uuid := gen_random_uuid ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if p_lines is null or jsonb_typeof (p_lines) <> 'array' or jsonb_array_length (p_lines) = 0 then
    raise exception 'El carrito está vacío';
  end if;

  select
    p.role,
    nullif(trim(p.rif), ''),
    nullif(trim(p.estado), ''),
    nullif(trim(p.ciudad), ''),
    nullif(trim(p.direccion), ''),
    nullif(trim(p.fiscal_maps_url), ''),
    coalesce(p.primeros_pedidos_contado_entregados, 0),
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_pce, v_kyc, v_psm
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;
  if v_role <> 'aliado' then
    raise exception 'Solo los aliados pueden confirmar el carrito';
  end if;
  if v_psm then
    raise exception
      'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad.';
  end if;
  if v_kyc is not null and v_kyc = 'rechazado' then
    raise exception
      'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
  end if;
  if v_rif is null then
    raise exception 'Registre su RIF comercial en Mi perfil para solicitar pedidos.';
  end if;
  if v_estado is null or v_ciudad is null or v_direccion is null then
    raise exception
      'Registre estado, ciudad y dirección fiscal en Mi perfil para poder solicitar pedidos.';
  end if;

  if p_destino_entrega_usa_perfil then
    if v_fiscal_maps is null then
      raise exception
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal.';
    end if;
  else
    if p_destino_entrega_texto is null
       or length(trim(p_destino_entrega_texto)) = 0 then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
    end if;
    if p_destino_entrega_maps_url is null
       or p_destino_entrega_maps_url !~* '^https?://' then
      raise exception
        'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.';
    end if;
  end if;

  v_fase_contado := v_pce < c_entregas_req;

  select count(*)::bigint
    into v_open_slots
  from (
    select distinct coalesce(tr.checkout_group_id, tr.id) as slot_key
    from public.transaction_requests tr
    where tr.aliado_id = v_uid
      and tr.status <> all (array['entregado'::text, 'rechazado'::text])
  ) s;

  if v_fase_contado and v_open_slots >= 1 then
    raise exception
      'En los primeros %s pedidos en contado solo puede tener un pedido activo a la vez.',
      c_entregas_req;
  end if;

  for rec in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    if rec.cantidad is null or rec.cantidad < 1 then
      raise exception 'Cantidad inválida en el carrito';
    end if;

    select
      pr.owner_id,
      pr.price_usd,
      pr.sale_price_usd,
      pr.stock,
      pr.is_active
    into v_owner, v_price, v_sale, v_stock, v_active
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;
    if not v_active then
      raise exception
        'El producto % no está disponible en el catálogo.',
        rec.product_id;
    end if;
    if v_stock < rec.cantidad then
      raise exception
        'Stock insuficiente: hay %s unidad(es) disponible(s) para una línea del carrito.',
        v_stock;
    end if;
  end loop;

  for rec in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    select
      pr.owner_id,
      pr.price_usd,
      pr.sale_price_usd,
      pr.stock,
      pr.discount_rules
    into v_owner, v_price, v_sale, v_stock, v_discount
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;

    v_unit := public.motoconecta_aliado_unit_price_usd (
      v_price,
      v_sale,
      v_discount,
      rec.cantidad,
      v_fase_contado
    );
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_discount_snap := public.motoconecta_enrich_discount_rules_snapshot (
      v_discount,
      rec.cantidad
    );
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    v_promo_id := null;
    if p_promo_by_importador is not null
       and jsonb_typeof (p_promo_by_importador) = 'object' then
      v_promo_raw := p_promo_by_importador ->> v_owner::text;
      if v_promo_raw is not null and btrim(v_promo_raw) <> '' then
        select c.id
          into v_promo_id
        from public.promo_campaigns c
        where c.id = v_promo_raw::uuid
          and c.importador_id = v_owner
          and c.is_active = true
          and c.starts_at <= now()
          and c.ends_at >= now();
      end if;
    end if;

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot,
      promo_campaign_id
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount_snap,
      v_comm_rate,
      v_promo_id
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb
) to authenticated;
