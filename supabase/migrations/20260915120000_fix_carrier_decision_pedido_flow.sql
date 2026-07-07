-- Alinea carrier_decision con transportistas realmente elegibles para el pedido.

create or replace function public.motoconecta_pedido_delivery_destination (
  p_request_id uuid,
  out dest_estado text,
  out dest_ciudad text,
  out dest_lat numeric,
  out dest_lng numeric,
  out dest_structured boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_usa_perfil boolean;
  v_aliado uuid;
begin
  select tr.destino_entrega_usa_perfil, tr.aliado_id
  into v_usa_perfil, v_aliado
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_aliado is null then
    dest_estado := null;
    dest_ciudad := null;
    dest_lat := null;
    dest_lng := null;
    dest_structured := false;
    return;
  end if;

  if coalesce(v_usa_perfil, true) then
    select pa.estado, pa.ciudad, pa.latitude, pa.longitude
    into dest_estado, dest_ciudad, dest_lat, dest_lng
    from public.profiles pa
    where pa.id = v_aliado;

    dest_structured :=
      coalesce(nullif(trim(dest_estado), ''), nullif(trim(dest_ciudad), '')) is not null;
  else
    dest_estado := null;
    dest_ciudad := null;
    dest_lat := null;
    dest_lng := null;
    dest_structured := false;
  end if;
end;
$$;

grant execute on function public.motoconecta_pedido_delivery_destination (uuid) to authenticated;

create or replace function public.motoconecta_pedido_has_selectable_carriers (p_request_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_importador uuid;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_dest_structured boolean;
begin
  select tr.importador_id
  into v_importador
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_importador is null then
    return false;
  end if;

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

  return exists (
    select 1
    from public.importer_carriers c
    where c.importador_id = v_importador
      and c.is_active = true
      and (
        not coalesce(v_dest_structured, false)
        or public.motoconecta_carrier_covers_destination (
          c.coverage_estados,
          c.coverage_ciudades,
          v_dest_estado,
          v_dest_ciudad
        )
      )
      and (
        v_dest_lat is null
        or v_dest_lng is null
        or c.max_coverage_km is null
        or public.motoconecta_haversine_km (
          c.base_latitude,
          c.base_longitude,
          v_dest_lat,
          v_dest_lng
        ) <= c.max_coverage_km
      )
  );
end;
$$;

grant execute on function public.motoconecta_pedido_has_selectable_carriers (uuid) to authenticated;

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
    if public.motoconecta_pedido_has_selectable_carriers (new.id) then
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

update public.transaction_requests tr
set
  carrier_decision = case
    when public.motoconecta_pedido_has_selectable_carriers (tr.id) then
      case
        when tr.importer_carrier_id is not null
          and tr.carrier_selected_at is not null
          and tr.carrier_decision = 'selected'
          then 'selected'
        else 'pending'
      end
    else 'not_applicable'
  end,
  carrier_decision_at = case
    when public.motoconecta_pedido_has_selectable_carriers (tr.id) then null
    else coalesce(tr.carrier_decision_at, now())
  end
where tr.status = 'pedido_listo'
  and tr.carrier_decision in ('not_applicable', 'pending')
  and tr.pickup_confirmed_at is null;

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

  if not public.motoconecta_pedido_has_selectable_carriers (p_request_id) then
    return;
  end if;

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
    and tr.pickup_confirmed_at is null
    and public.motoconecta_pedido_has_selectable_carriers (tr.id);

  return new;
end;
$$;

drop trigger if exists trg_importer_carriers_reopen_pedido on public.importer_carriers;

create trigger trg_importer_carriers_reopen_pedido
after insert or update of is_active on public.importer_carriers
for each row
execute function public.tr_importer_carriers_reopen_pedido_decision ();
