-- Permite leer/escribir facturas en rutas legacy `bundle_{checkout_group_id}/…`
-- (nuevas subidas usan `{transaction_request_id}/…`).

create or replace function public.order_inv_storage_importador_puede_acceder (object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.transaction_requests tr
    where tr.importador_id = auth.uid ()
      and (
        tr.id::text = (storage.foldername(object_name))[1]
        or (
          (storage.foldername(object_name))[1] like 'bundle\_%'
          and tr.checkout_group_id::text = substring(
            (storage.foldername(object_name))[1]
            from 8
          )
        )
      )
  );
$$;

grant execute on function public.order_inv_storage_importador_puede_acceder (text)
  to authenticated;

drop policy if exists "order_inv_insert_owner" on storage.objects;
create policy "order_inv_insert_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-invoices'
  and public.order_inv_storage_importador_puede_acceder (name)
);

drop policy if exists "order_inv_update_owner" on storage.objects;
create policy "order_inv_update_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'order-invoices'
  and public.order_inv_storage_importador_puede_acceder (name)
)
with check (
  bucket_id = 'order-invoices'
  and public.order_inv_storage_importador_puede_acceder (name)
);

drop policy if exists "order_inv_delete_owner" on storage.objects;
create policy "order_inv_delete_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-invoices'
  and public.order_inv_storage_importador_puede_acceder (name)
);

drop policy if exists "order_inv_select_participants" on storage.objects;
create policy "order_inv_select_participants"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-invoices'
  and (
    exists (
      select 1
      from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1
      from public.transaction_requests tr
      where (storage.foldername(name))[1] like 'bundle\_%'
        and tr.checkout_group_id::text = substring((storage.foldername(name))[1] from 8)
        and (tr.aliado_id = auth.uid () or tr.importador_id = auth.uid ())
    )
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid () and p.role = 'administrador'
    )
  )
);
