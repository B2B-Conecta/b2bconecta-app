-- Anular un corte emitido que todavía no se cobró.
-- El número de factura se conserva. Los pedidos vuelven a poder entrar en un corte nuevo.

alter table public.commission_settlements
  drop constraint if exists commission_settlements_importador_week_uniq;

create unique index if not exists commission_settlements_importador_week_active_uniq
  on public.commission_settlements (importador_id, period_start, period_end)
  where status <> 'anulado';

create or replace function public.admin_cancel_commission_settlement (p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_pago text;
  v_imp uuid;
  v_ref text;
begin
  perform public._assert_administrador ();

  select cs.status, cs.pago_estado_revision, cs.importador_id, cs.invoice_reference
    into v_status, v_pago, v_imp, v_ref
  from public.commission_settlements cs
  where cs.id = p_settlement_id
  for update;

  if v_status is null then
    raise exception 'Corte no encontrado.';
  end if;

  if v_status = 'pagado' or v_pago = 'aprobado' then
    raise exception 'No se puede anular un corte ya cobrado.';
  end if;

  if v_status not in ('borrador', 'emitido') then
    raise exception 'Solo se puede anular un corte en borrador o emitido.';
  end if;

  update public.transaction_requests tr
  set commission_settlement_id = null
  where tr.commission_settlement_id = p_settlement_id;

  update public.commission_settlements cs
  set
    status = 'anulado',
    pago_estado_revision = case
      when cs.pago_estado_revision = 'en_revision' then 'rechazado'
      else cs.pago_estado_revision
    end,
    pago_rechazo_nota = case
      when cs.pago_estado_revision = 'en_revision' then
        coalesce(nullif(btrim(cs.pago_rechazo_nota), ''), 'Corte anulado por administración.')
      else cs.pago_rechazo_nota
    end,
    notes = concat_ws(
      E'\n',
      nullif(btrim(cs.notes), ''),
      'Anulado el ' || to_char(now() at time zone 'America/Caracas', 'DD/MM/YYYY HH24:MI')
    )
  where cs.id = p_settlement_id
    and cs.status in ('borrador', 'emitido');

  if not found then
    raise exception 'No se pudo anular el corte.';
  end if;

  if v_imp is not null then
    perform public.mc_insert_notification(
      v_imp,
      'Corte anulado',
      case
        when nullif(btrim(v_ref), '') is not null then
          'B2B Conecta anuló el corte ' || btrim(v_ref) || '. Esos pedidos pueden entrar en un corte nuevo.'
        else
          'B2B Conecta anuló un corte. Esos pedidos pueden entrar en un corte nuevo.'
      end,
      'comision',
      p_settlement_id::text
    );
  end if;
end;
$$;
