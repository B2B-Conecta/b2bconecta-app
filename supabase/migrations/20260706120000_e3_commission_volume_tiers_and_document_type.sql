-- E3: tramos de comisión por volumen mensual + doble documento al emitir corte.

-- ---------------------------------------------------------------------------
-- 1) Tramos en platform_settings
-- ---------------------------------------------------------------------------
insert into public.platform_settings (key, value, updated_at)
values (
  'commission_volume_tiers',
  '[
    {"min_monthly_sales_usd": 0, "rate_pct": 0.05},
    {"min_monthly_sales_usd": 10000, "rate_pct": 0.03}
  ]'::jsonb,
  now()
)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 2) Volumen mensual del importador (entregado / devengado, America/Caracas)
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_importer_monthly_sales_volume_usd (
  p_importador_id uuid,
  p_at timestamptz default now()
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select
      date_trunc(
        'month',
        timezone('America/Caracas', coalesce(p_at, now()))
      ) as month_start_local,
      (
        date_trunc(
          'month',
          timezone('America/Caracas', coalesce(p_at, now()))
        )
        + interval '1 month'
      ) as month_end_exclusive_local
  )
  select coalesce(
    sum(tr.precio_total_usd)::numeric,
    0::numeric
  )
  from public.transaction_requests tr
  cross join bounds b
  where tr.importador_id = p_importador_id
    and tr.status = 'entregado'::text
    and tr.comision_devengada_at is not null
    and coalesce(tr.cancelado_por_aliado, false) = false
    and coalesce(btrim(tr.importador_cancelacion_motivo), '') = ''
    and coalesce(tr.anulado_por_motolink, false) = false
    and timezone('America/Caracas', tr.comision_devengada_at) >= b.month_start_local
    and timezone('America/Caracas', tr.comision_devengada_at) < b.month_end_exclusive_local;
$$;

