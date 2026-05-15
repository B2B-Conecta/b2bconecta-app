-- Recursión infinita en RLS: tr_select_importer_via_sub_order lee sub_orders;
-- sub_orders_select_aliado y order_items_select leían transaction_requests → ciclo.
-- Solución: aliado_id denormalizado en sub_orders + trigger SECURITY DEFINER;
-- políticas de sub_orders / order_items sin subconsulta a transaction_requests.

alter table public.sub_orders
  add column if not exists aliado_id uuid references public.profiles (id) on delete cascade;

comment on column public.sub_orders.aliado_id is
  'Copia del aliado del pedido maestro; evita JOIN a transaction_requests en políticas RLS.';

-- Rellena aliado_id en inserciones (checkout y futuras) sin tocar el RPC de checkout.
create or replace function public.sub_orders_set_aliado_from_parent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.aliado_id is not null then
    return new;
  end if;
  select tr.aliado_id into new.aliado_id
  from public.transaction_requests tr
  where tr.id = new.parent_order_id;
  if new.aliado_id is null then
    raise exception 'sub_orders: no se pudo resolver aliado_id del pedido maestro';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_sub_orders_bi_set_aliado on public.sub_orders;
create trigger tr_sub_orders_bi_set_aliado
before insert on public.sub_orders
for each row
execute function public.sub_orders_set_aliado_from_parent();

-- Filas ya existentes (si las hay) antes de NOT NULL
update public.sub_orders so
set aliado_id = tr.aliado_id
from public.transaction_requests tr
where tr.id = so.parent_order_id
  and so.aliado_id is null;

alter table public.sub_orders
  alter column aliado_id set not null;

-- Políticas sin leer transaction_requests
drop policy if exists "sub_orders_select_aliado" on public.sub_orders;
create policy "sub_orders_select_aliado"
on public.sub_orders
for select
to authenticated
using (aliado_id = auth.uid());

drop policy if exists "order_items_select" on public.order_items;
create policy "order_items_select"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1 from public.sub_orders so
    where so.id = order_items.sub_order_id
      and (
        so.aliado_id = auth.uid()
        or so.importador_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role = 'administrador'
        )
      )
  )
);
