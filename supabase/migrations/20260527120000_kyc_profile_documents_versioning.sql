-- Documentación KYC evolutiva: varias filas por (profile_id, doc_type); solo una is_current.
-- El archivo aprobado anterior permanece en BD y Storage; las nuevas versiones inician en pendiente.

alter table public.profile_documents
  add column if not exists is_current boolean not null default true;

alter table public.profile_documents
  drop constraint if exists profile_documents_profile_doc_unique;

drop index if exists profile_documents_one_current_per_type;

create unique index profile_documents_one_current_per_type
  on public.profile_documents (profile_id, doc_type)
  where is_current;

update public.profile_documents set is_current = true where is_current is null;

-- Antes de insertar la nueva versión vigente, marcar la anterior como no vigente
-- (evita violar el índice único parcial con dos is_current = true).
create or replace function public.profile_documents_before_insert_demote_previous()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_current then
    update public.profile_documents pd
    set is_current = false
    where pd.profile_id = new.profile_id
      and pd.doc_type = new.doc_type
      and pd.is_current;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_profile_documents_demote_previous on public.profile_documents;
drop trigger if exists tr_profile_documents_before_insert_demote on public.profile_documents;
create trigger tr_profile_documents_before_insert_demote
  before insert on public.profile_documents
  for each row
  execute function public.profile_documents_before_insert_demote_previous();

-- Sincronización KYC global: solo documentos vigentes (is_current).
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
    where pd.profile_id = p_aliado_id
      and pd.doc_type = exp.dt
      and pd.is_current
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
      and pd.is_current
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
      and pd.is_current
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
      and pd.is_current
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

drop trigger if exists tr_profile_documents_sync_kyc on public.profile_documents;
create trigger tr_profile_documents_sync_kyc
after insert or delete or update of review_status, doc_type, profile_id, is_current
on public.profile_documents
for each row execute procedure public.trg_profile_documents_sync_kyc();

-- Enviar a revisión solo la versión vigente en pendiente.
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
    and is_current
    and review_status = 'pendiente';
end;
$$;

-- Admin revisa la versión vigente del tipo de documento.
create or replace function public.admin_set_profile_document_review_status(
  p_aliado_id uuid,
  p_doc_type text,
  p_status text,
  p_note text default null
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

  if p_status = 'rechazado' then
    if p_note is null or length(trim(p_note)) < 3 then
      raise exception 'Indique el motivo del rechazo (nota para el aliado, mín. 3 caracteres).';
    end if;
  end if;

  update public.profile_documents
  set
    review_status = p_status,
    reviewed_at = now(),
    reviewed_by = auth.uid(),
    review_note = case
      when p_status = 'aprobado' then null
      when p_status = 'rechazado' then trim(p_note)
      when p_note is not null then nullif(trim(p_note), '')
      else review_note
    end
  where profile_id = p_aliado_id
    and doc_type = p_doc_type
    and is_current;

  if not found then
    raise exception 'No hay versión vigente cargada para ese tipo de documento';
  end if;
end;
$$;

-- Notificación admin: distinguir primera carga vs actualización sobre expediente ya aprobado.
create or replace function public.notify_new_kyc_document_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_rif text;
  v_doc_label text;
  v_body text;
  v_hay_aprobado_prev boolean;
begin
  select
    coalesce(nullif(trim(p.business_name), ''), 'Aliado sin nombre comercial'),
    nullif(trim(p.rif), '')
  into v_name, v_rif
  from public.profiles p
  where p.id = new.profile_id;

  if v_name is null then
    v_name := 'Aliado';
  end if;

  v_doc_label := public.kyc_doc_type_label_es(new.doc_type);

  select exists (
    select 1
    from public.profile_documents pd
    where pd.profile_id = new.profile_id
      and pd.doc_type = new.doc_type
      and pd.id is distinct from new.id
      and pd.review_status = 'aprobado'
  ) into v_hay_aprobado_prev;

  if v_hay_aprobado_prev then
    perform public.notify_to_all_admins(
      'Actualización de Expediente',
      'El Aliado ' || v_name || ' ha subido una nueva versión del documento «' || v_doc_label || '».',
      'kyc',
      new.profile_id::text
    );
    return new;
  end if;

  if v_rif is not null then
    v_body :=
      'RIF ' || v_rif
      || '. Toque para abrir Límites de crédito y revisar la documentación KYC.';
  else
    v_body :=
      'Toque para abrir Límites de crédito y revisar la documentación KYC.';
  end if;

  perform public.notify_to_all_admins(
    'Nuevo documento · «' || v_doc_label || '» · ' || v_name,
    v_body,
    'kyc',
    new.profile_id::text
  );
  return new;
end;
$$;

-- Aliado: solo puede eliminar la versión vigente no aprobada (no borrar histórico).
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
  and is_current
  and review_status is distinct from 'aprobado'
);

-- KYC global manual: solo versiones vigentes cuentan para los 6 obligatorios.
create or replace function public.admin_set_aliado_kyc_status(
  p_aliado_id uuid,
  p_status text
)
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
  not_aprobado int;
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

  if p_status = 'aprobado' then
    select count(*)::int into missing
    from unnest(required) as exp(dt)
    where not exists (
      select 1 from public.profile_documents pd
      where pd.profile_id = p_aliado_id
        and pd.doc_type = exp.dt
        and pd.is_current
        and pd.storage_path is not null
        and length(trim(pd.storage_path)) > 0
    );

    if missing > 0 then
      raise exception
        'No se puede marcar KYC como aprobado: deben estar registrados los 6 documentos obligatorios (archivo cargado por tipo).';
    end if;

    select count(*)::int into not_aprobado
    from public.profile_documents pd
    where pd.profile_id = p_aliado_id
      and pd.doc_type = any(required)
      and pd.is_current
      and pd.review_status is distinct from 'aprobado';

    if not_aprobado > 0 then
      raise exception
        'No se puede marcar KYC como aprobado: cada documento obligatorio debe tener estado de revisión «aprobado».';
    end if;
  end if;

  update public.profiles
  set kyc_status = p_status
  where id = p_aliado_id and role = 'aliado';
end;
$$;
