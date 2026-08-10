-- Sistema de referidos: código único por perfil, captura en registro y métricas admin.

alter table public.profiles
  add column if not exists referral_code text,
  add column if not exists referred_by_profile_id uuid references public.profiles (id) on delete set null,
  add column if not exists referred_at timestamptz;

comment on column public.profiles.referral_code is
  'Código público único para invitar nuevos usuarios.';
comment on column public.profiles.referred_by_profile_id is
  'Perfil que refirió a este usuario (si aplica).';
comment on column public.profiles.referred_at is
  'Momento en que se asoció el referido.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_no_self_referral'
  ) then
    alter table public.profiles
      add constraint profiles_no_self_referral
      check (
        referred_by_profile_id is null
        or referred_by_profile_id is distinct from id
      );
  end if;
end;
$$;

create unique index if not exists profiles_referral_code_uidx
  on public.profiles (upper(referral_code))
  where referral_code is not null;

create index if not exists profiles_referred_by_idx
  on public.profiles (referred_by_profile_id)
  where referred_by_profile_id is not null;

create or replace function public.generate_unique_referral_code ()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_i int;
  v_attempts int := 0;
  v_idx int;
begin
  loop
    v_attempts := v_attempts + 1;
    v_code := 'B2B';
    for v_i in 1..6 loop
      v_idx := 1 + floor(random() * length(v_alphabet))::int;
      if v_idx > length(v_alphabet) then
        v_idx := length(v_alphabet);
      end if;
      v_code := v_code || substr(v_alphabet, v_idx, 1);
    end loop;

    exit when not exists (
      select 1
      from public.profiles p
      where upper(p.referral_code) = upper(v_code)
    );

    if v_attempts > 40 then
      raise exception 'No se pudo generar un código de referido único.';
    end if;
  end loop;

  return v_code;
end;
$$;

create or replace function public._profiles_ensure_referral_code ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.referral_code is null or btrim(new.referral_code) = '' then
    new.referral_code := public.generate_unique_referral_code ();
  else
    new.referral_code := upper(btrim(new.referral_code));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_ensure_referral_code on public.profiles;
create trigger trg_profiles_ensure_referral_code
before insert or update of referral_code on public.profiles
for each row
execute function public._profiles_ensure_referral_code ();

-- Backfill códigos para perfiles existentes.
do $$
declare
  r record;
begin
  for r in
    select p.id
    from public.profiles p
    where p.referral_code is null
       or btrim(p.referral_code) = ''
  loop
    update public.profiles
    set referral_code = public.generate_unique_referral_code ()
    where id = r.id;
  end loop;
end;
$$;

create or replace function public._profiles_apply_referral_from_auth_meta ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_referrer uuid;
begin
  if new.referred_by_profile_id is not null then
    return new;
  end if;

  select nullif(upper(btrim(u.raw_user_meta_data ->> 'referral_code')), '')
  into v_code
  from auth.users u
  where u.id = new.id;

  if v_code is null then
    return new;
  end if;

  select p.id
  into v_referrer
  from public.profiles p
  where upper(p.referral_code) = v_code
  limit 1;

  if v_referrer is null or v_referrer = new.id then
    return new;
  end if;

  new.referred_by_profile_id := v_referrer;
  new.referred_at := coalesce(new.referred_at, now());
  return new;
end;
$$;

drop trigger if exists trg_profiles_apply_referral_from_auth_meta on public.profiles;
create trigger trg_profiles_apply_referral_from_auth_meta
before insert on public.profiles
for each row
execute function public._profiles_apply_referral_from_auth_meta ();

create or replace function public._profiles_notify_referrer_on_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if new.referred_by_profile_id is null then
    return new;
  end if;

  select p.referral_code
  into v_code
  from public.profiles p
  where p.id = new.referred_by_profile_id;

  perform public.mc_insert_notification (
    new.referred_by_profile_id,
    'Nuevo usuario referido',
    format(
      'Alguien se registró con su código %s%s.',
      coalesce(v_code, ''),
      case
        when coalesce(btrim(new.business_name), '') <> ''
          then ' (' || btrim(new.business_name) || ')'
        else ''
      end
    ),
    'promocion',
    new.id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_profiles_notify_referrer_on_insert on public.profiles;
create trigger trg_profiles_notify_referrer_on_insert
after insert on public.profiles
for each row
execute function public._profiles_notify_referrer_on_insert ();

create or replace function public.profile_apply_referral_code (p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_referrer record;
  v_me record;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if v_code = '' then
    raise exception 'Indique un código de referido.';
  end if;

  select
    p.id,
    p.referral_code,
    p.referred_by_profile_id,
    p.business_name
  into v_me
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Complete su perfil antes de aplicar un código de referido.';
  end if;

  if v_me.referred_by_profile_id is not null then
    raise exception 'Ya tiene un referido registrado; no se puede cambiar.';
  end if;

  if upper(coalesce(v_me.referral_code, '')) = v_code then
    raise exception 'No puede usar su propio código de referido.';
  end if;

  select
    p.id,
    p.business_name,
    p.role
  into v_referrer
  from public.profiles p
  where upper(p.referral_code) = v_code
  limit 1;

  if not found then
    raise exception 'Código de referido no válido.';
  end if;

  update public.profiles
  set
    referred_by_profile_id = v_referrer.id,
    referred_at = now()
  where id = v_uid;

  perform public.mc_insert_notification (
    v_referrer.id,
    'Nuevo usuario referido',
    format(
      'Alguien se registró con su código %s%s.',
      v_code,
      case
        when coalesce(btrim(v_me.business_name), '') <> ''
          then ' (' || btrim(v_me.business_name) || ')'
        else ''
      end
    ),
    'promocion',
    v_uid::text
  );
end;
$$;

grant execute on function public.profile_apply_referral_code (text) to authenticated;

create or replace function public.list_admin_referral_stats (
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  referrer_id uuid,
  business_name text,
  rif text,
  role text,
  referral_code text,
  referred_count bigint,
  last_referral_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden ver métricas de referidos.';
  end if;

  return query
  select
    r.id as referrer_id,
    r.business_name,
    r.rif,
    r.role,
    r.referral_code,
    count(c.id)::bigint as referred_count,
    max(c.referred_at) as last_referral_at
  from public.profiles r
  inner join public.profiles c
    on c.referred_by_profile_id = r.id
  group by r.id, r.business_name, r.rif, r.role, r.referral_code
  order by referred_count desc, last_referral_at desc nulls last
  limit v_limit
  offset v_offset;
end;
$$;

grant execute on function public.list_admin_referral_stats (int, int) to authenticated;

create or replace function public.list_admin_referred_users (
  p_referrer_id uuid,
  p_limit int default 100,
  p_offset int default 0
)
returns table (
  profile_id uuid,
  business_name text,
  rif text,
  role text,
  referred_at timestamptz,
  account_access_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden ver usuarios referidos.';
  end if;

  if p_referrer_id is null then
    raise exception 'Referidor requerido';
  end if;

  return query
  select
    p.id as profile_id,
    p.business_name,
    p.rif,
    p.role,
    p.referred_at,
    p.account_access_status,
    p.created_at
  from public.profiles p
  where p.referred_by_profile_id = p_referrer_id
  order by p.referred_at desc nulls last, p.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

grant execute on function public.list_admin_referred_users (uuid, int, int)
  to authenticated;
