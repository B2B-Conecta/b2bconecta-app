-- Notificaciones de pago MotoConecta:
-- · Aliado: factura del proveedor emitida / actualizada; pago aprobado o rechazado.
-- · Importador: comprobante del aliado en revisión.

-- ---------------------------------------------------------------------------
-- Helper: insertar notificación (bypass RLS, mismo patrón que mc_notify_tr_*)
-- ---------------------------------------------------------------------------
create or replace function public.mc_insert_notification (
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_related_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    return;
  end if;
  if p_title is null or length(trim(p_title)) = 0 then
    return;
  end if;
  perform set_config ('row_security', 'off', true);
  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    p_user_id,
    trim(p_title),
    coalesce(nullif(trim(p_body), ''), trim(p_title)),
    coalesce(nullif(trim(p_type), ''), 'pago'),
    nullif(trim(p_related_id), '')
  );
end;
$$;

-- Ancla de deep-link: carrito (checkout_group_id) o línea suelta.
create or replace function public.mc_tr_notif_anchor_id (p_row public.transaction_requests)
returns uuid
language sql
immutable
as $$
  select coalesce(p_row.checkout_group_id, p_row.id);
$$;

-- Solo una notificación por evento en carritos multi-línea (misma actualización en lote).
create or replace function public.mc_tr_is_notification_anchor_row (
  p_row public.transaction_requests,
  p_scope text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_anchor uuid;
begin
  v_anchor := public.mc_tr_notif_anchor_id (p_row);

  if p_scope = 'aliado_importador' then
    return p_row.id = (
      select min(tr.id)
      from public.transaction_requests tr
      where tr.aliado_id = p_row.aliado_id
        and tr.importador_id = p_row.importador_id
        and public.mc_tr_notif_anchor_id (tr) = v_anchor
    );
  elsif p_scope = 'importador_comprobante' then
    return p_row.id = (
      select min(tr.id)
      from public.transaction_requests tr
      where tr.importador_id = p_row.importador_id
        and public.mc_tr_notif_anchor_id (tr) = v_anchor
        and coalesce(tr.comprobante_pago_storage_path, '')
          = coalesce(p_row.comprobante_pago_storage_path, '')
    );
  end if;

  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: factura proveedor + comprobante + revisión de pago
-- ---------------------------------------------------------------------------
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

  -- 1) Factura del importador → aliado
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

  -- 2) Comprobante del aliado → importador
  if new.pago_estado_revision = 'en_revision'
     and old.pago_estado_revision is distinct from 'en_revision'
     and new.comprobante_pago_storage_path is not null
     and length(trim(new.comprobante_pago_storage_path)) > 0
     and public.mc_tr_is_notification_anchor_row (new, 'importador_comprobante') then
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
  end if;

  -- 3) Revisión del importador → aliado
  if new.pago_estado_revision is distinct from old.pago_estado_revision
     and new.pago_estado_revision in ('aprobado', 'rechazado')
     and public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    v_nota := nullif(trim(new.pago_comprobante_rechazo_nota), '');

    if new.pago_estado_revision = 'aprobado' then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pago confirmado por el importador',
        format(
          '%s confirmó su comprobante de pago.',
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

drop trigger if exists trg_mc_notify_tr_pago_y_factura on public.transaction_requests;

create trigger trg_mc_notify_tr_pago_y_factura
after update on public.transaction_requests
for each row
execute function public.mc_notify_tr_pago_y_factura ();
