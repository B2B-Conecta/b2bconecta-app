-- Owner local para probar Cuentas (equivalente a DEV / gimenopueyo).
-- Email: owner@motoconecta.seed  Contraseña: admin123
--
--   supabase db query -f supabase/scripts/seed_local_owner.sql
--   supabase db query --linked -f supabase/scripts/seed_local_owner.sql
--   # o: psql "$DB_URL" -f supabase/scripts/seed_local_owner.sql

do $seed_owner$
declare
  v_id uuid := 'c3000003-0000-4000-8000-000000000001';
  v_email text := 'owner@motoconecta.seed';
  v_instance uuid;
  v_has_owner boolean;
begin
  execute 'create extension if not exists pgcrypto with schema extensions';

  select coalesce(
    (select id from auth.instances limit 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  )
  into v_instance;

  if exists (
    select 1 from auth.users u
    where lower(u.email) = v_email
      and u.id is distinct from v_id
  ) then
    raise exception
      'Ya existe % con otro UUID. Bórrelo o ajuste este script.',
      v_email;
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  values (
    v_instance,
    v_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt('admin123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  )
  on conflict (id) do update set
    email = excluded.email,
    encrypted_password = excluded.encrypted_password,
    email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
    updated_at = now();

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  select
    gen_random_uuid(),
    v_id,
    jsonb_build_object(
      'sub', v_id::text,
      'email', v_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    v_email,
    now(),
    now(),
    now()
  where not exists (
    select 1
    from auth.identities i
    where i.user_id = v_id
      and i.provider = 'email'
  );

  perform public._allow_profile_privilege ();

  insert into public.profiles (
    id,
    business_name,
    rif,
    role,
    phone,
    estado,
    ciudad,
    direccion,
    account_access_status,
    kyc_status,
    terms_accepted_at,
    terms_version
  )
  values (
    v_id,
    'B2B Conecta Owner',
    'J-300000000',
    'administrador',
    '+58 212-3000000',
    'Distrito Capital',
    'Caracas',
    'Oficina B2B Conecta (cuenta owner local).',
    'active',
    'aprobado',
    now(),
    '2026-06-13'
  )
  on conflict (id) do update set
    business_name = excluded.business_name,
    rif = excluded.rif,
    role = excluded.role,
    phone = excluded.phone,
    estado = excluded.estado,
    ciudad = excluded.ciudad,
    direccion = excluded.direccion,
    account_access_status = 'active',
    deactivated_at = null,
    deactivated_by = null,
    terms_accepted_at = coalesce(public.profiles.terms_accepted_at, now()),
    terms_version = coalesce(public.profiles.terms_version, '2026-06-13');

  select exists (select 1 from public.profiles p where p.is_owner)
  into v_has_owner;

  perform public._allow_profile_privilege ();

  if not v_has_owner then
    update public.profiles
    set is_owner = true
    where id = v_id;
  elsif not exists (
    select 1 from public.profiles p where p.id = v_id and p.is_owner
  ) then
    raise notice
      'Ya hay un owner. % queda como administrador (sin is_owner).',
      v_email;
  end if;
end;
$seed_owner$;
