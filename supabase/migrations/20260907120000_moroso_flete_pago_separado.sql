-- Morosidad: entregado con factura(s) pendiente(s) de pago (importador y/o flete separado).

create or replace function public.tr_pago_importador_pendiente_moroso (
  p_row public.transaction_requests
)
returns boolean
language sql
stable
as $$
  select coalesce(p_row.proveedor_factura_storage_path, '') <> ''
     and coalesce(p_row.pago_estado_revision, '') <> 'aprobado';
$$;

create or replace function public.tr_pago_flete_pendiente_moroso (
  p_row public.transaction_requests
)
returns boolean
language sql
stable
as $$
  select coalesce(p_row.carrier_flete_pago_modo_snapshot, '') = 'pago_separado'
     and coalesce(p_row.flete_factura_storage_path, '') <> ''
     and coalesce(p_row.flete_comprobante_pago_storage_path, '') = '';
$$;

create or replace function public.tr_is_moroso_pago_pendiente (p_row public.transaction_requests)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_row.status <> 'entregado'::text then
    return false;
  end if;

  return public.tr_pago_importador_pendiente_moroso (p_row)
      or public.tr_pago_flete_pendiente_moroso (p_row);
end;
$$;

comment on function public.tr_is_moroso_pago_pendiente (public.transaction_requests) is
  'Entregado con factura del importador sin pago aprobado y/o factura de flete (pago separado) sin comprobante.';

drop trigger if exists trg_clear_aliado_pago_reminder_tr on public.transaction_requests;

create trigger trg_clear_aliado_pago_reminder_tr
after update of
  status,
  pago_estado_revision,
  proveedor_factura_storage_path,
  carrier_flete_pago_modo_snapshot,
  flete_factura_storage_path,
  flete_comprobante_pago_storage_path
  on public.transaction_requests
for each row
execute function public.tr_clear_aliado_pago_reminder_on_tr_update ();

-- Regularización moroso: también al registrar comprobante de flete.
create or replace function public.tr_notify_pedido_pago_regularizado ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_anchor text;
  v_was_moroso boolean;
  v_now_ok boolean;
  v_product text;
begin
  if new.status <> 'entregado'::text then
    return new;
  end if;

  v_was_moroso := public.tr_is_moroso_pago_pendiente (old);
  v_now_ok := not public.tr_is_moroso_pago_pendiente (new);

  if not v_was_moroso or not v_now_ok then
    return new;
  end if;

  if coalesce(old.pago_estado_revision, '') = coalesce(new.pago_estado_revision, '')
     and coalesce(old.flete_comprobante_pago_storage_path, '')
       = coalesce(new.flete_comprobante_pago_storage_path, '') then
    return new;
  end if;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := public.mc_tr_product_label (new);

  perform public.mc_insert_notification (
    new.aliado_id,
    'Pago confirmado',
    format(
      'Los pagos pendientes del pedido «%s» quedaron al día. Ya no figura como moroso.',
      v_product
    ),
    'pago',
    v_anchor
  );

  perform public.mc_insert_notification (
    new.importador_id,
    'Pago aliado confirmado',
    format(
      'El aliado completó los pagos pendientes del pedido «%s». El estado moroso quedó regularizado.',
      v_product
    ),
    'pago',
    v_anchor
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_pedido_pago_regularizado on public.transaction_requests;

create trigger trg_notify_pedido_pago_regularizado
after update of pago_estado_revision, flete_comprobante_pago_storage_path
  on public.transaction_requests
for each row
execute function public.tr_notify_pedido_pago_regularizado ();
