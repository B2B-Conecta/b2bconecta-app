-- Punto de recolección: decisión del aliado sobre transportista + confirmación del importador.

-- ---------------------------------------------------------------------------
-- Ubicaciones alternas del importador
-- ---------------------------------------------------------------------------
create table if not exists public.importer_pickup_locations (
  id uuid not null default gen_random_uuid () primary key,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  label text not null,
  estado text,
  ciudad text,
  direccion text not null,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  maps_url text,
  contact_name text,
  contact_phone text,
  is_active boolean not null default true,
  is_default boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint importer_pickup_locations_label_len_chk
    check (char_length(trim(label)) >= 2),
  constraint importer_pickup_locations_direccion_len_chk
    check (char_length(trim(direccion)) >= 5)
);

create index if not exists importer_pickup_locations_importador_active_idx
  on public.importer_pickup_locations (importador_id, is_active, sort_order);

comment on table public.importer_pickup_locations is
  'Puntos de recolección alternos registrados por el importador.';

-- ---------------------------------------------------------------------------
-- Preferencia por defecto del importador + snapshot por pedido
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists default_pickup_location_mode text not null default 'warehouse',
  add column if not exists default_pickup_location_id uuid references public.importer_pickup_locations (id) on delete set null;

alter table public.profiles
  drop constraint if exists profiles_default_pickup_location_mode_chk;

alter table public.profiles
  add constraint profiles_default_pickup_location_mode_chk
  check (default_pickup_location_mode in ('warehouse', 'alternate'));

alter table public.transaction_requests
  add column if not exists carrier_decision text not null default 'not_applicable',
  add column if not exists carrier_decision_at timestamptz,
  add column if not exists pickup_location_mode text,
  add column if not exists pickup_confirmed_at timestamptz,
  add column if not exists pickup_label text,
  add column if not exists pickup_estado text,
  add column if not exists pickup_ciudad text,
  add column if not exists pickup_direccion text,
  add column if not exists pickup_latitude numeric(10, 7),
  add column if not exists pickup_longitude numeric(10, 7),
  add column if not exists pickup_maps_url text,
  add column if not exists pickup_location_id uuid references public.importer_pickup_locations (id) on delete set null,
  add column if not exists pickup_carrier_id uuid references public.importer_carriers (id) on delete set null;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_carrier_decision_chk;

alter table public.transaction_requests
  add constraint transaction_requests_carrier_decision_chk
  check (
    carrier_decision in ('pending', 'selected', 'skipped', 'not_applicable')
  );

alter table public.transaction_requests
  drop constraint if exists transaction_requests_pickup_location_mode_chk;

alter table public.transaction_requests
  add constraint transaction_requests_pickup_location_mode_chk
  check (
    pickup_location_mode is null
    or pickup_location_mode in ('warehouse', 'carrier_base', 'alternate')
  );

comment on column public.transaction_requests.carrier_decision is
  'pending: aliado debe elegir u omitir transportista; selected|skipped|not_applicable: listo para confirmar recolección.';

-- Pedidos ya en pedido_listo: inicializar decisión
update public.transaction_requests tr
set carrier_decision = case
  when public.motoconecta_importador_has_active_carriers (tr.importador_id)
    then case
      when tr.importer_carrier_id is not null and tr.carrier_selected_at is not null
        then 'selected'
      else 'pending'
    end
  else 'not_applicable'
end
where tr.status = 'pedido_listo';

-- ---------------------------------------------------------------------------
-- Trigger: al pasar a pedido_listo, reiniciar decisión de transporte
-- ---------------------------------------------------------------------------
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

drop trigger if exists trg_tr_pedido_listo_carrier_decision on public.transaction_requests;

create trigger trg_tr_pedido_listo_carrier_decision
before update on public.transaction_requests
for each row
execute function public.tr_transaction_requests_pedido_listo_carrier_decision ();

-- ---------------------------------------------------------------------------
-- RLS importer_pickup_locations
-- ---------------------------------------------------------------------------
alter table public.importer_pickup_locations enable row level security;

