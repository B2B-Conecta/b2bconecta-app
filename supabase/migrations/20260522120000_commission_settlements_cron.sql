-- C1: núcleo de cortes sin assert admin (cron) + pg_cron semanal (lunes).

-- ---------------------------------------------------------------------------
-- Lunes ISO de una fecha (coincide con Flutter DateTime.monday).
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_week_start_monday (p_day date default current_date)
returns date
language sql
immutable
as $$
  select (date_trunc('week', p_day::timestamp))::date;
$$;

-- ---------------------------------------------------------------------------
-- Generación de cortes (sin auth; solo service_role / cron / funciones admin).
-- ---------------------------------------------------------------------------
create or replace function public._generate_commission_settlements_week_core (
  p_week_start date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week_start date;
  v_week_end date;
  v_imp uuid;
  v_settlement_id uuid;
  v_total numeric;
  v_cnt int;
  v_created int := 0;
  v_result jsonb := '[]'::jsonb;
begin
  v_week_start := p_week_start;
  v_week_end := v_week_start + 6;

  for v_imp in
    select distinct tr.importador_id
    from public.transaction_requests tr
    where tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.comision_devengada_usd > 0
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz
  loop
    if exists (
      select 1
      from public.commission_settlements cs
      where cs.importador_id = v_imp
        and cs.period_start = v_week_start
        and cs.period_end = v_week_end
        and cs.status <> 'anulado'::text
    ) then
      continue;
    end if;

    select
      coalesce(sum(tr.comision_devengada_usd), 0),
      count(*)::int
    into v_total, v_cnt
    from public.transaction_requests tr
    where tr.importador_id = v_imp
      and tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

    if v_cnt < 1 then
      continue;
    end if;

    insert into public.commission_settlements (
      importador_id,
      period_start,
      period_end,
      total_commission_usd,
      line_count,
      status,
      created_by
    )
    values (
      v_imp,
      v_week_start,
      v_week_end,
      v_total,
      v_cnt,
      'borrador',
      auth.uid ()
    )
    returning id into v_settlement_id;

    update public.transaction_requests tr
    set commission_settlement_id = v_settlement_id
    where tr.importador_id = v_imp
      and tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

    v_created := v_created + 1;
    v_result := v_result || jsonb_build_object(
      'settlement_id', v_settlement_id,
      'importador_id', v_imp,
      'line_count', v_cnt,
      'total_commission_usd', v_total
    );
  end loop;

  return jsonb_build_object(
    'week_start', v_week_start,
    'week_end', v_week_end,
    'created_count', v_created,
    'settlements', v_result
  );
end;
$$;

revoke all on function public._generate_commission_settlements_week_core (date) from public;
grant execute on function public._generate_commission_settlements_week_core (date) to service_role;

-- ---------------------------------------------------------------------------
-- RPC admin (delega al núcleo)
-- ---------------------------------------------------------------------------
create or replace function public.admin_generate_commission_settlements_week (
  p_week_start date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week_start date;
begin
  perform public._assert_administrador ();

  v_week_start := coalesce(
    p_week_start,
    public.motoconecta_week_start_monday (current_date - 7)
  );

  return public._generate_commission_settlements_week_core (v_week_start);
end;
$$;

-- Semana en curso (pruebas manuales desde la app).
create or replace function public.admin_generate_commission_settlements_current_week ()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();
  return public._generate_commission_settlements_week_core (
    public.motoconecta_week_start_monday (current_date)
  );
end;
$$;

grant execute on function public.admin_generate_commission_settlements_current_week () to authenticated;

-- Cron: cierra la semana anterior cada lunes 07:00 UTC.
create or replace function public.run_weekly_commission_settlements_auto ()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public._generate_commission_settlements_week_core (
    public.motoconecta_week_start_monday (current_date - 7)
  );
end;
$$;

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
    raise notice 'pg_cron no instalado; programe run_weekly_commission_settlements_auto manualmente.';
    return;
  end if;

  select jobid
  into v_job_id
  from cron.job
  where jobname = 'motoconecta_weekly_commission_settlements'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'motoconecta_weekly_commission_settlements',
    '0 7 * * 1',
    $cmd$select public.run_weekly_commission_settlements_auto();$cmd$
  );
exception
  when undefined_table then
    raise notice 'cron.job no disponible; omitiendo schedule.';
  when others then
    raise notice 'pg_cron schedule: %', sqlerrm;
end;
$schedule$;
