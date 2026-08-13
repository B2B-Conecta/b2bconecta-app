-- Referidos por vendedores externos (admin): no usan la app; tienen código/QR.
-- Los perfiles dejan de generar códigos propios; la atribución apunta a external_referrers.

create table if not exists public.external_referrers (
  id uuid primary key default gen_random_uuid (),
  full_name text not null,
  phone text not null,
  email text not null,
  code text not null,
  active boolean not null default true,
  notes text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_referrers_full_name_chk check (btrim(full_name) <> ''),
  constraint external_referrers_phone_chk check (btrim(phone) <> ''),
  constraint external_referrers_email_chk check (btrim(email) <> ''),
  constraint external_referrers_code_chk check (btrim(code) <> '')
);

comment on table public.external_referrers is
  'Vendedores externos registrados por admin; generan códigos/QR de referido.';

create unique index if not exists external_referrers_code_uidx
  on public.external_referrers (upper(code));

create index if not exists external_referrers_active_idx
  on public.external_referrers (active)
  where active;

alter table public.profiles
  add column if not exists referred_by_external_id uuid
    references public.external_referrers (id) on delete set null;

comment on column public.profiles.referred_by_external_id is
  'Vendedor externo que refirió a este usuario (si aplica).';

create index if not exists profiles_referred_by_external_idx
  on public.profiles (referred_by_external_id)
  where referred_by_external_id is not null;

