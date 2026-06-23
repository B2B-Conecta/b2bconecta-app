-- Revisión del comprobante de flete por el importador (igual que pago al proveedor).

alter table public.transaction_requests
  add column if not exists flete_pago_estado_revision text,
  add column if not exists flete_comprobante_rechazo_nota text,
  add column if not exists flete_pago_aprobado_at timestamptz;

comment on column public.transaction_requests.flete_pago_estado_revision is
  'pendiente | en_revision | aprobado | rechazado — comprobante de pago del flete.';

-- Comprobantes ya enviados quedan en revisión.
update public.transaction_requests tr
set flete_pago_estado_revision = 'en_revision'
where tr.flete_comprobante_pago_storage_path is not null
  and length(trim(tr.flete_comprobante_pago_storage_path)) > 0
  and coalesce(trim(tr.flete_pago_estado_revision), '') = '';

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
  v_flete_pe text;
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
    tr.importer_carrier_id,
    tr.flete_pago_estado_revision
  into
    v_aliado,
    v_status,
    v_flete_modo,
    v_flete_inv,
    v_carrier,
    v_flete_pe
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
  if coalesce(trim(v_flete_pe), '') = 'aprobado' then
    raise exception 'El pago del flete ya fue confirmado; no puede modificar el comprobante';
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
    flete_pago_estado_revision = 'en_revision',
    flete_comprobante_rechazo_nota = null,
    flete_pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ();
end;
$$;

create or replace function public.importador_set_flete_pago_revision_estado (
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
  v_pe text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if trim(p_nuevo_estado) not in ('aprobado', 'rechazado') then
    raise exception 'Estado no válido';
  end if;

  select
    tr.importador_id,
    tr.flete_comprobante_pago_storage_path,
    tr.flete_pago_estado_revision
  into v_imp, v_path, v_pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_imp is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_imp is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if coalesce(trim(v_pe), '') <> 'en_revision' then
    raise exception 'El comprobante del flete no está en revisión';
  end if;

  if trim(p_nuevo_estado) = 'aprobado' then
    if v_path is null or length(trim(v_path)) = 0 then
      raise exception 'No hay comprobante de flete para aprobar';
    end if;
    update public.transaction_requests
    set
      flete_pago_estado_revision = 'aprobado',
      flete_comprobante_rechazo_nota = null,
      flete_pago_aprobado_at = now(),
      updated_at = now()
    where id = p_request_id;
  else
    update public.transaction_requests
    set
      flete_pago_estado_revision = 'rechazado',
      flete_comprobante_rechazo_nota = nullif(trim(p_rechazo_nota), ''),
      flete_pago_aprobado_at = null,
      updated_at = now()
    where id = p_request_id;
  end if;
end;
$$;

grant execute on function public.importador_set_flete_pago_revision_estado (uuid, text, text) to authenticated;

-- Morosidad: flete pendiente hasta aprobación del importador.
create or replace function public.tr_pago_flete_pendiente_moroso (
  p_row public.transaction_requests
)
returns boolean
language sql
stable
as $$
  select coalesce(p_row.carrier_flete_pago_modo_snapshot, '') = 'pago_separado'
     and coalesce(p_row.flete_factura_storage_path, '') <> ''
     and coalesce(p_row.flete_pago_estado_revision, '') <> 'aprobado';
$$;

comment on function public.tr_is_moroso_pago_pendiente (public.transaction_requests) is
  'Entregado con factura del importador sin pago aprobado y/o flete separado sin comprobante aprobado.';

drop trigger if exists trg_clear_aliado_pago_reminder_tr on public.transaction_requests;

create trigger trg_clear_aliado_pago_reminder_tr
after update of
  status,
  pago_estado_revision,
  proveedor_factura_storage_path,
  carrier_flete_pago_modo_snapshot,
  flete_factura_storage_path,
  flete_comprobante_pago_storage_path,
  flete_pago_estado_revision
  on public.transaction_requests
for each row
execute function public.tr_clear_aliado_pago_reminder_on_tr_update ();

drop trigger if exists trg_notify_pedido_pago_regularizado on public.transaction_requests;

create trigger trg_notify_pedido_pago_regularizado
after update of pago_estado_revision, flete_pago_estado_revision
  on public.transaction_requests
for each row
execute function public.tr_notify_pedido_pago_regularizado ();

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
     and coalesce(old.flete_pago_estado_revision, '')
       = coalesce(new.flete_pago_estado_revision, '') then
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

-- Notificaciones: comprobante flete en revisión + aprobación/rechazo.
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
  v_nota text;
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

  if new.flete_pago_estado_revision = 'en_revision'
     and old.flete_pago_estado_revision is distinct from 'en_revision'
     and new.flete_comprobante_pago_storage_path is not null
     and length(trim(new.flete_comprobante_pago_storage_path)) > 0 then
    perform public.mc_insert_notification (
      new.importador_id,
      'Comprobante de pago del flete recibido',
      format(
        '%s adjuntó el comprobante del pago del transporte para revisar%s.',
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

  if new.flete_pago_estado_revision is distinct from old.flete_pago_estado_revision
     and new.flete_pago_estado_revision in ('aprobado', 'rechazado') then
    v_nota := nullif(trim(new.flete_comprobante_rechazo_nota), '');

    if new.flete_pago_estado_revision = 'aprobado' then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pago del flete confirmado',
        format(
          '%s confirmó su comprobante del transporte%s.',
          coalesce(v_imp_name, 'El importador'),
          case
            when v_carrier_name is not null then ' (' || v_carrier_name || ')'
            else ''
          end
        ),
        'pago',
        v_anchor
      );
    else
      perform public.mc_insert_notification (
        new.aliado_id,
        'Comprobante del flete rechazado',
        format(
          '%s no aprobó su comprobante del transporte.%s',
          coalesce(v_imp_name, 'El importador'),
          case
            when v_nota is not null then ' Motivo: ' || v_nota
            else ' Revise el pedido y adjunte un nuevo comprobante si corresponde.'
          end
        ),
        'pago',
        v_anchor
      );
    end if;
  end if;

  return new;
end;
$$;
