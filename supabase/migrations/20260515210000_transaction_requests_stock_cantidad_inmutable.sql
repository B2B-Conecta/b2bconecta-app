-- Stock suficiente al crear el pedido; cantidad fija durante el ciclo; descuento sigue al entregar.

-- ---------------------------------------------------------------------------
-- INSERT: stock del producto >= cantidad (producto debe coincidir con owner_id)
-- ---------------------------------------------------------------------------
create or replace function public.transaction_requests_validate_stock_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  st integer;
begin
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

-- Nombre con prefijo 000 para ejecutarse antes que tr_transaction_requests_check_credit (stock antes que cupo).
drop trigger if exists tr_transaction_requests_000_validate_stock on public.transaction_requests;
create trigger tr_transaction_requests_000_validate_stock
  before insert on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_validate_stock_on_insert();

-- ---------------------------------------------------------------------------
-- UPDATE: no permitir cambiar la cantidad (ni relación con precios fijados al crear)
-- ---------------------------------------------------------------------------
create or replace function public.transaction_requests_disallow_cantidad_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.cantidad is distinct from old.cantidad then
    raise exception
      'La cantidad del pedido no puede modificarse después de creada. '
      'Cancele con MotoLink y cree una nueva solicitud si necesita otra cantidad.';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_immutable_cantidad on public.transaction_requests;
create trigger tr_transaction_requests_immutable_cantidad
  before update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_disallow_cantidad_change();
