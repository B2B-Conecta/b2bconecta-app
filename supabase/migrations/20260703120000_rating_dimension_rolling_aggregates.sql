-- E2 polish: promedios por dimensión (últ. 100 valoraciones v2) en perfil importador.

alter table public.profiles
  add column if not exists rating_dimensions_received_rolling100 jsonb;

comment on column public.profiles.rating_dimensions_received_rolling100 is
  'Promedios 1–5 por pregunta bucket_v2 (aliado→importador), ventana rolling 100. '
  'Claves = question id; valor = {"avg": n, "count": n}.';

create or replace function public.compute_importador_dimension_aggregates_rolling100 (
  p_importador_id uuid
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
      public.rating_questions_for_audience('aliado_rates_importer')
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
      where r.ratee_role = 'importador'
        and r.rater_role = 'aliado'
        and r.importador_id = p_importador_id
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
  v_dims jsonb;
begin
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

  v_dims := public.compute_importador_dimension_aggregates_rolling100(p_profile_id);

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

  update public.profiles p
  set
    rating_avg_received = v_as_supplier_avg,
    rating_count_received = coalesce(v_as_supplier_cnt, 0),
    rating_avg_received_rolling100 = v_as_supplier_avg_rolling,
    rating_count_received_rolling100 = coalesce(v_as_supplier_cnt_rolling, 0),
    rating_dimensions_received_rolling100 = case
      when v_dims = '{}'::jsonb then null
      else v_dims
    end,
    rating_as_payer_avg = v_as_payer_avg,
    rating_as_payer_count = coalesce(v_as_payer_cnt, 0),
    rating_as_payer_avg_rolling100 = v_as_payer_avg_rolling,
    rating_as_payer_count_rolling100 = coalesce(v_as_payer_cnt_rolling, 0)
  where p.id = p_profile_id;
end;
$$;

do $$
declare
  v_id uuid;
begin
  for v_id in
    select p.id
    from public.profiles p
    where p.role = 'importador'
  loop
    perform public.refresh_profile_rating_aggregates(v_id);
  end loop;
end;
$$;
