-- Storage API (p.ej. v1.68.1) ejecuta UpsertObject con:
--   ON CONFLICT (name, bucket_id) DO UPDATE ...
-- aunque el cliente envíe x-upsert: false.
-- Los uniques parciales de versionado no sirven como target → 42P10.

do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage.objects no existe; se omite el índice.';
    return;
  end if;

  if exists (
    select 1
    from pg_indexes
    where schemaname = 'storage'
      and tablename = 'objects'
      and indexname = 'objects_name_bucket_id_unique'
  ) then
    return;
  end if;

  -- Migraciones corren como postgres; el owner de storage.objects es
  -- supabase_storage_admin.
  begin
    execute 'grant supabase_storage_admin to current_user';
  exception
    when insufficient_privilege then null;
    when undefined_object then null;
    when duplicate_object then null;
  end;

  begin
    execute 'set local role supabase_storage_admin';
  exception
    when insufficient_privilege then
      raise notice
        'No se pudo asumir supabase_storage_admin; '
        'cree objects_name_bucket_id_unique como ese rol.';
      return;
  end;

  execute $sql$
    create unique index objects_name_bucket_id_unique
      on storage.objects (name collate "C", bucket_id)
  $sql$;
end $$;
