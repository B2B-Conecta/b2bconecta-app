-- Rechazo de un documento KYC: avisa al minorista y, al reenviarlo, vuelve a revisión
-- y avisa a la administración. No cambia el estado de la cuenta ni la activación.

create or replace function public.profile_document_type_label_es (p_type text)
returns text
language sql
immutable
as $$
  select case trim(coalesce(p_type, ''))
    when 'foto_tienda' then 'Foto de la tienda'
    when 'registro_mercantil' then 'Registro mercantil / cámara'
    when 'cedula_propietario' then 'Cédula del propietario'
    when 'cedula_representante' then 'Cédula del representante legal'
    when 'referencia_bancaria_1' then 'Referencia bancaria (1)'
    when 'referencia_bancaria_2' then 'Referencia bancaria (2)'
    when 'referencia_comercial' then 'Referencia comercial / carta crédito'
    when 'acta_constitutiva' then 'Acta constitutiva / estatutos (histórico)'
    else coalesce(nullif(trim(p_type), ''), 'Documento')
  end;
$$;

create or replace function public._notify_admins_document_resubmitted (
  p_profile_id uuid,
  p_business_name text,
  p_doc_label text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid;
  v_name text := coalesce(nullif(trim(p_business_name), ''), 'Un minorista');
  v_label text := coalesce(nullif(trim(p_doc_label), ''), 'un documento');
begin
  for v_admin in
    select adm.id
    from public.profiles adm
    where adm.role = 'administrador'
  loop
    perform public.mc_insert_notification(
      v_admin,
      'Documento reenviado',
      format('%s volvió a enviar %s.', v_name, v_label),
      'kyc',
      p_profile_id::text
    );
  end loop;
end;
$$;

revoke all on function public._notify_admins_document_resubmitted (uuid, text, text) from public;

create or replace function public.admin_set_profile_document_review_status (
  p_profile_id uuid,
  p_doc_type text,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_st text;
  v_doc_id uuid;
  v_label text;
  v_note text;
begin
  perform public._assert_administrador ();

  v_st := lower(trim(p_status));
  if v_st not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado de revisión no válido';
  end if;

  v_note := nullif(trim(p_note), '');
  if v_st = 'rechazado' and (v_note is null or length(v_note) < 3) then
    raise exception 'Indique el motivo del rechazo (mínimo 3 caracteres).';
  end if;

  select pd.id
    into v_doc_id
  from public.profile_documents pd
  where pd.profile_id = p_profile_id
    and pd.doc_type = trim(p_doc_type)
    and pd.is_current = true
  order by pd.created_at desc
  limit 1;

  if v_doc_id is null then
    raise exception 'No hay documento vigente de ese tipo para este perfil.';
  end if;

  update public.profile_documents
  set
    review_status = v_st,
    review_note = case when v_st = 'rechazado' then v_note else null end,
    reviewed_at = now(),
    reviewed_by = auth.uid ()
  where id = v_doc_id;

  if v_st = 'rechazado' then
    v_label := public.profile_document_type_label_es(p_doc_type);
    perform public.mc_insert_notification(
      p_profile_id,
      'Documento rechazado',
      left(format('%s. Motivo: %s', v_label, v_note), 240),
      'kyc',
      p_profile_id::text
    );
  end if;
end;
$$;

-- El dueño no reemplaza un documento aprobado o que sigue en revisión.
-- Al sustituir uno rechazado, el archivo nuevo queda en revisión y se avisa al admin.
create or replace function public.trg_profile_documents_before_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_approved boolean := false;
  v_has_in_review boolean := false;
  v_has_rejected boolean := false;
  v_name text;
begin
  if new.profile_id is null or coalesce(new.is_current, false) is not true then
    return new;
  end if;

  select
    coalesce(bool_or(pd.review_status = 'aprobado'), false),
    coalesce(bool_or(pd.review_status = 'en_revision'), false),
    coalesce(bool_or(pd.review_status = 'rechazado'), false)
  into v_has_approved, v_has_in_review, v_has_rejected
  from public.profile_documents pd
  where pd.profile_id = new.profile_id
    and pd.doc_type = new.doc_type
    and pd.is_current = true;

  if auth.uid() = new.profile_id then
    if v_has_approved then
      raise exception 'Este documento ya fue aprobado y no se puede reemplazar.';
    end if;
    if v_has_in_review then
      raise exception 'Este documento está en revisión y no se puede reemplazar.';
    end if;
  end if;

  update public.profile_documents
  set is_current = false
  where profile_id = new.profile_id
    and doc_type = new.doc_type
    and is_current = true;

  if auth.uid() = new.profile_id and v_has_rejected then
    new.review_status := 'en_revision';
    new.review_note := null;
    new.reviewed_at := null;
    new.reviewed_by := null;

    select nullif(trim(p.business_name), '')
      into v_name
    from public.profiles p
    where p.id = new.profile_id;

    perform public._notify_admins_document_resubmitted(
      new.profile_id,
      v_name,
      public.profile_document_type_label_es(new.doc_type)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists profile_documents_before_insert on public.profile_documents;

create trigger profile_documents_before_insert
before insert on public.profile_documents
for each row
execute function public.trg_profile_documents_before_insert ();
