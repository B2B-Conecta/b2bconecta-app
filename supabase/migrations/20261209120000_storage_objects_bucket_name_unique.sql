-- Storage upsert (ON CONFLICT) necesita unique (bucket_id, name).
-- Sin este índice, upload con upsert:true responde 42P10.
do $$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage.objects no existe; se omite el índice.';
    return;
  end if;

  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'storage'
      and tablename = 'objects'
      and indexdef ilike '%UNIQUE%'
      and indexdef ilike '%bucket_id%'
      and indexdef ilike '%name%'
  ) then
    create unique index objects_bucket_id_name_idx
      on storage.objects (bucket_id, name);
  end if;
exception
  when insufficient_privilege then
    raise notice
      'Sin privilegio para crear índice en storage.objects; '
      'use upload sin upsert o revise el schema de Storage.';
  when duplicate_table then
    null;
  when duplicate_object then
    null;
end $$;
