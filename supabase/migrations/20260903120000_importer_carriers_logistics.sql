-- Logística B2B: transportistas del importador + selección en checkout del aliado.

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------
create table if not exists public.importer_carriers (
  id uuid not null default gen_random_uuid () primary key,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  company_name text not null,
  contact_name text,
  contact_phone text not null,
  contact_email text,
  contact_whatsapp text,
  coverage_estados text[] not null default '{}'::text[],
  coverage_ciudades text[] not null default '{}'::text[],
  coverage_notes text,
  base_estado text,
  base_ciudad text,
  base_latitude numeric(10, 7),
  base_longitude numeric(10, 7),
  base_maps_url text,
  accepted_pago_metodos text[] not null default '{}'::text[],
  eta_base_hours numeric(8, 2) not null default 24,
  eta_hours_per_km numeric(8, 4) not null default 0.15,
  max_coverage_km numeric(10, 2),
  flat_fee_usd numeric(12, 4),
  price_per_km_usd numeric(12, 4),
  notes text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint importer_carriers_company_name_len_chk
    check (char_length(trim(company_name)) >= 2),
  constraint importer_carriers_phone_len_chk
    check (char_length(trim(contact_phone)) >= 6),
  constraint importer_carriers_eta_base_chk
    check (eta_base_hours >= 0),
  constraint importer_carriers_eta_per_km_chk
    check (eta_hours_per_km >= 0)
);

create index if not exists importer_carriers_importador_active_idx
  on public.importer_carriers (importador_id, is_active, sort_order);

comment on table public.importer_carriers is
  'Empresas de transporte registradas por el importador para entregas a aliados.';

create table if not exists public.importer_carrier_drivers (
  id uuid not null default gen_random_uuid () primary key,
  carrier_id uuid not null references public.importer_carriers (id) on delete cascade,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  driver_name text not null,
  contact_phone text,
  license_id text,
  notes text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint importer_carrier_drivers_name_len_chk
    check (char_length(trim(driver_name)) >= 2)
);

create index if not exists importer_carrier_drivers_carrier_active_idx
  on public.importer_carrier_drivers (carrier_id, is_active, sort_order);

comment on table public.importer_carrier_drivers is
  'Conductores de confianza asociados a una empresa de transporte del importador.';

alter table public.transaction_requests
  add column if not exists importer_carrier_id uuid
    references public.importer_carriers (id) on delete set null,
  add column if not exists importer_carrier_driver_id uuid
    references public.importer_carrier_drivers (id) on delete set null,
  add column if not exists carrier_eta_hours_snapshot numeric(10, 2),
  add column if not exists carrier_distance_km_snapshot numeric(10, 2),
  add column if not exists carrier_fee_usd_snapshot numeric(12, 4);

create index if not exists transaction_requests_carrier_idx
  on public.transaction_requests (importer_carrier_id)
  where importer_carrier_id is not null;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.importer_carriers_set_updated_at ()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists importer_carriers_set_updated_at on public.importer_carriers;
create trigger importer_carriers_set_updated_at
before update on public.importer_carriers
for each row
execute function public.importer_carriers_set_updated_at ();

drop trigger if exists importer_carrier_drivers_set_updated_at on public.importer_carrier_drivers;
create trigger importer_carrier_drivers_set_updated_at
before update on public.importer_carrier_drivers
for each row
execute function public.importer_carriers_set_updated_at ();

create or replace function public.motoconecta_haversine_km (
  p_lat1 numeric,
  p_lon1 numeric,
  p_lat2 numeric,
  p_lon2 numeric
)
returns numeric
language sql
immutable
as $$
  select case
    when p_lat1 is null or p_lon1 is null or p_lat2 is null or p_lon2 is null then null
    else round(
      (
        6371 * acos(
          least(
            1.0,
            greatest(
              -1.0,
              cos(radians(p_lat1))
              * cos(radians(p_lat2))
              * cos(radians(p_lon2) - radians(p_lon1))
              + sin(radians(p_lat1))
              * sin(radians(p_lat2))
            )
          )
        )
      )::numeric,
      2
    )
  end;
