-- El trigger AFTER UPDATE OF status no disparaba en todos los casos (p. ej. cuando
-- otros triggers BEFORE modifican columnas en el mismo UPDATE). Usar AFTER UPDATE
-- y filtrar cambio de status dentro de la función.

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
  v_target uuid;
begin
  perform set_config ('row_security', 'off', true);

  if tg_op <> 'UPDATE' then
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
    v_target := new.aliado_id;
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

  elsif new.status = 'entregado'::text then
    v_target := new.importador_id;
    v_title := 'Pedido recibido';
    v_body := format(
      'El aliado confirmó la recepción de %s en su taller.',
      v_product
    );

  elsif new.status = 'rechazado'::text then
    v_target := new.aliado_id;
    v_title := 'Pedido rechazado';
    v_body := format(
      'Su solicitud de %s fue rechazada. Revísela en Pedidos.',
      v_product
    );

  else
    return new;
  end if;

  if v_target is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.notifications n
    where n.user_id = v_target
      and n.type = 'pedido'
      and n.related_id = v_anchor
      and n.title = v_title
      and n.created_at > now () - interval '3 minutes'
  ) then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_target,
      v_title,
      coalesce(nullif(trim(v_body), ''), v_title),
      'pedido',
      v_anchor
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_mc_notify_tr_status on public.transaction_requests;

create trigger trg_mc_notify_tr_status
after update on public.transaction_requests
for each row
execute function public.mc_notify_tr_status_changed ();
