-- Corrige notificaciones (product_name inexistente), pago moroso y avisos de transporte.

-- ---------------------------------------------------------------------------
-- Al marcar entregado: comprobante pendiente → en revisión
-- ---------------------------------------------------------------------------
create or replace function public.tr_entregado_promote_pago_a_revision ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'update'
     and new.status = 'entregado'
     and old.status is distinct from 'entregado'
     and coalesce(trim(new.pago_estado_revision), 'pendiente') = 'pendiente'
     and (
       new.comprobante_pago_storage_path is not null
       and length(trim(new.comprobante_pago_storage_path)) > 0
     ) then
    new.pago_estado_revision := 'en_revision';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_entregado_promote_pago_a_revision on public.transaction_requests;

create trigger trg_entregado_promote_pago_a_revision
before update of status on public.transaction_requests
for each row
execute function public.tr_entregado_promote_pago_a_revision ();

-- ---------------------------------------------------------------------------
-- Importador: aprobar pago moroso tras entrega
-- ---------------------------------------------------------------------------
create or replace function public.importador_set_pago_revision_estado (
  p_request_id uuid,
  p_nuevo_estado text,
  p_rechazo_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp uuid;
  v_path text;
  v_metodo text;
  v_pe text;
  v_status text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if trim(p_nuevo_estado) not in ('aprobado', 'rechazado') then
    raise exception 'Estado no válido';
  end if;

  select
    tr.importador_id,
    tr.comprobante_pago_storage_path,
    tr.pago_metodo,
    tr.pago_estado_revision,
    tr.status
  into v_imp, v_path, v_metodo, v_pe, v_status
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_imp is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_imp is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;

  if coalesce(trim(v_pe), '') not in ('en_revision', 'pendiente') then
    raise exception 'El pago no está en revisión';
  end if;

  if coalesce(trim(v_pe), '') = 'pendiente' then
    if v_status is distinct from 'entregado' then
      raise exception 'El pago aún no está listo para revisión';
    end if;
    if trim(coalesce(v_metodo, '')) <> 'efectivo'
       and (v_path is null or length(trim(v_path)) = 0) then
      raise exception 'No hay comprobante para aprobar';
    end if;
  end if;

  if trim(p_nuevo_estado) = 'aprobado' then
    if trim(coalesce(v_metodo, '')) <> 'efectivo'
       and (v_path is null or length(trim(v_path)) = 0) then
      raise exception 'No hay comprobante para aprobar';
    end if;
    update public.transaction_requests
    set
      pago_estado_revision = 'aprobado',
      pago_comprobante_rechazo_nota = null,
      pago_aprobado_at = now (),
      confirmado_por = auth.uid (),
      updated_at = now ()
    where id = p_request_id;
  else
    update public.transaction_requests
    set
      pago_estado_revision = 'rechazado',
      pago_comprobante_rechazo_nota = nullif(trim(p_rechazo_nota), ''),
      pago_aprobado_at = null,
      updated_at = now ()
    where id = p_request_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Aliado: cambios de estado del pedido
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_carrier_name text;
  v_anchor text;
  v_product text;
  v_has_carriers boolean;
  v_title text;
  v_body text;
begin
  perform set_config ('row_security', 'off', true);

  if tg_op <> 'update' then
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(ic.company_name), '')
    into v_carrier_name
  from public.importer_carriers ic
  where ic.id = new.importer_carrier_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := public.mc_tr_product_label (new);
  v_has_carriers := public.motoconecta_importador_has_active_carriers (new.importador_id);

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  ) then
    if not public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      return new;
    end if;

    v_title := case new.status
      when 'en_preparacion' then 'Pedido en preparación'
      when 'pedido_listo' then 'Listo para despacho'
      when 'en_transito' then 'Pedido en tránsito'
      else 'Actualización de pedido'
    end;

    v_body := case new.status
      when 'en_preparacion' then format(
        '%s confirmó su solicitud y está preparando %s.',
        coalesce(v_imp_name, 'El importador'),
        v_product
      )
      when 'pedido_listo' then case
        when v_has_carriers then
          format(
            'Su pedido %s está listo en %s. Elija un transportista o deje la entrega a elección del importador.',
            v_product,
            coalesce(v_imp_name, 'el importador')
          )
        else
          format(
            'Su pedido %s está listo para despacho en %s.',
            v_product,
            coalesce(v_imp_name, 'el importador')
          )
      end
      when 'en_transito' then case
        when v_carrier_name is not null then
          format(
            '%s despachó %s con %s. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador'),
            v_product,
            v_carrier_name
          )
        else
          format(
            '%s marcó %s como en tránsito. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador'),
            v_product
          )
      end
      else 'Hay un cambio de estado en su pedido.'
    end;

    perform public.mc_insert_notification (
      new.aliado_id,
      v_title,
      v_body,
      'pedido',
      v_anchor
    );

  elsif new.status = 'entregado'::text then
    perform public.mc_insert_notification (
      new.importador_id,
      'Pedido recibido',
      format(
        'El aliado confirmó la recepción de %s en su taller.',
        v_product
      ),
      'pedido',
      v_anchor
    );

  elsif new.status = 'rechazado'::text then
    if public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pedido rechazado',
        format(
          'Su solicitud de %s fue rechazada. Revísela en Pedidos.',
          v_product
        ),
        'pedido',
        v_anchor
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_mc_notify_tr_status on public.transaction_requests;

