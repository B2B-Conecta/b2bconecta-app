-- Notificación diaria de tasa BCV a todos los usuarios de la plataforma.

create or replace function public.mc_format_tasa_bcv_es (p_tasa numeric)
returns text
language sql
immutable
as $$
  select replace(trim(to_char(round(p_tasa::numeric, 4), 'FM999999990.9999')), '.', ',');
$$;

create or replace function public.mc_tasa_bcv_caracas_today ()
returns date
language sql
stable
as $$
  select (timezone('America/Caracas', now()))::date;
$$;

create or replace function public.mc_tasa_bcv_notif_sent_today ()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sent text;
  v_today text;
begin
  v_today := public.mc_tasa_bcv_caracas_today()::text;
  select c.value_text
    into v_sent
  from public.app_global_config c
  where c.key = 'tasa_bcv_notif_date';
  return coalesce(v_sent, '') = v_today;
end;
$$;

create or replace function public.mc_broadcast_tasa_bcv_day (p_tasa numeric)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_today date;
  v_today_txt text;
  v_tasa_txt text;
  v_body text;
  v_count int := 0;
begin
  if p_tasa is null or p_tasa <= 0 then
    return 0;
  end if;

  v_today := public.mc_tasa_bcv_caracas_today();
  v_today_txt := v_today::text;

  if public.mc_tasa_bcv_notif_sent_today() then
    return 0;
  end if;

  v_tasa_txt := public.mc_format_tasa_bcv_es(p_tasa);
  v_body := format(
    'Referencia MotoLink: %s VES por 1 REF (%s). '
    'Use esta tasa para consultar montos en bolívares en pedidos y facturas.',
    v_tasa_txt,
    to_char(v_today, 'DD/MM/YYYY')
  );

  perform set_config('row_security', 'off', true);

  for rec in
    select p.id
    from public.profiles p
    where p.role in ('aliado', 'importador', 'administrador')
  loop
    perform public.mc_insert_notification(
      rec.id,
      'Tasa BCV del día',
      v_body,
      'tasa_bcv',
      'tasa_bcv:' || v_today_txt
    );
    v_count := v_count + 1;
  end loop;

  insert into public.app_global_config (key, value_text, updated_at)
  values ('tasa_bcv_notif_date', v_today_txt, now())
  on conflict (key) do update
  set value_text = excluded.value_text, updated_at = excluded.updated_at;

  return v_count;
end;
$$;

comment on function public.mc_broadcast_tasa_bcv_day (numeric) is
  'Envía una notificación de tasa BCV del día a aliados, importadores y admins (una vez por día, zona Caracas).';

create or replace function public.run_daily_tasa_bcv_notify ()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tasa numeric;
begin
  select c.value_numeric
    into v_tasa
  from public.app_global_config c
  where c.key = 'tasa_bcv';

  return public.mc_broadcast_tasa_bcv_day(v_tasa);
end;
$$;

grant execute on function public.run_daily_tasa_bcv_notify () to authenticated;
grant execute on function public.run_daily_tasa_bcv_notify () to service_role;

create or replace function public.admin_set_tasa_bcv (p_tasa numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador();
  if p_tasa is null or p_tasa <= 0 then
    raise exception 'La tasa BCV debe ser un número mayor que cero.';
  end if;
  insert into public.app_global_config (key, value_numeric, updated_at, updated_by)
  values ('tasa_bcv', p_tasa, now(), auth.uid())
  on conflict (key) do update
  set
    value_numeric = excluded.value_numeric,
    updated_at = excluded.updated_at,
    updated_by = excluded.updated_by;

  perform public.mc_broadcast_tasa_bcv_day(p_tasa);
end;
$$;

-- pg_cron: recordatorio diario 08:00 (America/Caracas) con la tasa guardada
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

  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; use run_daily_tasa_bcv_notify al sincronizar la tasa.';
    return;
  end if;

  begin
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'motolink_daily_tasa_bcv_notify';
  exception
    when others then null;
  end;

  perform cron.schedule(
    'motolink_daily_tasa_bcv_notify',
    '0 8 * * *',
    $job$select public.run_daily_tasa_bcv_notify();$job$
  );
exception
  when others then
    raise notice 'pg_cron tasa BCV: %', sqlerrm;
end;
$cron$;
