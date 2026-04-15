-- Notificaciones KYC:
-- 1) Admins: nombre del aliado + tipo de documento al subir archivo.
-- 2) Aliado: textos con etiqueta legible del tipo de documento (no solo la clave).

create or replace function public.kyc_doc_type_label_es(p_doc_type text)
returns text
language sql
immutable
as $$
  select case trim(coalesce(p_doc_type, ''))
    when 'acta_constitutiva' then 'Acta constitutiva / estatutos'
    when 'registro_mercantil' then 'Registro mercantil / cámara'
    when 'cedula_representante' then 'Cédula del representante legal'
    when 'referencia_bancaria_1' then 'Referencia bancaria (1)'
    when 'referencia_bancaria_2' then 'Referencia bancaria (2)'
    when 'referencia_comercial' then 'Referencia comercial / carta crédito'
    else coalesce(nullif(trim(p_doc_type), ''), 'documento')
  end;
$$;

create or replace function public.notify_profile_document_review_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_label text;
begin
  v_label := public.kyc_doc_type_label_es(new.doc_type);

  if old.review_status is distinct from new.review_status then
    if new.review_status = 'aprobado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento KYC aprobado',
        'MotoLink aprobó su documento «' || v_label || '».',
        'kyc',
        new.id::text
      );
    elsif new.review_status = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento KYC rechazado',
        'Revise las observaciones y vuelva a cargar «' || v_label || '» si aplica.',
        'kyc',
        new.id::text
      );
    elsif new.review_status = 'en_revision' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.profile_id,
        'Documento en revisión',
        'MotoLink está revisando «' || v_label || '».',
        'kyc',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.notify_new_kyc_document_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_doc_label text;
begin
  select coalesce(nullif(trim(p.business_name), ''), 'Aliado sin nombre comercial')
    into v_name
  from public.profiles p
  where p.id = new.profile_id;

  if v_name is null then
    v_name := 'Aliado';
  end if;

  v_doc_label := public.kyc_doc_type_label_es(new.doc_type);

  perform public.notify_to_all_admins(
    'KYC: nuevo archivo · ' || v_name,
    v_name || ' cargó o actualizó «' || v_doc_label || '». Revise el expediente en Límites de crédito.',
    'kyc',
    new.id::text
  );
  return new;
end;
$$;
