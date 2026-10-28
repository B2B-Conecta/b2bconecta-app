-- REF is the BCV reference; a direct USD offer must never lower it.
-- Volume and billboard promotions remain mutually exclusive general discounts.
create or replace function public.mc_checkout_ref_unit_v1(
  p_price numeric, p_rules jsonb, p_quantity integer, p_campaign numeric default null)
returns numeric language sql stable set search_path=public as $$
  select round(p_price*(1-case
    when public.motoconecta_product_volume_discount_pct(p_rules,p_quantity)>0
      then public.motoconecta_product_volume_discount_pct(p_rules,p_quantity)/100
    when p_campaign>0 and p_campaign<100 then p_campaign/100
    else 0 end),4);
$$;

-- Currency incentives are alternative offers, never cumulative USD discounts.
create or replace function public.mc_checkout_usd_unit_v1(
  p_ref numeric, p_sale numeric, p_rules jsonb, p_owner_only boolean default false)
returns numeric language plpgsql immutable set search_path=public as $$
declare
  v_pct numeric;
  v_raw text := coalesce(p_rules->>'usd_payment_discount_pct',p_rules->>'applied_usd_payment_discount_pct');
  v_result numeric := p_ref;
begin
  if p_sale>0 and p_sale<v_result then v_result:=p_sale; end if;
  if not coalesce(p_owner_only,false) and v_raw ~ '^[0-9]+([.][0-9]+)?$' then
    v_pct:=v_raw::numeric;
    if v_pct>0 and v_pct<100 then
      v_result:=least(v_result,p_ref*(1-v_pct/100));
    end if;
  end if;
  return round(v_result,4);
end;
$$;

