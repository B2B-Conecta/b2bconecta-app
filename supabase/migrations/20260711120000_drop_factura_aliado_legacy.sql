-- Elimina facturación legada MotoLink admin→aliado (factura_aliado_*, emisiones PDF).

-- ---------------------------------------------------------------------------
-- 1) RPCs de emisión MotoLink al aliado (si existen en remoto)
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'admin_prepare_motolink_ally_document_emission',
        'admin_finalize_motolink_ally_document_emission'
      )
  loop
    execute format('drop function if exists %s cascade', r.sig);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Tabla de emisiones fragmentadas (nota / factura MotoLink)
-- ---------------------------------------------------------------------------
drop table if exists public.motolink_ally_document_emissions cascade;

-- ---------------------------------------------------------------------------
-- 3) Columnas legadas en transaction_requests
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  drop column if exists factura_aliado_storage_path,
  drop column if exists factura_aliado_file_name,
  drop column if exists factura_aliado_submitted_at,
  drop column if exists motolink_pending_auto_invoice;

-- ---------------------------------------------------------------------------
-- 4) Bucket Storage `order-ally-invoices` (legado)
-- Supabase no permite DELETE directo en storage.objects / storage.buckets
-- desde SQL migraciones. Si el bucket existe, vacíelo y bórrelo en:
-- Dashboard → Storage → order-ally-invoices → Empty bucket → Delete bucket
-- ---------------------------------------------------------------------------

comment on column public.transaction_requests.proveedor_factura_storage_path is
  'Factura del importador al aliado (bucket order-invoices).';
