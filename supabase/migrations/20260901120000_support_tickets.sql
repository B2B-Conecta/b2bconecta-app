-- Atención al cliente: reclamos aliado/importador ↔ administradores MotoLink.

create table if not exists public.support_tickets (
  id uuid not null default gen_random_uuid () primary key,
  created_by uuid not null references public.profiles (id) on delete cascade,
  author_role text not null
    check (author_role = any (array['aliado'::text, 'importador'::text])),
  subject text not null,
  category text not null default 'otro'
    check (
      category = any (
        array[
          'cuenta'::text,
          'pedido'::text,
          'pago'::text,
          'kyc'::text,
          'plataforma'::text,
          'otro'::text
        ]
      )
    ),
  status text not null default 'abierto'
    check (status = any (array['abierto'::text, 'en_revision'::text, 'cerrado'::text])),
  related_transaction_request_id uuid
    references public.transaction_requests (id) on delete set null,
  closed_by uuid references public.profiles (id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_tickets_subject_len_chk check (char_length(trim(subject)) >= 3),
  constraint support_tickets_closed_consistency_chk check (
    (status = 'cerrado' and closed_at is not null and closed_by is not null)
    or (status <> 'cerrado' and closed_at is null and closed_by is null)
  )
);

create index if not exists support_tickets_created_by_status_idx
  on public.support_tickets (created_by, status, created_at desc);

create index if not exists support_tickets_status_created_idx
  on public.support_tickets (status, created_at desc);

comment on table public.support_tickets is
  'Reclamos de atención al cliente (aliado/importador → MotoLink). Máx. 3 abiertos por usuario.';

create table if not exists public.support_ticket_messages (
  id uuid not null default gen_random_uuid () primary key,
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_role text not null
    check (
      author_role = any (
        array['aliado'::text, 'importador'::text, 'administrador'::text]
      )
    ),
  body text not null,
  created_at timestamptz not null default now(),
  constraint support_ticket_messages_body_len_chk check (char_length(trim(body)) >= 1)
);

create index if not exists support_ticket_messages_ticket_created_idx
  on public.support_ticket_messages (ticket_id, created_at asc);

-- updated_at
create or replace function public.support_tickets_set_updated_at ()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row
execute function public.support_tickets_set_updated_at ();

-- Notificaciones (bypass RLS como otros triggers del proyecto)
create or replace function public.mc_notify_support_ticket_message_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
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

  select coalesce(nullif(trim(p.business_name), ''), nullif(trim(p.email), ''), 'Usuario')
    into v_creator_name
  from public.profiles p
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

drop trigger if exists support_ticket_messages_notify_insert
  on public.support_ticket_messages;
create trigger support_ticket_messages_notify_insert
after insert on public.support_ticket_messages
for each row
execute function public.mc_notify_support_ticket_message_insert ();

-- Crear ticket + primer mensaje (máx. 3 abiertos)
create or replace function public.create_support_ticket (
  p_subject text,
  p_category text,
  p_body text,
  p_related_transaction_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_open_count integer;
  v_ticket_id uuid;
  v_subject text := trim(p_subject);
  v_body text := trim(p_body);
  v_category text := trim(coalesce(p_category, 'otro'));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role not in ('aliado', 'importador') then
    raise exception 'Solo aliados e importadores pueden abrir reclamos.';
  end if;

  if char_length(v_subject) < 3 then
    raise exception 'El asunto debe tener al menos 3 caracteres.';
  end if;

  if char_length(v_body) < 3 then
    raise exception 'El mensaje debe tener al menos 3 caracteres.';
  end if;

  if v_category not in ('cuenta', 'pedido', 'pago', 'kyc', 'plataforma', 'otro') then
    raise exception 'Categoría no válida.';
  end if;

  select count(*)::integer
    into v_open_count
  from public.support_tickets st
  where st.created_by = v_uid
    and st.status <> 'cerrado';

  if v_open_count >= 3 then
    raise exception
      'Ya tiene 3 reclamos abiertos. Cierre uno antes de abrir otro.';
  end if;

  if p_related_transaction_request_id is not null then
    if not exists (
      select 1
      from public.transaction_requests tr
      where tr.id = p_related_transaction_request_id
        and (
          tr.aliado_id = v_uid
          or tr.importador_id = v_uid
        )
    ) then
      raise exception 'El pedido vinculado no pertenece a su cuenta.';
    end if;
  end if;

  insert into public.support_tickets (
    created_by,
    author_role,
    subject,
    category,
    status,
    related_transaction_request_id
  )
  values (
    v_uid,
    v_role,
    v_subject,
    v_category,
    'abierto',
    p_related_transaction_request_id
  )
  returning id into v_ticket_id;

  insert into public.support_ticket_messages (
    ticket_id,
    author_id,
    author_role,
    body
  )
  values (
    v_ticket_id,
    v_uid,
    v_role,
    v_body
  );

  return v_ticket_id;
end;
$$;

-- Cerrar ticket (creador o administrador)
create or replace function public.close_support_ticket (p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_is_admin boolean;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'administrador'::text
  )
    into v_is_admin;

  update public.support_tickets st
  set
    status = 'cerrado',
    closed_by = v_uid,
    closed_at = now()
  where st.id = p_ticket_id
    and st.status <> 'cerrado'
    and (
      st.created_by = v_uid
      or v_is_admin
    );

  if not found then
    raise exception 'No se pudo cerrar el reclamo (no existe, ya está cerrado o sin permiso).';
  end if;
end;
$$;

-- Responder y pasar a en_revision (admin)
create or replace function public.admin_reply_support_ticket (
  p_ticket_id uuid,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_body text := trim(p_body);
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_uid
      and p.role = 'administrador'::text
  ) then
    raise exception 'Solo administradores pueden usar esta acción.';
  end if;

  if char_length(v_body) < 1 then
    raise exception 'El mensaje no puede estar vacío.';
  end if;

  if not exists (
    select 1
    from public.support_tickets st
    where st.id = p_ticket_id
      and st.status <> 'cerrado'
  ) then
    raise exception 'El reclamo no existe o ya está cerrado.';
  end if;

  insert into public.support_ticket_messages (
    ticket_id,
    author_id,
    author_role,
    body
  )
  values (
    p_ticket_id,
    v_uid,
    'administrador',
    v_body
  );

  update public.support_tickets
  set status = 'en_revision'
  where id = p_ticket_id
    and status = 'abierto';
end;
$$;

-- Respuesta del usuario (creador del ticket)
create or replace function public.reply_support_ticket_as_owner (
  p_ticket_id uuid,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_body text := trim(p_body);
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role not in ('aliado', 'importador') then
    raise exception 'Solo aliados e importadores pueden responder aquí.';
  end if;

  if char_length(v_body) < 1 then
    raise exception 'El mensaje no puede estar vacío.';
  end if;

  if not exists (
    select 1
    from public.support_tickets st
    where st.id = p_ticket_id
      and st.created_by = v_uid
      and st.status <> 'cerrado'
  ) then
    raise exception 'El reclamo no existe, está cerrado o no es suyo.';
  end if;

  insert into public.support_ticket_messages (
    ticket_id,
    author_id,
    author_role,
    body
  )
  values (
    p_ticket_id,
    v_uid,
    v_role,
    v_body
  );
end;
$$;

-- RLS
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;

drop policy if exists support_tickets_select_participant on public.support_tickets;
create policy support_tickets_select_participant
on public.support_tickets
for select
to authenticated
using (
  created_by = auth.uid ()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists support_ticket_messages_select_participant
  on public.support_ticket_messages;
create policy support_ticket_messages_select_participant
on public.support_ticket_messages
for select
to authenticated
using (
  exists (
    select 1
    from public.support_tickets st
    where st.id = support_ticket_messages.ticket_id
      and (
        st.created_by = auth.uid ()
        or exists (
          select 1
          from public.profiles p
          where p.id = auth.uid ()
            and p.role = 'administrador'::text
        )
      )
  )
);

grant select on public.support_tickets to authenticated;
grant select on public.support_ticket_messages to authenticated;
grant execute on function public.create_support_ticket (text, text, text, uuid) to authenticated;
grant execute on function public.close_support_ticket (uuid) to authenticated;
grant execute on function public.admin_reply_support_ticket (uuid, text) to authenticated;
grant execute on function public.reply_support_ticket_as_owner (uuid, text) to authenticated;

grant all on public.support_tickets to service_role;
grant all on public.support_ticket_messages to service_role;

-- Realtime (opcional; la app puede suscribirse)
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    alter publication supabase_realtime add table public.support_ticket_messages;
  end if;
exception
  when duplicate_object then
    null;
end;
$$;
