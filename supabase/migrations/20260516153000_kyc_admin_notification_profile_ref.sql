-- KYC admin: related_id = profile_id (aliado) para deep link en app.
-- Texto: nombre + RIF + documento; título más explícito.

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

  if v_rif is not null then
    v_body :=
      'Aliado: ' || v_name || ' · RIF ' || v_rif || '. Documento: «' || v_doc_label
      || '». Abra Límites de crédito para revisar el expediente y la documentación.';
  else
    v_body :=
      'Aliado: ' || v_name || '. Documento: «' || v_doc_label
      || '». Abra Límites de crédito para revisar el expediente y la documentación.';
  end if;

  perform public.notify_to_all_admins(
    'KYC: ' || v_name || ' — documento nuevo o actualizado',
    v_body,
    'kyc',
    new.profile_id::text
  );
  return new;
end;
$$;
