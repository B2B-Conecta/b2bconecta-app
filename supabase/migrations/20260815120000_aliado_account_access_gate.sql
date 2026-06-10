-- Fase 1: aliados deben ser aprobados por admin antes de acceder a la app.
-- Importadores y administradores: acceso activo por defecto.

alter table public.profiles
  add column if not exists account_access_status text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text,
  add column if not exists account_review_note text;

alter table public.profiles
  drop constraint if exists profiles_account_access_status_check;

alter table public.profiles
  add constraint profiles_account_access_status_check
  check (
    account_access_status is null
    or account_access_status = any (
      array[
        'draft'::text,
        'pending_review'::text,
        'active'::text,
        'rejected'::text
      ]
    )
  );

comment on column public.profiles.account_access_status is
  'Aliado: draft → pending_review → active|rejected. Importador/admin: active.';

-- Backfill cuentas existentes
update public.profiles
set account_access_status = 'active'
where coalesce(role, '') <> 'aliado';

update public.profiles
set account_access_status = 'active'
where role = 'aliado'
  and trim(coalesce(kyc_status, '')) = 'aprobado';

update public.profiles
set account_access_status = 'pending_review'
where role = 'aliado'
  and trim(coalesce(kyc_status, '')) = 'en_revision'
  and account_access_status is null;

update public.profiles
set account_access_status = 'rejected'
where role = 'aliado'
  and trim(coalesce(kyc_status, '')) = 'rechazado'
  and account_access_status is null;

update public.profiles
set account_access_status = 'draft'
where role = 'aliado'
  and account_access_status is null;

create or replace function public._profiles_default_account_access_status ()
returns trigger
language plpgsql
as $$
begin
  if new.account_access_status is not null then
    return new;
  end if;
  if new.role = 'aliado'::text then
    new.account_access_status := 'draft';
  else
    new.account_access_status := 'active';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_default_account_access_status on public.profiles;
create trigger profiles_default_account_access_status
before insert on public.profiles
for each row
execute function public._profiles_default_account_access_status ();

-- Aceptar términos (versión controlada desde la app).
create or replace function public.profile_accept_terms (p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_version text := nullif(trim(p_version), '');
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_version is null then
    raise exception 'Versión de términos requerida';
  end if;

  update public.profiles
  set
    terms_accepted_at = now(),
    terms_version = v_version
  where id = v_uid;
end;
$$;

grant execute on function public.profile_accept_terms (text) to authenticated;

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

  if v_role <> 'aliado'::text then
    raise exception 'Solo los aliados pueden enviar documentación KYC.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.terms_accepted_at is not null
      and nullif(trim(p.terms_version), '') is not null
  ) then
    raise exception 'Debe aceptar los términos y condiciones antes de enviar a revisión.';
  end if;

  if not public.profile_aliado_kyc_profile_complete (v_uid) then
    raise exception
      'Complete RIF, dirección fiscal (estado, ciudad, domicilio) y enlace de Google Maps en Mi perfil.';
  end if;

  if not public.profile_aliado_has_required_documents (v_uid) then
    raise exception
      'Suba foto de la tienda, cédula del propietario y registro mercantil antes de enviar a revisión.';
  end if;

  update public.profiles
  set
    kyc_status = 'en_revision'::text,
    account_access_status = 'pending_review'::text,
    account_review_note = null
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

create or replace function public.admin_set_profile_kyc_status (
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
    raise exception 'Estado KYC requerido';
  end if;

  if v_st not in ('pendiente', 'en_revision', 'aprobado', 'rechazado') then
    raise exception 'Estado KYC no válido';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = p_profile_id;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role <> 'aliado'::text then
    raise exception 'KYC documental solo aplica a perfiles aliado';
  end if;

  if v_st = 'aprobado' then
    update public.profiles
    set
      kyc_status = v_st,
      account_access_status = 'active'::text,
      account_review_note = null
    where id = p_profile_id;
  elsif v_st = 'rechazado' then
    update public.profiles
    set
      kyc_status = v_st,
      account_access_status = 'rejected'::text,
      account_review_note = v_note
    where id = p_profile_id;
  else
    update public.profiles
    set kyc_status = v_st
    where id = p_profile_id;
  end if;
end;
$$;
