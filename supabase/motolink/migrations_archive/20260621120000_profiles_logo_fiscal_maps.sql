-- Logo opcional (Storage `profile-logos`) y enlace Maps opcional para la ubicación fiscal.

alter table public.profiles
  add column if not exists logo_storage_path text,
  add column if not exists fiscal_maps_url text;

comment on column public.profiles.logo_storage_path is
  'Ruta en bucket profile-logos (privado), p. ej. {user_id}/logo.png.';
comment on column public.profiles.fiscal_maps_url is
  'Enlace público (p. ej. Google Maps) a la ubicación fiscal; opcional.';

insert into storage.buckets (id, name, public)
values ('profile-logos', 'profile-logos', false)
on conflict (id) do nothing;

drop policy if exists "profile_logos_select_own" on storage.objects;
create policy "profile_logos_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "profile_logos_insert_own" on storage.objects;
create policy "profile_logos_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "profile_logos_update_own" on storage.objects;
create policy "profile_logos_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "profile_logos_delete_own" on storage.objects;
create policy "profile_logos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-logos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
