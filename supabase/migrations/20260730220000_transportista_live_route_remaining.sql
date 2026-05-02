-- Ubicación en vivo opcional del transportista por pedido + publicación de ruta Google Maps (tramos restantes).

alter table public.transaction_requests
  add column if not exists transportista_live_location_opt_in boolean not null default false,
  add column if not exists transportista_live_lat double precision,
  add column if not exists transportista_live_lng double precision,
  add column if not exists transportista_live_location_at timestamptz;

comment on column public.transaction_requests.transportista_live_location_opt_in is
  'Si true, el transportista autoriza compartir coordenadas del dispositivo para este envío (en tránsito).';
comment on column public.transaction_requests.transportista_live_lat is
  'Última latitud reportada por el transportista para este pedido (tracking en vivo).';
comment on column public.transaction_requests.transportista_live_lng is
  'Última longitud reportada por el transportista para este pedido (tracking en vivo).';
comment on column public.transaction_requests.transportista_live_location_at is
  'Marca de tiempo del último reporte de ubicación en vivo.';

-- ---------------------------------------------------------------------------
-- Admin: al cambiar transportista, limpiar tracking en vivo y recogidas (misma función vigente).
-- ---------------------------------------------------------------------------
create or replace function public.admin_assign_transportista_pedido(
  p_request_id uuid,
  p_transportista_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_old uuid;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo MotoLink puede asignar transportista.';
  end if;

  select tr.assigned_transportista_id
  into v_old
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if p_transportista_id is not null then
    if not exists (
      select 1 from public.profiles p
      where p.id = p_transportista_id and p.role = 'transportista'
    ) then
      raise exception 'El usuario indicado no es un transportista.';
    end if;
    if not exists (
      select 1 from public.transportista_info t where t.id = p_transportista_id
    ) then
      raise exception 'El transportista debe completar su expediente (transportista_info).';
    end if;
  end if;

  update public.transaction_requests tr
  set
    assigned_transportista_id = p_transportista_id,
    transportista_assignment_acknowledged_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_assignment_acknowledged_at
    end,
    transportista_recogida_almacen_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_recogida_almacen_at
    end,
    transportista_live_location_opt_in = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then false
      else tr.transportista_live_location_opt_in
    end,
    transportista_live_lat = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_live_lat
    end,
    transportista_live_lng = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_live_lng
    end,
    transportista_live_location_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_live_location_at
    end,
    updated_at = now()
  where tr.id = p_request_id;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_old is distinct from p_transportista_id then
    update public.sub_orders so
    set
      transportista_recogida_almacen_at = null,
      updated_at = now()
    where so.parent_order_id = p_request_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Transportista: activar / desactivar tracking en vivo (solo pedido asignado, en tránsito).
-- ---------------------------------------------------------------------------
create or replace function public.transportista_set_live_tracking_opt_in(
  p_request_id uuid,
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  ) then
    raise exception 'Solo el transportista puede modificar esta opción.';
  end if;

  update public.transaction_requests tr
  set
    transportista_live_location_opt_in = p_enabled,
    transportista_live_lat = case when p_enabled then tr.transportista_live_lat else null end,
    transportista_live_lng = case when p_enabled then tr.transportista_live_lng else null end,
    transportista_live_location_at = case when p_enabled then tr.transportista_live_location_at else null end,
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.status = 'en_transito';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo actualizar. Verifique que el pedido esté en tránsito y asignado a usted.';
  end if;
end;
$$;

revoke all on function public.transportista_set_live_tracking_opt_in(uuid, boolean) from public;
grant execute on function public.transportista_set_live_tracking_opt_in(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Transportista: reportar coordenadas (la app puede limitar frecuencia p. ej. cada 30–60 s).
-- ---------------------------------------------------------------------------
create or replace function public.transportista_report_live_location(
  p_request_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if p_lat is null or p_lng is null then
    raise exception 'Coordenadas requeridas.';
  end if;
  if p_lat < -90 or p_lat > 90 or p_lng < -180 or p_lng > 180 then
    raise exception 'Coordenadas fuera de rango.';
  end if;

  update public.transaction_requests tr
  set
    transportista_live_lat = p_lat,
    transportista_live_lng = p_lng,
    transportista_live_location_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.status = 'en_transito'
    and tr.transportista_live_location_opt_in = true;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se registró la ubicación. Active el seguimiento en vivo y verifique que el pedido siga en tránsito y asignado a usted.';
  end if;
end;
$$;

revoke all on function public.transportista_report_live_location(uuid, double precision, double precision) from public;
grant execute on function public.transportista_report_live_location(uuid, double precision, double precision) to authenticated;

-- ---------------------------------------------------------------------------
-- Transportista: publicar URL de Google Maps con tramos restantes (la app calcula la cadena).
-- ---------------------------------------------------------------------------
create or replace function public.transportista_publica_ruta_maps_actualizada(
  p_request_id uuid,
  p_maps_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  u text;
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  u := nullif(trim(p_maps_url), '');
  if u is null
     or u !~* '^https://((www\\.|maps\\.)?google\\.com/maps)'
  then
    raise exception 'URL de Google Maps no válida.';
  end if;

  update public.transaction_requests tr
  set
    admin_ruta_maps_url = u,
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.status = 'en_transito';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo publicar la ruta. Verifique que el pedido esté en tránsito y asignado a usted.';
  end if;
end;
$$;

revoke all on function public.transportista_publica_ruta_maps_actualizada(uuid, text) from public;
grant execute on function public.transportista_publica_ruta_maps_actualizada(uuid, text) to authenticated;
