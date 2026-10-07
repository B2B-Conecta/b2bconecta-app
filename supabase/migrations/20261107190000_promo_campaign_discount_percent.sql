-- Descuento % de valla publicitaria sobre productos asociados (vigencia de la campaña).
-- No muta products.sale_price_usd: se calcula en catálogo (cliente) y checkout (servidor).

alter table public.promo_campaigns
  add column if not exists discount_percent numeric(5, 2);

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_discount_percent_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_discount_percent_chk
    check (
      discount_percent is null
      or (discount_percent > 0 and discount_percent < 100)
    );

comment on column public.promo_campaigns.discount_percent is
  'Descuento % sobre price_usd para product_ids mientras la campaña esté activa. Null = solo creativo/enlace.';

-- Precio mayorista efectivo: min(oferta directa, precio con % campaña) o lista.
create or replace function public.motoconecta_effective_wholesale_usd (
  p_price_usd numeric,
  p_sale_price_usd numeric,
  p_campaign_discount_percent numeric
)
returns numeric
language sql
immutable
as $$
  select coalesce(
    (
      select min(x)
      from unnest(
        array[
          case
            when p_sale_price_usd is not null
                 and p_sale_price_usd > 0
                 and p_sale_price_usd < p_price_usd
              then p_sale_price_usd
            else null
          end,
          case
            when p_campaign_discount_percent is not null
                 and p_campaign_discount_percent > 0
                 and p_campaign_discount_percent < 100
              then round(
                (p_price_usd * (1 - p_campaign_discount_percent / 100.0))::numeric,
                4
              )
            else null
          end
        ]
      ) as t (x)
      where x is not null
    ),
    p_price_usd
  );
$$;

-- Resuelve campaña activa con descuento para un SKU (preferida o mejor prioridad).
create or replace function public.promo_resolve_discount_for_product (
  p_product_id uuid,
  p_importador_id uuid,
  p_preferred_campaign_id uuid default null
)
returns table (
  campaign_id uuid,
  discount_percent numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_preferred_campaign_id is not null then
    return query
    select c.id, c.discount_percent
    from public.promo_campaigns c
    where c.id = p_preferred_campaign_id
      and c.importador_id = p_importador_id
      and c.is_active = true
      and c.starts_at <= now()
      and c.ends_at >= now()
      and c.sponsor_type = 'importador'
      and c.discount_percent is not null
      and c.discount_percent > 0
      and p_product_id = any (coalesce(c.product_ids, '{}'::uuid[]))
    limit 1;

    if found then
      return;
    end if;
  end if;

  return query
  select c.id, c.discount_percent
  from public.promo_campaigns c
  where c.importador_id = p_importador_id
    and c.is_active = true
    and c.starts_at <= now()
    and c.ends_at >= now()
    and c.sponsor_type = 'importador'
    and c.discount_percent is not null
    and c.discount_percent > 0
    and p_product_id = any (coalesce(c.product_ids, '{}'::uuid[]))
  order by c.priority desc, c.discount_percent desc, c.created_at desc
  limit 1;
end;
$$;

grant execute on function public.promo_resolve_discount_for_product (uuid, uuid, uuid)
  to authenticated;

-- Mapa producto → descuento activo (catálogo aliado).
create or replace function public.get_active_promo_product_discounts ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(
      p.product_id::text,
      jsonb_build_object(
        'campaign_id', p.campaign_id,
        'discount_percent', p.discount_percent,
        'display_title', p.display_title
      )
    ),
    '{}'::jsonb
  )
  from (
    select distinct on (pid)
      pid as product_id,
      c.id as campaign_id,
      c.discount_percent,
      c.display_title
    from public.promo_campaigns c
    cross join lateral unnest(coalesce(c.product_ids, '{}'::uuid[])) as pid
    where c.is_active = true
      and c.starts_at <= now()
      and c.ends_at >= now()
      and c.sponsor_type = 'importador'
      and c.audience in ('aliado', 'ambos')
      and c.discount_percent is not null
      and c.discount_percent > 0
    order by pid, c.priority desc, c.discount_percent desc, c.created_at desc
  ) p;
$$;

grant execute on function public.get_active_promo_product_discounts () to authenticated;

create or replace function public.get_active_promo_campaigns_for_aliado()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'display_title', c.display_title,
        'campaign_type', c.campaign_type,
        'image_public_url', c.image_public_url,
        'importador_id', c.importador_id,
        'product_id', c.product_id,
        'product_ids', to_jsonb(coalesce(c.product_ids, '{}'::uuid[])),
        'discount_percent', c.discount_percent,
        'action_type', c.action_type,
        'priority', c.priority,
        'sponsor_type', c.sponsor_type,
        'audience', c.audience,
        'advertiser_name', c.advertiser_name,
        'external_url', c.external_url
      )
      order by c.priority desc, c.created_at desc
    ),
    '[]'::jsonb
  )
  from public.promo_campaigns c
  where c.is_active = true
    and c.starts_at <= now()
    and c.ends_at >= now()
    and btrim(c.image_public_url) <> ''
    and c.audience in ('aliado', 'ambos');
$$;

