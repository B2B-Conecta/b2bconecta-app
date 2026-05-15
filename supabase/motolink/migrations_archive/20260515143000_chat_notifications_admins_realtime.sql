-- Chat aliado ↔ MotoLink: notificar a todos los admins cuando escribe un aliado;
-- unificar related_id como texto; Realtime en mensajes para la app.

create or replace function public.notify_transaction_request_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_owner uuid;
  v_rid text;
begin
  v_rid := new.transaction_request_id::text;

  select tr.aliado_id, tr.owner_id
    into v_aliado, v_owner
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' then
    if v_owner is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_owner,
        'Nuevo mensaje de aliado',
        'Tiene un nuevo mensaje en un pedido asignado.',
        'mensaje',
        v_rid
      );
    end if;
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
    if v_owner is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_owner,
        'Nuevo mensaje de MotoLink',
        'MotoLink dejó un mensaje en un pedido de su inventario.',
        'mensaje',
        v_rid
      );
    end if;
  end if;

  return new;
end;
$$;

do $$
begin
  begin
    alter publication supabase_realtime add table public.transaction_request_messages;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;
