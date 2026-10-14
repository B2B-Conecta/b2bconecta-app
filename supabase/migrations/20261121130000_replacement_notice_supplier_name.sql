-- El aviso del cambio nombra al proveedor, no solo el estado del envío.

create or replace function public.advance_replacement_order (
  p_caso_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.replacement_orders%rowtype;
  v_next text := lower(btrim(coalesce(p_status, '')));
  v_tr public.transaction_requests%rowtype;
  v_supplier text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_next not in ('en_transito', 'entregado') then
    raise exception 'Indique si el cambio va en tránsito o ya se entregó.';
  end if;

  select *
    into v_row
  from public.replacement_orders r
  where r.caso_id = p_caso_id
  for update;

  if not found then
    raise exception 'No hay un cambio de producto para este caso.';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = v_row.source_transaction_request_id;

  if v_tr.importador_id is distinct from v_uid then
    raise exception 'Solo el proveedor puede actualizar el envío del cambio.';
  end if;

  if v_row.status = 'pendiente_retiro' and v_next = 'en_transito' then
    null;
  elsif v_row.status = 'en_transito' and v_next = 'entregado' then
    if v_row.product_id is not null then
      update public.products
        set
          stock = stock - v_row.qty,
          stock_reserved = stock_reserved - v_row.qty
        where id = v_row.product_id
          and stock >= v_row.qty
          and stock_reserved >= v_row.qty;
      if not found then
        raise exception 'No se pudo descontar el stock del cambio.';
      end if;
    end if;
  else
    raise exception 'Ese paso no corresponde al estado actual del cambio.';
  end if;

  update public.replacement_orders
    set status = v_next, updated_at = now()
    where id = v_row.id;

  select coalesce(nullif(btrim(p.business_name), ''), 'Su proveedor')
    into v_supplier
  from public.profiles p
  where p.id = v_tr.importador_id;

  if v_supplier is null or btrim(v_supplier) = '' then
    v_supplier := 'Su proveedor';
  end if;

  perform public.mc_insert_notification (
    v_tr.aliado_id,
    case v_next
      when 'entregado' then v_supplier || ' · Cambio entregado'
      else v_supplier || ' · Cambio en tránsito'
    end,
    case v_next
      when 'entregado' then v_supplier || ' entregó el cambio de producto.'
      else v_supplier || ': el cambio de producto va en camino.'
    end,
    'pedido',
    public.mc_tr_notif_anchor_id (v_tr)::text
  );

  return jsonb_build_object('id', v_row.id, 'status', v_next);
end;
$$;

revoke all on function public.advance_replacement_order (uuid, text) from public;
grant execute on function public.advance_replacement_order (uuid, text) to authenticated;
