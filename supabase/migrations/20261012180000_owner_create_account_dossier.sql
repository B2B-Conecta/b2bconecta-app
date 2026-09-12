-- Owner: crear cuenta Auth + expediente, y cargar documentos ajenos.

create or replace function public._is_owner_session ()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.is_owner
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') is distinct from 'rejected'
  );
$$;

revoke all on function public._is_owner_session () from public;
grant execute on function public._is_owner_session () to authenticated;

create or replace function public.owner_create_account (
  p_email text,
  p_password text,
  p_role text,
  p_business_name text,
  p_rif text default null,
  p_phone text default null,
  p_estado text default null,
  p_ciudad text default null,
  p_direccion text default null,
  p_fiscal_maps_url text default null,
  p_legal_contact_name text default null,
  p_legal_contact_email text default null,
  p_legal_contact_phone text default null,
  p_activate boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid ();
  v_email text := lower(trim(p_email));
  v_role text := lower(trim(p_role));
  v_password text := p_password;
  v_rif text := nullif(trim(p_rif), '');
  v_name text := nullif(trim(p_business_name), '');
  v_activate boolean := coalesce(p_activate, true);
  v_access text;
  v_kyc text;
  v_instance uuid;
begin
  perform public._assert_owner ();

  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Indique un correo válido';
  end if;

  if v_password is null or length(v_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres';
  end if;

  if v_role is null or v_role not in ('aliado', 'importador', 'administrador') then
    raise exception 'Rol no válido';
  end if;

  if v_name is null then
    raise exception 'Indique el nombre comercial';
  end if;

  if exists (
    select 1
    from auth.users u
    where lower(trim(u.email::text)) = v_email
  ) then
    raise exception 'Ese correo ya está registrado';
  end if;

  if v_rif is not null and exists (
    select 1
    from public.profiles p
    where p.rif = v_rif
  ) then
    raise exception 'Ese RIF ya está registrado';
  end if;

  if v_role = 'administrador' or v_activate then
    v_access := 'active';
  elsif v_role = 'aliado' then
    v_access := 'draft';
  else
    v_access := 'draft';
  end if;

  if v_role = 'aliado' then
    v_kyc := case when v_activate then 'aprobado' else 'pendiente' end;
  else
    v_kyc := null;
  end if;

  execute 'create extension if not exists pgcrypto with schema extensions';

  select coalesce(
    (select id from auth.instances limit 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  )
  into v_instance;

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
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

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
  values (
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
    fiscal_maps_url,
    legal_contact_name,
    legal_contact_email,
    legal_contact_phone,
    account_access_status,
    kyc_status,
    terms_accepted_at,
    terms_version
  )
  values (
    v_id,
    v_name,
    v_rif,
    v_role,
    nullif(trim(p_phone), ''),
    nullif(trim(p_estado), ''),
    nullif(trim(p_ciudad), ''),
    nullif(trim(p_direccion), ''),
    nullif(trim(p_fiscal_maps_url), ''),
    nullif(trim(p_legal_contact_name), ''),
    nullif(trim(p_legal_contact_email), ''),
    nullif(trim(p_legal_contact_phone), ''),
    v_access,
    v_kyc,
    case
      when v_access = 'active' then now()
      else null
    end,
    case
      when v_access = 'active' then '2026-06-13'
      else null
    end
  );

  if v_access = 'active' then
    perform public.mc_insert_notification (
      v_id,
      'Cuenta creada',
      'B2B Conecta creó su cuenta. Ya puede entrar con su correo y la contraseña que le indicaron.',
      'kyc',
      v_id::text
    );
  else
    perform public.mc_insert_notification (
      v_id,
      'Cuenta creada',
      'B2B Conecta creó su cuenta. Complete el registro en la app para solicitar el acceso.',
      'kyc',
      v_id::text
    );
  end if;

  return v_id;
end;
$$;

create or replace function public.owner_update_account_dossier (
  p_profile_id uuid,
  p_business_name text,
  p_rif text default null,
  p_phone text default null,
  p_estado text default null,
  p_ciudad text default null,
  p_direccion text default null,
  p_fiscal_maps_url text default null,
  p_legal_contact_name text default null,
  p_legal_contact_email text default null,
  p_legal_contact_phone text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := nullif(trim(p_business_name), '');
  v_rif text := nullif(trim(p_rif), '');
begin
  perform public._owner_guard_target (p_profile_id);

  if v_name is null then
    raise exception 'Indique el nombre comercial';
  end if;

  if v_rif is not null and exists (
    select 1
    from public.profiles p
    where p.rif = v_rif
      and p.id is distinct from p_profile_id
  ) then
    raise exception 'Ese RIF ya está registrado';
  end if;

  update public.profiles
  set
    business_name = v_name,
    rif = v_rif,
    phone = nullif(trim(p_phone), ''),
    estado = nullif(trim(p_estado), ''),
    ciudad = nullif(trim(p_ciudad), ''),
    direccion = nullif(trim(p_direccion), ''),
    fiscal_maps_url = nullif(trim(p_fiscal_maps_url), ''),
    legal_contact_name = nullif(trim(p_legal_contact_name), ''),
    legal_contact_email = nullif(trim(p_legal_contact_email), ''),
    legal_contact_phone = nullif(trim(p_legal_contact_phone), '')
  where id = p_profile_id;

  perform public.mc_insert_notification (
    p_profile_id,
    'Expediente actualizado',
    'B2B Conecta actualizó los datos de su expediente.',
    'kyc',
    p_profile_id::text
  );
end;
$$;

create or replace function public.owner_insert_profile_document (
  p_profile_id uuid,
  p_doc_type text,
  p_storage_path text,
  p_file_name text,
  p_mark_approved boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := trim(p_doc_type);
  v_path text := trim(p_storage_path);
  v_approved boolean := coalesce(p_mark_approved, true);
begin
  perform public._owner_guard_target (p_profile_id);

  if v_type is null or v_type = '' then
    raise exception 'Tipo de documento requerido';
  end if;

  if v_path is null or v_path = '' then
    raise exception 'Ruta de archivo requerida';
  end if;

  update public.profile_documents
  set is_current = false
  where profile_id = p_profile_id
    and doc_type = v_type
    and is_current;

  insert into public.profile_documents (
    profile_id,
    doc_type,
    storage_path,
    file_name,
    is_current,
    review_status,
    reviewed_at,
    reviewed_by
  )
  values (
    p_profile_id,
    v_type,
    v_path,
    nullif(trim(p_file_name), ''),
    true,
    case when v_approved then 'aprobado' else 'pendiente' end,
    case when v_approved then now() else null end,
    case when v_approved then auth.uid () else null end
  );
end;
$$;

revoke all on function public.owner_create_account (
  text, text, text, text, text, text, text, text, text, text, text, text, text, boolean
) from public;
revoke all on function public.owner_update_account_dossier (
  uuid, text, text, text, text, text, text, text, text, text, text
) from public;
revoke all on function public.owner_insert_profile_document (
  uuid, text, text, text, boolean
) from public;

grant execute on function public.owner_create_account (
  text, text, text, text, text, text, text, text, text, text, text, text, text, boolean
) to authenticated;
grant execute on function public.owner_update_account_dossier (
  uuid, text, text, text, text, text, text, text, text, text, text
) to authenticated;
grant execute on function public.owner_insert_profile_document (
  uuid, text, text, text, boolean
) to authenticated;

drop policy if exists profile_documents_storage_insert_owner on storage.objects;
create policy profile_documents_storage_insert_owner
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-documents'
  and public._is_owner_session ()
);

drop policy if exists profile_documents_storage_update_owner on storage.objects;
create policy profile_documents_storage_update_owner
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-documents'
  and public._is_owner_session ()
)
with check (
  bucket_id = 'profile-documents'
  and public._is_owner_session ()
);

comment on function public.owner_create_account (
  text, text, text, text, text, text, text, text, text, text, text, text, text, boolean
) is
  'Owner: crea auth.users + perfil y avisa en la campana.';
comment on function public.owner_update_account_dossier (
  uuid, text, text, text, text, text, text, text, text, text, text
) is
  'Owner: actualiza el expediente fiscal de otra cuenta.';
comment on function public.owner_insert_profile_document (
  uuid, text, text, text, boolean
) is
  'Owner: registra un documento KYC subido en nombre del usuario.';
