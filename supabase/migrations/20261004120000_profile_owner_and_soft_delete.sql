-- Propietario de la plataforma (`is_owner`) y baja lógica de cuentas.
-- El rol CHECK sigue siendo aliado | importador | administrador.
-- El owner mantiene role = 'administrador' para el shell admin y _assert_administrador().
-- No se borra auth.users: la baja es soft delete (deactivated_at).

alter table public.profiles
  add column if not exists is_owner boolean not null default false,
  add column if not exists deactivated_at timestamptz,
  add column if not exists deactivated_by uuid references public.profiles (id) on delete set null;

comment on column public.profiles.is_owner is
  'Unico propietario de la plataforma. No se muestra en la UI publica.';
comment on column public.profiles.deactivated_at is
  'Baja logica (soft delete). Si no es null, la cuenta no entra a la app.';
comment on column public.profiles.deactivated_by is
  'Perfil del owner que aplico la baja logica.';

create unique index if not exists profiles_single_owner_idx
  on public.profiles ((true))
  where is_owner;

create index if not exists profiles_deactivated_at_idx
  on public.profiles (deactivated_at)
  where deactivated_at is not null;

-- Permite a RPCs security definer cambiar rol / is_owner / deactivated_*.
create or replace function public._allow_profile_privilege ()
returns void
language plpgsql
as $$
begin
  perform set_config('b2b.profile_privilege_ok', '1', true);
end;
$$;

revoke all on function public._allow_profile_privilege () from public;

create or replace function public._profiles_privilege_guard ()
returns trigger
language plpgsql
as $$
declare
  v_owner_email constant text := 'gimenopueyo@gmail.com';
  v_is_seed_owner boolean := false;
begin
  if tg_op = 'INSERT' then
    v_is_seed_owner := exists (
      select 1
      from auth.users u
      where u.id = new.id
        and lower(coalesce(u.email, '')) = v_owner_email
    )
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

drop trigger if exists profiles_privilege_guard on public.profiles;
create trigger profiles_privilege_guard
before insert or update on public.profiles
for each row
execute function public._profiles_privilege_guard ();

-- Admin RPCs: cuenta baja o bloqueada no opera el panel.
create or replace function public._assert_administrador ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.jwt () ->> 'role', '') = 'service_role'
     or coalesce(
       current_setting('request.jwt.claim.role', true),
       ''
     ) = 'service_role' then
    return;
  end if;
  if auth.uid () is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') is distinct from 'rejected'
  ) then
    raise exception 'Solo administradores' using errcode = '42501';
  end if;
end;
$$;

create or replace function public._assert_owner ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();
  if coalesce(auth.jwt () ->> 'role', '') = 'service_role'
     or coalesce(
       current_setting('request.jwt.claim.role', true),
       ''
     ) = 'service_role' then
    return;
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.is_owner
      and p.deactivated_at is null
  ) then
    raise exception 'Solo el propietario' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public._assert_owner () from public;

