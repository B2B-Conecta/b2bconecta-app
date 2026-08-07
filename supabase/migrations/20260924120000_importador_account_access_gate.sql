-- Mayoristas/proveedores (role = importador): aprobación manual antes de operar.
-- Flujo: draft → pending_review → active | rejected
-- Aliados conservan su flujo KYC documental. Administradores siguen active.

comment on column public.profiles.account_access_status is
  'Aliado/importador: draft → pending_review → active|rejected. Admin: active.';

-- Nuevos importadores arrancan en borrador (existentes ya activos se conservan).
create or replace function public._profiles_default_account_access_status ()
returns trigger
language plpgsql
as $$
begin
  if new.account_access_status is not null then
    return new;
  end if;
  if new.role in ('aliado'::text, 'importador'::text) then
    new.account_access_status := 'draft';
  else
    new.account_access_status := 'active';
  end if;
  return new;
end;
$$;

-- Perfil mínimo del mayorista (sin documentación KYC).
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
  );
$$;

grant execute on function public.profile_importador_profile_complete (uuid) to authenticated;

-- Importador: envía solicitud de ingreso (sin documentos KYC).
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
      'Complete nombre comercial, RIF, dirección fiscal (estado, ciudad, domicilio) y enlace de Google Maps.';
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

-- Admin: aprobar o rechazar acceso de mayorista (sin KYC documental).
create or replace function public.admin_set_importador_account_access (
  p_profile_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_st text;
  v_note text := nullif(trim(p_note), '');
begin
  perform public._assert_administrador ();

  v_st := lower(trim(p_status));
  if v_st is null or v_st = '' then
    raise exception 'Estado de acceso requerido';
  end if;

  -- Acepta etiquetas de UI (aprobado/rechazado) o estados de cuenta.
  if v_st in ('aprobado'::text, 'active'::text) then
    v_st := 'active';
  elsif v_st in ('rechazado'::text, 'rejected'::text) then
    v_st := 'rejected';
  else
    raise exception 'Estado no válido. Use aprobado o rechazado.';
  end if;

  select p.role into v_role
  from public.profiles p
  where p.id = p_profile_id;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role <> 'importador'::text then
    raise exception 'Esta acción solo aplica a perfiles importador (mayorista).';
  end if;

  if v_st = 'active' then
    update public.profiles
    set
      account_access_status = 'active'::text,
      account_review_note = null
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Perfil validado',
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.',
      'kyc',
      p_profile_id::text
    );
  else
    if v_note is null then
      raise exception 'Indique el motivo del rechazo.';
    end if;

    update public.profiles
    set
      account_access_status = 'rejected'::text,
      account_review_note = v_note
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Solicitud rechazada',
      v_note,
      'kyc',
      p_profile_id::text
    );
  end if;
end;
$$;

grant execute on function public.admin_set_importador_account_access (uuid, text, text) to authenticated;
