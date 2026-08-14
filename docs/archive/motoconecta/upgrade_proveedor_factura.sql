-- MotoConecta — factura del proveedor como adjunto (Storage).
-- Si PostgREST devuelve: column transaction_requests.proveedor_factura_storage_path does not exist
-- ejecuta este script en Supabase Dashboard → SQL Editor (proyecto en la nube o local).
-- Idempotente: usa IF NOT EXISTS.

alter table public.transaction_requests
  add column if not exists proveedor_factura_storage_path text,
  add column if not exists proveedor_factura_file_name text,
  add column if not exists proveedor_factura_submitted_at timestamptz;
