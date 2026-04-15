-- ETA de tránsito: días (0–365) y horas (0–23); al menos uno > 0.

alter table public.transaction_requests
  add column if not exists transit_eta_hours integer;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_transit_eta_days_range;

alter table public.transaction_requests
  add constraint transaction_requests_transit_eta_days_range
  check (transit_eta_days is null or (transit_eta_days >= 0 and transit_eta_days <= 365));

alter table public.transaction_requests
  drop constraint if exists transaction_requests_transit_eta_hours_range;

alter table public.transaction_requests
  add constraint transaction_requests_transit_eta_hours_range
  check (transit_eta_hours is null or (transit_eta_hours >= 0 and transit_eta_hours <= 23));

create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
  etd integer;
  eth integer;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;
      etd := coalesce(new.transit_eta_days, 0);
      eth := coalesce(new.transit_eta_hours, 0);
      if etd < 0 or etd > 365 or eth < 0 or eth > 23 then
        raise exception 'ETA de tránsito inválido: días 0–365, horas 0–23.';
      end if;
      if etd = 0 and eth = 0 then
        raise exception 'Debe indicar días y/o horas de tránsito (al menos uno mayor que 0).';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

drop function if exists public.admin_marca_pedido_en_transito(uuid, integer);

create or replace function public.admin_marca_pedido_en_transito(
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
  st text;
  inv text;
  v_days integer;
  v_hours integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden marcar en tránsito';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);

  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'Valores inválidos: días 0–365, horas 0–23.';
  end if;
  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día o una hora de tránsito estimado.';
  end if;

  select status, proveedor_factura_storage_path
  into st, inv
  from public.transaction_requests
  where id = p_request_id;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'en_preparacion' then
    raise exception 'Solo pedidos en preparación pueden pasar a en tránsito';
  end if;
  if coalesce(trim(inv), '') = '' then
    raise exception 'El importador debe adjuntar la factura digital antes.';
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_marca_pedido_en_transito(uuid, integer, integer) to authenticated;
