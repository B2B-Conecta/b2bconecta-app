-- Flete a criterio del proveedor: sin bloquear «en tránsito» por agencias.
-- Columnas de costo + RPC de actualización + gates de estado simplificados.

alter table public.transaction_requests
  add column if not exists shipping_included boolean,
  add column if not exists shipping_cost_usd numeric(14, 2),
  add column if not exists shipping_cost_bs numeric(18, 4);

alter table public.transaction_requests
  drop constraint if exists transaction_requests_shipping_cost_usd_chk;

alter table public.transaction_requests
  add constraint transaction_requests_shipping_cost_usd_chk
  check (shipping_cost_usd is null or shipping_cost_usd >= 0);

alter table public.transaction_requests
  drop constraint if exists transaction_requests_shipping_cost_bs_chk;

alter table public.transaction_requests
  add constraint transaction_requests_shipping_cost_bs_chk
  check (shipping_cost_bs is null or shipping_cost_bs >= 0);

comment on column public.transaction_requests.shipping_included is
  'True si el proveedor incluye el flete; false si cobra aparte; null = aún no definido.';

comment on column public.transaction_requests.shipping_cost_usd is
  'Monto de flete en USD/REF cuando shipping_included = false.';

comment on column public.transaction_requests.shipping_cost_bs is
  'Equivalente en bolívares del flete (USD × tasa_bcv_aplicada).';

-- Al pasar a pedido_listo ya no se espera decisión del aliado sobre agencias.
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
    new.carrier_decision := 'not_applicable';
    new.carrier_decision_at := now();
  end if;
  return new;
end;
$$;

-- Reparar pedidos que quedaron esperando al aliado.
update public.transaction_requests
set
  carrier_decision = 'not_applicable',
  carrier_decision_at = coalesce(carrier_decision_at, now()),
  updated_at = now()
where status = 'pedido_listo'
  and carrier_decision = 'pending';

-- Proveedor define flete (incluido o monto USD) sobre una o más líneas del pedido.
create or replace function public.importer_set_order_shipping (
  p_request_ids uuid[],
  p_shipping_included boolean,
  p_shipping_cost_usd numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_importador uuid;
  v_status text;
  v_rate numeric;
  v_cost_usd numeric;
  v_cost_bs numeric;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'importador'
      and p.deactivated_at is null
  ) then
    raise exception 'Solo el proveedor puede definir el flete'
      using errcode = '42501';
  end if;

  if p_request_ids is null or cardinality(p_request_ids) < 1 then
    raise exception 'Indique al menos un pedido.';
  end if;

  if p_shipping_included is null then
    raise exception 'Indique si el flete está incluido.';
  end if;

  if p_shipping_included then
    v_cost_usd := null;
    v_cost_bs := null;
  else
    if p_shipping_cost_usd is null or p_shipping_cost_usd < 0 then
      raise exception 'Indique el costo de envío en USD (0 o mayor).';
    end if;
    v_cost_usd := round(p_shipping_cost_usd, 2);
  end if;

  foreach v_id in array p_request_ids
  loop
    select tr.importador_id, tr.status, tr.tasa_bcv_aplicada
    into v_importador, v_status, v_rate
    from public.transaction_requests tr
    where tr.id = v_id;

    if v_importador is null then
      raise exception 'Pedido no encontrado.';
    end if;

    if v_importador is distinct from v_uid then
      raise exception 'No autorizado para este pedido.';
    end if;

    if v_status in (
      'entregado',
      'rechazado',
      'cancelado_por_aliado',
      'cancelado_por_importador',
      'anulado_motolink'
    ) then
      raise exception 'No se puede editar el flete de un pedido cerrado.';
    end if;

    if not p_shipping_included then
      if v_rate is null or v_rate <= 0 then
        -- Fallback: tasa BCV global si el pedido aún no congeló tasa.
        select c.value_numeric
        into v_rate
        from public.app_global_config c
        where c.key = 'tasa_bcv';
      end if;
      if v_rate is null or v_rate <= 0 then
        raise exception 'No hay tasa BCV para calcular el flete en bolívares.';
      end if;
      v_cost_bs := round(v_cost_usd * v_rate, 4);
    end if;

    update public.transaction_requests
    set
      shipping_included = p_shipping_included,
      shipping_cost_usd = v_cost_usd,
      shipping_cost_bs = v_cost_bs,
      updated_at = now()
    where id = v_id;
  end loop;
end;
$$;

revoke all on function public.importer_set_order_shipping (uuid[], boolean, numeric)
  from public;
grant execute on function public.importer_set_order_shipping (uuid[], boolean, numeric)
  to authenticated;

-- «En tránsito» sin esperar agencias ni punto de recolección.
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
  v_days integer;
  v_hours integer;
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
    tr.proveedor_factura_storage_path
  into
    v_importador, st, inv
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

grant execute on function public.importer_marca_pedido_en_transito (uuid, integer, integer)
  to authenticated;
