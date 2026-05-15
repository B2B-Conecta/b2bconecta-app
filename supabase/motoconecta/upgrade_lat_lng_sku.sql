-- Ejecutar en SQL Editor si ya tenías una base MotoConecta creada con un `schema.sql` antiguo.
-- Bases nuevas: aplicar `schema.sql` completo en lugar de este parche.

alter table public.profiles
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_updated_at timestamptz;

alter table public.products
  add column if not exists sku text not null default ''::text,
  add column if not exists description text,
  add column if not exists compatibility text,
  add column if not exists image_url text,
  add column if not exists category text;

-- Pedidos: FK opcional a producto (Flutter inserta `product_id` en MotoConecta).
alter table public.transaction_requests
  add column if not exists product_id uuid references public.products (id) on delete set null;

create index if not exists transaction_requests_product_idx
  on public.transaction_requests (product_id);

alter table public.transaction_requests
  add column if not exists proveedor_factura_storage_path text,
  add column if not exists proveedor_factura_file_name text,
  add column if not exists proveedor_factura_submitted_at timestamptz;
