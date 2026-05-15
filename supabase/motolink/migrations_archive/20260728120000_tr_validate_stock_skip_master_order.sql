-- Pedidos maestro (is_master_order): product_id/owner_id nulos; el stock se valida
-- en aliado_checkout_multi_importador y las líneas van a order_items. El trigger
-- legacy de stock no debe ejecutarse en esa fila o falla con
-- "El producto no existe o no corresponde al importador del pedido."

create or replace function public.transaction_requests_validate_stock_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  st integer;
begin
  if coalesce(new.is_master_order, false) = true then
    return new;
  end if;

  select p.stock into st
  from public.products p
  where p.id = new.product_id
    and p.owner_id = new.owner_id;

  if not found then
    raise exception
      'El producto no existe o no corresponde al importador del pedido.';
  end if;

  if new.cantidad > st then
    raise exception '%',
      format(
        'Stock insuficiente: hay %s unidad(es) disponible(s) y solicitó %s.',
        st,
        new.cantidad
      );
  end if;

  return new;
end;
$$;
