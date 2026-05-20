-- Columnas de trazabilidad cancelación aliado (p. ej. migración 20260620120000 en otros entornos).
alter table public.transaction_requests
  add column if not exists cancelado_por_aliado boolean not null default false;

alter table public.transaction_requests
  add column if not exists aliado_cancelacion_motivo text;

alter table public.transaction_requests
  add column if not exists original_checkout_group_id uuid;

-- 1) Columnas de precio usadas por la app y por aliado_responde_ajuste_cantidad (antes no existían en BD).
alter table public.transaction_requests
  add column if not exists precio_base_aliado_total numeric(14, 4),
  add column if not exists precio_unitario_proveedor numeric(14, 6),
  add column if not exists precio_unitario_aliado numeric(14, 6);

comment on column public.transaction_requests.precio_base_aliado_total is
  'Total REF aliado sin recargo efectivo; si null, equivale a precio_total_usd en lógica de negocio.';
comment on column public.transaction_requests.precio_unitario_proveedor is
  'Precio unitario referencia (proveedor / línea).';
comment on column public.transaction_requests.precio_unitario_aliado is
  'Precio unitario REF para el aliado (puede diferir con efectivo).';

update public.transaction_requests t
set precio_base_aliado_total = t.precio_total_usd
where t.precio_base_aliado_total is null;

update public.transaction_requests
set
  precio_unitario_proveedor = round(precio_total_usd / nullif(cantidad, 0)::numeric, 6),
  precio_unitario_aliado = round(
    coalesce(precio_base_aliado_total, precio_total_usd) / nullif(cantidad, 0)::numeric,
    6
  )
where cantidad > 0;

-- 2) Permitir pasar a rechazado con propuesta de cantidad pendiente (cierre al rechazar por aliado).
create or replace function public.tr_block_status_change_while_qty_pending ()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status
     and coalesce(old.qty_adjustment_status, '') = 'pendiente_aliado'
     and new.status is distinct from 'rechazado' then
    raise exception
      'Confirme o rechace primero el ajuste de cantidad que propuso el proveedor.';
  end if;
  return new;
end;
$$;

-- 3) Rechazo de propuesta → pedido cerrado (rechazado); aceptación sin cambio de lógica de totales.
create or replace function public.aliado_responde_ajuste_cantidad (
  p_request_id uuid,
  p_aceptar boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_aliado uuid;
  v_owner uuid;
  v_status text;
  v_adj text;
  v_old_qty integer;
  v_off integer;
  v_total numeric;
  v_base numeric;
  v_ratio numeric;
  v_new_total numeric;
  v_new_base numeric;
  v_product text;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'aliado' then
    raise exception 'Solo el aliado puede responder';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    coalesce(tr.qty_adjustment_status, ''),
    tr.cantidad,
    tr.qty_adjustment_offered,
    tr.precio_total_usd,
    coalesce(tr.precio_base_aliado_total, tr.precio_total_usd),
    coalesce(pr.name, 'Pedido')
  into
    v_aliado,
    v_owner,
    v_status,
    v_adj,
    v_old_qty,
    v_off,
    v_total,
    v_base,
    v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_aliado is distinct from v_uid then
    raise exception 'Este pedido no es suyo';
  end if;

  if v_adj is distinct from 'pendiente_aliado' then
    raise exception 'No hay propuesta de cantidad pendiente';
  end if;

  if v_off is null or v_off < 1 or v_old_qty is null or v_old_qty < 1 then
    raise exception 'Datos de propuesta inconsistentes';
  end if;

  if not p_aceptar then
    update public.transaction_requests
    set
      status = 'rechazado',
      at_rechazado = now(),
      cancelado_por_aliado = true,
      aliado_cancelacion_motivo =
        'Rechazo de la propuesta de ajuste de cantidad del proveedor (pedido cerrado).',
      importador_cancelacion_motivo = null,
      qty_adjustment_status = null,
      qty_adjustment_offered = null,
      qty_adjustment_note = null,
      qty_adjustment_solicitada_snapshot = null,
      original_checkout_group_id = coalesce(original_checkout_group_id, checkout_group_id),
      checkout_group_id = null,
      updated_at = now()
    where id = p_request_id;

    insert into public.transaction_request_messages (
      transaction_request_id,
      author_id,
      author_role,
      body
    )
    values (
      p_request_id,
      v_uid,
      'aliado',
      format(
        'Pedido cerrado: rechazó la oferta de %s uds (había solicitado %s uds).',
        v_off,
        v_old_qty
      )
    );

    insert into public.notifications (user_id, title, body, type, related_id)
    values
      (
        v_owner,
        'Pedido cerrado · cantidad no acordada',
        format(
          'El aliado no aceptó la oferta de %s uds para «%s». El pedido quedó cancelado.',
          v_off,
          v_product
        ),
        'envio',
        p_request_id
      );

    insert into public.notifications (user_id, title, body, type, related_id)
    select
      p.id,
      'Pedido cerrado (rechazo de cantidad)',
      format('Aliado cerró el pedido tras rechazar ajuste a %s uds en «%s».', v_off, v_product),
      'supervision',
      p_request_id
    from public.profiles p
    where p.role = 'administrador';
    return;
  end if;

  v_ratio := (v_off::numeric / v_old_qty::numeric);
  v_new_total := round(v_total * v_ratio, 4);
  v_new_base := round(coalesce(v_base, v_total) * v_ratio, 4);

  update public.transaction_requests
  set
    cantidad = v_off,
    precio_total_usd = v_new_total,
    precio_base_aliado_total = v_new_base,
    precio_unitario_proveedor = round(v_new_total / nullif(v_off, 0)::numeric, 6),
    precio_unitario_aliado = round(v_new_base / nullif(v_off, 0)::numeric, 6),
    qty_adjustment_status = 'aceptado',
    updated_at = now()
  where id = p_request_id;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    'aliado',
    format(
      'Aceptó la nueva cantidad: %s uds (total referencia %s REF).',
      v_off,
      round(v_new_total::numeric, 4)::text
    )
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_owner,
      'Ajuste de cantidad aceptado',
      format('El aliado aceptó %s uds en «%s».', v_off, v_product),
      'envio',
      p_request_id
    );
end;
$$;

grant execute on function public.aliado_responde_ajuste_cantidad (uuid, boolean)
  to authenticated;
