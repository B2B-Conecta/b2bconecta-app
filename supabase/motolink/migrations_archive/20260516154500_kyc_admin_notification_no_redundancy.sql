-- Notificación admin KYC: sin repetir el nombre del aliado.
-- Título: documento (tipo) + nombre. Cuerpo: RIF + CTA (el tap ya lleva a Límites de crédito / ficha KYC).

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
