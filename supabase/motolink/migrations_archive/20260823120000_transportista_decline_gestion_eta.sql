-- Transportista: rechazar asignación con motivo; confirmar con ETA de gestión (días/horas) y notificar aliado + admins.

alter table public.transaction_requests
  add column if not exists transportista_decline_motivo text,
  add column if not exists transportista_declined_at timestamptz,
  add column if not exists transportista_gestion_eta_days integer,
  add column if not exists transportista_gestion_eta_hours integer,
  add column if not exists transportista_gestion_eta_set_at timestamptz;

comment on column public.transaction_requests.transportista_decline_motivo is
  'Motivo indicado por el transportista al rechazar la asignación (antes de confirmar).';
comment on column public.transaction_requests.transportista_declined_at is
  'Marca de tiempo del rechazo de asignación por el transportista.';
comment on column public.transaction_requests.transportista_gestion_eta_days is
  'Días estimados de gestión del envío declarados por el transportista al confirmar la asignación.';
comment on column public.transaction_requests.transportista_gestion_eta_hours is
  'Horas (0–23) adicionales de gestión estimada, junto con transportista_gestion_eta_days.';
comment on column public.transaction_requests.transportista_gestion_eta_set_at is
  'Cuándo el transportista registró la estimación de gestión al confirmar.';

drop function if exists public.transportista_acknowledge_assignment(uuid);

create or replace function public.transportista_acknowledge_assignment(
  p_request_id uuid,
  p_gestion_eta_days integer,
  p_gestion_eta_hours integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_aliado uuid;
  v_owner uuid;
  v_days int;
  v_hours int;
  v_eta_text text;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  ) then
    raise exception 'Solo el transportista asignado puede confirmar.';
  end if;

  v_days := coalesce(p_gestion_eta_days, 0);
  v_hours := coalesce(p_gestion_eta_hours, 0);

  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception
      'Tiempo estimado inválido: use 0 a 365 días y 0 a 23 horas adicionales.';
  end if;

  if v_days = 0 and v_hours = 0 then
    raise exception
      'Indique al menos un día u hora estimada para gestionar este envío.';
  end if;

  update public.transaction_requests tr
  set
    transportista_assignment_acknowledged_at = now(),
    transportista_gestion_eta_days = v_days,
    transportista_gestion_eta_hours = v_hours,
    transportista_gestion_eta_set_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.transportista_assignment_acknowledged_at is null
    and tr.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito'
    );

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo confirmar. Verifique que sea su pedido asignado y que aún no esté confirmado.';
  end if;

  select tr.aliado_id, tr.owner_id
  into v_aliado, v_owner
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_days > 0 and v_hours > 0 then
    v_eta_text := format('%s día(s) y %s hora(s)', v_days, v_hours);
  elsif v_days > 0 then
    v_eta_text := format('%s día(s)', v_days);
  else
    v_eta_text := format('%s hora(s)', v_hours);
  end if;

  perform public.notify_to_all_admins(
    'Despacho: transportista confirmó',
    format(
      'El transportista confirmó la asignación e indicó gestionar el envío en aproximadamente %s.',
      v_eta_text
    ),
    'logistica',
    p_request_id::text
  );

  if v_aliado is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Transportista confirmó su pedido',
      format(
        'El transportista asignado por MotoLink confirmó el despacho. Tiempo estimado de gestión: %s.',
        v_eta_text
      ),
      'logistica',
      p_request_id::text
    );
  end if;

  if v_owner is not null and v_owner is distinct from v_aliado then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_owner,
      'Despacho: transportista confirmó',
      format(
        'El transportista confirmó la asignación. Tiempo estimado de gestión: %s.',
        v_eta_text
      ),
      'logistica',
      p_request_id::text
    );
  end if;
end;
$$;

