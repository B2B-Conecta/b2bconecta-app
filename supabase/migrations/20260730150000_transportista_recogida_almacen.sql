-- Recogida en almacén (transportista): marca + notificaciones + RLS lectura sub_orders/items.

alter table public.transaction_requests
  add column if not exists transportista_recogida_almacen_at timestamptz;

comment on column public.transaction_requests.transportista_recogida_almacen_at is
  'Pedido simple: el transportista confirmó retiro en almacén del importador (owner).';

alter table public.sub_orders
  add column if not exists transportista_recogida_almacen_at timestamptz;

comment on column public.sub_orders.transportista_recogida_almacen_at is
  'Transportista confirmó retiro en almacén de este importador (tramo maestro).';

-- ---------------------------------------------------------------------------
-- Admin: al cambiar transportista, limpiar recogidas y sub_orders.
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
-- Transportista: confirma retiro en almacén del importador.
-- ---------------------------------------------------------------------------
create or replace function public.transportista_marca_recogida_en_almacen(
  p_request_id uuid,
  p_sub_order_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_master boolean;
  v_assigned uuid;
  v_st text;
  v_aliado uuid;
  v_owner uuid;
  n int;
  v_imp_name text;
  v_body text;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  ) then
    raise exception 'Solo el transportista asignado puede registrar la recogida.';
  end if;

  select
    coalesce(tr.is_master_order, false),
    tr.assigned_transportista_id,
    tr.status,
    tr.aliado_id,
    tr.owner_id
  into v_master, v_assigned, v_st, v_aliado, v_owner
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;
  if v_assigned is null or v_assigned is distinct from auth.uid() then
    raise exception 'Este pedido no está asignado a usted.';
  end if;
  if v_st is distinct from 'en_transito' then
    raise exception 'Solo puede confirmar recogida mientras el pedido está en tránsito.';
  end if;

  if v_master then
    if p_sub_order_id is null then
      raise exception 'Indique el sub-pedido (tramo / importador) donde retiró la carga.';
    end if;
    update public.sub_orders so
    set
      transportista_recogida_almacen_at = now(),
      updated_at = now()
    where so.id = p_sub_order_id
      and so.parent_order_id = p_request_id
      and so.transportista_recogida_almacen_at is null;

    get diagnostics n = row_count;
    if n = 0 then
      raise exception
        'No se pudo registrar. Verifique el tramo o si ya estaba marcado como recogido.';
    end if;

    select p.business_name
    into v_imp_name
    from public.sub_orders so
    join public.profiles p on p.id = so.importador_id
    where so.id = p_sub_order_id;

    v_body := format(
      'El transportista confirmó retiro de carga en almacén de %s.',
      coalesce(nullif(trim(v_imp_name), ''), 'importador')
    );
  else
    if p_sub_order_id is not null then
      raise exception 'Este pedido no usa sub-pedidos; no indique tramo.';
    end if;
    update public.transaction_requests tr
    set
      transportista_recogida_almacen_at = now(),
      updated_at = now()
    where tr.id = p_request_id
      and tr.transportista_recogida_almacen_at is null;

    get diagnostics n = row_count;
    if n = 0 then
      raise exception
        'No se pudo registrar. Verifique que el pedido esté en tránsito y sin recogida previa.';
    end if;

    v_body := 'El transportista confirmó retiro de carga en almacén del importador.';
  end if;

  if v_aliado is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Recogida en almacén',
      v_body,
      'envio',
      p_request_id::text
    );
  end if;

  perform public.notify_to_all_admins(
    'Recogida en almacén',
    v_body,
    'envio',
    p_request_id::text
  );

  perform public.notify_tr_importer_recipients(
    p_request_id,
    v_master,
    v_owner,
    'Recogida en almacén',
    v_body,
    'envio',
    p_request_id::text
  );
end;
$$;

revoke all on function public.transportista_marca_recogida_en_almacen(uuid, uuid) from public;
grant execute on function public.transportista_marca_recogida_en_almacen(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: transportista asignado ve sub_orders del pedido
-- ---------------------------------------------------------------------------
drop policy if exists "sub_orders_select_transportista_assigned" on public.sub_orders;
create policy "sub_orders_select_transportista_assigned"
on public.sub_orders
for select
to authenticated
using (
  exists (
    select 1 from public.transaction_requests tr
    where tr.id = sub_orders.parent_order_id
      and tr.assigned_transportista_id = auth.uid()
  )
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  )
);

drop policy if exists "order_items_select" on public.order_items;
create policy "order_items_select"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1 from public.sub_orders so
    join public.transaction_requests tr on tr.id = so.parent_order_id
    where so.id = order_items.sub_order_id
      and (
        so.aliado_id = auth.uid()
        or so.importador_id = auth.uid()
        or tr.assigned_transportista_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role = 'administrador'
        )
      )
  )
);
