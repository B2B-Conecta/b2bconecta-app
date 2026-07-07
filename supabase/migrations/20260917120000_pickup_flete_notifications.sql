-- Recolección solo tras decisión del aliado, elección de factura del flete y notificaciones.

-- ---------------------------------------------------------------------------
-- Importador: bloquear recolección si el aliado aún debe decidir transporte
-- ---------------------------------------------------------------------------
create or replace function public.importer_confirm_pickup_location (
  p_request_id uuid,
  p_mode text,
  p_pickup_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_row record;
  v_mode text;
  v_label text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_lat numeric;
  v_lng numeric;
  v_maps text;
  v_carrier_id uuid;
  v_loc record;
  v_prof record;
  v_carrier record;
begin
  v_uid := public.motoconecta_assert_importador_role ();
  v_mode := coalesce(nullif(trim(p_mode), ''), 'warehouse');

  if v_mode not in ('warehouse', 'carrier_base', 'alternate') then
    raise exception 'Modo de punto de recolección no válido.';
  end if;

  select
    tr.id,
    tr.importador_id,
    tr.status,
    tr.carrier_decision,
    tr.importer_carrier_id
  into v_row
  from public.transaction_requests tr
  where tr.id = p_request_id
    and tr.importador_id = v_uid;

  if v_row.id is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_row.status is distinct from 'pedido_listo' then
    raise exception 'Solo puede confirmar recolección en pedidos listos para despacho.';
  end if;

  if v_row.carrier_decision = 'pending' then
    raise exception 'Espere a que el aliado decida si usará un transportista de la plataforma.';
  end if;

  if v_row.carrier_decision = 'not_applicable'
     and public.motoconecta_importador_has_active_carriers (v_row.importador_id) then
    raise exception 'Espere a que el aliado decida si usará un transportista de la plataforma.';
  end if;

  if v_mode = 'carrier_base' then
    if v_row.carrier_decision is distinct from 'selected' then
      raise exception 'La base del transportista solo aplica si el aliado eligió un transportista.';
    end if;
    if v_row.importer_carrier_id is null then
      raise exception 'No hay transportista asignado a este pedido.';
    end if;
  end if;

  if v_mode = 'alternate' then
    if p_pickup_location_id is null then
      raise exception 'Seleccione una ubicación alterna.';
    end if;
    select l.*
    into v_loc
    from public.importer_pickup_locations l
    where l.id = p_pickup_location_id
      and l.importador_id = v_uid
      and l.is_active = true;
    if not found then
      raise exception 'Ubicación alterna no válida.';
    end if;
    v_label := v_loc.label;
    v_estado := v_loc.estado;
    v_ciudad := v_loc.ciudad;
    v_direccion := v_loc.direccion;
    v_lat := v_loc.latitude;
    v_lng := v_loc.longitude;
    v_maps := v_loc.maps_url;
    v_carrier_id := null;
  elsif v_mode = 'carrier_base' then
    select c.*
    into v_carrier
    from public.importer_carriers c
    where c.id = v_row.importer_carrier_id;

    v_label := coalesce(v_carrier.company_name, 'Base del transportista');
    v_estado := v_carrier.base_estado;
    v_ciudad := v_carrier.base_ciudad;
    v_direccion := coalesce(
      nullif(trim(concat_ws(', ', v_carrier.base_ciudad, v_carrier.base_estado)), ''),
      v_carrier.company_name
    );
    v_lat := v_carrier.base_latitude;
    v_lng := v_carrier.base_longitude;
    v_maps := v_carrier.base_maps_url;
    v_carrier_id := v_carrier.id;
  else
    select
      p.business_name,
      p.estado,
      p.ciudad,
      p.direccion,
      p.latitude,
      p.longitude,
      p.fiscal_maps_url
    into v_prof
    from public.profiles p
    where p.id = v_uid;

    v_label := coalesce(nullif(trim(v_prof.business_name), ''), 'Mi almacén');
    v_estado := v_prof.estado;
    v_ciudad := v_prof.ciudad;
    v_direccion := v_prof.direccion;
    v_lat := v_prof.latitude;
    v_lng := v_prof.longitude;
    v_maps := v_prof.fiscal_maps_url;
    v_carrier_id := null;

    if coalesce(btrim(v_direccion), '') = '' then
      raise exception 'Complete la dirección de su almacén en el perfil antes de usar «Mi almacén».';
    end if;
  end if;

  update public.transaction_requests tr
  set
    pickup_location_mode = v_mode,
    pickup_confirmed_at = now(),
    pickup_label = v_label,
    pickup_estado = v_estado,
    pickup_ciudad = v_ciudad,
    pickup_direccion = v_direccion,
    pickup_latitude = v_lat,
    pickup_longitude = v_lng,
    pickup_maps_url = v_maps,
    pickup_location_id = case when v_mode = 'alternate' then p_pickup_location_id else null end,
    pickup_carrier_id = v_carrier_id,
    updated_at = now()
  where tr.id = p_request_id
    and tr.importador_id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Aliado: elegir transportista y modo de factura del flete
-- ---------------------------------------------------------------------------
create or replace function public.aliado_select_carrier_for_pedido (
  p_request_id uuid,
  p_carrier_id uuid,
  p_driver_id uuid default null,
  p_flete_pago_modo text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_importador uuid;
  v_status text;
  v_decision text;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  v_dest_structured boolean;
  v_carrier record;
  v_flete_modo text;
  v_dist numeric;
  v_eta numeric;
  v_fee numeric;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;
  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden elegir transportista.';
  end if;

  perform public.motoconecta_ensure_carrier_decision_pending (p_request_id);

  select
    tr.importador_id,
    tr.status,
    tr.carrier_decision,
    d.dest_estado,
    d.dest_ciudad,
    d.dest_lat,
    d.dest_lng,
    d.dest_structured
  into
    v_importador,
    v_status,
    v_decision,
    v_dest_estado,
    v_dest_ciudad,
    v_dest_lat,
    v_dest_lng,
    v_dest_structured
  from public.transaction_requests tr
  cross join lateral public.motoconecta_pedido_delivery_destination (tr.id) as d
  where tr.id = p_request_id
    and tr.aliado_id = v_uid;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_status is distinct from 'pedido_listo' then
    raise exception 'Solo puede elegir transportista cuando el pedido está listo para despacho.';
  end if;

  if not public.motoconecta_importador_has_active_carriers (v_importador) then
    raise exception 'Este importador no tiene transportistas activos.';
  end if;

  if v_decision not in ('pending', 'selected') then
    raise exception 'No puede cambiar el transportista en el estado actual del pedido.';
  end if;

  if p_carrier_id is null then
    raise exception 'Seleccione un transportista.';
  end if;

  select * into v_carrier
  from public.importer_carriers c
  where c.id = p_carrier_id
    and c.importador_id = v_importador
    and c.is_active = true;

  if not found then
    raise exception 'Transportista no válido.';
  end if;

  v_flete_modo := coalesce(nullif(trim(p_flete_pago_modo), ''), v_carrier.flete_pago_modo);

  if v_flete_modo not in ('incluido_factura', 'pago_separado') then
    raise exception 'Modo de factura del flete no válido.';
  end if;

  if p_driver_id is not null and not exists (
    select 1
    from public.importer_carrier_drivers d
    where d.id = p_driver_id
      and d.carrier_id = p_carrier_id
      and d.is_active = true
  ) then
    raise exception 'Conductor no válido para el transportista.';
  end if;

  if coalesce(v_dest_structured, false) then
    if not public.motoconecta_carrier_covers_destination (
      v_carrier.coverage_estados,
      v_carrier.coverage_ciudades,
      v_dest_estado,
      v_dest_ciudad
    ) then
      raise exception 'El transportista no cubre el destino de entrega.';
    end if;

    v_dist := public.motoconecta_haversine_km (
      v_carrier.base_latitude,
      v_carrier.base_longitude,
      v_dest_lat,
      v_dest_lng
    );

    if v_carrier.max_coverage_km is not null
       and v_dist is not null
       and v_dist > v_carrier.max_coverage_km then
      raise exception 'El transportista no cubre la distancia hasta su destino.';
    end if;
  else
    v_dist := public.motoconecta_haversine_km (
      v_carrier.base_latitude,
      v_carrier.base_longitude,
      v_dest_lat,
      v_dest_lng
    );
  end if;

  v_eta := public.motoconecta_carrier_eta_hours (
    v_carrier.eta_base_hours,
    v_carrier.eta_hours_per_km,
    v_dist
  );
  v_fee := public.motoconecta_carrier_fee_usd (
    v_carrier.flat_fee_usd,
    v_carrier.price_per_km_usd,
    v_dist
  );

  update public.transaction_requests tr
  set
    importer_carrier_id = p_carrier_id,
    importer_carrier_driver_id = p_driver_id,
    carrier_eta_hours_snapshot = v_eta,
    carrier_distance_km_snapshot = v_dist,
    carrier_fee_usd_snapshot = v_fee,
    carrier_flete_pago_modo_snapshot = v_flete_modo,
    carrier_company_name_snapshot = v_carrier.company_name,
    carrier_accepted_pago_metodos_snapshot = v_carrier.accepted_pago_metodos,
    carrier_pago_instrucciones_snapshot = v_carrier.pago_metodo_instrucciones,
    carrier_selected_at = now(),
    carrier_decision = 'selected',
    carrier_decision_at = now(),
    flete_factura_storage_path = case
      when v_flete_modo = 'pago_separado' then tr.flete_factura_storage_path
      else null
    end,
    flete_factura_file_name = case
      when v_flete_modo = 'pago_separado' then tr.flete_factura_file_name
      else null
    end,
    flete_factura_submitted_at = case
      when v_flete_modo = 'pago_separado' then tr.flete_factura_submitted_at
      else null
    end,
    flete_pago_metodo = case
      when v_flete_modo = 'pago_separado' then tr.flete_pago_metodo
      else null
    end,
    flete_comprobante_pago_storage_path = case
      when v_flete_modo = 'pago_separado' then tr.flete_comprobante_pago_storage_path
      else null
    end,
    flete_comprobante_pago_file_name = case
      when v_flete_modo = 'pago_separado' then tr.flete_comprobante_pago_file_name
      else null
    end,
    flete_comprobante_submitted_at = case
      when v_flete_modo = 'pago_separado' then tr.flete_comprobante_submitted_at
      else null
    end,
    flete_pago_estado_revision = case
      when v_flete_modo = 'pago_separado' then tr.flete_pago_estado_revision
      else null
    end,
    flete_comprobante_rechazo_nota = case
      when v_flete_modo = 'pago_separado' then tr.flete_comprobante_rechazo_nota
      else null
    end,
    flete_pago_aprobado_at = case
      when v_flete_modo = 'pago_separado' then tr.flete_pago_aprobado_at
      else null
    end,
    pickup_confirmed_at = null,
    pickup_location_mode = null,
    pickup_label = null,
    pickup_estado = null,
    pickup_ciudad = null,
    pickup_direccion = null,
    pickup_latitude = null,
    pickup_longitude = null,
    pickup_maps_url = null,
    pickup_location_id = null,
    pickup_carrier_id = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = v_uid
    and tr.status = 'pedido_listo';
end;
$$;

grant execute on function public.aliado_select_carrier_for_pedido (uuid, uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Notificaciones al aliado: en preparación, listo, en tránsito
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
            'Su pedido está listo en %s. Elija un transportista o indique que coordinará la entrega usted mismo.',
            coalesce(v_imp_name, 'el importador')
          )
        else
          format(
            'Su pedido está listo para despacho en %s.',
            coalesce(v_imp_name, 'el importador')
          )
      end
      when 'en_transito' then case
        when v_carrier_name is not null then
          format(
            '%s despachó su pedido con %s. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador'),
            v_carrier_name
          )
        else
          format(
            '%s marcó su pedido como en tránsito. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador')
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
-- Notificación al aliado al elegir transportista (ambos modos de factura)
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
      'Sin transportista de la plataforma',
      format(
        '%s indicó que coordinará la entrega. Confirme el punto de recolección.',
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
            then ' Usted coordinará el retiro de la mercancía.'
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
