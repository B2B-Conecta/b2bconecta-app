-- El trigger de owner leía auth.users como el usuario autenticado (invoker).
-- authenticated no puede SELECT ahí → 403 al insertar profiles (cualquier alta).
-- Debe correr como definer para resolver el email del owner.

create or replace function public._profiles_privilege_guard ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_email constant text := 'gimenopueyo@gmail.com';
  v_is_seed_owner boolean := false;
  v_email text;
begin
  if tg_op = 'INSERT' then
    select lower(coalesce(u.email, ''))
      into v_email
    from auth.users u
    where u.id = new.id;

    if v_email is null or v_email = '' then
      v_email := lower(coalesce(auth.jwt () ->> 'email', ''));
    end if;

    v_is_seed_owner :=
      v_email = v_owner_email
      and not exists (
        select 1
        from public.profiles p
        where p.is_owner
      );

    if v_is_seed_owner then
      new.is_owner := true;
      new.role := 'administrador';
      if new.account_access_status is null
         or new.account_access_status in ('draft', 'pending_review') then
        new.account_access_status := 'active';
      end if;
      new.deactivated_at := null;
      new.deactivated_by := null;
    elsif coalesce(current_setting('b2b.profile_privilege_ok', true), '') is distinct from '1' then
      new.is_owner := false;
      new.deactivated_at := null;
      new.deactivated_by := null;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if coalesce(current_setting('b2b.profile_privilege_ok', true), '') is distinct from '1' then
      if new.is_owner is distinct from old.is_owner
         or new.role is distinct from old.role
         or new.deactivated_at is distinct from old.deactivated_at
         or new.deactivated_by is distinct from old.deactivated_by then
        raise exception 'No autorizado a cambiar rol o privilegios de cuenta'
          using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public._profiles_privilege_guard () from public;
grant execute on function public._profiles_privilege_guard () to postgres, authenticated, service_role;
