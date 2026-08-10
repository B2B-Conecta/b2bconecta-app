-- Referencia legal del mayorista: nombre, correo y teléfono (en lugar de un solo texto).

alter table public.profiles
  add column if not exists legal_contact_name text,
  add column if not exists legal_contact_email text,
  add column if not exists legal_contact_phone text;

comment on column public.profiles.legal_contact_name is
  'Importador: nombre del contacto legal.';
comment on column public.profiles.legal_contact_email is
  'Importador: correo del contacto legal.';
comment on column public.profiles.legal_contact_phone is
  'Importador: teléfono del contacto legal.';

-- Migrar texto libre previo al nombre (mejor esfuerzo).
update public.profiles
set legal_contact_name = nullif(trim(legal_reference), '')
where role = 'importador'
  and nullif(trim(legal_contact_name), '') is null
  and nullif(trim(legal_reference), '') is not null;

create or replace function public.profile_importador_profile_complete (p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_uid
      and p.role = 'importador'
      and nullif(trim(p.business_name), '') is not null
      and nullif(trim(p.rif), '') is not null
      and nullif(trim(p.estado), '') is not null
      and nullif(trim(p.ciudad), '') is not null
      and nullif(trim(p.direccion), '') is not null
      and nullif(trim(p.fiscal_maps_url), '') is not null
      and trim(p.fiscal_maps_url) ~* '^https?://'
      and nullif(trim(p.legal_contact_name), '') is not null
      and nullif(trim(p.legal_contact_email), '') is not null
      and nullif(trim(p.legal_contact_phone), '') is not null
  );
$$;

grant execute on function public.profile_importador_profile_complete (uuid) to authenticated;

create or replace function public.profile_submit_importador_for_review ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_name text;
  v_access text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, nullif(trim(p.business_name), ''), p.account_access_status
    into v_role, v_name, v_access
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role <> 'importador'::text then
    raise exception 'Solo los mayoristas (importador) pueden enviar esta solicitud.';
  end if;

  if v_access is not null
     and v_access not in ('draft'::text, 'rejected'::text) then
    raise exception 'La solicitud ya fue enviada o el acceso ya está habilitado.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.terms_accepted_at is not null
      and nullif(trim(p.terms_version), '') is not null
  ) then
    raise exception
      'Debe aceptar los términos y condiciones antes de enviar a revisión.';
  end if;

  if not public.profile_importador_profile_complete (v_uid) then
    raise exception
      'Complete nombre comercial, RIF, dirección fiscal, Maps y referencia legal (nombre, correo y teléfono).';
  end if;

  update public.profiles
  set
    account_access_status = 'pending_review'::text,
    account_review_note = null
  where id = v_uid;

  perform public._notify_admins_kyc_review (v_uid, v_name, v_role);

  perform public.mc_insert_notification (
    v_uid,
    'Solicitud enviada a revisión',
    'B2B Conecta revisará su registro de mayorista. Le avisaremos en la app cuando haya novedades.',
    'kyc',
    v_uid::text
  );
end;
$$;

grant execute on function public.profile_submit_importador_for_review () to authenticated;
