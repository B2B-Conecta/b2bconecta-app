-- E2: cierres semanales de reputación + valoraciones recibidas por aliado + dimensiones aliado.

-- ---------------------------------------------------------------------------
-- 1) Snapshots semanales (importador como proveedor / aliado como pagador valorado)
-- ---------------------------------------------------------------------------
create table if not exists public.reputation_weekly_snapshots (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  week_start date not null,
  avg_overall numeric(4, 2),
  rating_count integer not null default 0,
  dimensions jsonb,
  created_at timestamptz not null default now (),
  primary key (profile_id, week_start)
);

create index if not exists reputation_weekly_snapshots_week_idx
  on public.reputation_weekly_snapshots (week_start desc);

comment on table public.reputation_weekly_snapshots is
  'Cierre semanal de reputación (promedio y conteo de valoraciones en la semana ISO).';

alter table public.reputation_weekly_snapshots enable row level security;

create policy reputation_weekly_snapshots_select_own on public.reputation_weekly_snapshots
  for select
  to authenticated
  using (profile_id = auth.uid ());

create policy reputation_weekly_snapshots_select_admin on public.reputation_weekly_snapshots
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'
    )
  );

-- ---------------------------------------------------------------------------
-- 2) Dimensiones rolling cuando el aliado es valorado (importador → aliado)
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists rating_dimensions_as_payer_rolling100 jsonb;

comment on column public.profiles.rating_dimensions_as_payer_rolling100 is
  'Promedios bucket_v2 cuando el aliado es ratee (Comunicación, Pagos), ventana 100.';

create or replace function public.compute_aliado_dimension_aggregates_rolling100 (
  p_aliado_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_out jsonb := '{}'::jsonb;
  v_q jsonb;
  v_qid text;
  v_avg numeric;
  v_cnt int;
begin
  for v_q in
    select elem
    from jsonb_array_elements(
      public.rating_questions_for_audience('importer_rates_aliado')
    ) elem
  loop
    v_qid := v_q ->> 'id';
    select
      round(avg(sub.val)::numeric, 2),
      count(*)::int
      into v_avg, v_cnt
    from (
      select (r.answers ->> v_qid)::numeric as val
      from public.order_ratings r
      where r.ratee_role = 'aliado'
        and r.rater_role = 'importador'
        and r.aliado_id = p_aliado_id
        and r.questionnaire_version = 'bucket_v2'
        and r.answers ? v_qid
        and (r.answers ->> v_qid)::numeric between 1 and 5
      order by r.submitted_at desc
      limit 100
    ) sub;

    if coalesce(v_cnt, 0) > 0 then
      v_out := v_out || jsonb_build_object(
        v_qid,
        jsonb_build_object('avg', v_avg, 'count', v_cnt)
      );
    end if;
  end loop;

  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) refresh_profile_rating_aggregates (+ dimensiones aliado)
