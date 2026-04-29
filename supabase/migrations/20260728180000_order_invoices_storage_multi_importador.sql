-- Storage RLS (order-invoices): soportar rutas de sub-pedido en maestros multi-importador.
-- Formato nuevo: {request_id}/sub_{sub_order_id}/{archivo}
-- Formato legacy: {request_id}/{archivo}

drop policy if exists "order_inv_select_participants" on storage.objects;
create policy "order_inv_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    -- Participantes legacy (aliado/importador owner) o administrador.
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid() or tr.owner_id = auth.uid())
    )
    -- Importador participante de sub_order (maestro multi-importador).
    or exists (
      select 1
      from public.sub_orders so
      where so.parent_order_id::text = (storage.foldername(name))[1]
        and ('sub_' || so.id::text) = (storage.foldername(name))[2]
        and so.importador_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
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
  and (
    -- Legacy: importador owner del pedido simple.
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.owner_id = auth.uid()
    )
    -- Maestro: importador dueño del sub-pedido asociado en la ruta.
    or exists (
      select 1
      from public.sub_orders so
      where so.parent_order_id::text = (storage.foldername(name))[1]
        and ('sub_' || so.id::text) = (storage.foldername(name))[2]
        and so.importador_id = auth.uid()
    )
  )
);

drop policy if exists "order_inv_delete_owner" on storage.objects;
create policy "order_inv_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    -- Legacy
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.owner_id = auth.uid()
    )
    -- Maestro
    or exists (
      select 1
      from public.sub_orders so
      where so.parent_order_id::text = (storage.foldername(name))[1]
        and ('sub_' || so.id::text) = (storage.foldername(name))[2]
        and so.importador_id = auth.uid()
    )
  )
);
