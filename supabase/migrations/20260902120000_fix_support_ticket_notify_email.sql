-- Fix: profiles no tiene columna email; usar business_name o auth.users.

create or replace function public.mc_notify_support_ticket_message_insert ()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_creator_name text;
begin
  perform set_config ('row_security', 'off', true);

  select *
    into v_ticket
  from public.support_tickets st
  where st.id = new.ticket_id;

  if not found then
    return new;
  end if;

  select coalesce(
    nullif(trim(p.business_name), ''),
    nullif(trim(u.email), ''),
    'Usuario'
  )
    into v_creator_name
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.id = v_ticket.created_by;

  if new.author_role in ('aliado', 'importador') then
    insert into public.notifications (user_id, title, body, type, related_id)
    select
      p.id,
      'Nuevo reclamo de soporte',
      v_creator_name || ': ' || left(trim(v_ticket.subject), 80),
      'soporte',
      v_ticket.id::text
    from public.profiles p
    where p.role = 'administrador'::text;
  elsif new.author_role = 'administrador' and v_ticket.status <> 'cerrado' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_ticket.created_by,
      'Respuesta de soporte',
      'MotoLink respondió su reclamo «' || left(trim(v_ticket.subject), 60) || '».',
      'soporte',
      v_ticket.id::text
    );
  end if;

  return new;
end;
$$;