-- ---------------------------------------------------------------------------
create or replace function public.refresh_profile_rating_aggregates (p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_as_supplier_avg numeric;
  v_as_supplier_cnt int;
  v_as_supplier_avg_rolling numeric;
  v_as_supplier_cnt_rolling int;
  v_as_payer_avg numeric;
  v_as_payer_cnt int;
  v_as_payer_avg_rolling numeric;
  v_as_payer_cnt_rolling int;
  v_dims_importador jsonb;
  v_dims_aliado jsonb;
  v_role text;
begin
  select p.role into v_role from public.profiles p where p.id = p_profile_id;

  select
    round(avg(overall_stars)::numeric, 2),
    count(*)::int
    into v_as_supplier_avg, v_as_supplier_cnt
  from public.order_ratings r
  where r.ratee_role = 'importador'
    and r.importador_id = p_profile_id;

  select
    round(avg(recent.overall_stars)::numeric, 2),
    count(*)::int
    into v_as_supplier_avg_rolling, v_as_supplier_cnt_rolling
  from (
    select r.overall_stars
    from public.order_ratings r
    where r.ratee_role = 'importador'
      and r.importador_id = p_profile_id
    order by r.submitted_at desc
    limit 100
  ) recent;

  v_dims_importador :=
    public.compute_importador_dimension_aggregates_rolling100(p_profile_id);

  select
    round(avg(overall_stars)::numeric, 2),
    count(*)::int
    into v_as_payer_avg, v_as_payer_cnt
  from public.order_ratings r
  where r.ratee_role = 'aliado'
    and r.aliado_id = p_profile_id;

  select
    round(avg(recent.overall_stars)::numeric, 2),
    count(*)::int
    into v_as_payer_avg_rolling, v_as_payer_cnt_rolling
  from (
    select r.overall_stars
    from public.order_ratings r
    where r.ratee_role = 'aliado'
      and r.aliado_id = p_profile_id
    order by r.submitted_at desc
    limit 100
  ) recent;

  if v_role = 'aliado' then
    v_dims_aliado := public.compute_aliado_dimension_aggregates_rolling100(p_profile_id);
  else
    v_dims_aliado := null;
  end if;

  update public.profiles p
  set
    rating_avg_received = v_as_supplier_avg,
    rating_count_received = coalesce(v_as_supplier_cnt, 0),
    rating_avg_received_rolling100 = v_as_supplier_avg_rolling,
    rating_count_received_rolling100 = coalesce(v_as_supplier_cnt_rolling, 0),
    rating_dimensions_received_rolling100 = case
      when v_dims_importador = '{}'::jsonb then null
      else v_dims_importador
    end,
    rating_as_payer_avg = v_as_payer_avg,
    rating_as_payer_count = coalesce(v_as_payer_cnt, 0),
    rating_as_payer_avg_rolling100 = v_as_payer_avg_rolling,
    rating_as_payer_count_rolling100 = coalesce(v_as_payer_cnt_rolling, 0),
    rating_dimensions_as_payer_rolling100 = case
      when v_dims_aliado is null or v_dims_aliado = '{}'::jsonb then null
      else v_dims_aliado
    end
  where p.id = p_profile_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Captura semanal + cron (lunes 08:00 UTC, semana anterior)
-- ---------------------------------------------------------------------------
create or replace function public.capture_reputation_weekly_snapshots (
  p_week_start date
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week_start date := public.motoconecta_week_start_monday(p_week_start);
  v_week_end date := v_week_start + 6;
  v_importador_rows int := 0;
  v_aliado_rows int := 0;
begin
  insert into public.reputation_weekly_snapshots (
    profile_id,
    week_start,
    avg_overall,
    rating_count,
    dimensions
  )
  select
    r.importador_id,
    v_week_start,
    round(avg(r.overall_stars)::numeric, 2),
    count(*)::int,
    null::jsonb
  from public.order_ratings r
  where r.ratee_role = 'importador'
    and r.rater_role = 'aliado'
    and r.submitted_at >= v_week_start::timestamptz
    and r.submitted_at < (v_week_end + 1)::timestamptz
  group by r.importador_id
  on conflict (profile_id, week_start) do update
  set
    avg_overall = excluded.avg_overall,
    rating_count = excluded.rating_count,
    dimensions = excluded.dimensions,
    created_at = now ();

  get diagnostics v_importador_rows = row_count;

  insert into public.reputation_weekly_snapshots (
    profile_id,
    week_start,
    avg_overall,
    rating_count,
    dimensions
  )
  select
    r.aliado_id,
    v_week_start,
    round(avg(r.overall_stars)::numeric, 2),
    count(*)::int,
    null::jsonb
  from public.order_ratings r
  where r.ratee_role = 'aliado'
    and r.rater_role = 'importador'
    and r.submitted_at >= v_week_start::timestamptz
    and r.submitted_at < (v_week_end + 1)::timestamptz
  group by r.aliado_id
  on conflict (profile_id, week_start) do update
  set
    avg_overall = excluded.avg_overall,
    rating_count = excluded.rating_count,
    dimensions = excluded.dimensions,
    created_at = now ();

  get diagnostics v_aliado_rows = row_count;

  return v_importador_rows + v_aliado_rows;
end;
$$;

create or replace function public.run_weekly_reputation_snapshots_auto ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev_week date;
begin
  v_prev_week := public.motoconecta_week_start_monday(current_date - 7);
  perform public.capture_reputation_weekly_snapshots(v_prev_week);
end;
$$;

grant execute on function public.capture_reputation_weekly_snapshots (date)
  to service_role;

grant execute on function public.run_weekly_reputation_snapshots_auto ()
  to service_role;

create or replace function public.list_my_reputation_weekly_snapshots (
  p_limit integer default 12
)
returns table (
  week_start date,
  avg_overall numeric,
  rating_count integer,
  dimensions jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.week_start,
    s.avg_overall,
    s.rating_count,
    s.dimensions
  from public.reputation_weekly_snapshots s
  where s.profile_id = auth.uid ()
  order by s.week_start desc
  limit greatest(1, least(coalesce(p_limit, 12), 52));
$$;

grant execute on function public.list_my_reputation_weekly_snapshots (integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Valoraciones recibidas por aliado (importador anónimo)
-- ---------------------------------------------------------------------------
create or replace function public.list_aliado_received_ratings (
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid,
  overall_stars integer,
  comment text,
  answers jsonb,
  submitted_at timestamptz,
  importer_label text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.overall_stars,
    r.comment,
    r.answers,
    r.submitted_at,
    (
      'Importador de '
      || coalesce(nullif(trim(pi.ciudad), ''), nullif(trim(pi.estado), ''), 'Venezuela')
    ) as importer_label
  from public.order_ratings r
  join public.profiles pi on pi.id = r.importador_id
  where r.ratee_role = 'aliado'
    and r.rater_role = 'importador'
    and r.aliado_id = auth.uid ()
  order by r.submitted_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_aliado_received_ratings (integer, integer)
  to authenticated;

-- Índice catálogo: orden por reputación rolling (E2.3 indexación)
create index if not exists profiles_importador_rating_rolling_idx
  on public.profiles (rating_avg_received_rolling100 desc nulls last)
  where role = 'importador';

-- Cron semanal reputación (lunes 08:15 UTC)
do $cron$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_weekly_reputation_snapshots_auto manualmente.';
    return;
  end if;

  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'motoconecta_weekly_reputation_snapshots';

  perform cron.schedule(
    'motoconecta_weekly_reputation_snapshots',
    '15 8 * * 1',
    $cmd$select public.run_weekly_reputation_snapshots_auto();$cmd$
  );
end;
$cron$;

-- Backfill últimas 8 semanas (demo / histórico reciente)
do $$
declare
  v_ws date;
  i int;
begin
  for i in 0..7 loop
    v_ws := public.motoconecta_week_start_monday(current_date - (i * 7));
    perform public.capture_reputation_weekly_snapshots(v_ws);
  end loop;
end;
$$;
