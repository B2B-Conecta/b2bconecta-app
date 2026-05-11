-- =============================================================================
-- MotoConecta — esquema inicial (solo proyecto Supabase greenfield)
-- =============================================================================
-- Ejecutar una vez antes de supabase/seed.sql en base vacía o dedicada.
-- No mezclar con migraciones legacy de MotoLink en el mismo database.
-- =============================================================================

create extension if not exists pgcrypto;

-- Orden: dependientes primero
drop table if exists public.messages cascade;
drop table if exists public.transaction_requests cascade;
drop table if exists public.products cascade;
drop table if exists public.profiles cascade;

-- 1. Perfiles (sin transportista)
create table public.profiles (
  id uuid not null references auth.users (id) on delete cascade primary key,
  business_name text,
  rif text unique,
  role text not null
    check (role = any (array['importador'::text, 'aliado'::text, 'administrador'::text])),
  phone text,
  logo_storage_path text,
  estado text,
  ciudad text,
  direccion text,
  fiscal_maps_url text,
  created_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

-- 2. Productos
create table public.products (
  id uuid not null default gen_random_uuid () primary key,
  owner_id uuid references public.profiles (id) on delete set null,
  name text not null,
  price_usd numeric(14, 4) not null check (price_usd >= 0),
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index products_owner_idx on public.products (owner_id);
create index products_active_idx on public.products (is_active) where is_active = true;

-- 3. Pedidos directos + comisión 5 % (generada)
create table public.transaction_requests (
  id uuid not null default gen_random_uuid () primary key,
  aliado_id uuid not null references public.profiles (id) on delete restrict,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  status text not null default 'pendiente'
    check (
      status = any (
        array[
          'pendiente'::text,
          'en_preparacion'::text,
          'enviado'::text,
          'entregado'::text,
          'rechazado'::text
        ]
      )
    ),
  cantidad integer not null check (cantidad > 0),
  precio_total_usd numeric(14, 4) not null check (precio_total_usd >= 0),
  comision_motoconecta numeric(14, 4)
    generated always as (precio_total_usd * 0.05) stored,
  factura_url text,
  tiempo_estimado_envio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transaction_requests_aliado_idx on public.transaction_requests (aliado_id);
create index transaction_requests_importador_idx on public.transaction_requests (importador_id);
create index transaction_requests_status_idx on public.transaction_requests (status);

-- 4. Chat por pedido
create table public.messages (
  id uuid not null default gen_random_uuid () primary key,
  transaction_id uuid not null references public.transaction_requests (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create index messages_transaction_idx on public.messages (transaction_id, created_at desc);

-- updated_at en pedidos
create or replace function public.set_transaction_requests_updated_at ()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger transaction_requests_set_updated_at
before update on public.transaction_requests
for each row
execute procedure public.set_transaction_requests_updated_at ();

-- ---------------------------------------------------------------------------
-- RLS (app con anon + JWT autenticado)
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.transaction_requests enable row level security;
alter table public.messages enable row level security;

-- Perfiles: lectura para usuarios autenticados; solo el dueño actualiza el suyo
create policy profiles_select_authenticated
  on public.profiles for select
  to authenticated
  using (true);

create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = auth.uid ())
  with check (id = auth.uid ());

create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid ());

-- Productos: catálogo activo para todos; el importador gestiona los suyos
create policy products_select_marketplace
  on public.products for select
  to authenticated
  using (is_active = true or owner_id = auth.uid ());

create policy products_insert_owner
  on public.products for insert
  to authenticated
  with check (owner_id = auth.uid ());

create policy products_update_owner
  on public.products for update
  to authenticated
  using (owner_id = auth.uid ())
  with check (owner_id = auth.uid ());

create policy products_delete_owner
  on public.products for delete
  to authenticated
  using (owner_id = auth.uid ());

-- Pedidos: aliado, importador del pedido o admin
create policy tr_select_participants
  on public.transaction_requests for select
  to authenticated
  using (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );

create policy tr_insert_aliado
  on public.transaction_requests for insert
  to authenticated
  with check (
    aliado_id = auth.uid ()
    and exists (
      select 1 from public.profiles p
      where p.id = importador_id and p.role = 'importador'
    )
  );

create policy tr_update_participants
  on public.transaction_requests for update
  to authenticated
  using (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
  with check (
    aliado_id = auth.uid ()
    or importador_id = auth.uid ()
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  );

-- Mensajes: solo participantes del pedido (o admin lectura)
create policy messages_select_participants
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id = messages.transaction_id
        and (
          tr.aliado_id = auth.uid ()
          or tr.importador_id = auth.uid ()
          or exists (
            select 1 from public.profiles p
            where p.id = auth.uid () and p.role = 'administrador'
          )
        )
    )
  );

create policy messages_insert_participants
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid ()
    and exists (
      select 1 from public.transaction_requests tr
      where tr.id = transaction_id
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
  );

-- Permisos API (PostgREST)
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.transaction_requests to authenticated;
grant select, insert, update, delete on public.messages to authenticated;

grant all on public.profiles to service_role;
grant all on public.products to service_role;
grant all on public.transaction_requests to service_role;
grant all on public.messages to service_role;
