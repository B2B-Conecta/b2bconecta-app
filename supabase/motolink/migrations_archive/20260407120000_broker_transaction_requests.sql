-- Intermediación broker: solicitudes de pedido (reemplaza product_messages).

alter table public.profiles
  add column if not exists credit_score integer not null default 100;
alter table public.profiles
  add column if not exists credit_limit numeric(14, 2);

alter table public.profiles
  drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('importador', 'aliado', 'administrador'));

-- CASCADE elimina políticas RLS asociadas.
drop table if exists public.product_messages cascade;

create table if not exists public.transaction_requests (
  id uuid primary key default gen_random_uuid(),
  aliado_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'aprobado_admin', 'rechazado', 'completado')),
  cantidad integer not null check (cantidad > 0),
  precio_unitario_proveedor numeric(14, 4) not null,
  precio_unitario_aliado numeric(14, 4) not null,
  precio_total numeric(14, 2) not null,
  notas_admin text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists transaction_requests_aliado_id_idx
  on public.transaction_requests (aliado_id);
create index if not exists transaction_requests_owner_id_idx
  on public.transaction_requests (owner_id);
create index if not exists transaction_requests_product_id_idx
  on public.transaction_requests (product_id);
create index if not exists transaction_requests_status_idx
  on public.transaction_requests (status);
create index if not exists transaction_requests_created_at_idx
  on public.transaction_requests (created_at desc);

alter table public.transaction_requests enable row level security;

drop policy if exists "tr_select_aliado_own" on public.transaction_requests;
create policy "tr_select_aliado_own"
on public.transaction_requests
for select
to authenticated
using (aliado_id = auth.uid());

drop policy if exists "tr_select_importer_approved" on public.transaction_requests;
create policy "tr_select_importer_approved"
on public.transaction_requests
for select
to authenticated
using (
  owner_id = auth.uid()
  and status = 'aprobado_admin'
);

drop policy if exists "tr_select_admin_all" on public.transaction_requests;
create policy "tr_select_admin_all"
on public.transaction_requests
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  )
);

drop policy if exists "tr_insert_aliado" on public.transaction_requests;
create policy "tr_insert_aliado"
on public.transaction_requests
for insert
to authenticated
with check (
  aliado_id = auth.uid()
  and exists (
    select 1 from public.products p
    where p.id = transaction_requests.product_id
      and p.owner_id = transaction_requests.owner_id
  )
);

drop policy if exists "tr_update_admin" on public.transaction_requests;
create policy "tr_update_admin"
on public.transaction_requests
for update
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  )
)
with check (
  exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'administrador'
  )
);
