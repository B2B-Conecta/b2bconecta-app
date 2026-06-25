-- Transportista post-despacho: modo de pago del flete, selección en pedido_listo, facturas.

alter table public.importer_carriers
  add column if not exists flete_pago_modo text not null default 'incluido_factura';

alter table public.importer_carriers
  drop constraint if exists importer_carriers_flete_pago_modo_chk;

alter table public.importer_carriers
  add constraint importer_carriers_flete_pago_modo_chk
  check (flete_pago_modo in ('incluido_factura', 'pago_separado'));

comment on column public.importer_carriers.flete_pago_modo is
  'Si el flete va en la factura del importador o se paga aparte al transportista.';

alter table public.transaction_requests
  add column if not exists carrier_flete_pago_modo_snapshot text,
  add column if not exists carrier_selected_at timestamptz,
  add column if not exists flete_factura_storage_path text,
  add column if not exists flete_factura_file_name text,
  add column if not exists flete_factura_submitted_at timestamptz;

comment on column public.transaction_requests.carrier_flete_pago_modo_snapshot is
  'Snapshot del modo de pago del flete al elegir transportista.';
comment on column public.transaction_requests.flete_factura_storage_path is
  'Factura del flete cuando el pago es separado al transportista.';

create or replace function public.motoconecta_importador_has_active_carriers (p_importador_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.importer_carriers c
    where c.importador_id = p_importador_id
      and c.is_active = true
  );
$$;

grant execute on function public.motoconecta_importador_has_active_carriers (uuid) to authenticated;


-- Checkout sin transportista
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
  v_promo_raw text;
  v_group_id uuid := gen_random_uuid ();
  v_carrier_raw jsonb;
  v_carrier_id uuid;
  v_driver_id uuid;
  v_carrier_rec record;
  v_active_carrier_count integer;
  v_dist numeric;
  v_eta numeric;
  v_fee numeric;
  v_importers uuid[];
  v_imp uuid;
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

  -- Transportista se elige en pedido_listo (no en checkout).

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
      false
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

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) to authenticated;