$$;

create or replace function public.motoconecta_carrier_covers_destination (
  p_coverage_estados text[],
  p_coverage_ciudades text[],
  p_dest_estado text,
  p_dest_ciudad text
)
returns boolean
language sql
immutable
as $$
  select
    (
      coalesce(cardinality(p_coverage_estados), 0) = 0
      or lower(trim(coalesce(p_dest_estado, ''))) = any (
        select lower(trim(x))
        from unnest(coalesce(p_coverage_estados, '{}'::text[])) as t (x)
        where trim(x) <> ''
      )
    )
    and (
      coalesce(cardinality(p_coverage_ciudades), 0) = 0
      or lower(trim(coalesce(p_dest_ciudad, ''))) = any (
        select lower(trim(x))
        from unnest(coalesce(p_coverage_ciudades, '{}'::text[])) as t (x)
        where trim(x) <> ''
      )
    );
$$;

create or replace function public.motoconecta_carrier_eta_hours (
  p_eta_base_hours numeric,
  p_eta_hours_per_km numeric,
  p_distance_km numeric
)
returns numeric
language sql
immutable
as $$
  select round(
    (
      coalesce(p_eta_base_hours, 0)
      + coalesce(p_eta_hours_per_km, 0) * coalesce(p_distance_km, 0)
    )::numeric,
    2
  );
$$;

create or replace function public.motoconecta_carrier_fee_usd (
  p_flat_fee_usd numeric,
  p_price_per_km_usd numeric,
  p_distance_km numeric
)
returns numeric
language sql
immutable
as $$
  select round(
    (
      coalesce(p_flat_fee_usd, 0)
      + coalesce(p_price_per_km_usd, 0) * coalesce(p_distance_km, 0)
    )::numeric,
    4
  );
$$;

create or replace function public.motoconecta_assert_importador_role ()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden gestionar transportistas.';
  end if;

  return v_uid;
end;
$$;

create or replace function public.motoconecta_sanitize_pago_metodos (p_metodos text[])
returns text[]
language plpgsql
as $$
declare
  v_allowed text[] := public.motoconecta_all_pago_metodos ();
  v_clean text[] := array[]::text[];
  v_m text;
begin
  if p_metodos is null then
    return v_clean;
  end if;

  foreach v_m in array p_metodos loop
    if trim(v_m) = any (v_allowed) and not (trim(v_m) = any (v_clean)) then
      v_clean := array_append(v_clean, trim(v_m));
    end if;
  end loop;

  return v_clean;
end;
$$;

