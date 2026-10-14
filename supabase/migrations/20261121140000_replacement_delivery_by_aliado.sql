-- El proveedor marca el cambio en tránsito.
-- La tienda confirma la recepción, igual que en el pedido original.

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
  v_name text;
  v_notify uuid;
  v_title text;
  v_body text;
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

  if v_row.status = 'pendiente_retiro' and v_next = 'en_transito' then
    if v_tr.importador_id is distinct from v_uid then
      raise exception 'Solo el proveedor puede marcar el cambio en tránsito.';
    end if;
  elsif v_row.status = 'en_transito' and v_next = 'entregado' then
    if v_tr.aliado_id is distinct from v_uid then
      raise exception 'Solo la tienda puede confirmar que recibió el cambio.';
    end if;
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

  if v_next = 'en_transito' then
    select coalesce(nullif(btrim(p.business_name), ''), 'Su proveedor')
      into v_name
    from public.profiles p
    where p.id = v_tr.importador_id;
    if v_name is null or btrim(v_name) = '' then
      v_name := 'Su proveedor';
    end if;
    v_notify := v_tr.aliado_id;
    v_title := v_name || ' · Cambio en tránsito';
    v_body := v_name || ': el cambio de producto va en camino.';
  else
    select coalesce(nullif(btrim(p.business_name), ''), 'La tienda')
      into v_name
    from public.profiles p
    where p.id = v_tr.aliado_id;
    if v_name is null or btrim(v_name) = '' then
      v_name := 'La tienda';
    end if;
    v_notify := v_tr.importador_id;
    v_title := v_name || ' · Cambio recibido';
    v_body := v_name || ' confirmó la recepción del cambio de producto.';
  end if;

  if v_notify is not null then
    perform public.mc_insert_notification (
      v_notify,
      v_title,
      v_body,
      'pedido',
      public.mc_tr_notif_anchor_id (v_tr)::text
    );
  end if;

  return jsonb_build_object('id', v_row.id, 'status', v_next);
end;
$$;

revoke all on function public.advance_replacement_order (uuid, text) from public;
grant execute on function public.advance_replacement_order (uuid, text) to authenticated;

create or replace function public.importer_aliado_credit_balances ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'aliado_id', n.aliado_id,
        'aliado_name', coalesce(nullif(btrim(p.business_name), ''), 'Tienda'),
        'remaining', n.remaining
      )
      order by p.business_name
    ),
    '[]'::jsonb
  )
  from (
    select aliado_id, sum(remaining) as remaining
    from public.aliado_importer_credit_notes
    where importador_id = auth.uid()
      and status = 'vigente'
      and remaining > 0
    group by aliado_id
  ) n
  join public.profiles p on p.id = n.aliado_id;
$$;

revoke all on function public.importer_aliado_credit_balances () from public;
grant execute on function public.importer_aliado_credit_balances () to authenticated;
