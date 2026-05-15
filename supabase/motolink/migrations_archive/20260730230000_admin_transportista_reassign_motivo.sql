-- En tránsito: cambiar o quitar transportista solo con motivo (auditoría).

alter table public.transaction_requests
  add column if not exists transportista_reassign_motivo text,
  add column if not exists transportista_reassign_at timestamptz;

comment on column public.transaction_requests.transportista_reassign_motivo is
  'Último motivo registrado al cambiar o quitar transportista mientras el pedido está en_tránsito.';
comment on column public.transaction_requests.transportista_reassign_at is
  'Marca de tiempo del último cambio de transportista en tránsito con motivo.';

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