revoke all on function public.transportista_acknowledge_assignment(uuid, integer, integer) from public;
grant execute on function public.transportista_acknowledge_assignment(uuid, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Transportista: rechaza la asignación (quita asignación y notifica).
-- ---------------------------------------------------------------------------
create or replace function public.transportista_decline_assignment(
  p_request_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_aliado uuid;
  v_owner uuid;
  v_m text;
  v_snip text;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  ) then
    raise exception 'Solo el transportista asignado puede rechazar.';
  end if;

  v_m := nullif(trim(p_motivo), '');
  if v_m is null then
    raise exception 'Indique el motivo del rechazo.';
  end if;

  update public.transaction_requests tr
  set
    assigned_transportista_id = null,
    transportista_assignment_acknowledged_at = null,
    transportista_recogida_almacen_at = null,
    transportista_live_location_opt_in = false,
    transportista_live_lat = null,
    transportista_live_lng = null,
    transportista_live_location_at = null,
    transportista_gestion_eta_days = null,
    transportista_gestion_eta_hours = null,
    transportista_gestion_eta_set_at = null,
    transportista_decline_motivo = v_m,
    transportista_declined_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.transportista_assignment_acknowledged_at is null
    and tr.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito'
    )
  returning tr.aliado_id, tr.owner_id into v_aliado, v_owner;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo rechazar. Verifique que sea su pedido asignado, sin confirmación previa, y en un estado operativo.';
  end if;

  update public.sub_orders so
  set
    transportista_recogida_almacen_at = null,
    updated_at = now()
  where so.parent_order_id = p_request_id;

  v_snip := left(v_m, 380);
  perform public.notify_to_all_admins(
    'Despacho: transportista rechazó asignación',
    format('Un transportista declinó el despacho de un pedido. Motivo: %s', v_snip),
    'logistica',
    p_request_id::text
  );

  if v_aliado is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Despacho: transportista no disponible',
      format(
        'El transportista asignado por MotoLink no aceptó el pedido. Motivo: %s',
        v_snip
      ),
      'logistica',
      p_request_id::text
    );
  end if;

  if v_owner is not null and v_owner is distinct from v_aliado then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_owner,
      'Despacho: transportista no disponible',
      format(
        'El transportista no aceptó el despacho asignado por MotoLink. Motivo: %s',
        v_snip
      ),
      'logistica',
      p_request_id::text
    );
  end if;
end;
$$;

revoke all on function public.transportista_decline_assignment(uuid, text) from public;
grant execute on function public.transportista_decline_assignment(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: al reasignar, limpiar rechazo/ETA de gestión del transportista anterior.
-- ---------------------------------------------------------------------------
create or replace function public.admin_assign_transportista_pedido(
  p_request_id uuid,
  p_transportista_id uuid,
  p_cambio_motivo text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_old uuid;
  v_st text;
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

  select tr.assigned_transportista_id, tr.status
  into v_old, v_st
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_st = 'en_transito' and v_old is distinct from p_transportista_id then
    if coalesce(trim(p_cambio_motivo), '') = '' then
      raise exception
        'En tránsito debe indicar el motivo del cambio o retiro del transportista asignado.';
    end if;
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
    transportista_gestion_eta_days = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_gestion_eta_days
    end,
    transportista_gestion_eta_hours = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_gestion_eta_hours
    end,
    transportista_gestion_eta_set_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
      then null
      else tr.transportista_gestion_eta_set_at
    end,
    transportista_decline_motivo = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
        and p_transportista_id is not null
      then null
      else tr.transportista_decline_motivo
    end,
    transportista_declined_at = case
      when tr.assigned_transportista_id is distinct from p_transportista_id
        and p_transportista_id is not null
      then null
      else tr.transportista_declined_at
    end,
    transportista_reassign_motivo = case
      when v_st = 'en_transito' and v_old is distinct from p_transportista_id
      then nullif(trim(p_cambio_motivo), '')
      else tr.transportista_reassign_motivo
    end,
    transportista_reassign_at = case
      when v_st = 'en_transito' and v_old is distinct from p_transportista_id
      then now()
      else tr.transportista_reassign_at
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

revoke all on function public.admin_assign_transportista_pedido(uuid, uuid, text) from public;
grant execute on function public.admin_assign_transportista_pedido(uuid, uuid, text) to authenticated;
