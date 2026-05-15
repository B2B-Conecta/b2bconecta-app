-- A5: coordenadas en perfiles (catálogo por proximidad) y actualización segura desde la app.

alter table public.profiles
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists location_updated_at timestamptz;

comment on column public.profiles.latitude is
  'Latitud WGS84 (GPS aliado o geocodificación fiscal importador/aliado) para ordenar catálogo por distancia.';
comment on column public.profiles.longitude is
  'Longitud WGS84; par con latitude.';
comment on column public.profiles.location_updated_at is
  'Última vez que se registraron latitude/longitude desde la app.';

-- Actualiza solo coordenadas del usuario autenticado (SECURITY DEFINER; no amplía UPDATE general en profiles).
create or replace function public.update_my_geolocation(
  p_latitude double precision,
  p_longitude double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;
  if p_latitude is null
    or p_longitude is null
    or p_latitude < -90
    or p_latitude > 90
    or p_longitude < -180
    or p_longitude > 180 then
    raise exception 'Coordenadas inválidas';
  end if;

  update public.profiles
  set
    latitude = p_latitude,
    longitude = p_longitude,
    location_updated_at = now()
  where id = auth.uid();
end;
$$;

grant execute on function public.update_my_geolocation(double precision, double precision)
  to authenticated;