-- ---------------------------------------------------------------------------
-- Checkout: listar transportistas del importador con ETA estimado
-- ---------------------------------------------------------------------------
create or replace function public.list_importer_carriers_for_checkout (
  p_importador_id uuid,
  p_dest_estado text default null,
  p_dest_ciudad text default null,
  p_dest_latitude numeric default null,
  p_dest_longitude numeric default null
)
returns table (
  id uuid,
  importador_id uuid,
  company_name text,
  contact_name text,
  contact_phone text,
  contact_email text,
  coverage_estados text[],
  coverage_ciudades text[],
  coverage_notes text,
  base_estado text,
  base_ciudad text,
  base_latitude numeric,
  base_longitude numeric,
  accepted_pago_metodos text[],
  eta_base_hours numeric,
  eta_hours_per_km numeric,
  max_coverage_km numeric,
  flat_fee_usd numeric,
  price_per_km_usd numeric,
  notes text,
  distance_km numeric,
  eta_hours numeric,
  fee_usd numeric,
  covers_destination boolean,
  drivers jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;

  if v_role is distinct from 'aliado' then
    raise exception 'Solo los aliados pueden consultar transportistas en checkout.';
  end if;

  if p_importador_id is null then
    raise exception 'Importador no indicado.';
  end if;

  return query
  with base as (
    select c.*
    from public.importer_carriers c
    where c.importador_id = p_importador_id
      and c.is_active = true
  ),
  enriched as (
    select
      b.*,
      public.motoconecta_haversine_km (
        b.base_latitude,
        b.base_longitude,
        p_dest_latitude,
        p_dest_longitude
      ) as distance_km,
      public.motoconecta_carrier_covers_destination (
        b.coverage_estados,
        b.coverage_ciudades,
        p_dest_estado,
        p_dest_ciudad
      ) as covers_destination
    from base b
  )
  select
    e.id,
    e.importador_id,
    e.company_name,
    e.contact_name,
    e.contact_phone,
    e.contact_email,
    e.coverage_estados,
    e.coverage_ciudades,
    e.coverage_notes,
    e.base_estado,
    e.base_ciudad,
    e.base_latitude,
    e.base_longitude,
    e.accepted_pago_metodos,
    e.eta_base_hours,
    e.eta_hours_per_km,
    e.max_coverage_km,
    e.flat_fee_usd,
    e.price_per_km_usd,
    e.notes,
    e.distance_km,
    public.motoconecta_carrier_eta_hours (
      e.eta_base_hours,
      e.eta_hours_per_km,
      e.distance_km
    ) as eta_hours,
    public.motoconecta_carrier_fee_usd (
      e.flat_fee_usd,
      e.price_per_km_usd,
      e.distance_km
    ) as fee_usd,
    e.covers_destination,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', d.id,
            'driver_name', d.driver_name,
            'contact_phone', d.contact_phone,
            'license_id', d.license_id
          )
          order by d.sort_order, d.driver_name
        )
        from public.importer_carrier_drivers d
        where d.carrier_id = e.id
          and d.is_active = true
      ),
      '[]'::jsonb
    ) as drivers
  from enriched e
  where e.covers_destination
    and (
      e.max_coverage_km is null
      or e.distance_km is null
      or e.distance_km <= e.max_coverage_km
    )
  order by e.sort_order, e.company_name;
end;
$$;

grant execute on function public.list_importer_carriers_for_checkout (
  uuid, text, text, numeric, numeric
) to authenticated;

-- ---------------------------------------------------------------------------
-- Importador: CRUD transportistas (REST-like vía RPC)
-- ---------------------------------------------------------------------------
create or replace function public.list_my_importer_carriers ()
returns setof public.importer_carriers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  return query
  select c.*
  from public.importer_carriers c
  where c.importador_id = v_uid
  order by c.sort_order, c.company_name;
end;
$$;

grant execute on function public.list_my_importer_carriers () to authenticated;

