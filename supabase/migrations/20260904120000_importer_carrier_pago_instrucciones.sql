-- Transportistas: datos de cuenta por método de pago (visible al aliado en checkout).

alter table public.importer_carriers
  add column if not exists pago_metodo_instrucciones jsonb not null default '{}'::jsonb;

comment on column public.importer_carriers.pago_metodo_instrucciones is
  'Datos de cuenta / instrucciones por método aceptado (clave = pago_metodo).';

create or replace function public.motoconecta_sanitize_carrier_pago_instrucciones (
  p_instrucciones jsonb,
  p_accepted text[]
)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_clean jsonb := '{}'::jsonb;
  v_key text;
  v_val text;
  v_allowed text[] := coalesce(p_accepted, '{}'::text[]);
begin
  if p_instrucciones is null or jsonb_typeof(p_instrucciones) <> 'object' then
    return v_clean;
  end if;

  for v_key, v_val in
    select key, value #>> '{}'
    from jsonb_each(p_instrucciones)
  loop
    if trim(v_key) = any (v_allowed) then
      v_val := left(trim(coalesce(v_val, '')), 2000);
      if v_val <> '' then
        v_clean := v_clean || jsonb_build_object(trim(v_key), v_val);
      end if;
    end if;
  end loop;

  return v_clean;
end;
$$;

drop function if exists public.list_importer_carriers_for_checkout (
  uuid, text, text, numeric, numeric
);

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
  pago_metodo_instrucciones jsonb,
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
    e.pago_metodo_instrucciones,
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
  p_pago_metodo_instrucciones jsonb default '{}'::jsonb,
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
  v_instr jsonb;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);
  v_instr := public.motoconecta_sanitize_carrier_pago_instrucciones (
    p_pago_metodo_instrucciones,
    v_metodos
  );

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
    pago_metodo_instrucciones,
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
    v_instr,
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
  numeric, numeric, text, text[], jsonb, numeric, numeric, numeric, numeric,
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
  p_pago_metodo_instrucciones jsonb default '{}'::jsonb,
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
  v_instr jsonb;
begin
  v_uid := public.motoconecta_assert_importador_role ();

  if char_length(trim(coalesce(p_company_name, ''))) < 2 then
    raise exception 'Indique el nombre de la empresa de transporte.';
  end if;
  if char_length(trim(coalesce(p_contact_phone, ''))) < 6 then
    raise exception 'Indique un teléfono de contacto válido.';
  end if;

  v_metodos := public.motoconecta_sanitize_pago_metodos (p_accepted_pago_metodos);
  v_instr := public.motoconecta_sanitize_carrier_pago_instrucciones (
    p_pago_metodo_instrucciones,
    v_metodos
  );

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
    pago_metodo_instrucciones = v_instr,
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
  numeric, numeric, text, text[], jsonb, numeric, numeric, numeric, numeric,
  numeric, text, boolean, integer
) to authenticated;
