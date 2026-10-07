-- Adjuntos de chat del pedido (foto o video) en la misma fila del mensaje.
-- El texto sigue en `body`. Un mensaje viejo no tiene adjuntos (`[]`).
-- Un mensaje puede ir sin texto solo si trae al menos un archivo.
-- Bucket privado: solo aliado, importador o administrador de ese pedido.

alter table public.transaction_request_messages
  add column if not exists attachments jsonb not null default '[]'::jsonb;

comment on column public.transaction_request_messages.attachments is
  'Adjuntos del mensaje. Cada elemento: path, kind (image|video), mime, name. '
  'Hasta 3 fotos o 1 video. Ruta en el bucket order-message-attachments.';

create or replace function public.order_message_attachments_ok (p jsonb)
returns boolean
language sql
immutable
as $$
  select
    jsonb_typeof(p) = 'array'
    and jsonb_array_length(p) <= 3
    and not exists (
      select 1
      from jsonb_array_elements(p) e
      where jsonb_typeof(e) <> 'object'
        or coalesce(e ->> 'kind', '') not in ('image', 'video')
        or length(trim(coalesce(e ->> 'path', ''))) = 0
        or position('..' in coalesce(e ->> 'path', '')) > 0
    )
    and (
      jsonb_array_length(p) = 0
      or not exists (
        select 1
        from jsonb_array_elements(p) e
        where e ->> 'kind' = 'video'
      )
      or (
        jsonb_array_length(p) = 1
        and p -> 0 ->> 'kind' = 'video'
      )
    );
$$;

do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'transaction_request_messages'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%trim(body)%'
  loop
    execute format(
      'alter table public.transaction_request_messages drop constraint %I',
      r.conname
    );
  end loop;
end $$;

alter table public.transaction_request_messages
  drop constraint if exists transaction_request_messages_body_check;

alter table public.transaction_request_messages
  add constraint transaction_request_messages_body_check
  check (
    char_length(trim(body)) > 0
    or (
      jsonb_typeof(attachments) = 'array'
      and jsonb_array_length(attachments) > 0
    )
  );

alter table public.transaction_request_messages
  drop constraint if exists transaction_request_messages_attachments_check;

alter table public.transaction_request_messages
  add constraint transaction_request_messages_attachments_check
  check (public.order_message_attachments_ok(attachments));

-- Storage privado. El primer segmento de la ruta es el id del pedido.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'order-message-attachments',
  'order-message-attachments',
  false,
  52428800,
  array[
    'image/jpeg'::text,
    'image/png'::text,
    'image/webp'::text,
    'video/mp4'::text,
    'video/quicktime'::text
  ]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.order_message_attachment_puede_acceder (object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transaction_requests tr
    where tr.id::text = (storage.foldername(object_name))[1]
      and (
        tr.aliado_id = auth.uid()
        or tr.importador_id = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.id = auth.uid()
            and p.role = 'administrador'
        )
      )
  );
$$;

revoke all on function public.order_message_attachment_puede_acceder (text) from public;
grant execute on function public.order_message_attachment_puede_acceder (text) to authenticated;

drop policy if exists order_msg_attach_select on storage.objects;
create policy order_msg_attach_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-message-attachments'
  and public.order_message_attachment_puede_acceder(name)
);

drop policy if exists order_msg_attach_insert on storage.objects;
create policy order_msg_attach_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-message-attachments'
  and public.order_message_attachment_puede_acceder(name)
);

drop policy if exists order_msg_attach_update on storage.objects;
create policy order_msg_attach_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-message-attachments'
  and public.order_message_attachment_puede_acceder(name)
)
with check (
  bucket_id = 'order-message-attachments'
  and public.order_message_attachment_puede_acceder(name)
);

drop policy if exists order_msg_attach_delete on storage.objects;
create policy order_msg_attach_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-message-attachments'
  and public.order_message_attachment_puede_acceder(name)
);
