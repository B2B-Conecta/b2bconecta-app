-- Tasa BCV: sincronización automática cada 30 minutos vía Edge Function sync-tasa-bcv.
-- No envía la notificación diaria (sigue el cron 08:00 Caracas / run_daily_tasa_bcv_notify).

create or replace function public.service_upsert_tasa_bcv (
  p_tasa numeric,
  p_effective_date text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev numeric;
  v_fecha text;
begin
  if coalesce(auth.jwt () ->> 'role', '') is distinct from 'service_role'
     and coalesce(
       current_setting('request.jwt.claim.role', true),
       ''
     ) is distinct from 'service_role' then
    raise exception 'solo service_role puede sincronizar la tasa BCV automáticamente';
  end if;

  if p_tasa is null or p_tasa <= 0 then
    raise exception 'La tasa BCV debe ser un número mayor que cero.';
  end if;

  select c.value_numeric
    into v_prev
  from public.app_global_config c
  where c.key = 'tasa_bcv';

  v_fecha := nullif(btrim(coalesce(p_effective_date, '')), '');

  insert into public.app_global_config (
    key,
    value_numeric,
    value_text,
    updated_at,
    updated_by
  )
  values (
    'tasa_bcv',
    p_tasa,
    v_fecha,
    now (),
    null
  )
  on conflict (key) do update
  set
    value_numeric = excluded.value_numeric,
    value_text = coalesce(excluded.value_text, public.app_global_config.value_text),
    updated_at = excluded.updated_at,
    updated_by = null;

  return jsonb_build_object(
    'previous', v_prev,
    'tasa', p_tasa,
    'effective_date', v_fecha,
    'changed',
      v_prev is null
      or abs(v_prev - p_tasa) > 0.00005
  );
end;
$$;

comment on function public.service_upsert_tasa_bcv (numeric, text) is
  'service_role: actualiza tasa_bcv desde el boletín BCV sin disparar la notificación diaria.';

revoke all on function public.service_upsert_tasa_bcv (numeric, text) from public;
revoke all on function public.service_upsert_tasa_bcv (numeric, text) from anon;
revoke all on function public.service_upsert_tasa_bcv (numeric, text) from authenticated;
grant execute on function public.service_upsert_tasa_bcv (numeric, text) to service_role;

-- Dispara la Edge Function usando los secretos de vault ya usados por push.
create or replace function public.run_sync_tasa_bcv_http ()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_url text;
  v_service_key text;
  v_request_id bigint;
begin
  begin
    select decrypted_secret
      into v_base_url
    from vault.decrypted_secrets
    where name = 'push_supabase_url'
    limit 1;

    select decrypted_secret
      into v_service_key
    from vault.decrypted_secrets
    where name = 'push_service_role_key'
    limit 1;
  exception
    when undefined_table or invalid_schema_name then
      return null;
  end;

  if coalesce(v_base_url, '') = '' or coalesce(v_service_key, '') = '' then
    raise warning 'run_sync_tasa_bcv_http: faltan vault push_supabase_url / push_service_role_key';
    return null;
  end if;

  select net.http_post(
    url := rtrim(v_base_url, '/') || '/functions/v1/sync-tasa-bcv',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := jsonb_build_object('source', 'pg_cron')
  )
  into v_request_id;

  return v_request_id;
exception
  when others then
    raise warning 'run_sync_tasa_bcv_http failed: %', sqlerrm;
    return null;
end;
$$;

comment on function public.run_sync_tasa_bcv_http () is
  'pg_cron: POST a Edge Function sync-tasa-bcv (cada 30 min).';

revoke all on function public.run_sync_tasa_bcv_http () from public;
grant execute on function public.run_sync_tasa_bcv_http () to service_role;

do $cron$
begin
  begin
    create extension if not exists pg_cron with schema extensions;
  exception
    when insufficient_privilege then
      raise notice 'pg_cron: sin privilegio (omitir en local).';
    when others then
      raise notice 'pg_cron: %', sqlerrm;
  end;

  begin
    create extension if not exists pg_net with schema extensions;
  exception
    when insufficient_privilege then
      raise notice 'pg_net: sin privilegio (omitir en local).';
    when others then
      raise notice 'pg_net: %', sqlerrm;
  end;

  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_sync_tasa_bcv_http manualmente.';
    return;
  end if;

  begin
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'b2bconecta_sync_tasa_bcv_30m';
  exception
    when others then null;
  end;

  perform cron.schedule(
    'b2bconecta_sync_tasa_bcv_30m',
    '*/30 * * * *',
    $job$select public.run_sync_tasa_bcv_http();$job$
  );
exception
  when others then
    raise notice 'pg_cron sync tasa BCV: %', sqlerrm;
end;
$cron$;
