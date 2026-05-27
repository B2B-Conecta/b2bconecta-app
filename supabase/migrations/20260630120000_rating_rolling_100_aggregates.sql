-- E2.1: reputación rolling (últimas 100 valoraciones) para catálogo y perfil importador.
-- Mantiene agregados históricos en rating_avg_received / rating_count_received.

alter table public.profiles
  add column if not exists rating_avg_received_rolling100 numeric(4, 2),
  add column if not exists rating_count_received_rolling100 integer not null default 0,
  add column if not exists rating_as_payer_avg_rolling100 numeric(4, 2),
  add column if not exists rating_as_payer_count_rolling100 integer not null default 0;

comment on column public.profiles.rating_avg_received_rolling100 is
  'Promedio 1–5 como proveedor sobre las últimas 100 valoraciones de aliados (E2.1).';

comment on column public.profiles.rating_count_received_rolling100 is
  'Cantidad en ventana rolling (máx. 100) usada para rating_avg_received_rolling100.';

comment on column public.profiles.rating_as_payer_avg_rolling100 is
  'Promedio 1–5 como pagador sobre las últimas 100 valoraciones de importadores.';

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
    rating_as_payer_avg = v_as_payer_avg,
    rating_as_payer_count = coalesce(v_as_payer_cnt, 0),
    rating_as_payer_avg_rolling100 = v_as_payer_avg_rolling,
    rating_as_payer_count_rolling100 = coalesce(v_as_payer_cnt_rolling, 0)
  where p.id = p_profile_id;
end;
$$;

-- Backfill agregados (histórico + rolling) para perfiles existentes.
do $$
declare
  v_id uuid;
begin
  for v_id in select p.id from public.profiles p
  loop
    perform public.refresh_profile_rating_aggregates(v_id);
  end loop;
end;
$$;
