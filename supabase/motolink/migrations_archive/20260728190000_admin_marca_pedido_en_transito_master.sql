-- Admin: permitir paso a en_transito en pedidos maestro multi-importador.
-- Reglas:
-- - Pedido maestro debe estar en `pedido_listo`.
-- - Debe existir factura MotoLink al aliado (nivel maestro).
-- - Todos los sub-pedidos deben estar en `listo` y con factura proveedor.
-- - Si es pedido simple (legacy), conserva reglas anteriores.

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
  is_m boolean;
  v_days integer;
  v_hours integer;
  n_sub int;
  n_bad_status int;
  n_missing_inv int;
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

  select
    tr.status,
    tr.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path,
    coalesce(tr.is_master_order, false)
  into st, inv, fa, is_m
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'pedido_listo' then
    raise exception 'Solo pedidos listos para recolección pueden pasar a en tránsito';
  end if;
  if coalesce(trim(fa), '') = '' then
    raise exception 'Adjunte la factura oficial al aliado antes.';
  end if;

  if is_m then
    select count(*) into n_sub
    from public.sub_orders so
    where so.parent_order_id = p_request_id;

    if n_sub = 0 then
      raise exception 'Pedido maestro sin sub-pedidos.';
    end if;

    select count(*) into n_bad_status
    from public.sub_orders so
    where so.parent_order_id = p_request_id
      and so.status is distinct from 'listo';

    if n_bad_status > 0 then
      raise exception 'Todos los sub-pedidos deben estar en estado listo.';
    end if;

    select count(*) into n_missing_inv
    from public.sub_orders so
    where so.parent_order_id = p_request_id
      and coalesce(trim(so.proveedor_factura_storage_path), '') = '';

    if n_missing_inv > 0 then
      raise exception 'Falta factura del proveedor en uno o más sub-pedidos.';
    end if;

    update public.sub_orders
    set
      status = 'en_ruta',
      transit_eta_days = v_days,
      transit_eta_hours = v_hours,
      transit_eta_set_at = now(),
      updated_at = now()
    where parent_order_id = p_request_id;
  else
    if coalesce(trim(inv), '') = '' then
      raise exception 'El importador debe adjuntar la factura digital antes.';
    end if;
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