drop policy if exists importer_pickup_locations_select_owner on public.importer_pickup_locations;
create policy importer_pickup_locations_select_owner
on public.importer_pickup_locations
for select
to authenticated
using (importador_id = auth.uid ());

drop policy if exists importer_pickup_locations_insert_owner on public.importer_pickup_locations;
create policy importer_pickup_locations_insert_owner
on public.importer_pickup_locations
for insert
to authenticated
with check (importador_id = auth.uid ());

drop policy if exists importer_pickup_locations_update_owner on public.importer_pickup_locations;
create policy importer_pickup_locations_update_owner
on public.importer_pickup_locations
for update
to authenticated
using (importador_id = auth.uid ())
with check (importador_id = auth.uid ());

drop policy if exists importer_pickup_locations_delete_owner on public.importer_pickup_locations;
create policy importer_pickup_locations_delete_owner
on public.importer_pickup_locations
for delete
to authenticated
using (importador_id = auth.uid ());

-- ---------------------------------------------------------------------------
-- Aliado: omitir transportista de la plataforma
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Aliado: elegir transportista (actualizado)
-- ---------------------------------------------------------------------------
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
    tr.carrier_decision,
    case when tr.destino_entrega_usa_perfil then pa.estado else null end,
    case when tr.destino_entrega_usa_perfil then pa.ciudad else null end,
    case when tr.destino_entrega_usa_perfil then pa.latitude else null end,
    case when tr.destino_entrega_usa_perfil then pa.longitude else null end
  into
    v_importador, v_status, v_decision,
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

-- ---------------------------------------------------------------------------
-- Importador: CRUD ubicaciones alternas
-- ---------------------------------------------------------------------------
create or replace function public.list_importer_pickup_locations ()
returns setof public.importer_pickup_locations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();
  return query
  select l.*
  from public.importer_pickup_locations l
  where l.importador_id = v_uid
  order by l.sort_order, l.label;
end;
$$;

grant execute on function public.list_importer_pickup_locations () to authenticated;

create or replace function public.upsert_importer_pickup_location (
  p_id uuid default null,
  p_label text default null,
  p_estado text default null,
  p_ciudad text default null,
  p_direccion text default null,
  p_latitude numeric default null,
  p_longitude numeric default null,
  p_maps_url text default null,
  p_contact_name text default null,
  p_contact_phone text default null,
  p_is_active boolean default true,
  p_is_default boolean default false,
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
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_label, ''))) < 2 then
    raise exception 'Indique un nombre para la ubicación.';
  end if;
  if char_length(trim(coalesce(p_direccion, ''))) < 5 then
    raise exception 'Indique la dirección de la ubicación.';
  end if;

  if p_is_default then
    update public.importer_pickup_locations
    set is_default = false, updated_at = now()
    where importador_id = v_uid;
  end if;

  if p_id is not null then
    update public.importer_pickup_locations l
    set
      label = trim(p_label),
      estado = nullif(trim(coalesce(p_estado, '')), ''),
      ciudad = nullif(trim(coalesce(p_ciudad, '')), ''),
      direccion = trim(p_direccion),
      latitude = p_latitude,
      longitude = p_longitude,
      maps_url = nullif(trim(coalesce(p_maps_url, '')), ''),
      contact_name = nullif(trim(coalesce(p_contact_name, '')), ''),
      contact_phone = nullif(trim(coalesce(p_contact_phone, '')), ''),
      is_active = coalesce(p_is_active, true),
      is_default = coalesce(p_is_default, false),
      sort_order = coalesce(p_sort_order, 0),
      updated_at = now()
    where l.id = p_id
      and l.importador_id = v_uid
    returning l.id into v_id;

    if v_id is null then
      raise exception 'Ubicación no encontrada.';
    end if;
  else
    insert into public.importer_pickup_locations (
      importador_id,
      label,
      estado,
      ciudad,
      direccion,
      latitude,
      longitude,
      maps_url,
      contact_name,
      contact_phone,
      is_active,
      is_default,
      sort_order
    )
    values (
      v_uid,
      trim(p_label),
      nullif(trim(coalesce(p_estado, '')), ''),
      nullif(trim(coalesce(p_ciudad, '')), ''),
      trim(p_direccion),
      p_latitude,
      p_longitude,
      nullif(trim(coalesce(p_maps_url, '')), ''),
      nullif(trim(coalesce(p_contact_name, '')), ''),
      nullif(trim(coalesce(p_contact_phone, '')), ''),
      coalesce(p_is_active, true),
      coalesce(p_is_default, false),
      coalesce(p_sort_order, 0)
    )
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

