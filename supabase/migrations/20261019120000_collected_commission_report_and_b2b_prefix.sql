-- Comisión cobrada (ingreso de plataforma) + prefijo B2B en documentos nuevos.
--
-- Ingreso = sum(transaction_requests.comision_devengada_usd) de cortes
--   commission_settlements.status = 'pagado', fecha contable paid_at (America/Caracas).
-- No reescribe invoice_reference históricos ML-COM- / ML-NOT-.
-- El correlativo anual (platform_settings) no se reinicia; solo cambia el prefijo de marca.

-- ---------------------------------------------------------------------------
-- 1) Formato canónico de referencia nueva: B2B-{COM|NOT}-{AAAA}-{NNNNNN}
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_format_commission_document_reference (
  p_kind text,
  p_year text,
  p_seq integer
)
returns text
language plpgsql
immutable
set search_path = public
as $$
begin
  if p_kind is null or p_kind not in ('COM', 'NOT') then
    raise exception 'Tipo de documento inválido. Use COM o NOT.';
  end if;
  if p_year is null or p_year !~ '^[0-9]{4}$' then
    raise exception 'Año de referencia inválido.';
  end if;
  if p_seq is null or p_seq < 1 or p_seq > 999999 then
    raise exception 'Secuencia de referencia inválida.';
  end if;
  return 'B2B-' || p_kind || '-' || p_year || '-' || lpad(p_seq::text, 6, '0');
end;
$$;

comment on function public.motoconecta_format_commission_document_reference (text, text, integer) is
  'Formato nuevo B2B-COM/NOT. No convierte referencias históricas ML-.';

