-- Aliado puede declarar pago en efectivo sin adjunto obligatorio.
-- El importador confirma la recepción (como admin_aprobar_pago_aliado para efectivo).

create or replace function public.aliado_declara_pago_efectivo (p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_importador uuid;
  v_status text;
  v_pe text;
  v_accepted text[];
  v_solo_divisas boolean;
  v_cant integer;
  v_base numeric;
  v_total numeric;
  v_unit numeric;
  v_rules jsonb;
  v_rules_out jsonb;
  v_pct numeric;
  v_applied boolean;
  v_comm_rate numeric;
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
  v_metodo text := 'efectivo';
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    tr.pago_estado_revision,
    tr.cantidad,
    coalesce(tr.precio_base_aliado_total, tr.precio_total_usd),
    tr.discount_rules,
    tr.commission_rate_snapshot
  into
    v_aliado,
    v_importador,
    v_status,
    v_pe,
    v_cant,
    v_base,
    v_rules,
    v_comm_rate
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
  if v_pe is not null and trim(v_pe) = 'aprobado' then
    raise exception 'El pago ya fue confirmado';
  end if;

  select
    coalesce(p.accepted_pago_metodos, public.motoconecta_all_pago_metodos ()),
    coalesce(p.pago_solo_divisas, false)
  into v_accepted, v_solo_divisas
  from public.profiles p
  where p.id = v_importador;

  if coalesce(v_solo_divisas, false) then
    raise exception
      'Este importador solo acepta pagos en divisas (USD). Elija Zelle, Binance, USDT o efectivo.';
  end if;

  if not (v_metodo = any (v_accepted)) then
    raise exception
      'Este importador no acepta pago en efectivo. Elija otro método o acuerde con el proveedor.';
  end if;

  v_pct := public.motoconecta_usd_discount_pct (v_rules);
  v_applied := not coalesce(v_solo_divisas, false)
    and v_metodo = any (public.motoconecta_usd_discount_metodos ())
    and v_pct > 0;

  v_total := public.motoconecta_order_total_for_pago_metodo (
    v_base,
    v_rules,
    v_metodo
  );

  v_unit := round(
    (v_total / greatest(coalesce(v_cant, 1), 1))::numeric,
    6
  );

  v_rules_out := public.motoconecta_enrich_discount_rules_pago_metodo (
    v_rules,
    v_metodo,
    v_applied
  );

  update public.transaction_requests
  set
    pago_metodo = v_metodo,
    comprobante_pago_submitted_at = coalesce(comprobante_pago_submitted_at, now()),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    precio_base_aliado_total = v_base,
    precio_total_usd = v_total,
    precio_unitario_aliado = v_unit,
    discount_rules = v_rules_out,
    comision_devengada_usd = case
      when comision_devengada_at is null and coalesce(v_comm_rate, 0) > 0
        then round((v_total * v_comm_rate)::numeric, 2)
      else comision_devengada_usd
    end
  where id = p_request_id;

  perform public._aliado_register_pago_frecuente (v_aliado, v_importador, v_metodo);
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo (uuid) to authenticated;

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
    tr.pago_estado_revision
  into v_imp, v_path, v_metodo, v_pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_imp is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_imp is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if coalesce(trim(v_pe), '') <> 'en_revision' then
    raise exception 'El pago no está en revisión';
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

create or replace function public.mc_notify_tr_pago_y_factura ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_aliado_name text;
  v_anchor text;
  v_nota text;
begin
  perform set_config ('row_security', 'off', true);

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;

  if new.proveedor_factura_storage_path is not null
     and length(trim(new.proveedor_factura_storage_path)) > 0
     and (
       old.proveedor_factura_storage_path is null
       or length(trim(old.proveedor_factura_storage_path)) = 0
       or old.proveedor_factura_storage_path is distinct from new.proveedor_factura_storage_path
     )
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    perform public.mc_insert_notification (
      new.aliado_id,
      case
        when old.proveedor_factura_storage_path is not null
             and length(trim(old.proveedor_factura_storage_path)) > 0
          then 'Factura del proveedor actualizada'
        else 'Factura del proveedor disponible'
      end,
      format(
        '%s adjuntó su factura%s. Revise el monto y registre su pago en Pedidos.',
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

  if new.pago_estado_revision = 'en_revision'
     and old.pago_estado_revision is distinct from 'en_revision'
     and public.mc_tr_is_notification_anchor_row (new, 'importador_comprobante') then
    if new.comprobante_pago_storage_path is not null
       and length(trim(new.comprobante_pago_storage_path)) > 0 then
      perform public.mc_insert_notification (
        new.importador_id,
        'Comprobante de pago recibido',
        format(
          '%s adjuntó un comprobante para revisar%s.',
          coalesce(v_aliado_name, 'El aliado'),
          case
            when new.checkout_group_id is not null then ' (varias líneas del mismo carrito)'
            else ''
          end
        ),
        'pago',
        new.id::text
      );
    elsif trim(coalesce(new.pago_metodo, '')) = 'efectivo' then
      perform public.mc_insert_notification (
        new.importador_id,
        'Pago en efectivo declarado',
        format(
          '%s declaró pago en efectivo%s. Confirme cuando haya recibido el dinero.',
          coalesce(v_aliado_name, 'El aliado'),
          case
            when new.checkout_group_id is not null then ' (varias líneas del mismo carrito)'
            else ''
          end
        ),
        'pago',
        new.id::text
      );
    end if;
  end if;

  if new.pago_estado_revision is distinct from old.pago_estado_revision
     and new.pago_estado_revision in ('aprobado', 'rechazado')
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    v_nota := nullif(trim(new.pago_comprobante_rechazo_nota), '');

    if new.pago_estado_revision = 'aprobado' then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pago confirmado por el importador',
        format(
          case
            when trim(coalesce(new.pago_metodo, '')) = 'efectivo'
              then '%s confirmó la recepción del pago en efectivo.'
            else '%s confirmó su comprobante de pago.'
          end,
          coalesce(v_imp_name, 'El importador')
        ),
        'pago',
        v_anchor
      );
    else
      perform public.mc_insert_notification (
        new.aliado_id,
        'Comprobante de pago rechazado',
        format(
          '%s no aprobó su comprobante.%s',
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
