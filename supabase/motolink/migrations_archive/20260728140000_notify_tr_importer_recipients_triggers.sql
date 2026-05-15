-- Pedidos maestro: owner_id es NULL. notify_logistica_status_change, notify_pago_revision_change
-- y notify_transaction_request_notes_change insertaban con new.owner_id → 23502.
-- Centralizamos: enviar a cada sub_orders.importador_id cuando is_master_order, si no a owner_id.
-- Requiere migración multi_importador (sub_orders) previa.

create or replace function public.notify_tr_importer_recipients(
  p_tr_id uuid,
  p_is_master boolean,
  p_owner_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_related_id text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(p_is_master, false) then
    insert into public.notifications (user_id, title, body, type, related_id)
    select distinct so.importador_id, p_title, p_body, p_type, p_related_id
    from public.sub_orders so
    where so.parent_order_id = p_tr_id
      and so.importador_id is not null;
  elsif p_owner_id is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (p_owner_id, p_title, p_body, p_type, p_related_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
create or replace function public.notify_pago_revision_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.pago_estado_revision is distinct from new.pago_estado_revision then
    if new.pago_estado_revision = 'aprobado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pago aprobado',
        'MotoLink aprobó su comprobante de pago del pedido.',
        'pago',
        new.id::text
      );
      perform public.notify_tr_importer_recipients(
        new.id,
        coalesce(new.is_master_order, false),
        new.owner_id,
        'Pago validado por MotoLink',
        'El comprobante del aliado fue aprobado para un pedido de su inventario.',
        'pago',
        new.id::text
      );
    elsif new.pago_estado_revision = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Comprobante rechazado',
        'MotoLink rechazó su comprobante. Revise la nota y vuelva a cargarlo.',
        'pago',
        new.id::text
      );
    elsif new.pago_estado_revision = 'en_revision' then
      perform public.notify_to_all_admins(
        'Comprobante por revisar',
        'Un aliado envió un comprobante y requiere revisión.',
        'pago',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
create or replace function public.notify_transaction_request_notes_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.notas_admin is distinct from new.notas_admin then
    if coalesce(btrim(new.notas_admin), '') <> '' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Nueva nota de MotoLink',
        'MotoLink agregó una nota al pedido. Revise el detalle.',
        'mensaje',
        new.id::text
      );
      perform public.notify_tr_importer_recipients(
        new.id,
        coalesce(new.is_master_order, false),
        new.owner_id,
        'Nota administrativa en pedido',
        'MotoLink agregó una nota en un pedido de su inventario.',
        'mensaje',
        new.id::text
      );
    end if;
  end if;

  if old.pago_comprobante_rechazo_nota is distinct from new.pago_comprobante_rechazo_nota then
    if coalesce(btrim(new.pago_comprobante_rechazo_nota), '') <> '' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Nota sobre comprobante',
        'MotoLink dejó una observación sobre su comprobante de pago.',
        'pago',
        new.id::text
      );
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Misma lógica que 20260705120000 (anulación MotoLink) con notify_tr_importer_recipients.
-- ---------------------------------------------------------------------------
create or replace function public.notify_logistica_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  fac text;
  prev text;
  pago_pend boolean;
  mot text;
  body_importer text;
  mot2 text;
  v_master boolean;
