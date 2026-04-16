-- Corrige validación ETA: permitir tránsito por horas sin exigir días >= 1.

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
  v_days integer;
  v_hours integer;
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

      v_days := coalesce(new.transit_eta_days, 0);
      v_hours := coalesce(new.transit_eta_hours, 0);
      if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
        raise exception 'ETA inválido: días 0–365 y horas 0–23.';
      end if;
      if v_days = 0 and v_hours = 0 then
        raise exception 'Debe indicar transit_eta_days o transit_eta_hours (al menos uno).';
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

-- Compatibilidad: elimina firma antigua de 2 parámetros si existe.
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
  fa text;
  pe text;
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

  select
    tr.status,
    tr.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path,
    tr.pago_estado_revision
  into st, inv, fa, pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'en_preparacion' then
    raise exception 'Solo pedidos en preparación pueden pasar a en tránsito';
  end if;
  if coalesce(trim(inv), '') = '' then
    raise exception 'El importador debe adjuntar la factura digital antes.';
  end if;
  if coalesce(trim(fa), '') = '' then
    raise exception 'Adjunte la factura oficial al aliado antes.';
  end if;
  if coalesce(pe, '') is distinct from 'aprobado' then
    raise exception 'Apruebe primero el pago del aliado (comprobante).';
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

grant execute on function public.admin_marca_pedido_en_transito(uuid, integer, integer)
  to authenticated;
