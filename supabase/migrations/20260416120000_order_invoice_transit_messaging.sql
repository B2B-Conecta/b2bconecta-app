-- Factura del proveedor en preparación; tránsito lo marca MotoLink con ETA en días; mensajes aliado↔MotoLink.

alter table public.transaction_requests
  add column if not exists proveedor_factura_storage_path text,
  add column if not exists proveedor_factura_file_name text,
  add column if not exists proveedor_factura_submitted_at timestamptz,
  add column if not exists transit_eta_days integer,
  add column if not exists transit_eta_set_at timestamptz;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_transit_eta_days_range;

alter table public.transaction_requests
  add constraint transaction_requests_transit_eta_days_range
  check (transit_eta_days is null or (transit_eta_days >= 1 and transit_eta_days <= 365));

-- ---------------------------------------------------------------------------
-- Mensajes en el pedido (aliado ↔ administrador MotoLink)
-- ---------------------------------------------------------------------------

create table if not exists public.transaction_request_messages (
  id uuid primary key default gen_random_uuid(),
  transaction_request_id uuid not null
    references public.transaction_requests (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete set null,
  author_role text not null,
  body text not null,
  created_at timestamptz not null default now(),
  constraint trm_author_role_check
    check (author_role in ('aliado', 'administrador')),
  constraint trm_body_nonempty check (char_length(trim(body)) > 0)
);

create index if not exists transaction_request_messages_request_idx
  on public.transaction_request_messages (transaction_request_id, created_at);

alter table public.transaction_request_messages enable row level security;

drop policy if exists "trm_select_participants" on public.transaction_request_messages;
create policy "trm_select_participants"
on public.transaction_request_messages
for select
to authenticated
using (
  exists (
    select 1 from public.transaction_requests tr
    where tr.id = transaction_request_messages.transaction_request_id
      and (tr.aliado_id = auth.uid() or tr.owner_id = auth.uid())
  )
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

drop policy if exists "trm_insert_aliado" on public.transaction_request_messages;
create policy "trm_insert_aliado"
on public.transaction_request_messages
for insert
to authenticated
with check (
  author_id = auth.uid()
  and author_role = 'aliado'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id = transaction_request_messages.transaction_request_id
      and tr.aliado_id = auth.uid()
  )
);

drop policy if exists "trm_insert_admin" on public.transaction_request_messages;
create policy "trm_insert_admin"
on public.transaction_request_messages
for insert
to authenticated
with check (
  author_id = auth.uid()
  and author_role = 'administrador'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

-- ---------------------------------------------------------------------------
-- Transiciones: solo MotoLink pasa en_preparacion → en_transito (con factura)
-- ---------------------------------------------------------------------------

create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;
      if new.transit_eta_days is null or new.transit_eta_days < 1 then
        raise exception 'Debe indicar transit_eta_days (días estimados de entrega, mín. 1).';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: MotoLink marca en tránsito + días ETA (actualiza timestamps vía trigger)
-- ---------------------------------------------------------------------------

create or replace function public.admin_marca_pedido_en_transito(
  p_request_id uuid,
  p_transit_eta_days integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
  inv text;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden marcar en tránsito';
  end if;

  if p_transit_eta_days is null or p_transit_eta_days < 1 or p_transit_eta_days > 365 then
    raise exception 'Días de tránsito inválidos (use 1 a 365).';
  end if;

  select status, proveedor_factura_storage_path
  into st, inv
  from public.transaction_requests
  where id = p_request_id;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'en_preparacion' then
    raise exception 'Solo pedidos en preparación pueden pasar a en tránsito';
  end if;
  if coalesce(trim(inv), '') = '' then
    raise exception 'El importador debe adjuntar la factura digital antes.';
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = p_transit_eta_days,
    transit_eta_set_at = now(),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_marca_pedido_en_transito(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: facturas de pedido (carpeta = id del pedido)
-- ---------------------------------------------------------------------------

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
        and (tr.aliado_id = auth.uid() or tr.owner_id = auth.uid())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
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
      and tr.owner_id = auth.uid()
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
      and tr.owner_id = auth.uid()
  )
);
