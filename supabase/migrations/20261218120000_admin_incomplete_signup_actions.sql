-- Acciones admin sobre Auth sin ficha en profiles (registro incompleto).
-- Baja: bloquea el acceso (banned_until). Borrado: elimina Auth y libera el correo.

create or replace function public.admin_ban_incomplete_signup (
  p_user_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(trim(p_note), '');
begin
  perform public._assert_administrador ();

  if p_user_id is null then
    raise exception 'Usuario no indicado';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id = p_user_id
  ) then
    raise exception
      'Esta cuenta ya tiene expediente. Use Dar de baja desde Cuentas.';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = p_user_id
  ) then
    raise exception 'Usuario de Auth no encontrado';
  end if;

  if v_note is null then
    raise exception 'Indique el motivo de la baja';
  end if;

  update auth.users
  set
    banned_until = timestamptz '2099-01-01 00:00:00+00',
    raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object(
        'incomplete_ban_note',
        v_note,
        'incomplete_banned_by',
        auth.uid ()::text,
        'incomplete_banned_at',
        to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      )
  where id = p_user_id;
end;
$$;

create or replace function public.admin_purge_incomplete_signup (
  p_user_id uuid,
  p_confirm text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_confirm text := lower(trim(coalesce(p_confirm, '')));
begin
  perform public._assert_administrador ();

  if p_user_id is null then
    raise exception 'Usuario no indicado';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id = p_user_id
  ) then
    raise exception
      'Esta cuenta ya tiene expediente. Use Borrar y liberar correo desde Cuentas.';
  end if;

  select lower(trim(u.email::text))
    into v_email
  from auth.users u
  where u.id = p_user_id;

  if not found then
    raise exception 'Usuario de Auth no encontrado';
  end if;

  if v_email is null or v_email = '' then
    if v_confirm is distinct from lower(p_user_id::text) then
      raise exception 'Escriba el id de usuario para confirmar el borrado';
    end if;
  elsif v_confirm is distinct from v_email then
    raise exception 'Escriba el correo de la cuenta para confirmar el borrado';
  end if;

  delete from auth.identities i
  where i.user_id = p_user_id;

  delete from auth.users u
  where u.id = p_user_id;

  if not found then
    raise exception 'No se pudo borrar el usuario de Auth';
  end if;
end;
$$;

-- RETURNS TABLE cambió (añade banned_until): REPLACE no basta (42P13).
drop function if exists public.list_admin_incomplete_signups ();

create or replace function public.list_admin_incomplete_signups ()
returns table (
  user_id uuid,
  email text,
  phone text,
  display_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed_at timestamptz,
  banned_until timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  perform public._assert_administrador ();

  return query
  select
    u.id,
    nullif(trim(u.email::text), ''),
    nullif(trim(u.phone::text), ''),
    nullif(
      trim(
        coalesce(
          u.raw_user_meta_data ->> 'full_name',
          u.raw_user_meta_data ->> 'name',
          u.raw_user_meta_data ->> 'display_name'
        )
      ),
      ''
    ),
    u.created_at,
    u.last_sign_in_at,
    u.email_confirmed_at,
    u.banned_until
  from auth.users u
  where not exists (
    select 1
    from public.profiles p
    where p.id = u.id
  )
  order by u.created_at desc nulls last, u.email nulls last;
end;
$$;

revoke all on function public.admin_ban_incomplete_signup (uuid, text) from public;
revoke all on function public.admin_purge_incomplete_signup (uuid, text) from public;
revoke all on function public.list_admin_incomplete_signups () from public;

grant execute on function public.admin_ban_incomplete_signup (uuid, text) to authenticated;
grant execute on function public.admin_purge_incomplete_signup (uuid, text) to authenticated;
grant execute on function public.list_admin_incomplete_signups () to authenticated;

comment on function public.admin_ban_incomplete_signup (uuid, text) is
  'Admin: bloquea Auth sin perfil (registro incompleto). El correo sigue ocupado.';

comment on function public.admin_purge_incomplete_signup (uuid, text) is
  'Admin: borra Auth sin perfil y libera correo/teléfono para un registro nuevo.';
