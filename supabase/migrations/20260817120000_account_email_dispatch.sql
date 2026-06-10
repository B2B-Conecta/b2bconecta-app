-- Registro de envíos (deduplicación) + despacho opcional vía Edge Function + pg_net.
create table if not exists public.account_email_log (
  id bigserial primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  event text not null,
  sent_at timestamptz not null default now()
);

create index if not exists account_email_log_profile_event_sent_idx
  on public.account_email_log (profile_id, event, sent_at desc);

alter table public.account_email_log enable row level security;

revoke all on table public.account_email_log from anon, authenticated;
grant select, insert on table public.account_email_log to service_role;

-- Despacho opcional de correos transaccionales vía Edge Function + pg_net.
-- Configurar en Vault (Dashboard → Database → Vault):
--   account_email_supabase_url  → https://<project-ref>.supabase.co
--   account_email_service_role_key → service role key
--   account_email_webhook_secret → mismo valor que EMAIL_WEBHOOK_SECRET en Edge Function

create extension if not exists pg_net with schema extensions;

create or replace function public._dispatch_account_email (
  p_event text,
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_base_url text;
  v_service_key text;
  v_webhook_secret text;
  v_request_id bigint;
begin
  if p_event is null or trim(p_event) = '' or p_profile_id is null then
    return;
  end if;

  begin
    select decrypted_secret
      into v_base_url
    from vault.decrypted_secrets
    where name = 'account_email_supabase_url'
    limit 1;

    select decrypted_secret
      into v_service_key
    from vault.decrypted_secrets
    where name = 'account_email_service_role_key'
    limit 1;

    select decrypted_secret
      into v_webhook_secret
    from vault.decrypted_secrets
    where name = 'account_email_webhook_secret'
    limit 1;
  exception
    when undefined_table or invalid_schema_name then
      return;
  end;

  if coalesce(v_base_url, '') = ''
     or coalesce(v_service_key, '') = ''
     or coalesce(v_webhook_secret, '') = '' then
    return;
  end if;

  select net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/send-account-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key,
      'x-email-webhook-secret', v_webhook_secret
    ),
    body := jsonb_build_object(
      'event', trim(p_event),
      'profile_id', p_profile_id::text,
      'source', 'database'
    )
  )
  into v_request_id;
exception
  when others then
    raise warning 'account email dispatch (%) failed: %', p_event, sqlerrm;
end;
$$;

revoke all on function public._dispatch_account_email (text, uuid) from public;
grant execute on function public._dispatch_account_email (text, uuid) to service_role;

-- Re-envío KYC: correo al aliado tras registro inicial.
create or replace function public.profile_submit_kyc_for_review ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_name text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, nullif(trim(p.business_name), '')
    into v_role, v_name
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;

  if v_role <> 'aliado'::text then
    raise exception 'Solo los aliados pueden enviar documentación KYC.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.terms_accepted_at is not null
      and nullif(trim(p.terms_version), '') is not null
  ) then
    raise exception 'Debe aceptar los términos y condiciones antes de enviar a revisión.';
  end if;

  if not public.profile_aliado_kyc_profile_complete (v_uid) then
    raise exception
      'Complete RIF, dirección fiscal (estado, ciudad, domicilio) y enlace de Google Maps en Mi perfil.';
  end if;

  if not public.profile_aliado_has_required_documents (v_uid) then
    raise exception
      'Suba foto de la tienda, cédula del propietario y registro mercantil antes de enviar a revisión.';
  end if;

  update public.profiles
  set
    kyc_status = 'en_revision'::text,
    account_access_status = 'pending_review'::text,
    account_review_note = null
  where id = v_uid;

  update public.profile_documents
  set
    review_status = 'en_revision'::text,
    review_note = null,
    reviewed_at = null,
    reviewed_by = null
  where profile_id = v_uid
    and is_current = true
    and coalesce(review_status, 'pendiente') in ('pendiente'::text, 'rechazado'::text);

  perform public._notify_admins_kyc_review (v_uid, v_name, v_role);
  perform public._dispatch_account_email ('registration_submitted', v_uid);
end;
$$;

-- Aprobación admin: correo de perfil validado.
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

    perform public._dispatch_account_email ('profile_approved', p_profile_id);
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