create trigger trg_mc_notify_tr_status
after update of status on public.transaction_requests
for each row
execute function public.mc_notify_tr_status_changed ();

-- ---------------------------------------------------------------------------
-- Transporte, recolección, flete y comprobantes
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_carrier_y_flete ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_aliado_name text;
  v_carrier_name text;
  v_anchor text;
  v_pickup_line text;
  v_product text;
begin
  perform set_config ('row_security', 'off', true);

  if tg_op <> 'update' then
    return new;
  end if;

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  select nullif(trim(ic.company_name), '')
    into v_carrier_name
  from public.importer_carriers ic
  where ic.id = new.importer_carrier_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := public.mc_tr_product_label (new);

  if new.importer_carrier_id is not null
     and (
       old.importer_carrier_id is null
       or old.importer_carrier_id is distinct from new.importer_carrier_id
     )
     and new.carrier_selected_at is not null
     and (
       old.carrier_selected_at is null
       or old.carrier_selected_at is distinct from new.carrier_selected_at
     ) then
    perform public.mc_insert_notification (
      new.importador_id,
      'Transportista elegido',
      format(
        '%s eligió %s para el despacho de %s.',
        coalesce(v_aliado_name, 'El aliado'),
        coalesce(v_carrier_name, 'un transportista'),
        v_product
      ),
      'pedido',
      v_anchor
    );

    if public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Transportista confirmado',
        case coalesce(new.carrier_flete_pago_modo_snapshot, '')
          when 'pago_separado' then format(
            'Seleccionó %s con factura de flete aparte. Cuando el importador la adjunte podrá registrar el pago del transporte.',
            coalesce(v_carrier_name, 'el transportista')
          )
          else format(
            'Seleccionó %s. El flete irá incluido en la factura del importador.',
            coalesce(v_carrier_name, 'el transportista')
          )
        end,
        'pedido',
        v_anchor
      );
    end if;
  end if;

  if new.carrier_decision = 'skipped'
     and old.carrier_decision is distinct from 'skipped' then
    perform public.mc_insert_notification (
      new.importador_id,
      'Entrega a elección del importador',
      format(
        '%s dejó la entrega de %s a su criterio. Confirme el punto de recolección.',
        coalesce(v_aliado_name, 'El aliado'),
        v_product
      ),
      'pedido',
      v_anchor
    );
  end if;

  if new.pickup_confirmed_at is not null
     and old.pickup_confirmed_at is null then
    v_pickup_line := coalesce(
      nullif(trim(concat_ws(', ', new.pickup_ciudad, new.pickup_estado)), ''),
      nullif(trim(new.pickup_label), ''),
      'ubicación confirmada'
    );

    perform public.mc_insert_notification (
      new.aliado_id,
      'Punto de recolección confirmado',
      format(
        '%s confirmó el punto de recolección de %s: %s.',
        coalesce(v_imp_name, 'El importador'),
        v_product,
        v_pickup_line
      ),
      'pedido',
      v_anchor
    );
  end if;

  if new.flete_factura_storage_path is not null
     and length(trim(new.flete_factura_storage_path)) > 0
     and (
       old.flete_factura_storage_path is null
       or length(trim(old.flete_factura_storage_path)) = 0
       or old.flete_factura_storage_path is distinct from new.flete_factura_storage_path
     )
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    perform public.mc_insert_notification (
      new.aliado_id,
      case
        when old.flete_factura_storage_path is not null
             and length(trim(old.flete_factura_storage_path)) > 0
          then 'Factura del flete actualizada'
        else 'Factura del flete disponible'
      end,
      format(
        '%s adjuntó la factura del transporte de %s. Revise el monto y registre el pago del flete.',
        coalesce(v_imp_name, 'El importador'),
        v_product
      ),
      'pedido',
      v_anchor
    );
  end if;

  if new.flete_comprobante_pago_storage_path is not null
     and length(trim(new.flete_comprobante_pago_storage_path)) > 0
     and (
       old.flete_comprobante_pago_storage_path is null
       or length(trim(old.flete_comprobante_pago_storage_path)) = 0
       or old.flete_comprobante_pago_storage_path is distinct from new.flete_comprobante_pago_storage_path
     ) then
    perform public.mc_insert_notification (
      new.importador_id,
      'Comprobante de pago del flete',
      format(
        '%s registró el pago del flete de %s. Revíselo en Pedidos.',
        coalesce(v_aliado_name, 'El aliado'),
        v_product
      ),
      'pedido',
      v_anchor
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_mc_notify_tr_carrier_y_flete on public.transaction_requests;

create trigger trg_mc_notify_tr_carrier_y_flete
after update on public.transaction_requests
for each row
execute function public.mc_notify_tr_carrier_y_flete ();