-- Códigos únicos compartidos entre externos (y legacy profiles.referral_code).
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

    exit when
      not exists (
        select 1
        from public.external_referrers e
        where upper(e.code) = upper(v_code)
      )
      and not exists (
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

-- Ya no auto-generar código en profiles.
drop trigger if exists trg_profiles_ensure_referral_code on public.profiles;

-- Notificaciones a referidor-usuario: desactivar (externos no tienen cuenta).
drop trigger if exists trg_profiles_notify_referrer_on_insert on public.profiles;

create or replace function public._profiles_apply_referral_from_auth_meta ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_ext uuid;
begin
  if new.referred_by_external_id is not null then
    return new;
  end if;

  select nullif(upper(btrim(u.raw_user_meta_data ->> 'referral_code')), '')
  into v_code
  from auth.users u
  where u.id = new.id;

  if v_code is null then
    return new;
  end if;

  select e.id
  into v_ext
  from public.external_referrers e
  where e.active
    and upper(e.code) = v_code
  limit 1;

  if v_ext is null then
    return new;
  end if;

  new.referred_by_external_id := v_ext;
  new.referred_at := coalesce(new.referred_at, now());
  -- Limpiar vínculo legado usuario→usuario si existía en meta vieja.
  new.referred_by_profile_id := null;
  return new;
end;
$$;

create or replace function public.profile_apply_referral_code (p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_ext record;
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
    p.referred_by_external_id,
    p.referred_by_profile_id,
    p.business_name
  into v_me
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Complete su perfil antes de aplicar un código de referido.';
  end if;

  if v_me.referred_by_external_id is not null
     or v_me.referred_by_profile_id is not null then
    raise exception 'Ya tiene un referido registrado; no se puede cambiar.';
  end if;

  select e.id, e.full_name, e.code
  into v_ext
  from public.external_referrers e
  where e.active
    and upper(e.code) = v_code
  limit 1;

  if not found then
    raise exception 'Código de referido no válido.';
  end if;

  update public.profiles
  set
    referred_by_external_id = v_ext.id,
    referred_by_profile_id = null,
    referred_at = now()
  where id = v_uid;
end;
$$;

grant execute on function public.profile_apply_referral_code (text) to authenticated;

create or replace function public._require_admin ()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
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
    raise exception 'Solo administradores.';
  end if;
  return v_uid;
end;
$$;

create or replace function public.admin_create_external_referrer (
  p_full_name text,
  p_phone text,
  p_email text,
  p_notes text default null
)
returns public.external_referrers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public._require_admin ();
  v_row public.external_referrers;
begin
  if btrim(coalesce(p_full_name, '')) = '' then
    raise exception 'Nombre requerido.';
  end if;
  if btrim(coalesce(p_phone, '')) = '' then
    raise exception 'Teléfono requerido.';
  end if;
  if btrim(coalesce(p_email, '')) = '' then
    raise exception 'Correo requerido.';
  end if;

  insert into public.external_referrers (
    full_name,
    phone,
    email,
    code,
    notes,
    created_by
  )
  values (
    btrim(p_full_name),
    btrim(p_phone),
    lower(btrim(p_email)),
    public.generate_unique_referral_code (),
    nullif(btrim(coalesce(p_notes, '')), ''),
    v_uid
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.admin_create_external_referrer (text, text, text, text)
  to authenticated;

create or replace function public.admin_update_external_referrer (
  p_id uuid,
  p_full_name text default null,
  p_phone text default null,
  p_email text default null,
  p_active boolean default null,
  p_notes text default null
)
returns public.external_referrers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.external_referrers;
begin
  perform public._require_admin ();

  if p_id is null then
    raise exception 'ID requerido.';
  end if;

  update public.external_referrers e
  set
    full_name = coalesce(nullif(btrim(coalesce(p_full_name, '')), ''), e.full_name),
    phone = coalesce(nullif(btrim(coalesce(p_phone, '')), ''), e.phone),
    email = coalesce(nullif(lower(btrim(coalesce(p_email, ''))), ''), e.email),
    active = coalesce(p_active, e.active),
    notes = case
      when p_notes is null then e.notes
      else nullif(btrim(p_notes), '')
    end,
    updated_at = now()
  where e.id = p_id
  returning * into v_row;

  if not found then
    raise exception 'Vendedor externo no encontrado.';
  end if;

  return v_row;
end;
$$;

grant execute on function public.admin_update_external_referrer (
  uuid, text, text, text, boolean, text
) to authenticated;

create or replace function public.list_admin_external_referrers (
  p_limit int default 100,
  p_offset int default 0,
  p_active_only boolean default false
)
returns table (
  referrer_id uuid,
  full_name text,
  phone text,
  email text,
  code text,
  active boolean,
  notes text,
  referred_count bigint,
  last_referral_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  perform public._require_admin ();

  return query
  select
    e.id as referrer_id,
    e.full_name,
    e.phone,
    e.email,
    e.code,
    e.active,
    e.notes,
    count(p.id)::bigint as referred_count,
    max(p.referred_at) as last_referral_at,
    e.created_at
  from public.external_referrers e
  left join public.profiles p
    on p.referred_by_external_id = e.id
  where (not coalesce(p_active_only, false)) or e.active
  group by
    e.id,
    e.full_name,
    e.phone,
    e.email,
    e.code,
    e.active,
    e.notes,
    e.created_at
  order by e.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

grant execute on function public.list_admin_external_referrers (int, int, boolean)
  to authenticated;

-- Reemplaza listado admin: ahora es por vendedor externo.
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
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  perform public._require_admin ();

  return query
  select
    e.id as referrer_id,
    e.full_name as business_name,
    e.phone as rif,
    'vendedor_externo'::text as role,
    e.code as referral_code,
    count(p.id)::bigint as referred_count,
    max(p.referred_at) as last_referral_at
  from public.external_referrers e
  left join public.profiles p
    on p.referred_by_external_id = e.id
  where e.active
  group by e.id, e.full_name, e.phone, e.code
  having count(p.id) > 0
  order by referred_count desc, last_referral_at desc nulls last
  limit v_limit
  offset v_offset;
end;
$$;

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
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 500));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  perform public._require_admin ();

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
  where p.referred_by_external_id = p_referrer_id
  order by p.referred_at desc nulls last, p.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

alter table public.external_referrers enable row level security;

drop policy if exists external_referrers_admin_all on public.external_referrers;
create policy external_referrers_admin_all
  on public.external_referrers
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );
