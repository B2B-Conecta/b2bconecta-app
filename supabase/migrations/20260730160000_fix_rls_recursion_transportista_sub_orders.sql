-- Evita recursión RLS (42P17): políticas de sub_orders/order_items no deben leer transaction_requests
-- cuando el cliente hace SELECT en transaction_requests con embed de sub_orders/order_items.

alter table public.sub_orders
  add column if not exists assigned_transportista_id uuid
    references public.profiles (id) on delete set null;

comment on column public.sub_orders.assigned_transportista_id is
  'Copia de transaction_requests.assigned_transportista_id; evita JOIN a transaction_requests en RLS.';

update public.sub_orders so
set assigned_transportista_id = tr.assigned_transportista_id
from public.transaction_requests tr
where tr.id = so.parent_order_id
  and so.assigned_transportista_id is distinct from tr.assigned_transportista_id;

-- Inserción sub_orders: copiar transportista asignado del maestro (puede ser null).
create or replace function public.sub_orders_set_aliado_from_parent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_t uuid;
begin
  if new.aliado_id is null or new.assigned_transportista_id is null then
    select tr.aliado_id, tr.assigned_transportista_id
    into v_aliado, v_t
    from public.transaction_requests tr
    where tr.id = new.parent_order_id;
    if new.aliado_id is null then
      new.aliado_id := v_aliado;
    end if;
    if new.assigned_transportista_id is null then
      new.assigned_transportista_id := v_t;
    end if;
  end if;
  if new.aliado_id is null then
    raise exception 'sub_orders: no se pudo resolver aliado_id del pedido maestro';
  end if;
  return new;
end;
$$;

-- Propagar cambios de asignación desde el maestro a los tramos.
create or replace function public.sub_orders_sync_assigned_transportista_from_parent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.assigned_transportista_id is distinct from old.assigned_transportista_id then
    update public.sub_orders so
    set
      assigned_transportista_id = new.assigned_transportista_id,
      updated_at = now()
    where so.parent_order_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_au_sync_sub_transportista
  on public.transaction_requests;
create trigger tr_transaction_requests_au_sync_sub_transportista
after update of assigned_transportista_id on public.transaction_requests
for each row
when (old.assigned_transportista_id is distinct from new.assigned_transportista_id)
execute function public.sub_orders_sync_assigned_transportista_from_parent();

drop policy if exists "sub_orders_select_transportista_assigned" on public.sub_orders;
create policy "sub_orders_select_transportista_assigned"
on public.sub_orders
for select
to authenticated
using (
  assigned_transportista_id = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  )
);

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
        or so.assigned_transportista_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role = 'administrador'
        )
      )
  )
);