-- ---------------------------------------------------------------------------
-- Aliado: listar / elegir transportista en pedido_listo
-- ---------------------------------------------------------------------------
create or replace function public.list_importer_carriers_for_pedido (p_request_id uuid)
returns table (
  id uuid,
  importador_id uuid,
  company_name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  coverage_estados text[],
  coverage_ciudades text[],
  coverage_notes text,
  base_estado text,
  base_ciudad text,
  base_latitude numeric,
  base_longitude numeric,
  accepted_pago_metodos text[],
  pago_metodo_instrucciones jsonb,
  flete_pago_modo text,
  eta_base_hours numeric,
  eta_hours_per_km numeric,
  max_coverage_km numeric,
  flat_fee_usd numeric,
  price_per_km_usd numeric,
  notes text,
  distance_km numeric,
  eta_hours numeric,
  fee_usd numeric,
  covers_destination boolean,
  drivers jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_importador uuid;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_status text;
  v_usa_perfil boolean;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden consultar transportistas del pedido.';
  end if;

  select
    tr.importador_id,
    tr.status,
    tr.destino_entrega_usa_perfil,
    case when tr.destino_entrega_usa_perfil then pa.estado else null end,
    case when tr.destino_entrega_usa_perfil then pa.ciudad else null end,
    case when tr.destino_entrega_usa_perfil then pa.latitude else null end,
    case when tr.destino_entrega_usa_perfil then pa.longitude else null end
  into
    v_importador, v_status, v_usa_perfil,
    v_dest_estado, v_dest_ciudad, v_dest_lat, v_dest_lng
  from public.transaction_requests tr
  join public.profiles pa on pa.id = tr.aliado_id
  where tr.id = p_request_id
    and tr.aliado_id = v_uid;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_status is distinct from 'pedido_listo' then
    raise exception 'Solo puede elegir transportista cuando el pedido está listo para despacho.';
  end if;

  if not public.motoconecta_importador_has_active_carriers (v_importador) then
    return;
  end if;

  return query
  with base as (
    select c.*
    from public.importer_carriers c
    where c.importador_id = v_importador
      and c.is_active = true
  ),
  enriched as (
    select
      b.*,
      public.motoconecta_haversine_km (
        b.base_latitude,
        b.base_longitude,
        v_dest_lat,
        v_dest_lng
      ) as distance_km,
      public.motoconecta_carrier_covers_destination (
        b.coverage_estados,
        b.coverage_ciudades,
        v_dest_estado,
        v_dest_ciudad
      ) as covers_destination
    from base b
  )
  select
    e.id,
    e.importador_id,
    e.company_name,
    e.contact_name,
    e.contact_phone,
    e.contact_email,
    e.coverage_estados,
    e.coverage_ciudades,
    e.coverage_notes,
    e.base_estado,
    e.base_ciudad,
    e.base_latitude,
    e.base_longitude,
    e.accepted_pago_metodos,
    e.pago_metodo_instrucciones,
    e.flete_pago_modo,
    e.eta_base_hours,
    e.eta_hours_per_km,
    e.max_coverage_km,
    e.flat_fee_usd,
    e.price_per_km_usd,
    e.notes,
    e.distance_km,
    public.motoconecta_carrier_eta_hours (
      e.eta_base_hours,
      e.eta_hours_per_km,
      e.distance_km
    ) as eta_hours,
    public.motoconecta_carrier_fee_usd (
      e.flat_fee_usd,
      e.price_per_km_usd,
      e.distance_km
    ) as fee_usd,
    e.covers_destination,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', d.id,
            'driver_name', d.driver_name,
            'contact_phone', d.contact_phone,
            'license_id', d.license_id
          )
          order by d.sort_order, d.driver_name
        )
        from public.importer_carrier_drivers d
        where d.carrier_id = e.id
          and d.is_active = true
      ),
      '[]'::jsonb
    ) as drivers
  from enriched e
  where e.covers_destination
    and (
      e.max_coverage_km is null
      or e.distance_km is null
      or e.distance_km <= e.max_coverage_km
    )
  order by e.sort_order, e.company_name;
end;
$$;

grant execute on function public.list_importer_carriers_for_pedido (uuid) to authenticated;

