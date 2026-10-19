-- Usuarios de Auth que nunca guardaron la ficha de negocio.
-- El panel de cuentas los lista para que el administrador pueda contactarlos.

create or replace function public.list_admin_incomplete_signups ()
returns table (
  user_id uuid,
  email text,
  phone text,
  display_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed_at timestamptz
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
    u.email_confirmed_at
  from auth.users u
  where not exists (
    select 1
    from public.profiles p
    where p.id = u.id
  )
  order by u.created_at desc nulls last, u.email nulls last;
end;
$$;

revoke all on function public.list_admin_incomplete_signups () from public;
grant execute on function public.list_admin_incomplete_signups () to authenticated;

comment on function public.list_admin_incomplete_signups () is
  'Admin: usuarios de Auth sin perfil. Registro incompleto, del más reciente al más antiguo.';
