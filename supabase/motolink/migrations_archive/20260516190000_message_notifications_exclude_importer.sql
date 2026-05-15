-- El hilo MotoLink ↔ aliado no está disponible para el importador: no enviarle notificaciones de ese chat.

create or replace function public.notify_transaction_request_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_rid text;
begin
  v_rid := new.transaction_request_id::text;

  select tr.aliado_id
    into v_aliado
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' then
    perform public.notify_to_all_admins(
      'Nuevo mensaje de aliado',
      'Un aliado escribió en el chat de un pedido activo.',
      'mensaje',
      v_rid
    );
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje de MotoLink',
      'MotoLink dejó un mensaje en su pedido.',
      'mensaje',
      v_rid
    );
  end if;

  return new;
end;
$$;
