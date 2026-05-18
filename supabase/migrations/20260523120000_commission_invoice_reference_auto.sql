-- C1: referencia de factura de comisión automatizada (Minuta #7).
--
-- Formato (sujeto a confirmación con el cliente en reporte operativo):
--   ML-COM-{AAAA}-{NNNNNN}
--   Ejemplo: ML-COM-2026-000042
--
-- Reglas:
-- - Secuencia anual por calendario (reinicia cada año).
-- - Se incrementa al emitir un corte (borrador → emitido).
-- - Contador en platform_settings: commission_invoice_seq_{AAAA}.
-- - p_invoice_reference opcional en admin_issue_* (override manual / migración).

-- ---------------------------------------------------------------------------
-- Vista previa del siguiente número (sin consumir secuencia).
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

  return 'ML-COM-' || v_year || '-' || lpad(v_seq::text, 6, '0');
end;
$$;

grant execute on function public.motoconecta_peek_commission_invoice_reference () to authenticated;

-- ---------------------------------------------------------------------------
-- Asignación atómica del siguiente número (consumir secuencia).
-- ---------------------------------------------------------------------------
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

  return 'ML-COM-' || v_year || '-' || lpad(v_seq::text, 6, '0');
end;
$$;

revoke all on function public.motoconecta_allocate_commission_invoice_reference () from public;
grant execute on function public.motoconecta_allocate_commission_invoice_reference () to service_role;

-- ---------------------------------------------------------------------------
-- Emitir corte: referencia automática si no se indica.
-- (DROP necesario: la versión C1 devolvía void; ahora devuelve text.)
-- ---------------------------------------------------------------------------
drop function if exists public.admin_issue_commission_settlement (uuid, text);

create or replace function public.admin_issue_commission_settlement (
  p_settlement_id uuid,
  p_invoice_reference text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ref text;
begin
  perform public._assert_administrador ();

  v_ref := nullif(trim(p_invoice_reference), '');

  if v_ref is null then
    v_ref := public.motoconecta_allocate_commission_invoice_reference ();
  end if;

  update public.commission_settlements cs
  set
    status = 'emitido',
    invoice_reference = v_ref,
    issued_at = now (),
    notes = coalesce(cs.notes, '')
  where cs.id = p_settlement_id
    and cs.status = 'borrador';

  if not found then
    raise exception 'Corte no encontrado o ya fue emitido/anulado.';
  end if;

  return v_ref;
end;
$$;

grant execute on function public.admin_issue_commission_settlement (uuid, text) to authenticated;
