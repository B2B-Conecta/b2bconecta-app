-- Hotfix: FOR UPDATE con LEFT JOIN requiere "FOR UPDATE OF tr" (PostgreSQL).
-- Re-aplica RPCs ya desplegadas sin ese detalle. Idempotente.

create or replace function public.aliado_cancela_pedido_pendiente (
  p_request_id uuid,
  p_motivo text
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
  v_product text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'aliado' then
    raise exception 'Solo el aliado puede cancelar este pedido de esta forma';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Debe indicar un motivo de al menos 3 caracteres';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    coalesce(pr.name, 'Pedido')
    into v_aliado, v_owner, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_aliado is distinct from v_uid then
    raise exception 'Este pedido no corresponde a su cuenta';
  end if;

  if v_status is distinct from 'pendiente' then
    raise exception 'Solo puede cancelar mientras el pedido está pendiente';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    cancelado_por_aliado = true,
    aliado_cancelacion_motivo = v_motivo,
    importador_cancelacion_motivo = null,
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
    format('Pedido cancelado por el aliado. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_owner,
      'Pedido cancelado por el aliado',
      format('El aliado canceló "%s". Revisa el motivo en el detalle del pedido.', v_product),
      'envio',
      p_request_id
    );

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    p.id,
    'Cancelación por aliado',
    format('El aliado canceló "%s". Revisa seguimiento y motivo.', v_product),
    'supervision',
    p_request_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

grant execute on function public.aliado_cancela_pedido_pendiente (uuid, text)
  to authenticated;

create or replace function public.importer_propone_ajuste_cantidad (
  p_request_id uuid,
  p_offered_qty integer,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_owner uuid;
  v_status text;
  v_curr_qty integer;
  v_adj text;
  v_off integer := p_offered_qty;
  v_note text := btrim(coalesce(p_note, ''));
  v_product text;
  v_aliado uuid;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo el importador puede proponer el ajuste';
  end if;

  if p_request_id is null or v_off is null or v_off < 1 then
    raise exception 'Cantidad ofrecida inválida';
  end if;

  select
    tr.importador_id,
    tr.aliado_id,
    tr.status,
    tr.cantidad,
    coalesce(tr.qty_adjustment_status, ''),
    coalesce(pr.name, 'Pedido')
  into v_owner, v_aliado, v_status, v_curr_qty, v_adj, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_owner is distinct from v_uid then
    raise exception 'Este pedido no pertenece a su inventario';
  end if;

  if v_status is distinct from 'pendiente' then
    raise exception 'Solo se puede proponer ajuste mientras el pedido está pendiente';
  end if;

  if v_adj = 'pendiente_aliado' then
    raise exception 'Ya hay una propuesta pendiente de respuesta del aliado';
  end if;

  if v_curr_qty <= 1 then
    raise exception 'No aplica ajuste por cantidad en este pedido';
  end if;

  if v_off >= v_curr_qty then
    raise exception 'La cantidad ofrecida debe ser menor que la solicitada';
  end if;

  update public.transaction_requests
  set
    qty_adjustment_status = 'pendiente_aliado',
    qty_adjustment_offered = v_off,
    qty_adjustment_note = nullif(v_note, ''),
    qty_adjustment_solicitada_snapshot = v_curr_qty,
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
    'importador',
    format(
      'Propuesta formal de cantidad: de %s uds solicitadas ofrecemos %s uds.%s',
      v_curr_qty,
      v_off,
      case
        when length(v_note) > 0 then format(' Nota: %s', v_note)
        else ''
      end
    )
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_aliado,
      'Ajuste de cantidad pendiente',
      format(
        'El proveedor propuso otra cantidad para «%s». Revise la ficha y acepte o rechace.',
        v_product
      ),
      'envio',
      p_request_id
    );
end;
$$;

grant execute on function public.importer_propone_ajuste_cantidad (uuid, integer, text)
  to authenticated;

-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- Al cancelar por importador, limpiar propuestas de cantidad abiertas.
create or replace function public.importer_cancela_pedido_en_gestion (
  p_request_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_owner uuid;
  v_aliado uuid;
  v_status text;
  v_product text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo el importador puede cancelar este pedido';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Debe indicar un motivo de al menos 3 caracteres';
  end if;

  select
    tr.importador_id,
    tr.aliado_id,
    tr.status,
    coalesce(pr.name, 'Pedido')
    into v_owner, v_aliado, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_owner is distinct from v_uid then
    raise exception 'Este pedido no pertenece a su inventario';
  end if;

  if v_status not in ('pendiente', 'en_preparacion', 'pedido_listo') then
    raise exception
      'Solo se puede cancelar mientras el pedido está pendiente, en preparación o listo para despacho';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    importador_cancelacion_motivo = v_motivo,
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
    'importador',
    format('Pedido cancelado por proveedor. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_aliado,
      'Pedido cancelado por el proveedor',
      format('El proveedor canceló "%s". Revisa el motivo en el detalle del pedido.', v_product),
      'envio',
      p_request_id
    );

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    p.id,
    'Cancelación por proveedor',
    format('El importador canceló "%s". Revisa seguimiento y motivo.', v_product),
    'supervision',
    p_request_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

grant execute on function public.importer_cancela_pedido_en_gestion (uuid, text)
  to authenticated;
