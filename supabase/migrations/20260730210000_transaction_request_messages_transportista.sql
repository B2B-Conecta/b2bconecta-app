-- Chat del pedido: transportista asignado lee y escribe junto con aliado y MotoLink.

alter table public.transaction_request_messages
  drop constraint if exists trm_author_role_check;

alter table public.transaction_request_messages
  add constraint trm_author_role_check
  check (author_role in ('aliado', 'administrador', 'transportista'));

drop policy if exists "trm_select_participants" on public.transaction_request_messages;
create policy "trm_select_participants"
on public.transaction_request_messages
for select
to authenticated
using (
  exists (
    select 1 from public.transaction_requests tr
    where tr.id = transaction_request_messages.transaction_request_id
      and (
        tr.aliado_id = auth.uid()
        or tr.owner_id = auth.uid()
        or tr.assigned_transportista_id = auth.uid()
      )
  )
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

drop policy if exists "trm_insert_transportista" on public.transaction_request_messages;
create policy "trm_insert_transportista"
on public.transaction_request_messages
for insert
to authenticated
with check (
  author_id = auth.uid()
  and author_role = 'transportista'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  )
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id = transaction_request_messages.transaction_request_id
      and tr.assigned_transportista_id = auth.uid()
  )
);

create or replace function public.notify_transaction_request_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_transportista uuid;
  v_rid text;
begin
  v_rid := new.transaction_request_id::text;

  select tr.aliado_id, tr.assigned_transportista_id
    into v_aliado, v_transportista
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
    if v_transportista is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_transportista,
        'Nuevo mensaje del aliado',
        'El aliado escribió en el chat de un pedido que tiene asignado. Abra Despacho para ver.',
        'mensaje',
        v_rid
      );
    end if;
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje de MotoLink',
      'MotoLink dejó un mensaje en su pedido.',
      'mensaje',
      v_rid
    );
    if v_transportista is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_transportista,
        'Nuevo mensaje de MotoLink',
        'MotoLink escribió en el chat del pedido asignado. Revise en Despacho.',
        'mensaje',
        v_rid
      );
    end if;
  elsif new.author_role = 'transportista' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Mensaje del transportista',
      'El transportista de despacho escribió en el chat de su pedido.',
      'mensaje',
      v_rid
    );
    perform public.notify_to_all_admins(
      'Mensaje del transportista',
      'Un transportista escribió en el chat de un pedido.',
      'mensaje',
      v_rid
    );
  end if;

  return new;
end;
$$;
