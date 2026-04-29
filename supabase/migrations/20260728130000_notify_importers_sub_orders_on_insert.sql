-- Pedido maestro: owner_id es NULL; el trigger notify_new_transaction_request_insert
-- insertaba user_id = null → violación NOT NULL en notifications.
-- 1) Solo notificar al importador cuando hay owner_id (pedido legacy 1:1).
-- 2) Por cada sub_pedido, notificar al importador (user_id = importador_id)
--    con related_id = id del maestro (transaction_request padre).

create or replace function public.notify_new_transaction_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_master_order, false) = false
     and new.owner_id is not null
  then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.owner_id,
      'Nueva solicitud de pedido',
      'Un aliado creó una nueva solicitud sobre su inventario.',
      'envio',
      new.id::text
    );
  end if;

  perform public.notify_to_all_admins(
    'Nueva solicitud por validar',
    'Se creó una nueva solicitud de pedido pendiente de revisión.',
    'validacion',
    new.id::text
  );
  return new;
end;
$$;

create or replace function public.notify_sub_order_importer_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.importador_id is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Nueva solicitud de pedido',
      'Un aliado creó una nueva solicitud que incluye su inventario.',
      'envio',
      new.parent_order_id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_sub_order_importer_insert on public.sub_orders;
create trigger trg_notify_sub_order_importer_insert
  after insert on public.sub_orders
  for each row
  execute function public.notify_sub_order_importer_on_insert();

comment on function public.notify_sub_order_importer_on_insert() is
  'In-app: avisa a cada importador afectado por un pedido maestro; related_id = id del contenedor.';
