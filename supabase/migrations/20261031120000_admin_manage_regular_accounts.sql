-- Administradores (role = administrador) pueden listar, crear y eliminar
-- cuentas regulares (aliado / importador), además de editar su expediente
-- y su acceso. El propietario (is_owner) conserva el resto:
-- crear otras cuentas de administración, cambiar roles, moderar catálogos
-- y gestionar a otros administradores. Nadie toca la cuenta is_owner.

create or replace function public._caller_has_owner_privileges ()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(auth.jwt () ->> 'role', '') = 'service_role'
     or coalesce(
       current_setting('request.jwt.claim.role', true),
       ''
     ) = 'service_role' then
    return true;
  end if;
  return public._is_owner_session ();
end;
$$;

revoke all on function public._caller_has_owner_privileges () from public;

create or replace function public._is_active_administrador_session ()
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
      and p.role = 'administrador'
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') is distinct from 'rejected'
  );
$$;

revoke all on function public._is_active_administrador_session () from public;
grant execute on function public._is_active_administrador_session () to authenticated;

create or replace function public._guard_account_operator_target (p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
  v_role text;
begin
  perform public._assert_administrador ();

  if p_profile_id is null then
    raise exception 'Perfil requerido';
  end if;

  if p_profile_id = auth.uid () then
    raise exception 'No puede modificar su propia cuenta' using errcode = '42501';
  end if;

  select p.is_owner, lower(trim(p.role))
    into v_is_owner, v_role
  from public.profiles p
  where p.id = p_profile_id;

  if not found then
    raise exception 'Perfil no encontrado';
  end if;

  if coalesce(v_is_owner, false) then
    raise exception 'No se puede modificar la cuenta del propietario'
      using errcode = '42501';
  end if;

  if public._caller_has_owner_privileges () then
    return;
  end if;

  if v_role is distinct from 'aliado' and v_role is distinct from 'importador' then
    raise exception 'Solo puede gestionar cuentas de tienda minorista o mayorista'
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public._guard_account_operator_target (uuid) from public;


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
  perform public._assert_administrador ();

  if v_email is null or position('@' in v_email) = 0 then
    raise exception 'Indique un correo válido';
  end if;

  if v_password is null or length(v_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres';
  end if;

  if v_role is null or v_role not in ('aliado', 'importador', 'administrador') then
    raise exception 'Rol no válido';
  end if;

  if v_role = 'administrador' and not public._caller_has_owner_privileges () then
    raise exception 'Solo el propietario puede crear cuentas de administración'
      using errcode = '42501';
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
  perform public._guard_account_operator_target (p_profile_id);

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
  perform public._guard_account_operator_target (p_profile_id);

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
  perform public._guard_account_operator_target (p_profile_id);

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

  perform public.mc_insert_notification (
    p_profile_id,
    'Cuenta deshabilitada',
    v_note,
    'kyc',
    p_profile_id::text
  );
end;
$$;

create or replace function public.owner_hard_delete_profile (
  p_profile_id uuid,
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
  perform public._guard_account_operator_target (p_profile_id);

  select lower(trim(u.email::text))
    into v_email
  from auth.users u
  where u.id = p_profile_id;

  if v_email is null then
    raise exception 'Usuario de Auth no encontrado';
  end if;

  if v_confirm is distinct from v_email then
    raise exception 'Escriba el correo de la cuenta para confirmar el borrado';
  end if;

  if exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = p_profile_id
       or tr.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene pedidos. Use baja lógica para conservarlos.';
  end if;

  if exists (
    select 1
    from public.commission_settlements cs
    where cs.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene cortes de comisión. Use baja lógica para conservarlos.';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.aliado_id = p_profile_id
       or r.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene valoraciones. Use baja lógica para conservarlos.';
  end if;

  update public.commission_settlements
  set created_by = null
  where created_by = p_profile_id;

  update public.commission_settlements
  set issued_by = null
  where issued_by = p_profile_id;

  update public.order_ratings
  set
    comment_hidden_by = null
  where comment_hidden_by = p_profile_id;

  update public.order_ratings
  set submitted_by_admin_id = null
  where submitted_by_admin_id = p_profile_id;

  update public.profile_documents
  set reviewed_by = null
  where reviewed_by = p_profile_id;

  update public.transaction_requests
  set confirmado_por = null
  where confirmado_por = p_profile_id;

  delete from public.products p
  where p.owner_id = p_profile_id;

  delete from auth.identities i
  where i.user_id = p_profile_id;

  delete from auth.users u
  where u.id = p_profile_id;

  if not found then
    raise exception 'No se pudo borrar el usuario de Auth';
  end if;
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
  perform public._assert_administrador ();

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
  v_prev text;
  v_role text;
begin
  perform public._guard_account_operator_target (p_profile_id);

  v_status := lower(trim(p_status));
  if v_status is null or v_status not in ('active', 'rejected') then
    raise exception 'Estado de acceso no valido';
  end if;

  if v_status = 'rejected' and v_note is null then
    raise exception 'Indique el motivo del bloqueo';
  end if;

  select p.account_access_status, p.role
    into v_prev, v_role
  from public.profiles p
  where p.id = p_profile_id;

  perform public._allow_profile_privilege ();

  if v_status = 'active' then
    update public.profiles
    set
      account_access_status = 'active',
      account_review_note = null,
      deactivated_at = null,
      deactivated_by = null,
      terms_accepted_at = coalesce(terms_accepted_at, now()),
      terms_version = coalesce(nullif(trim(terms_version), ''), '2026-06-13'),
      kyc_status = case
        when role = 'aliado' then 'aprobado'
        else kyc_status
      end
    where id = p_profile_id;

    if v_prev in ('draft', 'pending_review') then
      perform public.mc_insert_notification (
        p_profile_id,
        'Cuenta activada',
        'B2B Conecta habilitó su cuenta con el expediente cargado. Ya puede entrar.',
        'kyc',
        p_profile_id::text
      );
    else
      perform public.mc_insert_notification (
        p_profile_id,
        'Cuenta reactivada',
        'B2B Conecta restauró el acceso a su cuenta.',
        'kyc',
        p_profile_id::text
      );
    end if;
  else
    update public.profiles
    set
      account_access_status = 'rejected',
      account_review_note = v_note,
      deactivated_at = null,
      deactivated_by = null
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Cuenta bloqueada',
      coalesce(v_note, 'B2B Conecta bloqueó el acceso a su cuenta.'),
      'kyc',
      p_profile_id::text
    );
  end if;
end;
$$;

comment on function public.owner_create_account (
  text, text, text, text, text, text, text, text, text, text, text, text, text, boolean
) is
  'Administrador: crea auth.users + perfil. Solo el propietario crea otra cuenta de administración.';

comment on function public.owner_deactivate_profile (uuid, text) is
  'Baja lógica. El propietario también puede dar de baja a otros administradores; un admin solo a aliado o importador.';

comment on function public.owner_hard_delete_profile (uuid, text) is
  'Borra auth.users y el perfil si no hay pedidos. Misma restricción de objetivo que la baja lógica.';

comment on function public.owner_list_profiles () is
  'Administrador: listado de cuentas con email de Auth.';

comment on function public.owner_update_account_dossier (
  uuid, text, text, text, text, text, text, text, text, text, text
) is
  'Actualiza el expediente de otra cuenta. Un admin no alcanza al propietario ni a otras cuentas de administración.';

comment on function public.owner_insert_profile_document (
  uuid, text, text, text, boolean
) is
  'Adjunta un documento al expediente. Un admin no alcanza al propietario ni a otras cuentas de administración.';

comment on function public.owner_set_account_access (uuid, text, text) is
  'Bloquea, activa o reactiva otra cuenta. Un admin no alcanza al propietario ni a otras cuentas de administración.';

create or replace function public._can_write_profile_document_object (p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_folder text;
  v_id uuid;
  v_is_owner boolean;
  v_role text;
begin
  if not public._is_active_administrador_session () then
    return false;
  end if;

  v_folder := (storage.foldername(p_name))[1];
  if v_folder is null or v_folder = '' then
    return false;
  end if;

  begin
    v_id := v_folder::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  if v_id = auth.uid () then
    return false;
  end if;

  select p.is_owner, lower(trim(p.role))
    into v_is_owner, v_role
  from public.profiles p
  where p.id = v_id;

  if not found or coalesce(v_is_owner, false) then
    return false;
  end if;

  if public._caller_has_owner_privileges () then
    return true;
  end if;

  return v_role in ('aliado', 'importador');
end;
$$;

revoke all on function public._can_write_profile_document_object (text) from public;
grant execute on function public._can_write_profile_document_object (text) to authenticated;

drop policy if exists profile_documents_storage_insert_owner on storage.objects;
create policy profile_documents_storage_insert_owner
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-documents'
  and public._can_write_profile_document_object (name)
);

drop policy if exists profile_documents_storage_update_owner on storage.objects;
create policy profile_documents_storage_update_owner
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-documents'
  and public._can_write_profile_document_object (name)
)
with check (
  bucket_id = 'profile-documents'
  and public._can_write_profile_document_object (name)
);
