-- Volumen por unidades y descuento de valla son excluyentes sobre el precio base (lista).
-- Si la cantidad activa un tramo → % volumen sobre lista (oferta directa si es menor).
-- Si no → % campaña / oferta directa sobre lista. No se apilan.

comment on column public.promo_campaigns.discount_percent is
  'Descuento % sobre price_usd (base) para product_ids mientras la campaña esté activa. '
  'Excluyente con descuento por volumen: si la cantidad activa un tramo, se ignora la valla. '
  'Null = solo creativo/enlace.';

-- Precio REF aliado: camino volumen O camino promo/oferta sobre lista.
create or replace function public.motoconecta_aliado_ref_unit_usd (
  p_price_usd numeric,
  p_sale_price_usd numeric,
  p_discount_rules jsonb,
  p_cantidad integer,
  p_campaign_discount_percent numeric
)
returns numeric
language sql
stable
as $$
  select round(
    (
      case
        when public.motoconecta_product_volume_discount_pct (
          p_discount_rules,
          p_cantidad
        ) > 0 then
          -- Camino volumen: % sobre lista; oferta directa si es menor. Sin valla.
          coalesce(
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
                  round(
                    (
                      p_price_usd * (
                        1 - public.motoconecta_product_volume_discount_pct (
                          p_discount_rules,
                          p_cantidad
                        ) / 100.0
                      )
                    )::numeric,
                    4
                  )
                ]
              ) as t (x)
              where x is not null
                and x > 0
            ),
            p_price_usd
          )
        else
          -- Camino promo / oferta sobre base (sin volumen).
          public.motoconecta_effective_wholesale_usd (
            p_price_usd,
            p_sale_price_usd,
            p_campaign_discount_percent
          )
      end
    )::numeric,
    4
  );
$$;

comment on function public.motoconecta_aliado_ref_unit_usd (
  numeric, numeric, jsonb, integer, numeric
) is
  'E4+valla: unitario aliado = volumen sobre base O promo/oferta sobre base (excluyentes).';

revoke all on function public.motoconecta_aliado_ref_unit_usd (
  numeric, numeric, jsonb, integer, numeric
) from public;
grant execute on function public.motoconecta_aliado_ref_unit_usd (
  numeric, numeric, jsonb, integer, numeric
) to authenticated;

-- Alinear unit price legacy (sin campaña) con el mismo modelo excluyente.
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
  select public.motoconecta_aliado_ref_unit_usd (
    p_price_usd,
    p_sale_price_usd,
    p_discount_rules,
    p_cantidad,
    null::numeric
  );
$$;

comment on function public.motoconecta_aliado_unit_price_usd (
  numeric, numeric, jsonb, integer, boolean
) is
  'E4: precio unitario aliado = volumen sobre base O oferta sobre base; p_fase_contado ignorado.';

-- Checkout: precio excluyente volumen vs valla; snapshot solo del descuento aplicado.
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
  v_vol_pct numeric;
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

    v_vol_pct := public.motoconecta_product_volume_discount_pct (
      v_discount,
      rec.cantidad
    );

    -- Volumen O promo sobre base (no apilar).
    v_unit := public.motoconecta_aliado_ref_unit_usd (
      v_price,
      v_sale,
      v_discount,
      rec.cantidad,
      case when v_vol_pct > 0 then null else v_promo_pct end
    );
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_discount_snap := public.motoconecta_enrich_discount_rules_snapshot (
      v_discount,
      rec.cantidad
    );
    -- Solo registrar % de valla si se aplicó (camino sin volumen).
    if v_vol_pct <= 0 and v_promo_pct is not null and v_promo_pct > 0 then
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

comment on function public.aliado_checkout_multi_importador_impl (
  jsonb, boolean, text, text, jsonb, jsonb
) is
  'Checkout aliado; precio = volumen o promo sobre base (excluyentes).';
