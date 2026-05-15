-- Inventario B2B: SKU, categoría, modo pausa; mensajes por producto.
-- Ejecutar en Supabase SQL Editor (o migraciones) tras revisar.

alter table public.products
  add column if not exists sku text,
  add column if not exists is_active boolean not null default true,
  add column if not exists category text;

-- Un SKU por importador (dueño).
create unique index if not exists products_owner_sku_unique
  on public.products (owner_id, sku)
  where sku is not null and btrim(sku) <> '';

update public.products
set sku = 'ML-' || replace(id::text, '-', '')
where sku is null or btrim(sku) = '';

-- Aliados solo ven productos activos; el dueño ve los suyos aunque estén pausados.
drop policy if exists "products_select_authenticated" on public.products;
create policy "products_select_authenticated"
on public.products
for select
to authenticated
using (is_active = true or owner_id = auth.uid());

-- Mensajes ligados a producto (negociación).
create table if not exists public.product_messages (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists product_messages_product_id_idx
  on public.product_messages (product_id);
create index if not exists product_messages_created_at_idx
  on public.product_messages (created_at desc);

alter table public.product_messages enable row level security;

drop policy if exists "product_messages_select" on public.product_messages;
create policy "product_messages_select"
on public.product_messages
for select
to authenticated
using (
  exists (
    select 1 from public.products p
    where p.id = product_messages.product_id
      and (p.owner_id = auth.uid() or product_messages.sender_id = auth.uid())
  )
);

drop policy if exists "product_messages_insert" on public.product_messages;
create policy "product_messages_insert"
on public.product_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.products p
    where p.id = product_messages.product_id
  )
);
