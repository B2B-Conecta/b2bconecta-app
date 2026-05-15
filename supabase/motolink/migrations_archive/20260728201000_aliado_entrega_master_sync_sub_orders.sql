-- Al confirmar entrega del pedido maestro por parte del aliado,
-- sincronizar sub-pedidos multi-importador a `entregado` para que
-- el panel del importador no siga mostrando `en_ruta`.

create or replace function public.aliado_marca_pedido_entregado(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  v_is_master boolean;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede confirmar la entrega en su taller.';
  end if;

  update public.transaction_requests tr
  set
    status = 'entregado',
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'en_transito';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo marcar como entregado. Verifique que el pedido esté en tránsito y sea suyo.';
  end if;

  select coalesce(tr.is_master_order, false)
  into v_is_master
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_is_master then
    update public.sub_orders so
    set
      status = 'entregado',
      updated_at = now()
    where so.parent_order_id = p_request_id
      and so.status in ('en_ruta', 'listo', 'preparando');
  end if;
end;
$$;