create or replace function public.create_importer_carrier (
  p_company_name text,
  p_contact_phone text,
  p_contact_name text default null,
  p_contact_email text default null,
  p_contact_whatsapp text default null,
  p_coverage_estados text[] default '{}'::text[],
  p_coverage_ciudades text[] default '{}'::text[],
  p_coverage_notes text default null,
  p_base_estado text default null,
  p_base_ciudad text default null,
  p_base_latitude numeric default null,
  p_base_longitude numeric default null,
  p_base_maps_url text default null,
  p_accepted_pago_metodos text[] default '{}'::text[],
  p_eta_base_hours numeric default 24,
  p_eta_hours_per_km numeric default 0.15,
  p_max_coverage_km numeric default null,
  p_flat_fee_usd numeric default null,
  p_price_per_km_usd numeric default null,
  p_notes text default null,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_id uuid;
  v_metodos text[];
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);

  insert into public.importer_carriers (
    importador_id,
    company_name,
    contact_name,
    contact_phone,
    contact_email,
    contact_whatsapp,
    coverage_estados,
    coverage_ciudades,
    coverage_notes,
    base_estado,
    base_ciudad,
    base_latitude,
    base_longitude,
    base_maps_url,
    accepted_pago_metodos,
    eta_base_hours,
    eta_hours_per_km,
    max_coverage_km,
    flat_fee_usd,
    price_per_km_usd,
    notes,
    sort_order
  )
  values (
    v_uid,
    trim(p_company_name),
    nullif(trim(coalesce(p_contact_name, '')), ''),
    trim(p_contact_phone),
    nullif(trim(coalesce(p_contact_email, '')), ''),
    nullif(trim(coalesce(p_contact_whatsapp, '')), ''),
    coalesce(p_coverage_estados, '{}'::text[]),
    coalesce(p_coverage_ciudades, '{}'::text[]),
    nullif(trim(coalesce(p_coverage_notes, '')), ''),
    nullif(trim(coalesce(p_base_estado, '')), ''),
    nullif(trim(coalesce(p_base_ciudad, '')), ''),
    p_base_latitude,
    p_base_longitude,
    nullif(trim(coalesce(p_base_maps_url, '')), ''),
    v_metodos,
    coalesce(p_eta_base_hours, 24),
    coalesce(p_eta_hours_per_km, 0.15),
    p_max_coverage_km,
    p_flat_fee_usd,
    p_price_per_km_usd,
    nullif(trim(coalesce(p_notes, '')), ''),
    coalesce(p_sort_order, 0)
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.create_importer_carrier (
  text, text, text, text, text, text[], text[], text, text, text,
  numeric, numeric, text, text[], numeric, numeric, numeric, numeric,
  numeric, text, integer
) to authenticated;

create or replace function public.update_importer_carrier (
  p_carrier_id uuid,
  p_company_name text,
  p_contact_phone text,
  p_contact_name text default null,
  p_contact_email text default null,
  p_contact_whatsapp text default null,
  p_coverage_estados text[] default '{}'::text[],
  p_coverage_ciudades text[] default '{}'::text[],
  p_coverage_notes text default null,
  p_base_estado text default null,
  p_base_ciudad text default null,
  p_base_latitude numeric default null,
  p_base_longitude numeric default null,
  p_base_maps_url text default null,
  p_accepted_pago_metodos text[] default '{}'::text[],
  p_eta_base_hours numeric default 24,
  p_eta_hours_per_km numeric default 0.15,
  p_max_coverage_km numeric default null,
  p_flat_fee_usd numeric default null,
  p_price_per_km_usd numeric default null,
  p_notes text default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_metodos text[];
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);

  update public.importer_carriers c
  set
    company_name = trim(p_company_name),
    contact_name = nullif(trim(coalesce(p_contact_name, '')), ''),
    contact_phone = trim(p_contact_phone),
    contact_email = nullif(trim(coalesce(p_contact_email, '')), ''),
    contact_whatsapp = nullif(trim(coalesce(p_contact_whatsapp, '')), ''),
    coverage_estados = coalesce(p_coverage_estados, '{}'::text[]),
    coverage_ciudades = coalesce(p_coverage_ciudades, '{}'::text[]),
    coverage_notes = nullif(trim(coalesce(p_coverage_notes, '')), ''),
    base_estado = nullif(trim(coalesce(p_base_estado, '')), ''),
    base_ciudad = nullif(trim(coalesce(p_base_ciudad, '')), ''),
    base_latitude = p_base_latitude,
    base_longitude = p_base_longitude,
    base_maps_url = nullif(trim(coalesce(p_base_maps_url, '')), ''),
    accepted_pago_metodos = v_metodos,
    eta_base_hours = coalesce(p_eta_base_hours, 24),
    eta_hours_per_km = coalesce(p_eta_hours_per_km, 0.15),
    max_coverage_km = p_max_coverage_km,
    flat_fee_usd = p_flat_fee_usd,
    price_per_km_usd = p_price_per_km_usd,
    notes = nullif(trim(coalesce(p_notes, '')), ''),
    is_active = coalesce(p_is_active, true),
    sort_order = coalesce(p_sort_order, 0)
  where c.id = p_carrier_id
    and c.importador_id = v_uid;

  if not found then
    raise exception 'Transportista no encontrado o sin permiso.';
  end if;
end;
$$;

grant execute on function public.update_importer_carrier (
  uuid, text, text, text, text, text, text[], text[], text, text, text,
  numeric, numeric, text, text[], numeric, numeric, numeric, numeric,
  numeric, text, boolean, integer
) to authenticated;

create or replace function public.delete_importer_carrier (p_carrier_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  update public.importer_carriers c
  set is_active = false
  where c.id = p_carrier_id
    and c.importador_id = v_uid;

  if not found then
    raise exception 'Transportista no encontrado o sin permiso.';
  end if;
end;
$$;

grant execute on function public.delete_importer_carrier (uuid) to authenticated;

-- Conductores
create or replace function public.list_importer_carrier_drivers (p_carrier_id uuid)
returns setof public.importer_carrier_drivers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if not exists (
    select 1
    from public.importer_carriers c
    where c.id = p_carrier_id
      and c.importador_id = v_uid
  ) then
    raise exception 'Transportista no encontrado o sin permiso.';
  end if;

  return query
  select d.*
  from public.importer_carrier_drivers d
  where d.carrier_id = p_carrier_id
  order by d.sort_order, d.driver_name;
end;
$$;

grant execute on function public.list_importer_carrier_drivers (uuid) to authenticated;

create or replace function public.create_importer_carrier_driver (
  p_carrier_id uuid,
  p_driver_name text,
  p_contact_phone text default null,
  p_license_id text default null,
  p_notes text default null,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_id uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_driver_name, ''))) < 2 then
    raise exception 'Indique el nombre del conductor.';
  end if;

  if not exists (
    select 1
    from public.importer_carriers c
    where c.id = p_carrier_id
      and c.importador_id = v_uid
  ) then
    raise exception 'Transportista no encontrado o sin permiso.';
  end if;

  insert into public.importer_carrier_drivers (
    carrier_id,
    importador_id,
    driver_name,
    contact_phone,
    license_id,
    notes,
    sort_order
  )
  values (
    p_carrier_id,
    v_uid,
    trim(p_driver_name),
    nullif(trim(coalesce(p_contact_phone, '')), ''),
    nullif(trim(coalesce(p_license_id, '')), ''),
    nullif(trim(coalesce(p_notes, '')), ''),
    coalesce(p_sort_order, 0)
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.create_importer_carrier_driver (
  uuid, text, text, text, text, integer
) to authenticated;

create or replace function public.update_importer_carrier_driver (
  p_driver_id uuid,
  p_driver_name text,
  p_contact_phone text default null,
  p_license_id text default null,
  p_notes text default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_driver_name, ''))) < 2 then
    raise exception 'Indique el nombre del conductor.';
  end if;

  update public.importer_carrier_drivers d
  set
    driver_name = trim(p_driver_name),
    contact_phone = nullif(trim(coalesce(p_contact_phone, '')), ''),
    license_id = nullif(trim(coalesce(p_license_id, '')), ''),
    notes = nullif(trim(coalesce(p_notes, '')), ''),
    is_active = coalesce(p_is_active, true),
    sort_order = coalesce(p_sort_order, 0)
  where d.id = p_driver_id
    and d.importador_id = v_uid;

  if not found then
    raise exception 'Conductor no encontrado o sin permiso.';
  end if;
