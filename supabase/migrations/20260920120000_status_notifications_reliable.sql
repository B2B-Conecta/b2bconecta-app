-- Notificaciones de estado: sin depender de la fila ancla (evita perder avisos en carritos)
-- y deduplicación breve cuando el importador actualiza varias líneas seguidas.

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

    if not exists (
      select 1
      from public.notifications n
      where n.user_id = new.aliado_id
        and n.type = 'pedido'
        and n.related_id = v_anchor
        and n.title = v_title
        and n.created_at > now () - interval '3 minutes'
    ) then
      perform public.mc_insert_notification (
        new.aliado_id,
        v_title,
        v_body,
        'pedido',
        v_anchor
      );
    end if;

  elsif new.status = 'entregado'::text then
    v_title := 'Pedido recibido';
    v_body := format(
      'El aliado confirmó la recepción de %s en su taller.',
      v_product
    );

    if not exists (
      select 1
      from public.notifications n
      where n.user_id = new.importador_id
        and n.type = 'pedido'
        and n.related_id = v_anchor
        and n.title = v_title
        and n.created_at > now () - interval '3 minutes'
    ) then
      perform public.mc_insert_notification (
        new.importador_id,
        v_title,
        v_body,
        'pedido',
        v_anchor
      );
    end if;

  elsif new.status = 'rechazado'::text then
    v_title := 'Pedido rechazado';
    v_body := format(
      'Su solicitud de %s fue rechazada. Revísela en Pedidos.',
      v_product
    );

    if not exists (
      select 1
      from public.notifications n
      where n.user_id = new.aliado_id
        and n.type = 'pedido'
        and n.related_id = v_anchor
        and n.title = v_title
        and n.created_at > now () - interval '3 minutes'
    ) then
      perform public.mc_insert_notification (
        new.aliado_id,
        v_title,
        v_body,
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