grant execute on function public.motoconecta_importer_monthly_sales_volume_usd (uuid, timestamptz)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Tasa desde tramos (umbrales inclusivos USD)
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_commission_rate_from_volume_tiers (
  p_volume_usd numeric
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  with tiers as (
    select
      (elem ->> 'min_monthly_sales_usd')::numeric as min_usd,
      (elem ->> 'rate_pct')::numeric as rate_pct
    from public.platform_settings ps
    cross join lateral jsonb_array_elements(ps.value) elem
    where ps.key = 'commission_volume_tiers'
      and jsonb_typeof(ps.value) = 'array'
  ),
  picked as (
    select t.rate_pct
    from tiers t
    where t.min_usd is not null
      and t.rate_pct is not null
      and t.rate_pct >= 0
      and t.rate_pct <= 1
      and coalesce(p_volume_usd, 0) >= t.min_usd
    order by t.min_usd desc
    limit 1
  )
  select coalesce(
    (select rate_pct from picked),
    public.motoconecta_default_commission_rate ()
  );
$$;

revoke all on function public.motoconecta_commission_rate_from_volume_tiers (numeric) from public;
grant execute on function public.motoconecta_commission_rate_from_volume_tiers (numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Tasa efectiva: override manual > tramos > default
-- ---------------------------------------------------------------------------
drop function if exists public.motoconecta_commission_rate_for_importador (uuid);

create or replace function public.motoconecta_commission_rate_for_importador (
  p_importador_id uuid,
  p_at timestamptz default now()
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.commission_rate_pct
      from public.profiles p
      where p.id = p_importador_id
        and p.role = 'importador'
    ),
    public.motoconecta_commission_rate_from_volume_tiers (
      public.motoconecta_importer_monthly_sales_volume_usd (p_importador_id, p_at)
    )
  );
$$;

grant execute on function public.motoconecta_commission_rate_for_importador (uuid, timestamptz)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Admin: leer / guardar tramos
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_commission_volume_tiers ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  perform public._assert_administrador ();
  select ps.value into v
  from public.platform_settings ps
  where ps.key = 'commission_volume_tiers';
  return coalesce(v, '[]'::jsonb);
end;
$$;

create or replace function public.admin_set_commission_volume_tiers (p_tiers jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_elem jsonb;
  v_min numeric;
  v_rate numeric;
begin
  perform public._assert_administrador ();

  if p_tiers is null or jsonb_typeof(p_tiers) <> 'array' then
    raise exception 'Los tramos deben ser un arreglo JSON.';
  end if;

  for v_elem in select value from jsonb_array_elements(p_tiers)
  loop
    v_min := (v_elem ->> 'min_monthly_sales_usd')::numeric;
    v_rate := (v_elem ->> 'rate_pct')::numeric;
    if v_min is null or v_rate is null then
      raise exception 'Cada tramo requiere min_monthly_sales_usd y rate_pct.';
    end if;
    if v_min < 0 or v_rate < 0 or v_rate > 1 then
      raise exception 'Umbrales y tasas deben ser válidos (rate_pct entre 0 y 1).';
    end if;
  end loop;

  insert into public.platform_settings (key, value, updated_at)
  values ('commission_volume_tiers', p_tiers, now())
  on conflict (key) do update
  set value = excluded.value, updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.admin_get_commission_volume_tiers () to authenticated;
grant execute on function public.admin_set_commission_volume_tiers (jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) document_type + issued_by en cortes
-- ---------------------------------------------------------------------------
alter table public.commission_settlements
  add column if not exists document_type text,
  add column if not exists issued_by uuid references public.profiles (id);

alter table public.commission_settlements
  drop constraint if exists commission_settlements_document_type_chk;

alter table public.commission_settlements
  add constraint commission_settlements_document_type_chk check (
    document_type is null
    or document_type = any (
      array['fiscal_invoice'::text, 'delivery_note'::text]
    )
  );

comment on column public.commission_settlements.document_type is
  'E3: fiscal_invoice (IVA) o delivery_note (control interno). Fijado al emitir.';

comment on column public.commission_settlements.issued_by is
  'Admin que emitió el documento (auditoría E3).';

-- ---------------------------------------------------------------------------
-- 7) Referencias ML-NOT- (nota de entrega)
-- ---------------------------------------------------------------------------
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

  return 'ML-NOT-' || v_year || '-' || lpad(v_seq::text, 6, '0');
end;
$$;

grant execute on function public.motoconecta_peek_commission_delivery_note_reference () to authenticated;

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

  return 'ML-NOT-' || v_year || '-' || lpad(v_seq::text, 6, '0');
end;
$$;

revoke all on function public.motoconecta_allocate_commission_delivery_note_reference () from public;
grant execute on function public.motoconecta_allocate_commission_delivery_note_reference () to service_role;

create or replace function public.motoconecta_peek_commission_settlement_reference (
  p_document_type text default 'fiscal_invoice'
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(p_document_type, 'fiscal_invoice') = 'delivery_note' then
    return public.motoconecta_peek_commission_delivery_note_reference ();
  end if;
  return public.motoconecta_peek_commission_invoice_reference ();
end;
$$;

grant execute on function public.motoconecta_peek_commission_settlement_reference (text) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Emitir corte con document_type (irreversible)
-- ---------------------------------------------------------------------------
drop function if exists public.admin_issue_commission_settlement (uuid, text);

create or replace function public.admin_issue_commission_settlement (
  p_settlement_id uuid,
  p_invoice_reference text default null,
  p_document_type text default 'fiscal_invoice'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cs public.commission_settlements%rowtype;
  v_ref text;
  v_doc text := coalesce(nullif(trim(p_document_type), ''), 'fiscal_invoice');
  v_title text;
  v_body text;
begin
  perform public._assert_administrador ();

  if v_doc not in ('fiscal_invoice', 'delivery_note') then
    raise exception 'document_type inválido. Use fiscal_invoice o delivery_note.';
  end if;

  v_ref := nullif(trim(p_invoice_reference), '');

  if v_ref is null then
    if v_doc = 'delivery_note' then
      v_ref := public.motoconecta_allocate_commission_delivery_note_reference ();
    else
      v_ref := public.motoconecta_allocate_commission_invoice_reference ();
    end if;
  end if;

  update public.commission_settlements cs
  set
    status = 'emitido',
    document_type = v_doc,
    issued_by = auth.uid (),
    invoice_reference = v_ref,
    issued_at = now (),
    notes = coalesce(cs.notes, '')
  where cs.id = p_settlement_id
    and cs.status = 'borrador'
  returning * into v_cs;

  if not found then
    raise exception 'Corte no encontrado o ya fue emitido/anulado.';
  end if;

  if v_doc = 'delivery_note' then
    v_title := 'Relación de control interno emitida';
    v_body :=
      'MotoLink emitió la nota de entrega ' || v_ref
      || ' por USD '
      || trim(to_char(v_cs.total_commission_usd, '999999990.00'))
      || ' (sin IVA). Registre el pago en Perfil → Cortes de comisión.';
  else
    v_title := 'Factura de comisión emitida';
    v_body :=
      'MotoLink emitió la factura ' || v_ref
      || ' por USD '
      || trim(to_char(v_cs.total_commission_usd, '999999990.00'))
      || ' (base comisión; IVA en documento). Registre el pago en Perfil → Cortes de comisión.';
  end if;

  perform public.mc_insert_notification (
    v_cs.importador_id,
    v_title,
    v_body,
    'comision',
    p_settlement_id::text
  );

  return v_ref;
end;
$$;

grant execute on function public.admin_issue_commission_settlement (uuid, text, text) to authenticated;