begin
  v_master := coalesce(new.is_master_order, false);

  if old.status is distinct from new.status then
    if new.status = 'aprobado_admin' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido aprobado por MotoLink',
        'Su solicitud fue aprobada y pasará a preparación.',
        'envio',
        new.id::text
      );
      perform public.notify_tr_importer_recipients(
        new.id,
        v_master,
        new.owner_id,
        'Pedido aprobado para su inventario',
        'MotoLink aprobó una solicitud asociada a su inventario.',
        'envio',
        new.id::text
      );
    elsif new.status = 'rechazado' then
      if coalesce(new.cancelado_por_aliado, false) then
        mot := left(trim(coalesce(new.aliado_cancelacion_motivo, '')), 1200);
        perform public.notify_to_all_admins(
          'Solicitud cancelada por un aliado',
          format('Pedido %s. Motivo: %s', new.id::text, coalesce(mot, '')),
          'envio',
          new.id::text
        );
        body_importer := 'El aliado canceló la solicitud antes de la aprobación de MotoLink. Motivo: ' || coalesce(mot, '');
        perform public.notify_tr_importer_recipients(
          new.id,
          v_master,
          new.owner_id,
          'Solicitud cancelada por el aliado',
          left(body_importer, 2000),
          'envio',
          new.id::text
        );
      elsif coalesce(new.anulado_por_motolink, false) then
        mot2 := left(trim(coalesce(new.motolink_anulacion_motivo, '')), 1200);
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Pedido anulado por MotoLink',
          'MotoLink anuló un pedido que había estado aprobado. Motivo: ' || coalesce(mot2, ''),
          'envio',
          new.id::text
        );
        perform public.notify_tr_importer_recipients(
          new.id,
          v_master,
          new.owner_id,
          'Pedido anulado por MotoLink',
          'MotoLink anuló un pedido asociado a su inventario. Motivo: ' || left(coalesce(mot2, ''), 1200),
          'envio',
          new.id::text
        );
        perform public.notify_to_all_admins(
          'Pedido anulado por administrador',
          format('Pedido %s. Motivo: %s', new.id::text, coalesce(mot2, '')),
          'envio',
          new.id::text
        );
      else
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Pedido rechazado',
          'MotoLink rechazó su solicitud. Revise notas del pedido.',
          'envio',
          new.id::text
        );
        perform public.notify_tr_importer_recipients(
          new.id,
          v_master,
          new.owner_id,
          'Pedido rechazado por MotoLink',
          'Una solicitud de su inventario fue rechazada.',
          'envio',
          new.id::text
        );
      end if;
    elsif new.status = 'en_preparacion' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido en preparación',
        'El importador empezó la preparación de su pedido.',
        'envio',
        new.id::text
      );
      perform public.notify_to_all_admins(
        'Pedido en preparación',
        'Un importador marcó un pedido como en preparación.',
        'envio',
        new.id::text
      );
    elsif new.status = 'pedido_listo' then
      perform public.notify_to_all_admins(
        'Pedido listo para recolección',
        'El importador confirmó que la mercancía está lista en despacho. Puede coordinar la recolección y marcar en tránsito cuando el transporte retire la carga.',
        'envio',
        new.id::text
      );
    elsif new.status = 'en_transito' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido en tránsito',
        'Su pedido fue despachado y está en tránsito.',
        'envio',
        new.id::text
      );
    elsif new.status = 'entregado' then
      fac := coalesce(trim(new.factura_aliado_storage_path), '');
      prev := coalesce(nullif(trim(new.pago_estado_revision), ''), 'pendiente');
      pago_pend := fac <> '' and prev is distinct from 'aprobado';

      if pago_pend then
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Entrega confirmada · pago pendiente',
          'Registró la recepción del pedido. Sigue pendiente el comprobante de pago o su aprobación por MotoLink; complételo en la ficha del pedido.',
          'pago',
          new.id::text
        );
        perform public.notify_to_all_admins(
          'Entrega con pago pendiente',
          format(
            'El aliado confirmó la recepción del pedido %s; el pago aún no está aprobado por MotoLink.',
            new.id::text
          ),
          'pago',
          new.id::text
        );
        perform public.notify_tr_importer_recipients(
          new.id,
          v_master,
          new.owner_id,
          'Entrega confirmada · pago pendiente',
          'El aliado recibió el pedido. El comprobante de pago aún no fue aprobado por MotoLink.',
          'pago',
          new.id::text
        );
      else
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Pedido entregado',
          'El pedido fue marcado como entregado.',
          'envio',
          new.id::text
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;

comment on function public.notify_tr_importer_recipients is
  'In-app: maestro = filas de sub_orders; legado = owner_id.';
