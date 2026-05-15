-- Ubicación B2B (estado + ciudad) para filtros de catálogo y reglas de negocio en app.

alter table public.profiles
  add column if not exists estado text,
  add column if not exists ciudad text;

create index if not exists profiles_importador_ubicacion_idx
  on public.profiles (estado, ciudad)
  where role = 'importador';
