-- Documentación KYC aliados: metadatos, bucket privado, verificación admin, bloqueo de pedidos.

alter table public.profiles
  add column if not exists kyc_status text;

update public.profiles
set kyc_status = 'aprobado'
where role = 'aliado' and (kyc_status is null or btrim(kyc_status) = '');

update public.profiles
set kyc_status = null
where role is distinct from 'aliado';

alter table public.profiles
  drop constraint if exists profiles_kyc_status_check;

alter table public.profiles
  add constraint profiles_kyc_status_check
  check (
    kyc_status is null
    or kyc_status in ('pendiente', 'en_revision', 'aprobado', 'rechazado')
  );

create or replace function public.profiles_default_kyc_for_aliado()
returns trigger
language plpgsql
as $$
begin
  if new.role = 'aliado' then
    if new.kyc_status is null then
      new.kyc_status := 'pendiente';
    end if;
  else
    new.kyc_status := null;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_profiles_kyc_default on public.profiles;
create trigger tr_profiles_kyc_default
  before insert or update of role on public.profiles
  for each row
  execute procedure public.profiles_default_kyc_for_aliado();

-- ---------------------------------------------------------------------------
-- Tabla de documentos (paths en Storage)
-- ---------------------------------------------------------------------------

create table if not exists public.profile_documents (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  doc_type text not null,
  storage_path text not null,
  file_name text,
  created_at timestamptz not null default now(),
  constraint profile_documents_profile_doc_unique unique (profile_id, doc_type)
);

create index if not exists profile_documents_profile_id_idx
  on public.profile_documents (profile_id);

alter table public.profile_documents enable row level security;

drop policy if exists "profile_documents_select_own_or_admin" on public.profile_documents;
create policy "profile_documents_select_own_or_admin"
on public.profile_documents
for select
to authenticated
using (
  profile_id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

drop policy if exists "profile_documents_insert_aliado_self" on public.profile_documents;
create policy "profile_documents_insert_aliado_self"
on public.profile_documents
for insert
to authenticated
with check (
  profile_id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'aliado'
  )
);

drop policy if exists "profile_documents_delete_own_aliado" on public.profile_documents;
create policy "profile_documents_delete_own_aliado"
on public.profile_documents
for delete
to authenticated
using (
  profile_id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'aliado'
  )
);

-- ---------------------------------------------------------------------------
-- RPC: broker actualiza estado KYC
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_aliado_kyc_status(
  p_aliado_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar el estado KYC';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;
  if p_status not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado KYC no válido';
  end if;
  update public.profiles
  set kyc_status = p_status
  where id = p_aliado_id;
end;
$$;

grant execute on function public.admin_set_aliado_kyc_status(uuid, text) to authenticated;

-- Aliado: envía carpeta a revisión (desde pendiente o rechazado)
create or replace function public.aliado_submit_kyc_for_review()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
begin
  select kyc_status into st
  from public.profiles
  where id = auth.uid() and role = 'aliado';
  if st is null then
    raise exception 'Perfil aliado no encontrado';
  end if;
  if st not in ('pendiente', 'rechazado') then
    raise exception 'No puede enviar a revisión en este estado';
  end if;
  update public.profiles
  set kyc_status = 'en_revision'
  where id = auth.uid() and role = 'aliado';
end;
$$;

grant execute on function public.aliado_submit_kyc_for_review() to authenticated;

-- ---------------------------------------------------------------------------
-- Pedidos: exigir KYC aprobado (además de cupo)
-- ---------------------------------------------------------------------------

create or replace function public.transaction_requests_check_aliado_credit_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lim numeric;
  exp numeric;
  tol constant numeric := 0.01;
  ks text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  select kyc_status into ks
  from public.profiles
  where id = new.aliado_id and role = 'aliado';
  if ks is distinct from 'aprobado' then
    raise exception 'La verificación documental del aliado debe estar aprobada por MotoLink.';
  end if;

  select credit_limit into lim
  from public.profiles
  where id = new.aliado_id and role = 'aliado';
  if lim is null then
    raise exception 'El aliado no tiene límite de crédito autorizado.';
  end if;
  select coalesce(sum(precio_total), 0) into exp
  from public.transaction_requests
  where aliado_id = new.aliado_id
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito'
    );
  if (exp + new.precio_total) > lim + tol then
    raise exception 'El pedido supera el límite de crédito disponible.';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Storage: bucket privado profile-documents
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('profile-documents', 'profile-documents', false)
on conflict (id) do nothing;

drop policy if exists "profile_docs_select_own_or_admin" on storage.objects;
create policy "profile_docs_select_own_or_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-documents'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
    )
  )
);

drop policy if exists "profile_docs_insert_own_aliado" on storage.objects;
create policy "profile_docs_insert_own_aliado"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'aliado'
  )
);

drop policy if exists "profile_docs_delete_own" on storage.objects;
create policy "profile_docs_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);