end;
$$;

grant execute on function public.update_importer_carrier_driver (
  uuid, text, text, text, text, boolean, integer
) to authenticated;

create or replace function public.delete_importer_carrier_driver (p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  update public.importer_carrier_drivers d
  set is_active = false
  where d.id = p_driver_id
    and d.importador_id = v_uid;

  if not found then
    raise exception 'Conductor no encontrado o sin permiso.';
  end if;
end;
$$;

grant execute on function public.delete_importer_carrier_driver (uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Checkout: persistir transportista por importador
-- ---------------------------------------------------------------------------
create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}'::jsonb,
  p_carriers_by_importador jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_rif text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_fiscal_maps text;
  v_lat numeric;
  v_lng numeric;
  v_kyc text;
  v_psm boolean;
  v_dest_estado text;
  v_dest_ciudad text;
  v_dest_lat numeric;
  v_dest_lng numeric;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_sale numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_discount_snap jsonb;
  v_comm_rate numeric;
  v_promo_id uuid;
  v_promo_raw text;
  v_group_id uuid := gen_random_uuid ();
  v_carrier_raw jsonb;
  v_carrier_id uuid;
  v_driver_id uuid;
  v_carrier_rec record;
  v_active_carrier_count integer;
  v_dist numeric;
  v_eta numeric;
  v_fee numeric;
  v_importers uuid[];
  v_imp uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if p_lines is null or jsonb_typeof (p_lines) <> 'array' or jsonb_array_length (p_lines) = 0 then
    raise exception 'El carrito está vacío';
  end if;

  select
    p.role,
    nullif(trim(p.rif), ''),
    nullif(trim(p.estado), ''),
    nullif(trim(p.ciudad), ''),
    nullif(trim(p.direccion), ''),
    nullif(trim(p.fiscal_maps_url), ''),
    p.latitude,
    p.longitude,
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_lat, v_lng, v_kyc, v_psm
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;
  if v_role <> 'aliado' then
    raise exception 'Solo los aliados pueden confirmar el carrito';
  end if;
  if v_psm then
    raise exception
      'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad.';
  end if;
  if v_kyc is not null and v_kyc = 'rechazado' then
    raise exception
      'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
  end if;
  if v_rif is null then
    raise exception 'Registre su RIF comercial en Mi perfil para solicitar pedidos.';
  end if;
  if v_estado is null or v_ciudad is null or v_direccion is null then
    raise exception
      'Registre estado, ciudad y dirección fiscal en Mi perfil para poder solicitar pedidos.';
  end if;

  if p_destino_entrega_usa_perfil then
    if v_fiscal_maps is null then
      raise exception
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal.';
    end if;
    v_dest_estado := v_estado;
    v_dest_ciudad := v_ciudad;
    v_dest_lat := v_lat;
    v_dest_lng := v_lng;
  else
    if p_destino_entrega_texto is null
       or length(trim(p_destino_entrega_texto)) = 0 then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
    end if;
    if p_destino_entrega_maps_url is null
       or p_destino_entrega_maps_url !~* '^https?://' then
      raise exception
        'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.';
    end if;
    v_dest_estado := null;
    v_dest_ciudad := null;
    v_dest_lat := null;
    v_dest_lng := null;
  end if;

  select array_agg(distinct pr.owner_id)
    into v_importers
  from jsonb_array_elements (p_lines) as t (elem)
  join public.products pr on pr.id = (elem ->> 'product_id')::uuid;

  if v_importers is not null then
    foreach v_imp in array v_importers loop
      select count(*)::integer
        into v_active_carrier_count
      from public.importer_carriers c
      where c.importador_id = v_imp
        and c.is_active = true;

      if v_active_carrier_count > 0 then
        v_carrier_raw := p_carriers_by_importador -> v_imp::text;
        if v_carrier_raw is null or jsonb_typeof (v_carrier_raw) <> 'object' then
          raise exception
            'Seleccione un transportista para el importador con productos en el carrito.';
        end if;

        v_carrier_id := nullif(v_carrier_raw ->> 'carrier_id', '')::uuid;
        v_driver_id := nullif(v_carrier_raw ->> 'driver_id', '')::uuid;

        if v_carrier_id is null then
          raise exception 'Seleccione un transportista válido para cada importador.';
        end if;

        select *
          into v_carrier_rec
        from public.importer_carriers c
        where c.id = v_carrier_id
          and c.importador_id = v_imp
          and c.is_active = true;

        if not found then
          raise exception 'Transportista no válido para el importador.';
        end if;

        if not public.motoconecta_carrier_covers_destination (
          v_carrier_rec.coverage_estados,
          v_carrier_rec.coverage_ciudades,
          v_dest_estado,
          v_dest_ciudad
        ) then
          raise exception
            'El transportista seleccionado no cubre el destino de entrega.';
        end if;

        if v_driver_id is not null and not exists (
          select 1
          from public.importer_carrier_drivers d
          where d.id = v_driver_id
            and d.carrier_id = v_carrier_id
            and d.is_active = true
        ) then
          raise exception 'Conductor no válido para el transportista seleccionado.';
        end if;
      end if;
    end loop;
  end if;

  for rec in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    if rec.cantidad is null or rec.cantidad < 1 then
      raise exception 'Cantidad inválida en el carrito';
    end if;

    select
      pr.owner_id,
      pr.price_usd,
      pr.sale_price_usd,
      pr.stock,
      pr.is_active
    into v_owner, v_price, v_sale, v_stock, v_active
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;
    if not v_active then
      raise exception
        'El producto % no está disponible en el catálogo.',
        rec.product_id;
    end if;
    if v_stock < rec.cantidad then
      raise exception
        'Stock insuficiente: hay %s unidad(es) disponible(s) para una línea del carrito.',
        v_stock;
    end if;
  end loop;

  for rec in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    select
      pr.owner_id,
      pr.price_usd,
      pr.sale_price_usd,
      pr.stock,
      pr.discount_rules
    into v_owner, v_price, v_sale, v_stock, v_discount
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;

    v_unit := public.motoconecta_aliado_unit_price_usd (
      v_price,
      v_sale,
      v_discount,
      rec.cantidad,
      false
    );
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_discount_snap := public.motoconecta_enrich_discount_rules_snapshot (
      v_discount,
      rec.cantidad
    );
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    v_promo_id := null;
    if p_promo_by_importador is not null
       and jsonb_typeof (p_promo_by_importador) = 'object' then
      v_promo_raw := p_promo_by_importador ->> v_owner::text;
      if v_promo_raw is not null and btrim(v_promo_raw) <> '' then
        select c.id
          into v_promo_id
        from public.promo_campaigns c
        where c.id = v_promo_raw::uuid
          and c.importador_id = v_owner
          and c.is_active = true
          and c.starts_at <= now()
          and c.ends_at >= now();
      end if;
    end if;

    v_carrier_id := null;
    v_driver_id := null;
    v_dist := null;
    v_eta := null;
    v_fee := null;

    if p_carriers_by_importador is not null
       and jsonb_typeof (p_carriers_by_importador) = 'object' then
      v_carrier_raw := p_carriers_by_importador -> v_owner::text;
      if v_carrier_raw is not null and jsonb_typeof (v_carrier_raw) = 'object' then
        v_carrier_id := nullif(v_carrier_raw ->> 'carrier_id', '')::uuid;
        v_driver_id := nullif(v_carrier_raw ->> 'driver_id', '')::uuid;

        if v_carrier_id is not null then
          select *
            into v_carrier_rec
          from public.importer_carriers c
          where c.id = v_carrier_id
            and c.importador_id = v_owner
            and c.is_active = true;

          if found then
            v_dist := public.motoconecta_haversine_km (
              v_carrier_rec.base_latitude,
              v_carrier_rec.base_longitude,
              v_dest_lat,
              v_dest_lng
            );
            v_eta := public.motoconecta_carrier_eta_hours (
              v_carrier_rec.eta_base_hours,
              v_carrier_rec.eta_hours_per_km,
              v_dist
            );
            v_fee := public.motoconecta_carrier_fee_usd (
              v_carrier_rec.flat_fee_usd,
              v_carrier_rec.price_per_km_usd,
              v_dist
            );
          end if;
        end if;
      end if;
    end if;

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      precio_base_aliado_total,
      precio_unitario_proveedor,
      precio_unitario_aliado,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot,
      promo_campaign_id,
      importer_carrier_id,
      importer_carrier_driver_id,
      carrier_eta_hours_snapshot,
      carrier_distance_km_snapshot,
      carrier_fee_usd_snapshot
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      v_line_total,
      round(v_price::numeric, 6),
      round(v_unit::numeric, 6),
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount_snap,
      v_comm_rate,
      v_promo_id,
      v_carrier_id,
      v_driver_id,
      v_eta,
      v_dist,
      v_fee
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text,
  jsonb,
  jsonb
) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.importer_carriers enable row level security;
alter table public.importer_carrier_drivers enable row level security;

drop policy if exists importer_carriers_select_owner on public.importer_carriers;
create policy importer_carriers_select_owner
on public.importer_carriers
for select
to authenticated
using (importador_id = auth.uid ());

drop policy if exists importer_carrier_drivers_select_owner on public.importer_carrier_drivers;
create policy importer_carrier_drivers_select_owner
on public.importer_carrier_drivers
for select
to authenticated
using (importador_id = auth.uid ());
