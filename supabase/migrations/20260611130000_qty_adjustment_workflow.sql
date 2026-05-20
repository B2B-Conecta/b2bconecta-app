-- Formal workflow: importador propone menor cantidad en `pendiente`; aliado acepta o rechaza.
-- Totales se reescalan en proporción a la cantidad (misma lógica que escala en app).

alter table public.transaction_requests
  add column if not exists qty_adjustment_status text,
  add column if not exists qty_adjustment_offered integer,
  add column if not exists qty_adjustment_note text,
  add column if not exists qty_adjustment_solicitada_snapshot integer;

alter table public.transaction_requests
  add column if not exists cancelado_por_aliado boolean not null default false;

alter table public.transaction_requests
  add column if not exists aliado_cancelacion_motivo text;

alter table public.transaction_requests
  add column if not exists original_checkout_group_id uuid;

comment on column public.transaction_requests.original_checkout_group_id is
  'Auditoría: id del carrito (`checkout_group_id`) antes de desvincular la línea al cancelar o rechazar.';

comment on column public.transaction_requests.qty_adjustment_status is
  'pendiente_aliado | aceptado | rechazado; null si sin propuesta activa.';
comment on column public.transaction_requests.qty_adjustment_offered is
  'Unidades ofrecidas por el importador frente a la solicitud vigente.';
comment on column public.transaction_requests.qty_adjustment_note is
  'Contexto breve visible al aliado.';
comment on column public.transaction_requests.qty_adjustment_solicitada_snapshot is
  'Cantidad solicitada al momento de la propuesta (auditoría).';

alter table public.transaction_requests
  add column if not exists precio_base_aliado_total numeric(14, 4),
  add column if not exists precio_unitario_proveedor numeric(14, 6),
  add column if not exists precio_unitario_aliado numeric(14, 6);

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

drop trigger if exists tr_tr_qty_adj_block_status on public.transaction_requests;

create trigger tr_tr_qty_adj_block_status
before update on public.transaction_requests
for each row
execute function public.tr_block_status_change_while_qty_pending ();

-- -----------------------------------------------------------------------------
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