grant execute on function public.upsert_importer_pickup_location (
  uuid, text, text, text, text, numeric, numeric, text, text, text, boolean, boolean, integer
) to authenticated;

create or replace function public.set_importer_default_pickup_preferences (
  p_mode text,
  p_pickup_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_mode text;
begin
  v_uid := public.motoconecta_assert_importador_role ();
  v_mode := coalesce(nullif(trim(p_mode), ''), 'warehouse');

  if v_mode not in ('warehouse', 'alternate') then
    raise exception 'Modo de recolección por defecto no válido.';
  end if;

  if v_mode = 'alternate' then
    if p_pickup_location_id is null then
      raise exception 'Seleccione una ubicación alterna por defecto.';
    end if;
    if not exists (
      select 1
      from public.importer_pickup_locations l
      where l.id = p_pickup_location_id
        and l.importador_id = v_uid
        and l.is_active = true
    ) then
      raise exception 'Ubicación alterna no válida.';
    end if;
  end if;

  update public.profiles p
  set
    default_pickup_location_mode = v_mode,
    default_pickup_location_id = case
      when v_mode = 'alternate' then p_pickup_location_id
      else null
    end
  where p.id = v_uid;
end;
$$;

grant execute on function public.set_importer_default_pickup_preferences (text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Importador: confirmar punto de recolección en un pedido
-- ---------------------------------------------------------------------------
create or replace function public.importer_confirm_pickup_location (
  p_request_id uuid,
  p_mode text,
  p_pickup_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_row record;
  v_mode text;
  v_label text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_lat numeric;
  v_lng numeric;
  v_maps text;
  v_carrier_id uuid;
  v_loc record;
  v_prof record;
  v_carrier record;
begin
  v_uid := public.motoconecta_assert_importador_role ();
  v_mode := coalesce(nullif(trim(p_mode), ''), 'warehouse');

  if v_mode not in ('warehouse', 'carrier_base', 'alternate') then
    raise exception 'Modo de punto de recolección no válido.';
  end if;

  select
    tr.id,
    tr.importador_id,
    tr.status,
    tr.carrier_decision,
    tr.importer_carrier_id
  into v_row
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.importador_id = v_uid;

  if v_row.id is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_row.status is distinct from 'pedido_listo' then
    raise exception 'Solo puede confirmar recolección en pedidos listos para despacho.';
  end if;

  if v_row.carrier_decision = 'pending' then
    raise exception 'Espere a que el aliado decida si usará un transportista de la plataforma.';
  end if;

  if v_mode = 'carrier_base' then
    if v_row.carrier_decision is distinct from 'selected' then
      raise exception 'La base del transportista solo aplica si el aliado eligió un transportista.';
    end if;
    if v_row.importer_carrier_id is null then
      raise exception 'No hay transportista asignado a este pedido.';
    end if;
  end if;

  if v_mode = 'alternate' then
    if p_pickup_location_id is null then
      raise exception 'Seleccione una ubicación alterna.';
    end if;
    select l.*
    into v_loc
    from public.importer_pickup_locations l
    where l.id = p_pickup_location_id
      and l.importador_id = v_uid
      and l.is_active = true;
    if not found then
      raise exception 'Ubicación alterna no válida.';
    end if;
    v_label := v_loc.label;
    v_estado := v_loc.estado;
    v_ciudad := v_loc.ciudad;
    v_direccion := v_loc.direccion;
    v_lat := v_loc.latitude;
    v_lng := v_loc.longitude;
    v_maps := v_loc.maps_url;
    v_carrier_id := null;
  elsif v_mode = 'carrier_base' then
    select c.*
    into v_carrier
    from public.importer_carriers c
    where c.id = v_row.importer_carrier_id;

    v_label := coalesce(v_carrier.company_name, 'Base del transportista');
    v_estado := v_carrier.base_estado;
    v_ciudad := v_carrier.base_ciudad;
    v_direccion := coalesce(
      nullif(trim(concat_ws(', ', v_carrier.base_ciudad, v_carrier.base_estado)), ''),
      v_carrier.company_name
    );
    v_lat := v_carrier.base_latitude;
    v_lng := v_carrier.base_longitude;
    v_maps := v_carrier.base_maps_url;
    v_carrier_id := v_carrier.id;
  else
    select
      p.business_name,
      p.estado,
      p.ciudad,
      p.direccion,
      p.latitude,
      p.longitude,
      p.fiscal_maps_url
    into v_prof
    from public.profiles p
    where p.id = v_uid;

    v_label := coalesce(nullif(trim(v_prof.business_name), ''), 'Mi almacén');
    v_estado := v_prof.estado;
    v_ciudad := v_prof.ciudad;
    v_direccion := v_prof.direccion;
    v_lat := v_prof.latitude;
    v_lng := v_prof.longitude;
    v_maps := v_prof.fiscal_maps_url;
    v_carrier_id := null;

    if coalesce(btrim(v_direccion), '') = '' then
      raise exception 'Complete la dirección de su almacén en el perfil antes de usar «Mi almacén».';
    end if;
  end if;

  update public.transaction_requests tr
  set
    pickup_location_mode = v_mode,
    pickup_confirmed_at = now(),
    pickup_label = v_label,
    pickup_estado = v_estado,
    pickup_ciudad = v_ciudad,
    pickup_direccion = v_direccion,
    pickup_latitude = v_lat,
    pickup_longitude = v_lng,
    pickup_maps_url = v_maps,
    pickup_location_id = case when v_mode = 'alternate' then p_pickup_location_id else null end,
    pickup_carrier_id = v_carrier_id,
    updated_at = now()
  where tr.id = p_request_id
    and tr.importador_id = v_uid;
end;
$$;

grant execute on function public.importer_confirm_pickup_location (uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Importador: en tránsito (actualizado)
-- ---------------------------------------------------------------------------
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
  v_decision text;
  v_has_carriers boolean;
  v_days integer;
  v_hours integer;
  v_pickup_confirmed timestamptz;
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
    tr.importer_carrier_id,
    tr.carrier_decision,
    tr.pickup_confirmed_at
  into
    v_importador, st, inv, flete_inv, v_flete_modo, v_carrier, v_decision, v_pickup_confirmed
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

  if v_pickup_confirmed is null then
    raise exception 'Confirme el punto de recolección antes de marcar en tránsito.';
  end if;

  if v_decision = 'pending' then
    raise exception 'Espere la decisión del aliado sobre el transportista.';
  end if;

  v_has_carriers := public.motoconecta_importador_has_active_carriers (v_importador);

  if v_decision = 'selected' then
    if v_carrier is null then
      raise exception 'Falta el transportista seleccionado por el aliado.';
    end if;

    if coalesce(v_flete_modo, 'incluido_factura') = 'pago_separado'
       and coalesce(btrim(flete_inv), '') = '' then
      raise exception
        'Adjunte la factura del flete antes de marcar en tránsito (pago separado al transportista).';
    end if;
  elsif v_has_carriers and v_decision is null then
    raise exception 'Espere la decisión del aliado sobre el transportista.';
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

-- ---------------------------------------------------------------------------
-- Notificaciones: omitir transportista + confirmar recolección
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_carrier_y_flete ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_aliado_name text;
  v_carrier_name text;
  v_anchor text;
  v_pickup_line text;
begin
  if tg_op <> 'update' then
    return new;
  end if;

  perform set_config ('row_security', 'off', true);

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  select nullif(trim(ic.company_name), '')
    into v_carrier_name
  from public.importer_carriers ic
  where ic.id = new.importer_carrier_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;

  -- Aliado eligió transportista → importador
  if new.importer_carrier_id is not null
     and (
       old.importer_carrier_id is null
       or old.importer_carrier_id is distinct from new.importer_carrier_id
     )
     and new.carrier_selected_at is not null
     and (
       old.carrier_selected_at is null
       or old.carrier_selected_at is distinct from new.carrier_selected_at
     ) then
    perform public.mc_insert_notification (
      new.importador_id,
      'Transportista elegido',
      format(
        '%s seleccionó %s para el despacho%s.',
        coalesce(v_aliado_name, 'El aliado'),
        coalesce(v_carrier_name, 'un transportista'),
        case
          when new.checkout_group_id is not null then ' de su pedido en este carrito'
          else ''
        end
      ),
      'pedido',
      v_anchor
    );

    if coalesce(new.carrier_flete_pago_modo_snapshot, '') = 'pago_separado'
       and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Transportista confirmado',
        format(
          'Seleccionó %s. Cuando el importador adjunte la factura del flete podrá registrar el pago del transporte.',
          coalesce(v_carrier_name, 'el transportista')
        ),
        'pedido',
        v_anchor
      );
    end if;
  end if;

  -- Aliado omitió transportista → importador
  if new.carrier_decision = 'skipped'
     and old.carrier_decision is distinct from 'skipped' then
    perform public.mc_insert_notification (
      new.importador_id,
      'Sin transportista de la plataforma',
      format(
        '%s indicó que no usará un transportista registrado. Confirme el punto de recolección y coordine la entrega.',
        coalesce(v_aliado_name, 'El aliado')
      ),
      'pedido',
      v_anchor
    );
  end if;

  -- Importador confirmó punto de recolección → aliado
  if new.pickup_confirmed_at is not null
     and old.pickup_confirmed_at is null then
    v_pickup_line := coalesce(
      nullif(trim(concat_ws(', ', new.pickup_ciudad, new.pickup_estado)), ''),
      nullif(trim(new.pickup_label), ''),
      'ubicación confirmada'
    );

    perform public.mc_insert_notification (
      new.aliado_id,
      'Punto de recolección confirmado',
      format(
        '%s confirmó el punto de recolección: %s.%s',
        coalesce(v_imp_name, 'El importador'),
        v_pickup_line,
        case
          when new.carrier_decision = 'selected'
            then ' El transporte lo coordinará ' || coalesce(v_carrier_name, 'el transportista elegido') || '.'
          when new.carrier_decision in ('skipped', 'not_applicable')
            then ' La entrega la coordinará el importador.'
          else ''
        end
      ),
      'pedido',
      v_anchor
    );
  end if;

  -- Factura de flete → aliado
  if new.flete_factura_storage_path is not null
     and length(trim(new.flete_factura_storage_path)) > 0
     and (
       old.flete_factura_storage_path is null
       or length(trim(old.flete_factura_storage_path)) = 0
       or old.flete_factura_storage_path is distinct from new.flete_factura_storage_path
     )
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    perform public.mc_insert_notification (
      new.aliado_id,
      case
        when old.flete_factura_storage_path is not null
             and length(trim(old.flete_factura_storage_path)) > 0
          then 'Factura del flete actualizada'
        else 'Factura del flete disponible'
      end,
      format(
        '%s adjuntó la factura del transporte%s. Revise el monto y registre el pago del flete en Pedidos.',
        coalesce(v_imp_name, 'El importador'),
        case
          when new.checkout_group_id is not null then ' para su bloque en este carrito'
          else ''
        end
      ),
      'pago',
      v_anchor
    );
  end if;

  -- Comprobante de flete del aliado → importador
  if new.flete_comprobante_pago_storage_path is not null
     and length(trim(new.flete_comprobante_pago_storage_path)) > 0
     and (
       old.flete_comprobante_pago_storage_path is null
       or length(trim(old.flete_comprobante_pago_storage_path)) = 0
       or old.flete_comprobante_pago_storage_path is distinct from new.flete_comprobante_pago_storage_path
     ) then
    perform public.mc_insert_notification (
      new.importador_id,
      'Comprobante de pago del flete recibido',
      format(
        '%s adjuntó el comprobante del pago del transporte%s.',
        coalesce(v_aliado_name, 'El aliado'),
        case
          when v_carrier_name is not null then ' (' || v_carrier_name || ')'
          else ''
        end
      ),
      'pago',
      new.id::text
    );
  end if;

  return new;
end;
$$;
