-- C1 sprint: notificación al emitir factura de comisión.

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
  v_cs public.commission_settlements%rowtype;
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
    and cs.status = 'borrador'
  returning * into v_cs;

  if not found then
    raise exception 'Corte no encontrado o ya fue emitido/anulado.';
  end if;

  perform public.mc_insert_notification (
    v_cs.importador_id,
    'Factura de comisión emitida',
    'MotoLink emitió la factura ' || v_ref
      || ' por USD '
      || trim(to_char(v_cs.total_commission_usd, '999999990.00'))
      || '. Registre el pago en Perfil → Cortes de comisión.',
    'comision',
    p_settlement_id::text
  );

  return v_ref;
end;
$$;
