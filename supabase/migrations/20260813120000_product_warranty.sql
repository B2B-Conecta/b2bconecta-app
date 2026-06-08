-- Garantía por producto (importador habilita; aliado ve sello en catálogo).

alter table public.products
  add column if not exists has_warranty boolean not null default false;

comment on column public.products.has_warranty is
  'Si true, el aliado ve sello de garantía en catálogo y detalle del producto.';
