-- Buckets usados por la app Flutter pero ausentes en migraciones previas.
-- profile-logos: logos B2B (privado, signed URL)
-- product-images: fotos de catálogo (público, getPublicUrl)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-logos',
  'profile-logos',
  false,
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

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  10485760,
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

-- profile-logos: path = {auth.uid()}/logo_*.ext
drop policy if exists profile_logos_storage_select on storage.objects;
create policy profile_logos_storage_select
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-logos');

drop policy if exists profile_logos_storage_insert on storage.objects;
create policy profile_logos_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-logos'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

drop policy if exists profile_logos_storage_update on storage.objects;
create policy profile_logos_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-logos'
  and (storage.foldername (name))[1] = auth.uid ()::text
)
with check (
  bucket_id = 'profile-logos'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

drop policy if exists profile_logos_storage_delete on storage.objects;
create policy profile_logos_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-logos'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

-- product-images: path = {auth.uid()}/{productId|nuevo}/...
drop policy if exists product_images_storage_select on storage.objects;
create policy product_images_storage_select
on storage.objects
for select
to authenticated
using (bucket_id = 'product-images');

drop policy if exists product_images_storage_insert on storage.objects;
create policy product_images_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

drop policy if exists product_images_storage_update on storage.objects;
create policy product_images_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername (name))[1] = auth.uid ()::text
)
with check (
  bucket_id = 'product-images'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

drop policy if exists product_images_storage_delete on storage.objects;
create policy product_images_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername (name))[1] = auth.uid ()::text
);
