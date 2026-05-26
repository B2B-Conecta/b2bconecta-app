-- Asegura bucket promo-campaigns (creativos E1.2) y políticas de Storage en remoto.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'promo-campaigns',
  'promo-campaigns',
  true,
  5242880,
  array[
    'image/jpeg'::text,
    'image/png'::text,
    'image/webp'::text
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists promo_campaigns_storage_admin_insert on storage.objects;
create policy promo_campaigns_storage_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_storage_admin_update on storage.objects;
create policy promo_campaigns_storage_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
)
with check (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_storage_admin_delete on storage.objects;
create policy promo_campaigns_storage_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

-- Lectura autenticada (preview admin); URLs públicas no requieren policy.
drop policy if exists promo_campaigns_storage_select_public on storage.objects;
create policy promo_campaigns_storage_select_public
on storage.objects
for select
to authenticated
using (bucket_id = 'promo-campaigns');
