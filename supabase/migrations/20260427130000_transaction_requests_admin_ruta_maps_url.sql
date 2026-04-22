-- Enlace de ruta en Google Maps definido por MotoLink (visible a aliado/importador en tránsito).

alter table public.transaction_requests
  add column if not exists admin_ruta_maps_url text;

comment on column public.transaction_requests.admin_ruta_maps_url is
  'URL de Google Maps (direcciones / ruta) publicada por MotoLink para aliado e importador en tránsito.';