-- Checkout: aplicar descuento de valla al precio unitario y atribuir campaña.
create or replace function public.aliado_checkout_multi_importador_impl (
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
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_rif text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_fiscal_maps text;
  v_lat numeric;
  v_lng numeric;
  v_kyc text;
  v_psm boolean;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_sale numeric;
  v_eff_sale numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_discount_snap jsonb;
  v_comm_rate numeric;
  v_promo_id uuid;
  v_promo_pct numeric;
  v_promo_raw text;
  v_preferred uuid;
  v_group_id uuid := gen_random_uuid ();
  v_carrier_raw jsonb;
  v_carrier_id uuid;
  v_driver_id uuid;
  v_carrier_rec record;
  v_dist numeric;
  v_eta numeric;
  v_fee numeric;
  v_importers uuid[];
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
    p.latitude,
    p.longitude,
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_lat, v_lng, v_kyc, v_psm
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
    v_dest_estado := v_estado;
    v_dest_ciudad := v_ciudad;
    v_dest_lat := v_lat;
    v_dest_lng := v_lng;
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
    v_dest_estado := null;
    v_dest_ciudad := null;
    v_dest_lat := null;
    v_dest_lng := null;
  end if;

  select array_agg(distinct pr.owner_id)
    into v_importers
  from jsonb_array_elements (p_lines) as t (elem)
  join public.products pr on pr.id = (elem ->> 'product_id')::uuid;

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

    v_preferred := null;
    if p_promo_by_importador is not null
       and jsonb_typeof (p_promo_by_importador) = 'object' then
      v_promo_raw := p_promo_by_importador ->> v_owner::text;
      if v_promo_raw is not null and btrim(v_promo_raw) <> '' then
        v_preferred := v_promo_raw::uuid;
      end if;
    end if;

    select r.campaign_id, r.discount_percent
      into v_promo_id, v_promo_pct
    from public.promo_resolve_discount_for_product (
      rec.product_id,
      v_owner,
      v_preferred
    ) r
    limit 1;

    -- Si hay atribución válida sin descuento (solo creativo), conservar id.
    if v_promo_id is null and v_preferred is not null then
      select c.id
        into v_promo_id
      from public.promo_campaigns c
      where c.id = v_preferred
        and c.importador_id = v_owner
        and c.is_active = true
        and c.starts_at <= now()
        and c.ends_at >= now();
    end if;

    v_eff_sale := public.motoconecta_effective_wholesale_usd (
      v_price,
      v_sale,
      v_promo_pct
    );
    -- Pasar como "sale" el mayorista efectivo (lista si no hay oferta/campaña).
    if v_eff_sale is not distinct from v_price then
      v_eff_sale := null;
    end if;

    v_unit := public.motoconecta_aliado_unit_price_usd (
      v_price,
      v_eff_sale,
      v_discount,
      rec.cantidad,
      false
    );
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_discount_snap := public.motoconecta_enrich_discount_rules_snapshot (
      v_discount,
      rec.cantidad
    );
    if v_promo_pct is not null and v_promo_pct > 0 then
      v_discount_snap := coalesce(v_discount_snap, '{}'::jsonb)
        || jsonb_build_object(
          'promo_campaign_discount_percent',
          round(v_promo_pct::numeric, 2)
        );
    end if;
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    v_carrier_id := null;
    v_driver_id := null;
    v_dist := null;
    v_eta := null;
    v_fee := null;

    if p_carriers_by_importador is not null
       and jsonb_typeof (p_carriers_by_importador) = 'object' then
      v_carrier_raw := p_carriers_by_importador -> v_owner::text;
      if v_carrier_raw is not null and jsonb_typeof (v_carrier_raw) = 'object' then
        v_carrier_id := nullif(v_carrier_raw ->> 'carrier_id', '')::uuid;
        v_driver_id := nullif(v_carrier_raw ->> 'driver_id', '')::uuid;

        if v_carrier_id is not null then
          select *
            into v_carrier_rec
          from public.importer_carriers c
          where c.id = v_carrier_id
            and c.importador_id = v_owner
            and c.is_active = true;

          if found then
            v_dist := public.motoconecta_haversine_km (
              v_carrier_rec.base_latitude,
              v_carrier_rec.base_longitude,
              v_dest_lat,
              v_dest_lng
            );
            v_eta := public.motoconecta_carrier_eta_hours (
              v_carrier_rec.eta_base_hours,
              v_carrier_rec.eta_hours_per_km,
              v_dist
            );
            v_fee := public.motoconecta_carrier_fee_usd (
              v_carrier_rec.flat_fee_usd,
              v_carrier_rec.price_per_km_usd,
              v_dist
            );
          end if;
        end if;
      end if;
    end if;

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      precio_base_aliado_total,
      precio_unitario_proveedor,
      precio_unitario_aliado,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot,
      promo_campaign_id,
      importer_carrier_id,
      importer_carrier_driver_id,
      carrier_eta_hours_snapshot,
      carrier_distance_km_snapshot,
      carrier_fee_usd_snapshot
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      v_line_total,
      round(v_price::numeric, 6),
      round(v_unit::numeric, 6),
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount_snap,
      v_comm_rate,
      v_promo_id,
      v_carrier_id,
      v_driver_id,
      v_eta,
      v_dist,
      v_fee
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;