create or replace function public.aliado_select_carrier_for_pedido (
  p_request_id uuid,
  p_carrier_id uuid,
  p_driver_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_importador uuid;
  v_status text;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_carrier record;
  v_dist numeric;
  v_eta numeric;
  v_fee numeric;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden elegir transportista.';
  end if;

  select
    tr.importador_id,
    tr.status,
    case when tr.destino_entrega_usa_perfil then pa.estado else null end,
    case when tr.destino_entrega_usa_perfil then pa.ciudad else null end,
    case when tr.destino_entrega_usa_perfil then pa.latitude else null end,
    case when tr.destino_entrega_usa_perfil then pa.longitude else null end
  into
    v_importador, v_status,
    v_dest_estado, v_dest_ciudad, v_dest_lat, v_dest_lng
  from public.transaction_requests tr
  join public.profiles pa on pa.id = tr.aliado_id
  where tr.id = p_request_id
    and tr.aliado_id = v_uid;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_status is distinct from 'pedido_listo' then
    raise exception 'Solo puede elegir transportista cuando el pedido está listo para despacho.';
  end if;

  if not public.motoconecta_importador_has_active_carriers (v_importador) then
    raise exception 'Este importador no tiene transportistas activos.';
  end if;

  if p_carrier_id is null then
    raise exception 'Seleccione un transportista.';
  end if;

  select * into v_carrier
  from public.importer_carriers c
  where c.id = p_carrier_id
    and c.importador_id = v_importador
    and c.is_active = true;

  if not found then
    raise exception 'Transportista no válido.';
  end if;

  if not public.motoconecta_carrier_covers_destination (
    v_carrier.coverage_estados,
    v_carrier.coverage_ciudades,
    v_dest_estado,
    v_dest_ciudad
  ) then
    raise exception 'El transportista no cubre el destino de entrega.';
  end if;

  v_dist := public.motoconecta_haversine_km (
    v_carrier.base_latitude,
    v_carrier.base_longitude,
    v_dest_lat,
    v_dest_lng
  );

  if v_carrier.max_coverage_km is not null
     and v_dist is not null
     and v_dist > v_carrier.max_coverage_km then
    raise exception 'El transportista no cubre la distancia hasta su destino.';
  end if;

  if p_driver_id is not null and not exists (
    select 1
    from public.importer_carrier_drivers d
    where d.id = p_driver_id
      and d.carrier_id = p_carrier_id
      and d.is_active = true
  ) then
    raise exception 'Conductor no válido para el transportista.';
  end if;

  v_eta := public.motoconecta_carrier_eta_hours (
    v_carrier.eta_base_hours,
    v_carrier.eta_hours_per_km,
    v_dist
  );
  v_fee := public.motoconecta_carrier_fee_usd (
    v_carrier.flat_fee_usd,
    v_carrier.price_per_km_usd,
    v_dist
  );

  update public.transaction_requests tr
  set
    importer_carrier_id = p_carrier_id,
    importer_carrier_driver_id = p_driver_id,
    carrier_eta_hours_snapshot = v_eta,
    carrier_distance_km_snapshot = v_dist,
    carrier_fee_usd_snapshot = v_fee,
    carrier_flete_pago_modo_snapshot = v_carrier.flete_pago_modo,
    carrier_selected_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = v_uid
    and tr.status = 'pedido_listo';
end;
$$;

grant execute on function public.aliado_select_carrier_for_pedido (uuid, uuid, uuid) to authenticated;


create or replace function public.importer_marca_pedido_en_transito (
  p_request_id uuid,
  p_transit_eta_days integer,
  p_transit_eta_hours integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_importador uuid;
  st text;
  inv text;
  flete_inv text;
  v_flete_modo text;
  v_carrier uuid;
  v_days integer;
  v_hours integer;
  v_has_carriers boolean;
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'importador'
  ) then
    raise exception 'Solo importadores pueden marcar en tránsito.';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);

  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'ETA inválido: días 0–365, horas 0–23.';
  end if;

  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día o una hora de tránsito estimado.';
  end if;

  select
    tr.importador_id,
    tr.status,
    tr.proveedor_factura_storage_path,
    tr.flete_factura_storage_path,
    tr.carrier_flete_pago_modo_snapshot,
    tr.importer_carrier_id
  into
    v_importador, st, inv, flete_inv, v_flete_modo, v_carrier
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_importador is distinct from auth.uid () then
    raise exception 'No autorizado para este pedido.';
  end if;

  if st is distinct from 'pedido_listo' then
    raise exception 'Solo pedidos listos para despacho pueden pasar a en tránsito.';
  end if;

  if coalesce(btrim(inv), '') = '' then
    raise exception 'Adjunte la factura del proveedor antes de marcar en tránsito.';
  end if;

  v_has_carriers := public.motoconecta_importador_has_active_carriers (v_importador);

  if v_has_carriers then
    if v_carrier is null then
      raise exception
        'El aliado debe seleccionar un transportista antes de marcar en tránsito.';
    end if;

    if coalesce(v_flete_modo, 'incluido_factura') = 'pago_separado'
       and coalesce(btrim(flete_inv), '') = '' then
      raise exception
        'Adjunte la factura del flete antes de marcar en tránsito (pago separado al transportista).';
    end if;
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    at_en_transito = coalesce(at_en_transito, now()),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.importer_marca_pedido_en_transito (uuid, integer, integer) to authenticated;


