-- Aliado: requisitos mínimos KYC (RIF, domicilio, Maps + 3 documentos).

create or replace function public.profile_aliado_kyc_profile_complete (p_uid uuid)
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
      and p.role = 'aliado'
      and nullif(trim(p.rif), '') is not null
      and nullif(trim(p.estado), '') is not null
      and nullif(trim(p.ciudad), '') is not null
      and nullif(trim(p.direccion), '') is not null
      and nullif(trim(p.fiscal_maps_url), '') is not null
      and trim(p.fiscal_maps_url) ~* '^https?://'
  );
$$;

create or replace function public.profile_aliado_has_required_documents (p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.profile_documents pd
      where pd.profile_id = p_uid
        and pd.is_current = true
        and pd.doc_type = 'foto_tienda'
    )
    and exists (
      select 1
      from public.profile_documents pd
      where pd.profile_id = p_uid
        and pd.is_current = true
        and pd.doc_type = 'registro_mercantil'
    )
    and exists (
      select 1
      from public.profile_documents pd
      where pd.profile_id = p_uid
        and pd.is_current = true
        and pd.doc_type in ('cedula_propietario', 'cedula_representante')
    );
$$;

create or replace function public.profile_submit_kyc_for_review ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_name text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, nullif(trim(p.business_name), '')
    into v_role, v_name
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role not in ('aliado'::text, 'importador'::text) then
    raise exception 'Solo aliados e importadores pueden enviar documentación KYC.';
  end if;

  if v_role = 'aliado' then
    if not public.profile_aliado_kyc_profile_complete (v_uid) then
      raise exception
        'Complete RIF, dirección fiscal (estado, ciudad, domicilio) y enlace de Google Maps en Mi perfil.';
    end if;
    if not public.profile_aliado_has_required_documents (v_uid) then
      raise exception
        'Suba foto de la tienda, cédula del propietario y registro mercantil antes de enviar a revisión.';
    end if;
  elsif not exists (
    select 1
    from public.profile_documents pd
    where pd.profile_id = v_uid
      and pd.is_current = true
  ) then
    raise exception 'Suba al menos un documento antes de enviar a revisión.';
  end if;

  update public.profiles
  set kyc_status = 'en_revision'::text
  where id = v_uid;

  update public.profile_documents
  set
    review_status = 'en_revision'::text,
    review_note = null,
    reviewed_at = null,
    reviewed_by = null
  where profile_id = v_uid
    and is_current = true
    and coalesce(review_status, 'pendiente') in ('pendiente'::text, 'rechazado'::text);

  perform public._notify_admins_kyc_review (v_uid, v_name, v_role);
end;
$$;

grant execute on function public.profile_aliado_kyc_profile_complete (uuid) to authenticated;
grant execute on function public.profile_aliado_has_required_documents (uuid) to authenticated;
