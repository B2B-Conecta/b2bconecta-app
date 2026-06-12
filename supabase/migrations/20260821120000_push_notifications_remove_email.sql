-- Remove Gmail transactional email pipeline; add device push tokens + FCM dispatch.

drop function if exists public._dispatch_account_email (text, uuid);
drop function if exists public.resolve_notification_email (uuid);
drop table if exists public.account_email_log;

-- ---------------------------------------------------------------------------
-- Device push tokens (FCM)
-- ---------------------------------------------------------------------------
create table if not exists public.device_push_tokens (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text not null default 'unknown',
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists device_push_tokens_user_idx
  on public.device_push_tokens (user_id, updated_at desc);

alter table public.device_push_tokens enable row level security;

create policy device_push_tokens_select_own
  on public.device_push_tokens for select
  using (auth.uid () = user_id);

create policy device_push_tokens_insert_own
  on public.device_push_tokens for insert
  with check (auth.uid () = user_id);

create policy device_push_tokens_update_own
  on public.device_push_tokens for update
  using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

create policy device_push_tokens_delete_own
  on public.device_push_tokens for delete
  using (auth.uid () = user_id);

grant select, insert, update, delete on public.device_push_tokens to authenticated;

create or replace function public.upsert_device_push_token (
  p_token text,
  p_platform text default 'unknown'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_token text := nullif(trim(p_token), '');
  v_platform text := coalesce(nullif(trim(p_platform), ''), 'unknown');
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_token is null then
    raise exception 'Token requerido';
  end if;

  insert into public.device_push_tokens (user_id, token, platform, updated_at)
  values (v_uid, v_token, v_platform, now())
  on conflict (user_id, token) do update
  set platform = excluded.platform,
      updated_at = now();
end;
$$;

grant execute on function public.upsert_device_push_token (text, text) to authenticated;

create or replace function public.remove_device_push_token (p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_token text := nullif(trim(p_token), '');
begin
  if v_uid is null or v_token is null then
    return;
  end if;
  delete from public.device_push_tokens
  where user_id = v_uid
    and token = v_token;
end;
$$;

grant execute on function public.remove_device_push_token (text) to authenticated;

-- ---------------------------------------------------------------------------
-- Push dispatch via Edge Function + pg_net (optional Vault secrets)
--   push_supabase_url
--   push_service_role_key
--   push_webhook_secret  → PUSH_WEBHOOK_SECRET in Edge Function
-- ---------------------------------------------------------------------------
create or replace function public._dispatch_push_notification (
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_related_id text,
  p_notification_id uuid
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
  if p_user_id is null then
    return;
  end if;

  begin
    select decrypted_secret into v_base_url
    from vault.decrypted_secrets
    where name = 'push_supabase_url'
    limit 1;

    select decrypted_secret into v_service_key
    from vault.decrypted_secrets
    where name = 'push_service_role_key'
    limit 1;

    select decrypted_secret into v_webhook_secret
    from vault.decrypted_secrets
    where name = 'push_webhook_secret'
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
    url := rtrim(v_base_url, '/') || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key,
      'x-push-webhook-secret', v_webhook_secret
    ),
    body := jsonb_build_object(
      'user_id', p_user_id::text,
      'title', coalesce(nullif(trim(p_title), ''), 'MotoLink'),
      'body', coalesce(nullif(trim(p_body), ''), ''),
      'type', coalesce(nullif(trim(p_type), ''), 'mensaje'),
      'related_id', nullif(trim(p_related_id), ''),
      'notification_id', p_notification_id::text,
      'source', 'database'
    )
  )
  into v_request_id;
exception
  when others then
    raise warning 'push dispatch failed: %', sqlerrm;
end;
$$;

revoke all on function public._dispatch_push_notification (uuid, text, text, text, text, uuid) from public;
grant execute on function public._dispatch_push_notification (uuid, text, text, text, text, uuid) to service_role;

create or replace function public.trg_notifications_dispatch_push ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._dispatch_push_notification (
    new.user_id,
    new.title,
    new.body,
    new.type,
    new.related_id,
    new.id
  );
  return new;
end;
$$;

drop trigger if exists notifications_after_insert_push on public.notifications;

create trigger notifications_after_insert_push
  after insert on public.notifications
  for each row
  execute function public.trg_notifications_dispatch_push ();

-- KYC: in-app notifications only (no Gmail).
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

  perform public.mc_insert_notification (
    v_uid,
    'Solicitud enviada a revisión',
    'MotoLink revisará su documentación. Le avisaremos en la app cuando haya novedades.',
    'kyc',
    v_uid::text
  );
end;
$$;

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

  select p.role into v_role
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

    perform public.mc_insert_notification (
      p_profile_id,
      'Perfil validado',
      'Su acceso a MotoLink está habilitado. Ya puede operar en la plataforma.',
      'kyc',
      p_profile_id::text
    );
  elsif v_st = 'rechazado' then
    update public.profiles
    set
      kyc_status = v_st,
      account_access_status = 'rejected'::text,
      account_review_note = v_note
    where id = p_profile_id;

    perform public.mc_insert_notification (
      p_profile_id,
      'Documentación rechazada',
      coalesce(
        v_note,
        'Revise su expediente en Perfil y vuelva a enviar a revisión.'
      ),
      'kyc',
      p_profile_id::text
    );
  else
    update public.profiles
    set kyc_status = v_st
    where id = p_profile_id;
  end if;
end;
$$;