create or replace function public.create_importer_carrier (
  p_company_name text,
  p_contact_phone text,
  p_contact_name text default null,
  p_contact_email text default null,
  p_contact_whatsapp text default null,
  p_coverage_estados text[] default '{}'::text[],
  p_coverage_ciudades text[] default '{}'::text[],
  p_coverage_notes text default null,
  p_base_estado text default null,
  p_base_ciudad text default null,
  p_base_latitude numeric default null,
  p_base_longitude numeric default null,
  p_base_maps_url text default null,
  p_accepted_pago_metodos text[] default '{}'::text[],
  p_pago_metodo_instrucciones jsonb default '{}'::jsonb,
  p_flete_pago_modo text default 'incluido_factura',
  p_eta_base_hours numeric default 24,
  p_eta_hours_per_km numeric default 0.15,
  p_max_coverage_km numeric default null,
  p_flat_fee_usd numeric default null,
  p_price_per_km_usd numeric default null,
  p_notes text default null,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_id uuid;
  v_metodos text[];
  v_instr jsonb;
  v_flete text;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);
  v_instr := public.motoconecta_sanitize_carrier_pago_instrucciones (
    p_pago_metodo_instrucciones,
    v_metodos
  );
  v_flete := coalesce(nullif(trim(p_flete_pago_modo), ''), 'incluido_factura');
  if v_flete not in ('incluido_factura', 'pago_separado') then
    raise exception 'Modo de pago del flete no válido.';
  end if;

  insert into public.importer_carriers (
    importador_id,
    company_name,
    contact_name,
    contact_phone,
    contact_email,
    contact_whatsapp,
    coverage_estados,
    coverage_ciudades,
    coverage_notes,
    base_estado,
    base_ciudad,
    base_latitude,
    base_longitude,
    base_maps_url,
    accepted_pago_metodos,
    pago_metodo_instrucciones,
    flete_pago_modo,
    eta_base_hours,
    eta_hours_per_km,
    max_coverage_km,
    flat_fee_usd,
    price_per_km_usd,
    notes,
    sort_order
  )
  values (
    v_uid,
    trim(p_company_name),
    nullif(trim(coalesce(p_contact_name, '')), ''),
    trim(p_contact_phone),
    nullif(trim(coalesce(p_contact_email, '')), ''),
    nullif(trim(coalesce(p_contact_whatsapp, '')), ''),
    coalesce(p_coverage_estados, '{}'::text[]),
    coalesce(p_coverage_ciudades, '{}'::text[]),
    nullif(trim(coalesce(p_coverage_notes, '')), ''),
    nullif(trim(coalesce(p_base_estado, '')), ''),
    nullif(trim(coalesce(p_base_ciudad, '')), ''),
    p_base_latitude,
    p_base_longitude,
    nullif(trim(coalesce(p_base_maps_url, '')), ''),
    v_metodos,
    v_instr,
    v_flete,
    coalesce(p_eta_base_hours, 24),
    coalesce(p_eta_hours_per_km, 0.15),
    p_max_coverage_km,
    p_flat_fee_usd,
    p_price_per_km_usd,
    nullif(trim(coalesce(p_notes, '')), ''),
    coalesce(p_sort_order, 0)
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.create_importer_carrier (
  text, text, text, text, text, text[], text[], text, text, text,
  numeric, numeric, text, text[], jsonb, text, numeric, numeric, numeric, numeric,
  numeric, text, integer
) to authenticated;

create or replace function public.update_importer_carrier (
  p_carrier_id uuid,
  p_company_name text,
  p_contact_phone text,
  p_contact_name text default null,
  p_contact_email text default null,
  p_contact_whatsapp text default null,
  p_coverage_estados text[] default '{}'::text[],
  p_coverage_ciudades text[] default '{}'::text[],
  p_coverage_notes text default null,
  p_base_estado text default null,
  p_base_ciudad text default null,
  p_base_latitude numeric default null,
  p_base_longitude numeric default null,
  p_base_maps_url text default null,
  p_accepted_pago_metodos text[] default '{}'::text[],
  p_pago_metodo_instrucciones jsonb default '{}'::jsonb,
  p_flete_pago_modo text default 'incluido_factura',
  p_eta_base_hours numeric default 24,
  p_eta_hours_per_km numeric default 0.15,
  p_max_coverage_km numeric default null,
  p_flat_fee_usd numeric default null,
  p_price_per_km_usd numeric default null,
  p_notes text default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_metodos text[];
  v_instr jsonb;
  v_flete text;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);
  v_instr := public.motoconecta_sanitize_carrier_pago_instrucciones (
    p_pago_metodo_instrucciones,
    v_metodos
  );
  v_flete := coalesce(nullif(trim(p_flete_pago_modo), ''), 'incluido_factura');
  if v_flete not in ('incluido_factura', 'pago_separado') then
    raise exception 'Modo de pago del flete no válido.';
  end if;

  update public.importer_carriers c
  set
    company_name = trim(p_company_name),
    contact_name = nullif(trim(coalesce(p_contact_name, '')), ''),
    contact_phone = trim(p_contact_phone),
    contact_email = nullif(trim(coalesce(p_contact_email, '')), ''),
    contact_whatsapp = nullif(trim(coalesce(p_contact_whatsapp, '')), ''),
    coverage_estados = coalesce(p_coverage_estados, '{}'::text[]),
    coverage_ciudades = coalesce(p_coverage_ciudades, '{}'::text[]),
    coverage_notes = nullif(trim(coalesce(p_coverage_notes, '')), ''),
    base_estado = nullif(trim(coalesce(p_base_estado, '')), ''),
    base_ciudad = nullif(trim(coalesce(p_base_ciudad, '')), ''),
    base_latitude = p_base_latitude,
    base_longitude = p_base_longitude,
    base_maps_url = nullif(trim(coalesce(p_base_maps_url, '')), ''),
    accepted_pago_metodos = v_metodos,
    pago_metodo_instrucciones = v_instr,
    flete_pago_modo = v_flete,
    eta_base_hours = coalesce(p_eta_base_hours, 24),
    eta_hours_per_km = coalesce(p_eta_hours_per_km, 0.15),
    max_coverage_km = p_max_coverage_km,
    flat_fee_usd = p_flat_fee_usd,
    price_per_km_usd = p_price_per_km_usd,
    notes = nullif(trim(coalesce(p_notes, '')), ''),
    is_active = coalesce(p_is_active, true),
    sort_order = coalesce(p_sort_order, 0)
  where c.id = p_carrier_id
    and c.importador_id = v_uid;

  if not found then
    raise exception 'Transportista no encontrado o sin permiso.';
  end if;
end;
$$;

grant execute on function public.update_importer_carrier (
  uuid, text, text, text, text, text, text[], text[], text, text, text,
  numeric, numeric, text, text[], jsonb, text, numeric, numeric, numeric, numeric,
  numeric, text, boolean, integer
) to authenticated;


create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_carriers boolean;
begin
  if tg_op <> 'update' then
    return new;
  end if;
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  )
  then
    v_has_carriers := public.motoconecta_importador_has_active_carriers (new.importador_id);

    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      case new.status
        when 'en_preparacion' then 'Pedido en preparación'
        when 'pedido_listo' then 'Listo para despacho'
        when 'en_transito' then 'Pedido en tránsito'
        else 'Actualización de pedido'
      end,
      case new.status
        when 'en_preparacion' then
          'El importador confirmó la solicitud y está preparando tu pedido.'
        when 'pedido_listo' then
          case
            when v_has_carriers then
              'El importador marcó el pedido como listo. Elija un transportista en la ficha del pedido.'
            else
              'El importador marcó el pedido como listo para despacho.'
          end
        when 'en_transito' then
          'El pedido fue despachado y va en camino a tu taller.'
        else
          'Hay un cambio de estado en tu pedido.'
      end,
      'pedido',
      new.id::text
    );
  elsif new.status = 'entregado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido recibido',
      'El aliado confirmó la recepción del pedido en su taller.',
      'pedido',
      new.id::text
    );
  elsif new.status = 'rechazado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Pedido rechazado',
      'Un pedido pasó a rechazado. Revíselo en Pedidos.',
      'pedido',
      new.id::text
    );
  end if;

  return new;
end;
$$;

