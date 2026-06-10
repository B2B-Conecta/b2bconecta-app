-- PostgREST PGRST203: cannot choose between 2-arg and 3-arg overloads.
-- Keep a single admin_set_profile_kyc_status(uuid, text, text) signature.

drop function if exists public.admin_set_profile_kyc_status (uuid, text);

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

grant execute on function public.admin_set_profile_kyc_status (uuid, text, text) to authenticated;

create or replace function public.admin_set_aliado_kyc_status (
  p_aliado_id uuid,
  p_status text
)
returns void
language sql
security definer
set search_path = public
as $$
  select public.admin_set_profile_kyc_status (p_aliado_id, p_status, null::text);
$$;

grant execute on function public.admin_set_aliado_kyc_status (uuid, text) to authenticated;
