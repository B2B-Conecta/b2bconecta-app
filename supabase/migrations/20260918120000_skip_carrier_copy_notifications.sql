-- Alinea notificaciones con el nuevo copy «A elección del importador».

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
        '%s seleccionó %s para el despacho%s.',
        coalesce(v_aliado_name, 'El aliado'),
        coalesce(v_carrier_name, 'un transportista'),
        case
          when new.checkout_group_id is not null then ' de su pedido en este carrito'
          else ''
        end
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
        '%s dejó la entrega a su criterio. Confirme el punto de recolección.',
        coalesce(v_aliado_name, 'El aliado')
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
        '%s confirmó el punto de recolección: %s.%s',
        coalesce(v_imp_name, 'El importador'),
        v_pickup_line,
        case
          when new.carrier_decision = 'selected'
            then ' El transporte lo coordinará ' || coalesce(v_carrier_name, 'el transportista elegido') || '.'
          when new.carrier_decision in ('skipped', 'not_applicable')
            then ' El importador coordinará el retiro de la mercancía.'
          else ''
        end
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
        '%s adjuntó la factura del transporte%s. Revise el monto y registre el pago del flete en Pedidos.',
        coalesce(v_imp_name, 'El importador'),
        case
          when new.checkout_group_id is not null then ' de su pedido'
          else ''
        end
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
        '%s registró el pago del flete%s. Revíselo en Pedidos.',
        coalesce(v_aliado_name, 'El aliado'),
        case
          when new.checkout_group_id is not null then ' de su pedido'
          else ''
        end
      ),
      'pedido',
      v_anchor
    );
  end if;

  return new;
end;
$$;
