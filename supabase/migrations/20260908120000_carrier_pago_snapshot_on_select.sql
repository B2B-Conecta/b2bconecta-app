-- Snapshot de datos de pago del transportista al elegirlo (RLS bloquea join directo al aliado).

alter table public.transaction_requests
  add column if not exists carrier_company_name_snapshot text,
  add column if not exists carrier_accepted_pago_metodos_snapshot text[],
  add column if not exists carrier_pago_instrucciones_snapshot jsonb;

comment on column public.transaction_requests.carrier_pago_instrucciones_snapshot is
  'Datos de cuenta del transportista por método (copia al elegir transportista).';

-- Pedidos ya con transportista: rellenar desde importer_carriers.
update public.transaction_requests tr
set
  carrier_company_name_snapshot = coalesce(
    tr.carrier_company_name_snapshot,
    c.company_name
  ),
  carrier_accepted_pago_metodos_snapshot = coalesce(
    tr.carrier_accepted_pago_metodos_snapshot,
    c.accepted_pago_metodos
  ),
  carrier_pago_instrucciones_snapshot = coalesce(
    tr.carrier_pago_instrucciones_snapshot,
    c.pago_metodo_instrucciones
  )
from public.importer_carriers c
where tr.importer_carrier_id = c.id
  and (
    tr.carrier_pago_instrucciones_snapshot is null
    or tr.carrier_accepted_pago_metodos_snapshot is null
    or tr.carrier_company_name_snapshot is null
  );

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
    carrier_company_name_snapshot = v_carrier.company_name,
    carrier_accepted_pago_metodos_snapshot = v_carrier.accepted_pago_metodos,
    carrier_pago_instrucciones_snapshot = v_carrier.pago_metodo_instrucciones,
    carrier_selected_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = v_uid
    and tr.status = 'pedido_listo';
end;
$$;

grant execute on function public.aliado_select_carrier_for_pedido (uuid, uuid, uuid) to authenticated;

-- Aliado: datos de pago del transportista asignado (bypass RLS).
create or replace function public.get_aliado_pedido_carrier_pago_info (p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_row record;
  v_carrier record;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select
    tr.importer_carrier_id,
    tr.carrier_company_name_snapshot,
    tr.carrier_accepted_pago_metodos_snapshot,
    tr.carrier_pago_instrucciones_snapshot
  into v_row
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.aliado_id = v_uid;

  if v_row is null then
    raise exception 'Pedido no encontrado';
  end if;

  if v_row.importer_carrier_id is null then
    raise exception 'No hay transportista asignado a este pedido';
  end if;

  if v_row.carrier_pago_instrucciones_snapshot is not null
     and v_row.carrier_accepted_pago_metodos_snapshot is not null then
    return jsonb_build_object(
      'company_name', v_row.carrier_company_name_snapshot,
      'accepted_pago_metodos', to_jsonb(v_row.carrier_accepted_pago_metodos_snapshot),
      'pago_metodo_instrucciones', v_row.carrier_pago_instrucciones_snapshot
    );
  end if;

  select
    c.company_name,
    c.accepted_pago_metodos,
    c.pago_metodo_instrucciones
  into v_carrier
  from public.importer_carriers c
  where c.id = v_row.importer_carrier_id;

  if not found then
    raise exception 'Transportista no encontrado';
  end if;

  return jsonb_build_object(
    'company_name', coalesce(v_row.carrier_company_name_snapshot, v_carrier.company_name),
    'accepted_pago_metodos', to_jsonb(v_carrier.accepted_pago_metodos),
    'pago_metodo_instrucciones', v_carrier.pago_metodo_instrucciones
  );
end;
$$;

grant execute on function public.get_aliado_pedido_carrier_pago_info (uuid) to authenticated;
