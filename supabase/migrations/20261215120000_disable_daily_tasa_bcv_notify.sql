-- Desactiva notificaciones diarias de tasa BCV.
-- La tasa sigue en app_global_config (tasa_bcv) y se sincroniza cada 30 min
-- vía sync-tasa-bcv / service_upsert_tasa_bcv; la UI la consulta en vivo.

-- ---------------------------------------------------------------------------
-- No-op: broadcast y cron diario.
-- ---------------------------------------------------------------------------
create or replace function public.mc_broadcast_tasa_bcv_day (p_tasa numeric)
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Retirado: la tasa se muestra en vivo en la barra (BcvRateBadge).
  return 0;
end;
$$;

comment on function public.mc_broadcast_tasa_bcv_day (numeric) is
  'Obsoleto: ya no envía notificaciones diarias de tasa BCV (siempre retorna 0).';

create or replace function public.run_daily_tasa_bcv_notify ()
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  return 0;
end;
$$;

comment on function public.run_daily_tasa_bcv_notify () is
  'Obsoleto: no notifica la tasa BCV. Conservado por compatibilidad de clientes viejos.';

-- admin_set_tasa_bcv sin broadcast (solo persiste la tasa).
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
end;
$$;

comment on function public.admin_set_tasa_bcv (numeric) is
  'Admin: actualiza tasa_bcv global sin enviar notificaciones push.';

-- Quitar cron diario si existe.
do $cron$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return;
  end if;
  begin
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'motolink_daily_tasa_bcv_notify';
  exception
    when others then
      raise notice 'pg_cron unschedule tasa BCV notify: %', sqlerrm;
  end;
end;
$cron$;