create or replace function public._owner_guard_target (p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
begin
  perform public._assert_owner ();

  if p_profile_id is null then
    raise exception 'Perfil requerido';
  end if;

  if p_profile_id = auth.uid () then
    raise exception 'No puede modificar su propia cuenta' using errcode = '42501';
  end if;

  select p.is_owner
    into v_is_owner
  from public.profiles p
  where p.id = p_profile_id;

  if not found then
    raise exception 'Perfil no encontrado';
  end if;

  if v_is_owner then
    raise exception 'No se puede modificar la cuenta del propietario'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public._owner_guard_target (uuid) from public;

create or replace function public.owner_set_profile_role (
  p_profile_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  perform public._owner_guard_target (p_profile_id);

  v_role := lower(trim(p_role));
  if v_role is null or v_role not in ('aliado', 'importador', 'administrador') then
    raise exception 'Rol no valido';
  end if;

  perform public._allow_profile_privilege ();

  update public.profiles
  set role = v_role
  where id = p_profile_id;
end;
$$;

create or replace function public.owner_set_account_access (
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
  v_status text;
  v_note text := nullif(trim(p_note), '');
begin
  perform public._owner_guard_target (p_profile_id);

  v_status := lower(trim(p_status));
  if v_status is null or v_status not in ('active', 'rejected') then
    raise exception 'Estado de acceso no valido';
  end if;

  if v_status = 'rejected' and v_note is null then
    raise exception 'Indique el motivo del bloqueo';
  end if;

  perform public._allow_profile_privilege ();

  if v_status = 'active' then
    update public.profiles
    set
      account_access_status = 'active',
      account_review_note = null,
      deactivated_at = null,
      deactivated_by = null
    where id = p_profile_id;
  else
    update public.profiles
    set
      account_access_status = 'rejected',
      account_review_note = v_note,
      deactivated_at = null,
      deactivated_by = null
    where id = p_profile_id;
  end if;
end;
$$;

create or replace function public.owner_deactivate_profile (
  p_profile_id uuid,
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
  perform public._owner_guard_target (p_profile_id);

  if v_note is null then
    raise exception 'Indique el motivo de la baja';
  end if;

  perform public._allow_profile_privilege ();

  update public.profiles
  set
    account_access_status = 'rejected',
    account_review_note = v_note,
    deactivated_at = now(),
    deactivated_by = auth.uid ()
  where id = p_profile_id;
end;
$$;

create or replace function public.owner_list_profiles ()
returns table (
  id uuid,
  business_name text,
  rif text,
  role text,
  phone text,
  email text,
  account_access_status text,
  account_review_note text,
  kyc_status text,
  is_owner boolean,
  deactivated_at timestamptz,
  deactivated_by uuid,
  created_at timestamptz,
  estado text,
  ciudad text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_owner ();

  return query
  select
    p.id,
    p.business_name,
    p.rif,
    p.role,
    p.phone,
    u.email::text,
    p.account_access_status,
    p.account_review_note,
    p.kyc_status,
    p.is_owner,
    p.deactivated_at,
    p.deactivated_by,
    p.created_at,
    p.estado,
    p.ciudad
  from public.profiles p
  left join auth.users u on u.id = p.id
  order by
    p.is_owner desc,
    coalesce(p.business_name, u.email, p.rif, p.id::text);
end;
$$;

revoke all on function public.owner_set_profile_role (uuid, text) from public;
revoke all on function public.owner_set_account_access (uuid, text, text) from public;
revoke all on function public.owner_deactivate_profile (uuid, text) from public;
revoke all on function public.owner_list_profiles () from public;

grant execute on function public.owner_set_profile_role (uuid, text) to authenticated;
grant execute on function public.owner_set_account_access (uuid, text, text) to authenticated;
grant execute on function public.owner_deactivate_profile (uuid, text) to authenticated;
grant execute on function public.owner_list_profiles () to authenticated;

comment on function public.owner_set_profile_role (uuid, text) is
  'Owner: cambia el rol B2B de otro perfil (nunca el propio ni otro owner).';
comment on function public.owner_set_account_access (uuid, text, text) is
  'Owner: bloquea (rejected) o reactiva (active, limpia soft delete) otra cuenta.';
comment on function public.owner_deactivate_profile (uuid, text) is
  'Owner: baja logica. No borra auth.users ni el historial.';
comment on function public.owner_list_profiles () is
  'Owner: listado de cuentas con email de Auth.';

-- Si el usuario ya existe, marcarlo owner. La clave de Auth no se toca aqui.
do $$
begin
  perform public._allow_profile_privilege ();
  update public.profiles p
  set
    role = 'administrador',
    is_owner = true,
    account_access_status = 'active',
    deactivated_at = null,
    deactivated_by = null
  from auth.users u
  where u.id = p.id
    and lower(coalesce(u.email, '')) = 'gimenopueyo@gmail.com';
end;
$$;
