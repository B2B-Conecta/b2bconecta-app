-- =============================================================================
-- MotoConecta — migración baseline única (reemplaza el historial MotoLink).
-- Mantener sincronizado con `supabase/motoconecta/schema.sql` al editar el DDL.
-- =============================================================================
-- MotoConecta — esquema (greenfield, alineado a la app Flutter)
-- =============================================================================
-- Tablas: profiles, products, transaction_requests, transaction_request_messages,
--         notifications (centro de notificaciones + Realtime).
-- No sub_orders, payment_schedule, transportista ni tablas broker MotoLink.
--
-- Orden: SQL Editor en proyecto vacío, o vía `supabase db reset` (migración baseline).
-- =============================================================================

create extension if not exists pgcrypto;

-- Orden de borrado: dependientes primero (no usar DROP TRIGGER antes: en base vacía
-- la tabla aún no existe y Postgres falla aunque el trigger sea IF EXISTS).
drop table if exists public.transaction_request_messages cascade;
drop table if exists public.notifications cascade;
drop table if exists public.messages cascade;
drop table if exists public.transaction_requests cascade;
drop table if exists public.products cascade;
drop table if exists public.profiles cascade;

-- 1. Perfiles
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
  latitude double precision,
  longitude double precision,
  location_updated_at timestamptz,
  created_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

-- 2. Productos (columnas opcionales usadas por PartModel / catálogo)
create table public.products (
  id uuid not null default gen_random_uuid () primary key,
  owner_id uuid references public.profiles (id) on delete set null,
  name text not null,
  sku text not null default ''::text,
  description text,
  compatibility text,
  image_url text,
  category text,
  price_usd numeric(14, 4) not null check (price_usd >= 0),
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index products_owner_idx on public.products (owner_id);
create index products_active_idx on public.products (is_active) where is_active = true;

-- 3. Pedidos directos
create table public.transaction_requests (
  id uuid not null default gen_random_uuid () primary key,
  aliado_id uuid not null references public.profiles (id) on delete restrict,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  product_id uuid references public.products (id) on delete set null,
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
  proveedor_factura_storage_path text,
  proveedor_factura_file_name text,
  proveedor_factura_submitted_at timestamptz,
  tiempo_estimado_envio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transaction_requests_aliado_idx on public.transaction_requests (aliado_id);
create index transaction_requests_importador_idx on public.transaction_requests (importador_id);
create index transaction_requests_status_idx on public.transaction_requests (status);
create index transaction_requests_product_idx on public.transaction_requests (product_id);

-- 4. Chat por pedido (misma API PostgREST que usa Flutter: transaction_request_messages)
create table public.transaction_request_messages (
  id uuid not null default gen_random_uuid () primary key,
  transaction_request_id uuid not null references public.transaction_requests (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_role text not null
    check (
      author_role = any (
        array[
          'aliado'::text,
          'importador'::text,
          'administrador'::text,
          'transportista'::text
        ]
      )
    ),
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index transaction_request_messages_tr_idx on public.transaction_request_messages (
  transaction_request_id,
  created_at desc
);

-- 5. Notificaciones in-app
create table public.notifications (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'mensaje',
  is_read boolean not null default false,
  related_id text,
  created_at timestamptz not null default now ()
);

create index notifications_user_created_idx on public.notifications (user_id, created_at desc);

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
execute function public.set_transaction_requests_updated_at ();

-- Notificación al destinatario cuando hay mensaje en el hilo del pedido
create or replace function public.mc_notify_trm_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
begin
  select tr.aliado_id, tr.importador_id
    into v_aliado, v_imp
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' and v_imp is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_imp,
      'Nuevo mensaje',
      'Tiene un nuevo mensaje en un pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'importador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje del importador',
      'Tiene un nuevo mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje',
      'El equipo dejó un mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
    if v_imp is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_imp,
        'Nuevo mensaje',
        'El equipo dejó un mensaje en un pedido.',
        'mensaje',
        new.transaction_request_id::text
      );
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_mc_notify_trm_insert
after insert on public.transaction_request_messages
for each row
execute function public.mc_notify_trm_insert ();

-- Realtime (ignora error si la publicación no existe en entornos mínimos)
do $$
begin
  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.transaction_request_messages;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.transaction_requests enable row level security;
alter table public.transaction_request_messages enable row level security;
alter table public.notifications enable row level security;

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

create policy trm_select_participants
  on public.transaction_request_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id = transaction_request_messages.transaction_request_id
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

create policy trm_insert_participants
  on public.transaction_request_messages for insert
  to authenticated
  with check (
    author_id = auth.uid ()
    and exists (
      select 1 from public.transaction_requests tr
      where tr.id = transaction_request_id
        and (
          (tr.aliado_id = auth.uid () and author_role = 'aliado')
          or (tr.importador_id = auth.uid () and author_role = 'importador')
          or (
            exists (
              select 1 from public.profiles p
              where p.id = auth.uid () and p.role = 'administrador'
            )
            and author_role = 'administrador'
          )
        )
    )
  );

create policy notifications_select_own
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid ());

create policy notifications_update_own
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid ())
  with check (user_id = auth.uid ());

create policy notifications_delete_own
  on public.notifications for delete
  to authenticated
  using (user_id = auth.uid ());

-- Permisos API (PostgREST)
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.transaction_requests to authenticated;
grant select, insert, update, delete on public.transaction_request_messages to authenticated;
grant select, update, delete on public.notifications to authenticated;

grant all on public.profiles to service_role;
grant all on public.products to service_role;
grant all on public.transaction_requests to service_role;
grant all on public.transaction_request_messages to service_role;
grant all on public.notifications to service_role;

-- Storage: facturas de pedido (bucket order-invoices + RLS)
insert into storage.buckets (id, name, public)
values ('order-invoices', 'order-invoices', false)
on conflict (id) do nothing;

drop policy if exists "order_inv_select_participants" on storage.objects;
create policy "order_inv_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
);

drop policy if exists "order_inv_insert_owner" on storage.objects;
create policy "order_inv_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_update_owner" on storage.objects;
create policy "order_inv_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
)
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_delete_owner" on storage.objects;
create policy "order_inv_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);
