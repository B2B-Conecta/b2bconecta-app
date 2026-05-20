-- Elimina plan de cuotas / crédito en pedidos; notifica morosidad al cerrar pedido;
-- simplifica detección de moroso (solo pago MotoLink pendiente tras entrega).

-- ---------------------------------------------------------------------------
-- 1) Moroso: solo factura + pago no aprobado (sin payment_schedule)
-- ---------------------------------------------------------------------------
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
  if coalesce(p_row.factura_aliado_storage_path, '') = '' then
    return false;
  end if;
  return coalesce(p_row.pago_estado_revision, '') <> 'aprobado';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Notificar al pasar a entregado con pago pendiente (aliado, importador, admin)
-- ---------------------------------------------------------------------------
create or replace function public.tr_notify_pedido_moroso_on_entregado ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_anchor text;
  v_body_aliado text;
  v_body_imp text;
begin
  if new.status <> 'entregado'::text
     or old.status is not distinct from 'entregado'::text then
    return new;
  end if;

  if not public.tr_is_moroso_pago_pendiente (new) then
    return new;
  end if;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_body_aliado := format(
    'El pedido %s quedó recibido con pago pendiente ante MotoLink. '
    'El estado se mostrará como moroso hasta que su comprobante sea aprobado.',
    coalesce(new.product_name, 'sin nombre')
  );
  v_body_imp := format(
    'Pedido entregado con pago pendiente de verificación MotoLink (%s). '
    'El aliado debe registrar comprobante; el pedido figura como moroso hasta la aprobación.',
    coalesce(new.product_name, 'sin nombre')
  );

  perform public.mc_insert_notification (
    new.aliado_id,
    'Pedido moroso · pago pendiente',
    v_body_aliado,
    'morosidad',
    v_anchor
  );

  perform public.mc_insert_notification (
    new.importador_id,
    'Pedido moroso · pago pendiente',
    v_body_imp,
    'morosidad',
    v_anchor
  );

  for rec in
    select p.id
    from public.profiles p
    where p.role = 'administrador'::text
  loop
    perform public.mc_insert_notification (
      rec.id,
      'Pedido moroso',
      format(
        'Pedido %s entregado; pago MotoLink pendiente (aliado %s).',
        coalesce(new.product_name, new.id::text),
        new.aliado_id::text
      ),
      'morosidad',
      v_anchor
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_pedido_moroso_on_entregado on public.transaction_requests;

create trigger trg_notify_pedido_moroso_on_entregado
after update of status on public.transaction_requests
for each row
execute function public.tr_notify_pedido_moroso_on_entregado ();

-- ---------------------------------------------------------------------------
-- 3) Notificar cuando el pago deja de ser moroso (aprobado)
-- ---------------------------------------------------------------------------
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
begin
  if new.status <> 'entregado'::text then
    return new;
  end if;

  v_was_moroso := public.tr_is_moroso_pago_pendiente (old);
  v_now_ok := not public.tr_is_moroso_pago_pendiente (new);

  if not v_was_moroso or not v_now_ok then
    return new;
  end if;

  if coalesce(old.pago_estado_revision, '') = coalesce(new.pago_estado_revision, '') then
    return new;
  end if;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;

  perform public.mc_insert_notification (
    new.aliado_id,
    'Pago confirmado',
    format(
      'El pago del pedido %s fue aprobado. Ya no figura como moroso.',
      coalesce(new.product_name, 'sin nombre')
    ),
    'pago',
    v_anchor
  );

  perform public.mc_insert_notification (
    new.importador_id,
    'Pago aliado confirmado',
    format(
      'MotoLink aprobó el pago del pedido %s. El estado moroso quedó regularizado.',
      coalesce(new.product_name, 'sin nombre')
    ),
    'pago',
    v_anchor
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_pedido_pago_regularizado on public.transaction_requests;

create trigger trg_notify_pedido_pago_regularizado
after update of pago_estado_revision on public.transaction_requests
for each row
execute function public.tr_notify_pedido_pago_regularizado ();

-- ---------------------------------------------------------------------------
-- 4) Retirar plan de cuotas / payment_schedule
-- ---------------------------------------------------------------------------
drop table if exists public.payment_schedule cascade;

alter table public.transaction_requests
  drop column if exists credit_plan_type,
  drop column if exists credit_plan_confirmed_at,
  drop column if exists credit_monto_bloqueado;

-- RPC importador plan cuotas (obsoleto)
drop function if exists public.importer_confirm_order_credit_plan (uuid, numeric[], boolean);