CREATE OR REPLACE FUNCTION public.aliado_checkout_multi_importador_moneda(p_lines jsonb, p_destino_entrega_usa_perfil boolean, p_destino_entrega_texto text DEFAULT NULL::text, p_destino_entrega_maps_url text DEFAULT NULL::text, p_promo_by_importador jsonb DEFAULT '{}'::jsonb, p_carriers_by_importador jsonb DEFAULT '{}'::jsonb, p_apply_credit_by_importador jsonb DEFAULT '{}'::jsonb, p_moneda text DEFAULT 'BOLIVARES'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_moneda text := upper(trim(coalesce(p_moneda, '')));
  v_tasa numeric;
  v_unit_ref numeric;
  v_unit_usd numeric;
  v_owner_only boolean;
  v_min_record record;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if v_moneda not in ('DIVISAS', 'BOLIVARES') then
    raise exception 'Moneda de pago inválida.';
  end if;
  select value_numeric into v_tasa from public.app_global_config where key='tasa_bcv';
  if v_moneda='BOLIVARES' and coalesce(v_tasa,0)<=0 then
    raise exception 'No hay tasa BCV vigente para pago en bolívares.';
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
    v_unit_ref := public.mc_checkout_ref_unit_v1(
      v_price, v_discount, rec.cantidad,
      case when v_vol_pct > 0 then null else v_promo_pct end);
    select coalesce(pago_solo_divisas,false) into v_owner_only
      from public.profiles where id=v_owner;
    if v_moneda='BOLIVARES' and coalesce(v_owner_only,false) then
      raise exception 'Este proveedor solo acepta pagos en divisas.';
    end if;
    v_unit_usd := public.mc_checkout_usd_unit_v1(
      v_unit_ref, v_sale, v_discount, coalesce(v_owner_only,false));
    v_unit := case when v_moneda='DIVISAS' then v_unit_usd else v_unit_ref end;
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
    v_discount_snap := (coalesce(v_discount_snap,'{}'::jsonb)
        - 'usd_payment_discount_pct' - 'applied_usd_payment_discount_pct')
      || jsonb_build_object(
        'checkout_pricing_version',1,
        'checkout_payment_currency',v_moneda,
        'checkout_ref_unit',v_unit_ref,
        'checkout_usd_unit',v_unit_usd);
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
      carrier_fee_usd_snapshot,
      metodo_pago_moneda,
      tasa_bcv_aplicada,
      total_ref,
      total_bs
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
      v_fee,
      v_moneda,
      case when v_tasa>0 then v_tasa else null end,
      round(v_unit_ref*rec.cantidad,2),
      case when v_tasa>0 then round(v_unit_ref*rec.cantidad*v_tasa,2) else null end
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  -- Enforce supplier minimums on REF, independently of the USD incentive.
  for v_min_record in
    select tr.importador_id as id, max(coalesce(p.min_order_amount_ref,0)) as minimum,
      sum((tr.discount_rules->>'checkout_ref_unit')::numeric*tr.cantidad) as subtotal,
      max(p.business_name) as name
    from public.transaction_requests tr join public.profiles p on p.id=tr.importador_id
    where tr.checkout_group_id=v_group_id and tr.aliado_id=v_uid
    group by tr.importador_id
  loop
    if v_min_record.subtotal < v_min_record.minimum then
      raise exception 'min_order_amount:%:%:%:%', v_min_record.id,
        v_min_record.minimum,v_min_record.subtotal,v_min_record.name;
    end if;
  end loop;
  perform public.mc_apply_checkout_importer_credits(
    v_group_id, coalesce(p_apply_credit_by_importador,'{}'::jsonb));
  update public.transaction_requests tr set
    total_ref=round(greatest((tr.discount_rules->>'checkout_ref_unit')::numeric*tr.cantidad-coalesce(tr.credito_aplicado_monto,0),0),2),
    total_bs=case when v_tasa>0 then round(greatest((tr.discount_rules->>'checkout_ref_unit')::numeric*tr.cantidad-coalesce(tr.credito_aplicado_monto,0),0)*v_tasa,2) else null end
  where tr.checkout_group_id=v_group_id and tr.aliado_id=v_uid;
  return v_group_id::text;
end;
$function$
;

revoke all on function public.mc_checkout_ref_unit_v1(numeric,jsonb,integer,numeric) from public,anon;
revoke all on function public.mc_checkout_usd_unit_v1(numeric,numeric,jsonb,boolean) from public,anon;
revoke all on function public.aliado_checkout_multi_importador_moneda(jsonb,boolean,text,text,jsonb,jsonb,jsonb,text) from public,anon;
grant execute on function public.mc_checkout_ref_unit_v1(numeric,jsonb,integer,numeric) to authenticated;
grant execute on function public.mc_checkout_usd_unit_v1(numeric,numeric,jsonb,boolean) to authenticated;
grant execute on function public.aliado_checkout_multi_importador_moneda(jsonb,boolean,text,text,jsonb,jsonb,jsonb,text) to authenticated;
notify pgrst, 'reload schema';

-- New checkouts are already priced for their currency: never discount twice.
-- Historical orders retain their former payment-method calculation.
create or replace function public.motoconecta_order_total_for_pago_metodo(
  p_base_total numeric,p_discount_rules jsonb,p_metodo text)
returns numeric language plpgsql immutable set search_path=public as $$
begin
  if p_discount_rules->>'checkout_pricing_version'='1' then
    if (p_discount_rules->>'checkout_payment_currency'='DIVISAS'
        and not (trim(coalesce(p_metodo,''))=any(public.motoconecta_usd_discount_metodos())))
      or (p_discount_rules->>'checkout_payment_currency'='BOLIVARES'
        and not (trim(coalesce(p_metodo,''))=any(public.motoconecta_pago_metodos_bolivares()))) then
      raise exception 'El método de pago no corresponde a la moneda elegida en el pedido.';
    end if;
    return round(coalesce(p_base_total,0),4);
  end if;
  return round(coalesce(p_base_total,0)*(1-case
    when trim(coalesce(p_metodo,''))=any(public.motoconecta_usd_discount_metodos())
      and public.motoconecta_usd_discount_pct(p_discount_rules)>0
    then public.motoconecta_usd_discount_pct(p_discount_rules)/100 else 0::numeric end),4);
end;
$$;

CREATE OR REPLACE FUNCTION public.aliado_freeze_checkout_moneda(p_checkout_group_id uuid, p_moneda text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_moneda text := upper(trim(coalesce(p_moneda, '')));
  v_tasa numeric;
  v_updated int;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;
  if v_moneda not in ('DIVISAS', 'BOLIVARES') then
    raise exception 'Moneda de pago inválida.';
  end if;

  if exists (select 1 from public.transaction_requests tr
    where tr.checkout_group_id=p_checkout_group_id and tr.aliado_id=v_uid
      and tr.discount_rules->>'checkout_pricing_version'='1') then
    if exists (select 1 from public.transaction_requests tr
      where tr.checkout_group_id=p_checkout_group_id and tr.aliado_id=v_uid
        and tr.metodo_pago_moneda is distinct from v_moneda) then
      raise exception 'La moneda ya quedó fijada al crear el pedido.';
    end if;
    return;
  end if;

  select c.value_numeric
    into v_tasa
  from public.app_global_config c
  where c.key = 'tasa_bcv';

  if v_moneda = 'BOLIVARES' and coalesce(v_tasa, 0) <= 0 then
    raise exception 'No hay tasa BCV vigente para pago en bolívares.';
  end if;

  update public.transaction_requests tr
  set
    metodo_pago_moneda = v_moneda,
    tasa_bcv_aplicada = case
      when coalesce(v_tasa, 0) > 0 then v_tasa
      else null
    end,
    total_ref = round(tr.precio_total_usd, 2),
    total_bs = case
      when coalesce(v_tasa, 0) <= 0 then null
      else round(tr.precio_total_usd * v_tasa, 2)
    end
  where tr.checkout_group_id = p_checkout_group_id
    and tr.aliado_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'No se encontró el pedido para congelar la moneda.';
  end if;
end;
$function$
;
