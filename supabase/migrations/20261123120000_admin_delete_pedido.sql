-- Un administrador puede borrar una línea de pedido, o todo el carrito si lo confirma.
-- Limpia postventa y notas que no tienen ON DELETE antes de borrar la fila.

create or replace function public.admin_delete_pedido (
  p_request_id uuid,
  p_delete_checkout_group boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_ids uuid[];
  v_count integer;
begin
  perform public._assert_administrador ();

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  select tr.checkout_group_id
    into v_group
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if coalesce(p_delete_checkout_group, false) and v_group is not null then
    select array_agg(tr.id)
      into v_ids
    from public.transaction_requests tr
    where tr.checkout_group_id = v_group;
  else
    v_ids := array[p_request_id];
  end if;

  perform 1
  from public.transaction_requests tr
  where tr.id = any (v_ids)
  for update;

  delete from public.replacement_orders ro
  where ro.source_transaction_request_id = any (v_ids)
     or ro.caso_id in (
       select c.id
       from public.order_postventa_casos c
       where c.transaction_request_id = any (v_ids)
     );

  delete from public.aliado_importer_credit_notes n
  where n.caso_id in (
    select c.id
    from public.order_postventa_casos c
    where c.transaction_request_id = any (v_ids)
  );

  delete from public.notifications n
  where n.related_id in (
    select t.id::text
    from unnest(v_ids) as t(id)
  );

  delete from public.transaction_requests tr
  where tr.id = any (v_ids);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_delete_pedido (uuid, boolean) from public;
grant execute on function public.admin_delete_pedido (uuid, boolean) to authenticated;

comment on function public.admin_delete_pedido (uuid, boolean) is
  'Administrador: borra una línea de pedido. Con p_delete_checkout_group borra el carrito completo.';
