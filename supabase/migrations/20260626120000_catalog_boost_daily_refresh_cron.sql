-- E1.1 hardening: refresh diario del boost de catálogo (ventana móvil por días).
-- Mantiene `profiles.catalog_paid_orders_30d` sincronizado aunque no haya nuevos updates.

create or replace function public.run_daily_catalog_boost_refresh_auto ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.refresh_all_importer_catalog_boost ();
end;
$$;

grant execute on function public.refresh_all_importer_catalog_boost () to service_role;
grant execute on function public.run_daily_catalog_boost_refresh_auto () to service_role;

-- ---------------------------------------------------------------------------
-- pg_cron (si la extensión está disponible en el proyecto)
-- ---------------------------------------------------------------------------
do $cron$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when insufficient_privilege then
    raise notice 'pg_cron: sin privilegio para crear extensión (omitir en local).';
  when others then
    raise notice 'pg_cron: %', sqlerrm;
end;
$cron$;

do $schedule$
declare
  v_job_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_daily_catalog_boost_refresh_auto manualmente.';
    return;
  end if;

  select jobid
    into v_job_id
  from cron.job
  where jobname = 'motoconecta_daily_catalog_boost_refresh'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  -- Diario 04:10 UTC.
  perform cron.schedule(
    'motoconecta_daily_catalog_boost_refresh',
    '10 4 * * *',
    $cmd$select public.run_daily_catalog_boost_refresh_auto();$cmd$
  );
exception
  when undefined_table then
    raise notice 'cron.job no disponible; omitiendo schedule.';
  when others then
    raise notice 'pg_cron schedule: %', sqlerrm;
end;
$schedule$;
