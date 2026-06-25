-- Aliado: ver factura de flete (pago separado), registrar comprobante y notificaciones de transporte.

alter table public.transaction_requests
  add column if not exists flete_pago_metodo text,
  add column if not exists flete_comprobante_pago_storage_path text,
  add column if not exists flete_comprobante_pago_file_name text,
  add column if not exists flete_comprobante_submitted_at timestamptz;

comment on column public.transaction_requests.flete_pago_metodo is
  'Método con el que el aliado pagó el flete (pago_separado).';
comment on column public.transaction_requests.flete_comprobante_pago_storage_path is
  'Comprobante de pago del flete subido por el aliado (bucket order-payment-proofs).';

-- ---------------------------------------------------------------------------
-- Aliado: registrar comprobante de pago del flete (transporte pago separado)
-- ---------------------------------------------------------------------------
create or replace function public.aliado_registra_comprobante_flete_pago (
  p_request_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_status text;
  v_flete_modo text;
  v_flete_inv text;
  v_carrier uuid;
  v_metodo text;
  v_allowed_global text[] := public.motoconecta_all_pago_metodos ();
  v_accepted text[];
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  v_metodo := lower(trim(p_metodo));

  if v_metodo = '' or not (v_metodo = any (v_allowed_global)) then
    raise exception 'Método de pago no permitido';
  end if;

  if p_storage_path is null or length(trim(p_storage_path)) = 0 then
    raise exception 'Ruta del comprobante requerida';
  end if;

  select
    tr.aliado_id,
    tr.status,
    tr.carrier_flete_pago_modo_snapshot,
    tr.flete_factura_storage_path,
    tr.importer_carrier_id
  into
    v_aliado,
    v_status,
    v_flete_modo,
    v_flete_inv,
    v_carrier
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_aliado is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if v_status = 'rechazado' then
    raise exception 'El pedido está rechazado';
  end if;
  if coalesce(v_flete_modo, '') <> 'pago_separado' then
    raise exception 'El comprobante de flete solo aplica cuando el transporte se paga por separado';
  end if;
  if v_carrier is null then
    raise exception 'Debe seleccionar un transportista antes de registrar el pago del flete';
  end if;
  if v_flete_inv is null or length(trim(v_flete_inv)) = 0 then
    raise exception 'El importador aún no adjunta la factura del flete';
  end if;

  select coalesce(ic.accepted_pago_metodos, public.motoconecta_all_pago_metodos ())
    into v_accepted
  from public.importer_carriers ic
  where ic.id = v_carrier;

  if not (v_metodo = any (v_accepted)) then
    raise exception
      'Este transportista no acepta el método de pago seleccionado. Elija otro o acuerde con el transportista.';
  end if;

  update public.transaction_requests tr
  set
    flete_pago_metodo = v_metodo,
    flete_comprobante_pago_storage_path = trim(p_storage_path),
    flete_comprobante_pago_file_name = nullif(trim(coalesce(p_file_name, '')), ''),
    flete_comprobante_submitted_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ();
end;
$$;

grant execute on function public.aliado_registra_comprobante_flete_pago (uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Notificaciones: transportista elegido, factura de flete, comprobante de flete
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
begin
  if tg_op <> 'update' then
    return new;
  end if;

  perform set_config ('row_security', 'off', true);

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

  -- Aliado eligió transportista → importador
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

    -- Aliado: confirmación de su selección (pago separado)
    if coalesce(new.carrier_flete_pago_modo_snapshot, '') = 'pago_separado'
       and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Transportista confirmado',
        format(
          'Seleccionó %s. Cuando el importador adjunte la factura del flete podrá registrar el pago del transporte.',
          coalesce(v_carrier_name, 'el transportista')
        ),
        'pedido',
        v_anchor
      );
    end if;
  end if;

  -- Factura de flete → aliado
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
          when new.checkout_group_id is not null then ' para su bloque en este carrito'
          else ''
        end
      ),
      'pago',
      v_anchor
    );
  end if;

  -- Comprobante de flete del aliado → importador
  if new.flete_comprobante_pago_storage_path is not null
     and length(trim(new.flete_comprobante_pago_storage_path)) > 0
     and (
       old.flete_comprobante_pago_storage_path is null
       or length(trim(old.flete_comprobante_pago_storage_path)) = 0
       or old.flete_comprobante_pago_storage_path is distinct from new.flete_comprobante_pago_storage_path
     ) then
    perform public.mc_insert_notification (
      new.importador_id,
      'Comprobante de pago del flete recibido',
      format(
        '%s adjuntó el comprobante del pago del transporte%s.',
        coalesce(v_aliado_name, 'El aliado'),
        case
          when v_carrier_name is not null then ' (' || v_carrier_name || ')'
          else ''
        end
      ),
      'pago',
      new.id::text
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

-- En tránsito: mencionar transportista si fue asignado
create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_carriers boolean;
  v_carrier_name text;
begin
  if tg_op <> 'update' then
    return new;
  end if;
  if old.status is not distinct from new.status then
    return new;
  end if;

  select nullif(trim(ic.company_name), '')
    into v_carrier_name
  from public.importer_carriers ic
  where ic.id = new.importer_carrier_id;

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  )
  then
    v_has_carriers := public.motoconecta_importador_has_active_carriers (new.importador_id);

    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      case new.status
        when 'en_preparacion' then 'Pedido en preparación'
        when 'pedido_listo' then 'Listo para despacho'
        when 'en_transito' then 'Pedido en tránsito'
        else 'Actualización de pedido'
      end,
      case new.status
        when 'en_preparacion' then
          'El importador confirmó la solicitud y está preparando tu pedido.'
        when 'pedido_listo' then
          case
            when v_has_carriers then
              'El importador marcó el pedido como listo. Elija un transportista en la ficha del pedido.'
            else
              'El importador marcó el pedido como listo para despacho.'
          end
        when 'en_transito' then
          case
            when v_carrier_name is not null then
              format(
                'El pedido fue despachado con %s y va en camino a su taller.',
                v_carrier_name
              )
            else
              'El pedido fue despachado y va en camino a su taller.'
          end
        else
          'Hay un cambio de estado en tu pedido.'
      end,
      'pedido',
      new.id::text
    );
  elsif new.status = 'entregado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido recibido',
      'El aliado confirmó la recepción del pedido en su taller.',
      'pedido',
      new.id::text
    );
  elsif new.status = 'rechazado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Pedido rechazado',
      'Un pedido pasó a rechazado. Revíselo en Pedidos.',
      'pedido',
      new.id::text
    );
  end if;

  return new;
end;
$$;
