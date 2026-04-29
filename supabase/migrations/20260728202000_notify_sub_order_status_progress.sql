-- Notificar a aliado y administradores cuando cada importador marca su sub-pedido
-- en `preparando` y `listo`, con avance X/Y para pedidos multi-importador.

create or replace function public.notify_sub_order_status_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_done int;
  v_total int;
  v_title text;
  v_body_aliado text;
  v_body_admin text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status not in ('preparando', 'listo') then
    return new;
  end if;

  select p.business_name
  into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select count(*)
  into v_total
  from public.sub_orders so
  where so.parent_order_id = new.parent_order_id;

  if new.status = 'preparando' then
    select count(*)
    into v_done
    from public.sub_orders so
    where so.parent_order_id = new.parent_order_id
      and so.status in ('preparando', 'listo', 'en_ruta', 'entregado');

    v_title := 'Importador en preparación';
    v_body_aliado := format(
      'El importador %s marcó su tramo en preparación (%s/%s).',
      coalesce(nullif(trim(v_imp_name), ''), 'sin nombre'),
      coalesce(v_done, 0),
      coalesce(v_total, 0)
    );
    v_body_admin := format(
      'Importador %s marcó en preparación su tramo (%s/%s) del pedido.',
      coalesce(nullif(trim(v_imp_name), ''), 'sin nombre'),
      coalesce(v_done, 0),
      coalesce(v_total, 0)
    );
  else
    select count(*)
    into v_done
    from public.sub_orders so
    where so.parent_order_id = new.parent_order_id
      and so.status in ('listo', 'en_ruta', 'entregado');

    v_title := 'Importador listo para despacho';
    v_body_aliado := format(
      'El importador %s dejó su tramo listo para recolección (%s/%s).',
      coalesce(nullif(trim(v_imp_name), ''), 'sin nombre'),
      coalesce(v_done, 0),
      coalesce(v_total, 0)
    );
    v_body_admin := format(
      'Importador %s dejó su tramo listo para despacho (%s/%s).',
      coalesce(nullif(trim(v_imp_name), ''), 'sin nombre'),
      coalesce(v_done, 0),
      coalesce(v_total, 0)
    );
  end if;

  if new.aliado_id is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (new.aliado_id, v_title, v_body_aliado, 'envio', new.parent_order_id::text);
  end if;

  perform public.notify_to_all_admins(
    v_title,
    v_body_admin,
    'envio',
    new.parent_order_id::text
  );

  return new;
end;
$$;

drop trigger if exists tr_notify_sub_order_status_progress on public.sub_orders;
create trigger tr_notify_sub_order_status_progress
after update on public.sub_orders
for each row
execute procedure public.notify_sub_order_status_progress();
