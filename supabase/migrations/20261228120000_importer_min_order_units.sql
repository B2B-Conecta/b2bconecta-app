-- Unidades mínimas por pedido de un proveedor.
-- NULL = la plataforma exige 5. Un número guardado reemplaza ese defecto.

alter table public.profiles
  add column if not exists min_order_units integer;

alter table public.profiles
  drop constraint if exists profiles_min_order_units_positive;

alter table public.profiles
  add constraint profiles_min_order_units_positive
  check (min_order_units is null or min_order_units >= 1);

comment on column public.profiles.min_order_units is
  'Unidades mínimas por pedido de este proveedor, sumando todos sus productos. NULL = 5 por defecto.';
