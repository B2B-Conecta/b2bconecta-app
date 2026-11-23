-- El detalle web del importador puede proponer el mínimo del proveedor
-- (o 5 uds) aunque la tienda haya pedido 1 unidad, o una cantidad mayor.
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

  if v_off = v_curr_qty then
    raise exception 'La cantidad ofrecida debe ser distinta de la solicitada';
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
      'Propuesta formal de cantidad: de %s uds solicitadas a %s uds.%s',
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
