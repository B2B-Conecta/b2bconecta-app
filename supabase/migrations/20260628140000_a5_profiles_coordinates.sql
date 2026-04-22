-- A5: coordenadas para ordenación por proximidad (aliado GPS / fiscal geocodificado).

alter table public.profiles
  add column if not exists latitude double precision;

alter table public.profiles
  add column if not exists longitude double precision;

alter table public.profiles
  add column if not exists location_updated_at timestamptz;

comment on column public.profiles.latitude is
  'Latitud WGS84 (GPS aliado o geocodificación del domicilio fiscal importador).';
comment on column public.profiles.longitude is
  'Longitud WGS84 (GPS aliado o geocodificación del domicilio fiscal importador).';
comment on column public.profiles.location_updated_at is
  'Última vez que se actualizaron latitude/longitude desde la app.';

-- Permite al usuario autenticado actualizar solo sus coordenadas (bypass RLS si hiciera falta).
create or replace function public.update_my_last_coordinates(
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
  if p_latitude is null or p_longitude is null then
    raise exception 'Se requieren latitud y longitud';
  end if;
  if p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Coordenadas fuera de rango';
  end if;

  update public.profiles
  set
    latitude = p_latitude,
    longitude = p_longitude,
    location_updated_at = now()
  where id = auth.uid();
end;
$$;

revoke all on function public.update_my_last_coordinates(double precision, double precision) from public;
grant execute on function public.update_my_last_coordinates(double precision, double precision) to authenticated;
