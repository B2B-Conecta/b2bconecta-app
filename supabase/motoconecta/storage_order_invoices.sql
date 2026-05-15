-- Bucket + RLS para facturas de pedido (`order-invoices`).
-- MotoConecta: rutas `{transaction_request_id}/{archivo}`; importador sube; aliado y admin leen.
-- Errores típicos sin esto: StorageException «Bucket not found», o 403 al subir.
--
-- Ejecutar en SQL Editor. Si tu `transaction_requests` tiene columna `owner_id` (MotoLink legacy),
-- añade manualmente `or tr.owner_id = auth.uid()` en las condiciones equivalentes.

insert into storage.buckets (id, name, public)
values ('order-invoices', 'order-invoices', false)
on conflict (id) do nothing;

drop policy if exists "order_inv_select_participants" on storage.objects;
create policy "order_inv_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
);

drop policy if exists "order_inv_insert_owner" on storage.objects;
create policy "order_inv_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_update_owner" on storage.objects;
create policy "order_inv_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
)
with check (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);

drop policy if exists "order_inv_delete_owner" on storage.objects;
create policy "order_inv_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-invoices'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.importador_id = auth.uid ()
  )
);
