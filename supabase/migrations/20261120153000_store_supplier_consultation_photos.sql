-- Photos belong to a private, participant-only conversation, never to a public catalogue.
alter table public.store_supplier_messages
  add column if not exists attachments jsonb not null default '[]'::jsonb,
  add column if not exists consultation_model text;

create or replace function public.store_supplier_photos_ok(p jsonb, thread uuid, author uuid)
returns boolean language sql immutable set search_path = '' as $$
  select case when jsonb_typeof(p) <> 'array' then false else
    jsonb_array_length(p) <= 3 and not exists (
      select 1 from jsonb_array_elements(p) e
      where jsonb_typeof(e) <> 'object'
        or coalesce(e->>'kind','') <> 'image'
        or coalesce(e->>'mime','') not in ('image/jpeg','image/png','image/webp')
        or split_part(coalesce(e->>'path',''), '/', 1) <> thread::text
        or split_part(coalesce(e->>'path',''), '/', 2) <> author::text
        or coalesce(e->>'path','') like '%..%'
        or length(coalesce(e->>'path','')) > 512
    ) end;
$$;
alter table public.store_supplier_messages
  add constraint store_supplier_messages_photos_check
  check (public.store_supplier_photos_ok(attachments, thread_id, author_id)),
  add constraint store_supplier_messages_model_check
  check (consultation_model is null or char_length(consultation_model) <= 160);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('consultation-photos','consultation-photos',false,8388608,
  array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

create policy consultation_photos_read on storage.objects for select to authenticated
using (bucket_id='consultation-photos' and exists (
  select 1 from public.store_supplier_threads t
  where t.id::text=(storage.foldername(name))[1]
    and (t.aliado_id=(select auth.uid()) or t.importador_id=(select auth.uid()))));
create policy consultation_photos_insert on storage.objects for insert to authenticated
with check (bucket_id='consultation-photos'
  and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists (select 1 from public.store_supplier_threads t
    where t.id::text=(storage.foldername(name))[1]
      and (t.aliado_id=(select auth.uid()) or t.importador_id=(select auth.uid()))));
create policy consultation_photos_update on storage.objects for update to authenticated
using (bucket_id='consultation-photos' and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists (select 1 from public.store_supplier_threads t
    where t.id::text=(storage.foldername(name))[1]
      and (t.aliado_id=(select auth.uid()) or t.importador_id=(select auth.uid()))))
with check (bucket_id='consultation-photos' and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists (select 1 from public.store_supplier_threads t
    where t.id::text=(storage.foldername(name))[1]
      and (t.aliado_id=(select auth.uid()) or t.importador_id=(select auth.uid()))));
create policy consultation_photos_delete on storage.objects for delete to authenticated
using (bucket_id='consultation-photos' and (storage.foldername(name))[2]=(select auth.uid())::text
  and exists (select 1 from public.store_supplier_threads t
    where t.id::text=(storage.foldername(name))[1]
      and (t.aliado_id=(select auth.uid()) or t.importador_id=(select auth.uid()))));
notify pgrst, 'reload schema';
