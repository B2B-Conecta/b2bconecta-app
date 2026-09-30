-- Web Push (PWA / iOS Home Screen). Extiende el despacho FCM existente.
-- user_id siempre sale de auth.uid() en los RPC de cliente.

create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid (),
  user_id uuid not null references auth.users (id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  platform text not null default 'unknown',
  environment text not null default 'unknown',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint web_push_subscriptions_endpoint_key unique (endpoint)
);

create index if not exists web_push_subscriptions_user_active_idx
  on public.web_push_subscriptions (user_id, updated_at desc)
  where is_active = true;

alter table public.web_push_subscriptions enable row level security;

create policy web_push_subscriptions_select_own
  on public.web_push_subscriptions for select
  to authenticated
  using (auth.uid () = user_id);

create policy web_push_subscriptions_insert_own
  on public.web_push_subscriptions for insert
  to authenticated
  with check (auth.uid () = user_id);

create policy web_push_subscriptions_update_own
  on public.web_push_subscriptions for update
  to authenticated
  using (auth.uid () = user_id)
  with check (auth.uid () = user_id);

create policy web_push_subscriptions_delete_own
  on public.web_push_subscriptions for delete
  to authenticated
  using (auth.uid () = user_id);

grant select, insert, update, delete on public.web_push_subscriptions to authenticated;

create or replace function public._web_push_endpoint_ok (p_endpoint text)
returns boolean
language sql
immutable
as $$
  select
    p_endpoint is not null
    and length(p_endpoint) between 32 and 2048
    and p_endpoint like 'https://%'
    and position(' ' in p_endpoint) = 0;
$$;

create or replace function public._web_push_key_ok (p_value text)
returns boolean
language sql
immutable
as $$
  select
    p_value is not null
    and length(p_value) between 8 and 512
    and p_value !~ '\s';
$$;

create or replace function public.upsert_web_push_subscription (
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null,
  p_platform text default 'unknown',
  p_environment text default 'unknown'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_endpoint text := nullif(trim(p_endpoint), '');
  v_p256dh text := nullif(trim(p_p256dh), '');
  v_auth text := nullif(trim(p_auth), '');
  v_ua text := nullif(trim(p_user_agent), '');
  v_platform text := coalesce(nullif(trim(p_platform), ''), 'unknown');
  v_env text := coalesce(nullif(trim(p_environment), ''), 'unknown');
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  if not public._web_push_endpoint_ok (v_endpoint)
     or not public._web_push_key_ok (v_p256dh)
     or not public._web_push_key_ok (v_auth) then
    raise exception 'Suscripción Web Push inválida' using errcode = '22023';
  end if;
  if v_env not in ('local', 'dev', 'main', 'unknown') then
    v_env := 'unknown';
  end if;
  if v_platform not in ('ios', 'android', 'desktop', 'unknown') then
    v_platform := 'unknown';
  end if;
  if v_ua is not null then
    v_ua := left(v_ua, 400);
  end if;

  insert into public.web_push_subscriptions (
    user_id, endpoint, p256dh, auth, user_agent, platform, environment,
    is_active, created_at, updated_at
  )
  values (
    v_uid, v_endpoint, v_p256dh, v_auth, v_ua, v_platform, v_env,
    true, now(), now()
  )
  on conflict (endpoint) do update
  set user_id = v_uid,
      p256dh = excluded.p256dh,
      auth = excluded.auth,
      user_agent = excluded.user_agent,
      platform = excluded.platform,
      environment = excluded.environment,
      is_active = true,
      updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.upsert_web_push_subscription (
  text, text, text, text, text, text
) to authenticated;

create or replace function public.deactivate_web_push_subscription (p_endpoint text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_endpoint text := nullif(trim(p_endpoint), '');
begin
  if v_uid is null or v_endpoint is null then
    return;
  end if;
  update public.web_push_subscriptions
  set is_active = false,
      updated_at = now()
  where user_id = v_uid
    and endpoint = v_endpoint
    and is_active = true;
end;
$$;

grant execute on function public.deactivate_web_push_subscription (text) to authenticated;

create or replace function public.deactivate_my_web_push_subscriptions ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
begin
  if v_uid is null then
    return;
  end if;
  update public.web_push_subscriptions
  set is_active = false,
      updated_at = now()
  where user_id = v_uid
    and is_active = true;
end;
$$;

grant execute on function public.deactivate_my_web_push_subscriptions () to authenticated;

-- Service role / Edge Function: endpoints 404/410.
create or replace function public.deactivate_web_push_endpoint (p_endpoint text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_endpoint text := nullif(trim(p_endpoint), '');
begin
  if v_endpoint is null then
    return;
  end if;
  update public.web_push_subscriptions
  set is_active = false,
      updated_at = now()
  where endpoint = v_endpoint
    and is_active = true;
end;
$$;

revoke all on function public.deactivate_web_push_endpoint (text) from public, anon, authenticated;
grant execute on function public.deactivate_web_push_endpoint (text) to service_role;

-- Autoprueba: inserta una notificación in-app (dispara el mismo trigger FCM + Web Push).
create or replace function public.request_my_web_push_test ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  perform public.mc_insert_notification (
    v_uid,
    'Prueba Web Push',
    'Si ve este aviso, las notificaciones de la PWA están activas en este dispositivo.',
    'mensaje',
    null
  );
end;
$$;

grant execute on function public.request_my_web_push_test () to authenticated;

revoke all on function public._web_push_endpoint_ok (text) from public, anon, authenticated;
revoke all on function public._web_push_key_ok (text) from public, anon, authenticated;

comment on table public.web_push_subscriptions is
  'Suscripciones Web Push (VAPID) por usuario. Un endpoint solo pertenece a la última cuenta que lo registró.';
