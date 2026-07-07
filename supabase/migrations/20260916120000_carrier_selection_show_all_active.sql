-- El aliado debe ver todos los transportistas activos del importador al elegir.
-- La cobertura geográfica es informativa; no debe ocultar opciones ni saltar el paso.

create or replace function public.motoconecta_ensure_carrier_decision_pending (p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.transaction_requests tr
  set
    carrier_decision = 'pending',
    carrier_decision_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.status = 'pedido_listo'
    and tr.carrier_decision = 'not_applicable'
    and tr.pickup_confirmed_at is null
    and public.motoconecta_importador_has_active_carriers (tr.importador_id);
end;
$$;

grant execute on function public.motoconecta_ensure_carrier_decision_pending (uuid) to authenticated;

-- pending si el importador tiene transportistas activos (sin filtrar por cobertura).
create or replace function public.motoconecta_pedido_has_selectable_carriers (p_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transaction_requests tr
    where tr.id = p_request_id
      and public.motoconecta_importador_has_active_carriers (tr.importador_id)
  );
$$;

create or replace function public.tr_transaction_requests_pedido_listo_carrier_decision ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'update'
     and new.status = 'pedido_listo'
     and old.status is distinct from 'pedido_listo' then
    if public.motoconecta_importador_has_active_carriers (new.importador_id) then
      new.carrier_decision := 'pending';
      new.carrier_decision_at := null;
    else
      new.carrier_decision := 'not_applicable';
      new.carrier_decision_at := now();
    end if;
    new.pickup_confirmed_at := null;
    new.pickup_location_mode := null;
    new.pickup_label := null;
    new.pickup_estado := null;
    new.pickup_ciudad := null;
    new.pickup_direccion := null;
    new.pickup_latitude := null;
    new.pickup_longitude := null;
    new.pickup_maps_url := null;
    new.pickup_location_id := null;
    new.pickup_carrier_id := null;
  end if;
  return new;
end;
$$;

-- Reparar pedidos que saltaron la elección del aliado.
update public.transaction_requests tr
set
  carrier_decision = case
    when tr.importer_carrier_id is not null
      and tr.carrier_selected_at is not null
      and tr.carrier_decision = 'selected'
      then 'selected'
    else 'pending'
  end,
  carrier_decision_at = null,
  pickup_confirmed_at = null,
  pickup_location_mode = null,
  pickup_label = null,
  pickup_estado = null,
  pickup_ciudad = null,
  pickup_direccion = null,
  pickup_latitude = null,
  pickup_longitude = null,
  pickup_maps_url = null,
  pickup_location_id = null,
  pickup_carrier_id = null,
  updated_at = now()
where tr.status = 'pedido_listo'
  and tr.carrier_decision = 'not_applicable'
  and tr.pickup_confirmed_at is null
  and public.motoconecta_importador_has_active_carriers (tr.importador_id);

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
  v_status text;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_dest_structured boolean;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden consultar transportistas del pedido.';
  end if;

  select tr.importador_id, tr.status
  into v_importador, v_status
  from public.transaction_requests tr
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

  perform public.motoconecta_ensure_carrier_decision_pending (p_request_id);

  select
    d.dest_estado,
    d.dest_ciudad,
    d.dest_lat,
    d.dest_lng,
    d.dest_structured
  into
    v_dest_estado,
    v_dest_ciudad,
    v_dest_lat,
    v_dest_lng,
    v_dest_structured
  from public.motoconecta_pedido_delivery_destination (p_request_id) as d;

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
      case
        when not coalesce(v_dest_structured, false) then true
        else public.motoconecta_carrier_covers_destination (
          b.coverage_estados,
          b.coverage_ciudades,
          v_dest_estado,
          v_dest_ciudad
        )
      end as covers_destination
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
  order by e.covers_destination desc, e.sort_order, e.company_name;
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
  v_decision text;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_dest_structured boolean;
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

  perform public.motoconecta_ensure_carrier_decision_pending (p_request_id);

  select
    tr.importador_id,
    tr.status,
    tr.carrier_decision,
    d.dest_estado,
    d.dest_ciudad,
    d.dest_lat,
    d.dest_lng,
    d.dest_structured
  into
    v_importador,
    v_status,
    v_decision,
    v_dest_estado,
    v_dest_ciudad,
    v_dest_lat,
    v_dest_lng,
    v_dest_structured
  from public.transaction_requests tr
  cross join lateral public.motoconecta_pedido_delivery_destination (tr.id) as d
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

  if v_decision not in ('pending', 'selected') then
    raise exception 'No puede cambiar el transportista en el estado actual del pedido.';
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

  if p_driver_id is not null and not exists (
    select 1
    from public.importer_carrier_drivers d
    where d.id = p_driver_id
      and d.carrier_id = p_carrier_id
      and d.is_active = true
  ) then
    raise exception 'Conductor no válido para el transportista.';
  end if;

  if coalesce(v_dest_structured, false) then
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
  else
    v_dist := public.motoconecta_haversine_km (
      v_carrier.base_latitude,
      v_carrier.base_longitude,
      v_dest_lat,
      v_dest_lng
    );
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
    carrier_company_name_snapshot = v_carrier.company_name,
    carrier_accepted_pago_metodos_snapshot = v_carrier.accepted_pago_metodos,
    carrier_pago_instrucciones_snapshot = v_carrier.pago_metodo_instrucciones,
    carrier_selected_at = now(),
    carrier_decision = 'selected',
    carrier_decision_at = now(),
    pickup_confirmed_at = null,
    pickup_location_mode = null,
    pickup_label = null,
    pickup_estado = null,
    pickup_ciudad = null,
    pickup_direccion = null,
    pickup_latitude = null,
    pickup_longitude = null,
    pickup_maps_url = null,
    pickup_location_id = null,
    pickup_carrier_id = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = v_uid
    and tr.status = 'pedido_listo';
end;
$$;

grant execute on function public.aliado_select_carrier_for_pedido (uuid, uuid, uuid) to authenticated;

create or replace function public.aliado_skip_carrier_for_pedido (p_request_id uuid)
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
  v_decision text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden registrar esta decisión.';
  end if;

  perform public.motoconecta_ensure_carrier_decision_pending (p_request_id);

  select tr.importador_id, tr.status, tr.carrier_decision
  into v_importador, v_status, v_decision
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.aliado_id = v_uid;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_status is distinct from 'pedido_listo' then
    raise exception 'Solo aplica cuando el pedido está listo para despacho.';
  end if;

  if not public.motoconecta_importador_has_active_carriers (v_importador) then
    raise exception 'Este importador no ofrece transportistas en la plataforma.';
  end if;

  if v_decision is distinct from 'pending' then
    raise exception 'La decisión sobre transportista ya fue registrada.';
  end if;

  update public.transaction_requests tr
  set
    importer_carrier_id = null,
    importer_carrier_driver_id = null,
    carrier_eta_hours_snapshot = null,
    carrier_distance_km_snapshot = null,
    carrier_fee_usd_snapshot = null,
    carrier_flete_pago_modo_snapshot = null,
    carrier_company_name_snapshot = null,
    carrier_accepted_pago_metodos_snapshot = null,
    carrier_pago_instrucciones_snapshot = null,
    carrier_selected_at = null,
    carrier_decision = 'skipped',
    carrier_decision_at = now(),
    pickup_confirmed_at = null,
    pickup_location_mode = null,
    pickup_label = null,
    pickup_estado = null,
    pickup_ciudad = null,
    pickup_direccion = null,
    pickup_latitude = null,
    pickup_longitude = null,
    pickup_maps_url = null,
    pickup_location_id = null,
    pickup_carrier_id = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = v_uid
    and tr.status = 'pedido_listo';
end;
$$;

grant execute on function public.aliado_skip_carrier_for_pedido (uuid) to authenticated;

create or replace function public.tr_importer_carriers_reopen_pedido_decision ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if not coalesce(new.is_active, true) then
      return new;
    end if;
  elsif tg_op = 'UPDATE' then
    if coalesce(new.is_active, true) = coalesce(old.is_active, true)
       and new.importador_id is not distinct from old.importador_id then
      return new;
    end if;
    if not coalesce(new.is_active, true) then
      return new;
    end if;
  end if;

  update public.transaction_requests tr
  set
    carrier_decision = 'pending',
    carrier_decision_at = null,
    pickup_confirmed_at = null,
    pickup_location_mode = null,
    pickup_label = null,
    pickup_estado = null,
    pickup_ciudad = null,
    pickup_direccion = null,
    pickup_latitude = null,
    pickup_longitude = null,
    pickup_maps_url = null,
    pickup_location_id = null,
    pickup_carrier_id = null,
    updated_at = now()
  where tr.importador_id = new.importador_id
    and tr.status = 'pedido_listo'
    and tr.carrier_decision = 'not_applicable'
    and tr.pickup_confirmed_at is null;

  return new;
end;
$$;
