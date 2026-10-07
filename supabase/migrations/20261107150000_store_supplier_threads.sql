-- Conversación general tienda ↔ proveedor, sin pedido.
-- No usa transaction_request_messages. El chat de pedidos no cambia.
-- Solo la tienda autenticada puede abrir el hilo con el proveedor de la vitrina.
-- El proveedor responde en ese mismo hilo. Un tercero no lee ni escribe.

create table if not exists public.store_supplier_threads (
  id uuid primary key default gen_random_uuid(),
  aliado_id uuid not null references public.profiles (id) on delete cascade,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint store_supplier_threads_pair_unique unique (aliado_id, importador_id),
  constraint store_supplier_threads_distinct check (aliado_id <> importador_id)
);

create index if not exists store_supplier_threads_importador_idx
  on public.store_supplier_threads (importador_id);

create table if not exists public.store_supplier_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.store_supplier_threads (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_role text not null check (author_role in ('aliado', 'importador')),
  body text not null check (char_length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists store_supplier_messages_thread_idx
  on public.store_supplier_messages (thread_id, created_at);

comment on table public.store_supplier_threads is
  'Hilo general aliado-importador, independiente de los pedidos.';

alter table public.store_supplier_threads enable row level security;
alter table public.store_supplier_messages enable row level security;

create or replace function public.open_store_supplier_thread (p_importador_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_target_role text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'No hay sesión';
  end if;

  select p.role into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'aliado' then
    raise exception 'Solo la tienda puede iniciar esta conversación';
  end if;

  if p_importador_id is null or p_importador_id = v_uid then
    raise exception 'Proveedor inválido';
  end if;

  select p.role into v_target_role
  from public.profiles p
  where p.id = p_importador_id;

  if v_target_role is distinct from 'importador' then
    raise exception 'Ese usuario no es un proveedor';
  end if;

  insert into public.store_supplier_threads (aliado_id, importador_id)
  values (v_uid, p_importador_id)
  on conflict (aliado_id, importador_id) do nothing;

  select t.id into v_id
  from public.store_supplier_threads t
  where t.aliado_id = v_uid
    and t.importador_id = p_importador_id;

  return v_id;
end;
$$;

revoke all on function public.open_store_supplier_thread (uuid) from public;
grant execute on function public.open_store_supplier_thread (uuid) to authenticated;

create or replace function public.mc_notify_store_supplier_message ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
begin
  select t.aliado_id, t.importador_id
    into v_aliado, v_imp
  from public.store_supplier_threads t
  where t.id = new.thread_id;

  if new.author_role = 'aliado' and v_imp is not null then
    perform public.mc_insert_notification(
      v_imp,
      'Nuevo mensaje',
      'Una tienda te escribió sobre tu catálogo.',
      'mensaje_directo',
      new.thread_id::text
    );
  elsif new.author_role = 'importador' and v_aliado is not null then
    perform public.mc_insert_notification(
      v_aliado,
      'Nuevo mensaje del proveedor',
      'El proveedor respondió en la conversación de su catálogo.',
      'mensaje_directo',
      new.thread_id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_mc_notify_store_supplier_message
  on public.store_supplier_messages;

create trigger trg_mc_notify_store_supplier_message
after insert on public.store_supplier_messages
for each row
execute function public.mc_notify_store_supplier_message ();

drop policy if exists store_supplier_threads_select on public.store_supplier_threads;
create policy store_supplier_threads_select
  on public.store_supplier_threads
  for select
  to authenticated
  using (aliado_id = auth.uid() or importador_id = auth.uid());

drop policy if exists store_supplier_messages_select on public.store_supplier_messages;
create policy store_supplier_messages_select
  on public.store_supplier_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.store_supplier_threads t
      where t.id = thread_id
        and (t.aliado_id = auth.uid() or t.importador_id = auth.uid())
    )
  );

drop policy if exists store_supplier_messages_insert on public.store_supplier_messages;
create policy store_supplier_messages_insert
  on public.store_supplier_messages
  for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1
      from public.store_supplier_threads t
      where t.id = thread_id
        and (
          (t.aliado_id = auth.uid() and author_role = 'aliado')
          or (t.importador_id = auth.uid() and author_role = 'importador')
        )
    )
  );

grant select on public.store_supplier_threads to authenticated;
grant select, insert on public.store_supplier_messages to authenticated;
grant all on public.store_supplier_threads to service_role;
grant all on public.store_supplier_messages to service_role;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'store_supplier_messages'
  ) then
    alter publication supabase_realtime add table public.store_supplier_messages;
  end if;
end;
$$;
