-- Al marcar entregado: descontar stock del producto y mantener bump de credit_score en un solo disparador.

drop trigger if exists tr_transaction_requests_delivery_credit
  on public.transaction_requests;

drop function if exists public.transaction_requests_bump_credit_on_delivery();

create or replace function public.transaction_requests_on_entregado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if new.status = 'entregado' and (old.status is distinct from 'entregado') then
    update public.products p
    set stock = p.stock - new.cantidad
    where p.id = new.product_id
      and p.owner_id = new.owner_id
      and p.stock >= new.cantidad;
    get diagnostics n = row_count;
    if n = 0 then
      raise exception 'Stock insuficiente para marcar entregado.';
    end if;

    update public.profiles
    set credit_score = least(coalesce(credit_score, 100) + 2, 100)
    where id = new.aliado_id
      and role = 'aliado';
  end if;
  return new;
end;
$$;

create trigger tr_transaction_requests_on_entregado
  after update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_on_entregado();