grant execute on function public.motoconecta_format_commission_document_reference (text, text, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Peek / allocate: mismo correlativo, prefijo B2B
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_peek_commission_invoice_reference ()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_year text := to_char(current_date, 'YYYY');
  v_key text := 'commission_invoice_seq_' || v_year;
  v_seq int;
begin
  select coalesce((ps.value #>> '{}')::int, 0) + 1
  into v_seq
  from public.platform_settings ps
  where ps.key = v_key;

  v_seq := coalesce(v_seq, 1);

  return public.motoconecta_format_commission_document_reference ('COM', v_year, v_seq);
end;
$$;

create or replace function public.motoconecta_allocate_commission_invoice_reference ()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year text := to_char(current_date, 'YYYY');
  v_key text := 'commission_invoice_seq_' || v_year;
  v_seq int;
begin
  perform pg_advisory_xact_lock(hashtext('motoconecta_commission_invoice_ref'));

  insert into public.platform_settings (key, value, updated_at)
  values (v_key, '0'::jsonb, now())
  on conflict (key) do nothing;

  update public.platform_settings ps
  set
    value = to_jsonb(coalesce((ps.value #>> '{}')::int, 0) + 1),
    updated_at = now()
  where ps.key = v_key
  returning (value #>> '{}')::int into v_seq;

  return public.motoconecta_format_commission_document_reference ('COM', v_year, v_seq);
end;
$$;

revoke all on function public.motoconecta_allocate_commission_invoice_reference () from public;
grant execute on function public.motoconecta_allocate_commission_invoice_reference () to service_role;

create or replace function public.motoconecta_peek_commission_delivery_note_reference ()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_year text := to_char(current_date, 'YYYY');
  v_key text := 'commission_delivery_note_seq_' || v_year;
  v_seq int;
begin
  select coalesce((ps.value #>> '{}')::int, 0) + 1
  into v_seq
  from public.platform_settings ps
  where ps.key = v_key;

  v_seq := coalesce(v_seq, 1);

  return public.motoconecta_format_commission_document_reference ('NOT', v_year, v_seq);
end;
$$;

create or replace function public.motoconecta_allocate_commission_delivery_note_reference ()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year text := to_char(current_date, 'YYYY');
  v_key text := 'commission_delivery_note_seq_' || v_year;
  v_seq int;
begin
  perform pg_advisory_xact_lock(hashtext('motoconecta_commission_delivery_note_ref'));

  insert into public.platform_settings (key, value, updated_at)
  values (v_key, '0'::jsonb, now())
  on conflict (key) do nothing;

  update public.platform_settings ps
  set
    value = to_jsonb(coalesce((ps.value #>> '{}')::int, 0) + 1),
    updated_at = now()
  where ps.key = v_key
  returning (value #>> '{}')::int into v_seq;

  return public.motoconecta_format_commission_document_reference ('NOT', v_year, v_seq);
end;
$$;

revoke all on function public.motoconecta_allocate_commission_delivery_note_reference () from public;
grant execute on function public.motoconecta_allocate_commission_delivery_note_reference () to service_role;

-- ---------------------------------------------------------------------------
-- 3) Índice para el reporte por paid_at (no toca filas históricas)
-- ---------------------------------------------------------------------------
create index if not exists commission_settlements_pagado_paid_at_idx
  on public.commission_settlements (paid_at desc, importador_id)
  where status = 'pagado' and paid_at is not null;

-- ---------------------------------------------------------------------------
-- 4) Fuente única de líneas cobradas (mismo filtro para total y desgloses)
-- ---------------------------------------------------------------------------
create or replace function public._motoconecta_collected_commission_lines (
  p_from_ts timestamptz,
  p_to_exclusive timestamptz,
  p_importador_id uuid,
  p_document_type text
)
returns table (
  line_id uuid,
  comision_devengada_usd numeric,
  importador_id uuid,
  business_name text,
  settlement_id uuid,
  paid_at timestamptz,
  document_type text,
  invoice_reference text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    tr.id,
    tr.comision_devengada_usd,
    cs.importador_id,
    nullif(btrim(p.business_name), ''),
    cs.id,
    cs.paid_at,
    coalesce(nullif(btrim(cs.document_type), ''), 'fiscal_invoice'),
    nullif(btrim(cs.invoice_reference), '')
  from public.commission_settlements cs
  inner join public.transaction_requests tr
    on tr.commission_settlement_id = cs.id
  inner join public.profiles p
    on p.id = cs.importador_id
  where cs.status = 'pagado'::text
    and cs.paid_at is not null
    and cs.paid_at >= p_from_ts
    and cs.paid_at < p_to_exclusive
    and tr.comision_devengada_usd is not null
    and tr.comision_devengada_usd > 0
    and coalesce(tr.cancelado_por_aliado, false) = false
    and coalesce(btrim(tr.importador_cancelacion_motivo), '') = ''
    and coalesce(tr.anulado_por_motolink, false) = false
    and (p_importador_id is null or cs.importador_id = p_importador_id)
    and (
      p_document_type is null
      or coalesce(nullif(btrim(cs.document_type), ''), 'fiscal_invoice') = p_document_type
    );
$$;

revoke all on function public._motoconecta_collected_commission_lines (
  timestamptz, timestamptz, uuid, text
) from public;

-- ---------------------------------------------------------------------------
-- 5) RPC de reporte (admin: global u org; importador: solo su importador_id)
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_collected_commission_report (
  p_from date,
  p_to date,
  p_importador_id uuid default null,
  p_document_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_importador uuid;
  v_doc text;
  v_from_ts timestamptz;
  v_to_exclusive timestamptz;
  v_span int;
  v_prev_from date;
  v_prev_to date;
  v_prev_from_ts timestamptz;
  v_prev_to_exclusive timestamptz;
  v_days int;
  v_grain text;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;

  if v_role is not distinct from 'importador' then
    if p_importador_id is not null and p_importador_id is distinct from v_uid then
      raise exception 'Sin permiso para consultar otra organización'
        using errcode = '42501';
    end if;
    v_importador := v_uid;
  elsif v_role is not distinct from 'administrador' then
    v_importador := p_importador_id;
  else
    raise exception 'Sin permiso para consultar ingresos de comisión'
      using errcode = '42501';
  end if;

  if p_from is null or p_to is null then
    raise exception 'Indique fecha inicial y final.' using errcode = 'P0001';
  end if;
  if p_from > p_to then
    raise exception 'La fecha inicial no puede ser posterior a la final.'
      using errcode = 'P0001';
  end if;
  if (p_to - p_from) > 1096 then
    raise exception 'El rango no puede superar tres años.' using errcode = 'P0001';
  end if;

  v_doc := nullif(btrim(p_document_type), '');
  if v_doc is not null and v_doc not in ('fiscal_invoice', 'delivery_note') then
    raise exception 'document_type inválido. Use fiscal_invoice o delivery_note.'
      using errcode = 'P0001';
  end if;

  v_from_ts := p_from::timestamp at time zone 'America/Caracas';
  v_to_exclusive := (p_to + 1)::timestamp at time zone 'America/Caracas';

  v_span := (p_to - p_from);
  v_prev_to := p_from - 1;
  v_prev_from := v_prev_to - v_span;
  v_prev_from_ts := v_prev_from::timestamp at time zone 'America/Caracas';
  v_prev_to_exclusive := (v_prev_to + 1)::timestamp at time zone 'America/Caracas';

  v_days := v_span + 1;
  if v_days <= 14 then
    v_grain := 'day';
  elsif v_days <= 90 then
    v_grain := 'week';
  else
    v_grain := 'month';
  end if;

  -- Una sola sentencia: total y desgloses leen el mismo conjunto `eligible`.
  with eligible as materialized (
    select *
    from public._motoconecta_collected_commission_lines (
      v_from_ts, v_to_exclusive, v_importador, v_doc
    )
  ),
  eligible_prev as materialized (
    select *
    from public._motoconecta_collected_commission_lines (
      v_prev_from_ts, v_prev_to_exclusive, v_importador, v_doc
    )
  ),
  totals as (
    select
      coalesce(round(sum(comision_devengada_usd), 4), 0) as total_collected_usd,
      count(*)::bigint as operation_count,
      count(distinct settlement_id)::bigint as settlement_count
    from eligible
  ),
  prev_totals as (
    select
      coalesce(round(sum(comision_devengada_usd), 4), 0) as total_collected_usd,
      count(*)::bigint as operation_count,
      count(distinct settlement_id)::bigint as settlement_count
    from eligible_prev
  ),
  series as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'bucket', to_char(s.bucket, 'YYYY-MM-DD'),
          'total_collected_usd', s.total_collected_usd,
          'operation_count', s.operation_count,
          'settlement_count', s.settlement_count
        )
        order by s.bucket
      ),
      '[]'::jsonb
    ) as value
    from (
      select
        date_trunc(v_grain, timezone('America/Caracas', e.paid_at))::date as bucket,
        coalesce(round(sum(e.comision_devengada_usd), 4), 0) as total_collected_usd,
        count(*)::int as operation_count,
        count(distinct e.settlement_id)::int as settlement_count
      from eligible e
      group by 1
    ) s
  ),
  by_imp as (
    select case
      when v_role is distinct from 'administrador' then '[]'::jsonb
      else coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'importador_id', s.importador_id,
              'business_name', coalesce(s.business_name, 'Importador'),
              'total_collected_usd', s.total_collected_usd,
              'operation_count', s.operation_count,
              'settlement_count', s.settlement_count
            )
            order by s.total_collected_usd desc, s.business_name
          )
          from (
            select
              e.importador_id,
              max(e.business_name) as business_name,
              coalesce(round(sum(e.comision_devengada_usd), 4), 0) as total_collected_usd,
              count(*)::int as operation_count,
              count(distinct e.settlement_id)::int as settlement_count
            from eligible e
            group by e.importador_id
          ) s
        ),
        '[]'::jsonb
      )
    end as value
  ),
  by_doc as (
    select coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'document_type', s.document_type,
            'total_collected_usd', s.total_collected_usd,
            'operation_count', s.operation_count,
            'settlement_count', s.settlement_count
          )
          order by s.document_type
        )
        from (
          select
            e.document_type,
            coalesce(round(sum(e.comision_devengada_usd), 4), 0) as total_collected_usd,
            count(*)::int as operation_count,
            count(distinct e.settlement_id)::int as settlement_count
          from eligible e
          group by e.document_type
        ) s
      ),
      '[]'::jsonb
    ) as value
  ),
  settlements as (
    select coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'settlement_id', s.settlement_id,
            'invoice_reference', s.invoice_reference,
            'importador_id', s.importador_id,
            'business_name', coalesce(s.business_name, 'Importador'),
            'document_type', s.document_type,
            'paid_at', s.paid_at,
            'total_collected_usd', s.total_collected_usd,
            'operation_count', s.operation_count
          )
          order by s.paid_at desc
        )
        from (
          select
            e.settlement_id,
            max(e.invoice_reference) as invoice_reference,
            e.importador_id,
            max(e.business_name) as business_name,
            max(e.document_type) as document_type,
            max(e.paid_at) as paid_at,
            coalesce(round(sum(e.comision_devengada_usd), 4), 0) as total_collected_usd,
            count(*)::int as operation_count
          from eligible e
          group by e.settlement_id, e.importador_id
          order by max(e.paid_at) desc
          limit 80
        ) s
      ),
      '[]'::jsonb
    ) as value
  )
  select jsonb_build_object(
    'timezone', 'America/Caracas',
    'from', p_from,
    'to', p_to,
    'importador_id', v_importador,
    'document_type', v_doc,
    'grain', v_grain,
    'total_collected_usd', t.total_collected_usd,
    'operation_count', t.operation_count,
    'settlement_count', t.settlement_count,
    'previous', jsonb_build_object(
      'from', v_prev_from,
      'to', v_prev_to,
      'total_collected_usd', pt.total_collected_usd,
      'operation_count', pt.operation_count,
      'settlement_count', pt.settlement_count
    ),
    'variation_pct',
      case
        when pt.total_collected_usd > 0 then round(
          ((t.total_collected_usd - pt.total_collected_usd) / pt.total_collected_usd) * 100,
          2
        )
        else null
      end,
    'series', se.value,
    'by_importador', bi.value,
    'by_document_type', bd.value,
    'settlements', st.value
  )
  into v_result
  from totals t
  cross join prev_totals pt
  cross join series se
  cross join by_imp bi
  cross join by_doc bd
  cross join settlements st;

  return v_result;
end;
$$;

comment on function public.motoconecta_collected_commission_report (date, date, uuid, text) is
  'Ingreso cobrado: sum(comision_devengada_usd) de cortes pagado filtrados por paid_at (Caracas). Importador aislado por auth.uid().';

grant execute on function public.motoconecta_collected_commission_report (date, date, uuid, text)
  to authenticated;
