-- Cortes C1: permitir nuevos pedidos devengados en la misma semana aunque ya exista
-- un corte emitido/pagado; fusionar en borrador existente; backfill de devengo.

-- ---------------------------------------------------------------------------
-- Backfill: pedidos entregados sin comisión devengada registrada
-- ---------------------------------------------------------------------------
update public.transaction_requests tr
set
  commission_rate_snapshot = coalesce(
    tr.commission_rate_snapshot,
    public.motoconecta_default_commission_rate ()
  ),
  comision_devengada_usd = round(
    (
      tr.precio_total_usd * coalesce(
        tr.commission_rate_snapshot,
        public.motoconecta_default_commission_rate ()
      )
    )::numeric,
    4
  ),
  comision_devengada_at = coalesce(
    tr.at_entregado,
    tr.updated_at,
    tr.created_at,
    now()
  )
where tr.status = 'entregado'::text
  and tr.precio_total_usd > 0
  and (
    tr.comision_devengada_at is null
    or coalesce(tr.comision_devengada_usd, 0) <= 0
  );

-- ---------------------------------------------------------------------------
-- Generación / fusión de cortes (reemplaza núcleo restrictivo)
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
  v_merged int := 0;
  v_pending_before int := 0;
  v_result jsonb := '[]'::jsonb;
begin
  v_week_start := p_week_start;
  v_week_end := v_week_start + 6;

  select count(*)::int
    into v_pending_before
  from public.transaction_requests tr
  where tr.status = 'entregado'::text
    and tr.comision_devengada_at is not null
    and coalesce(tr.comision_devengada_usd, 0) > 0
    and tr.commission_settlement_id is null
    and tr.comision_devengada_at >= v_week_start::timestamptz
    and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

  for v_imp in
    select distinct tr.importador_id
    from public.transaction_requests tr
    where tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and coalesce(tr.comision_devengada_usd, 0) > 0
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz
  loop
    select cs.id
      into v_settlement_id
    from public.commission_settlements cs
    where cs.importador_id = v_imp
      and cs.period_start = v_week_start
      and cs.period_end = v_week_end
      and cs.status = 'borrador'::text
    order by cs.created_at desc
    limit 1;

    if v_settlement_id is not null then
      update public.transaction_requests tr
      set commission_settlement_id = v_settlement_id
      where tr.importador_id = v_imp
        and tr.status = 'entregado'::text
        and tr.comision_devengada_at is not null
        and tr.commission_settlement_id is null
        and tr.comision_devengada_at >= v_week_start::timestamptz
        and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

      select
        coalesce(sum(tr.comision_devengada_usd), 0),
        count(*)::int
      into v_total, v_cnt
      from public.transaction_requests tr
      where tr.commission_settlement_id = v_settlement_id;

      update public.commission_settlements cs
      set
        total_commission_usd = v_total,
        line_count = v_cnt
      where cs.id = v_settlement_id;

      v_merged := v_merged + 1;
      v_result := v_result || jsonb_build_object(
        'settlement_id', v_settlement_id,
        'importador_id', v_imp,
        'line_count', v_cnt,
        'total_commission_usd', v_total,
        'action', 'merged'
      );
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
      'total_commission_usd', v_total,
      'action', 'created'
    );
  end loop;

  return jsonb_build_object(
    'week_start', v_week_start,
    'week_end', v_week_end,
    'created_count', v_created,
    'merged_count', v_merged,
    'pending_lines_before', v_pending_before,
    'settlements', v_result
  );
end;
$$;
