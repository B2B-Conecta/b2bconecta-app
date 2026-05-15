-- Revisión KYC por documento; sincroniza profiles.kyc_status según el conjunto de archivos.

alter table public.profile_documents
  add column if not exists review_status text;

update public.profile_documents pd
set review_status = case
  when pr.kyc_status = 'aprobado' then 'aprobado'
  when pr.kyc_status = 'rechazado' then 'rechazado'
  when pr.kyc_status = 'en_revision' then 'en_revision'
  else 'pendiente'
end
from public.profiles pr
where pd.profile_id = pr.id
  and pr.role = 'aliado'
  and pd.review_status is null;

update public.profile_documents
set review_status = 'pendiente'
where review_status is null;

alter table public.profile_documents
  alter column review_status set not null;

alter table public.profile_documents
  drop constraint if exists profile_documents_review_status_check;

alter table public.profile_documents
  add constraint profile_documents_review_status_check
  check (review_status in ('pendiente', 'en_revision', 'aprobado', 'rechazado'));

-- ---------------------------------------------------------------------------
-- Sincroniza estado global del aliado a partir de los 6 tipos obligatorios.
-- ---------------------------------------------------------------------------

create or replace function public.sync_aliado_kyc_status_from_documents(p_aliado_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  required constant text[] := array[
    'acta_constitutiva',
    'registro_mercantil',
    'cedula_representante',
    'referencia_bancaria_1',
    'referencia_bancaria_2',
    'referencia_comercial'
  ];
  missing int;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_aliado_id and p.role = 'aliado'
  ) then
    return;
  end if;

  select count(*)::int into missing
  from unnest(required) as exp(dt)
  where not exists (
    select 1 from public.profile_documents pd
    where pd.profile_id = p_aliado_id and pd.doc_type = exp.dt
  );

  if missing > 0 then
    update public.profiles
    set kyc_status = 'pendiente'
    where id = p_aliado_id and role = 'aliado';
    return;
  end if;

  if exists (
    select 1 from public.profile_documents pd
    where pd.profile_id = p_aliado_id
      and pd.doc_type = any(required)
      and pd.review_status = 'rechazado'
  ) then
    update public.profiles
    set kyc_status = 'rechazado'
    where id = p_aliado_id and role = 'aliado';
    return;
  end if;

  if not exists (
    select 1 from public.profile_documents pd
    where pd.profile_id = p_aliado_id
      and pd.doc_type = any(required)
      and pd.review_status is distinct from 'aprobado'
  ) then
    update public.profiles
    set kyc_status = 'aprobado'
    where id = p_aliado_id and role = 'aliado';
    return;
  end if;

  if not exists (
    select 1 from public.profile_documents pd
    where pd.profile_id = p_aliado_id
      and pd.doc_type = any(required)
      and pd.review_status is distinct from 'pendiente'
  ) then
    update public.profiles
    set kyc_status = 'pendiente'
    where id = p_aliado_id and role = 'aliado';
    return;
  end if;

  update public.profiles
  set kyc_status = 'en_revision'
  where id = p_aliado_id and role = 'aliado';
end;
$$;

create or replace function public.trg_profile_documents_sync_kyc()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.sync_aliado_kyc_status_from_documents(old.profile_id);
    return old;
  end if;
  perform public.sync_aliado_kyc_status_from_documents(new.profile_id);
  return new;
end;
$$;

drop trigger if exists tr_profile_documents_sync_kyc on public.profile_documents;
create trigger tr_profile_documents_sync_kyc
after insert or delete or update of review_status, doc_type, profile_id
on public.profile_documents
for each row execute procedure public.trg_profile_documents_sync_kyc();

-- Recalcular todos los aliados (por si el trigger no cubrió backfill).
do $$
declare
  r record;
begin
  for r in (select id from public.profiles where role = 'aliado') loop
    perform public.sync_aliado_kyc_status_from_documents(r.id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Aliado: enviar a revisión solo documentos aún en pendiente
-- ---------------------------------------------------------------------------

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
  if st not in ('pendiente', 'rechazado', 'en_revision') then
    raise exception 'No puede enviar a revisión en este estado';
  end if;

  update public.profile_documents
  set review_status = 'en_revision'
  where profile_id = auth.uid()
    and review_status = 'pendiente';
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: fijar estado de un documento concreto
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_profile_document_review_status(
  p_aliado_id uuid,
  p_doc_type text,
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
    raise exception 'Solo administradores pueden actualizar el estado de documentos';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;
  if p_status not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado de revisión no válido';
  end if;

  update public.profile_documents
  set review_status = p_status
  where profile_id = p_aliado_id and doc_type = p_doc_type;

  if not found then
    raise exception 'No hay archivo cargado para ese tipo de documento';
  end if;
end;
$$;

grant execute on function public.admin_set_profile_document_review_status(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: admin puede actualizar filas de documentos (revisión)
-- ---------------------------------------------------------------------------

drop policy if exists "profile_documents_update_admin" on public.profile_documents;
create policy "profile_documents_update_admin"
on public.profile_documents
for update
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);
