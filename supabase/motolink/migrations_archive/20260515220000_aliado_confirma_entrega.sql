-- La entrega la confirma el aliado (no el importador). RPC + trigger de transiciones.

create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
  is_aliado_owner boolean;
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

  select
    new.aliado_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'aliado'
    )
  into is_aliado_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;
      if new.transit_eta_days is null or new.transit_eta_days < 1 then
        raise exception 'Debe indicar transit_eta_days (días estimados de entrega, mín. 1).';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  if is_aliado_owner then
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para el aliado';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

-- ---------------------------------------------------------------------------
-- Aliado: confirma recepción (en tránsito → entregado). Desencadena stock, contado, etc.
-- ---------------------------------------------------------------------------
create or replace function public.aliado_marca_pedido_entregado(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede confirmar la entrega en su taller.';
  end if;

  update public.transaction_requests
  set
    status = 'entregado',
    updated_at = now()
  where id = p_request_id
    and aliado_id = auth.uid()
    and status = 'en_transito';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo marcar como entregado. Verifique que el pedido esté en tránsito y sea suyo.';
  end if;
end;
$$;

grant execute on function public.aliado_marca_pedido_entregado(uuid) to authenticated;

comment on column public.transaction_requests.at_entregado is
  'Fecha en que el aliado confirma recepción (pedido entregado; stock descontado).';
