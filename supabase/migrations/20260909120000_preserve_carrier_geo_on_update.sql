-- Al editar transportista (p. ej. modo flete separado), no borrar lat/lng si el cliente no las envía.

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
  p_flete_pago_modo text default 'incluido_factura',
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
  v_flete text;
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
  v_flete := coalesce(nullif(trim(p_flete_pago_modo), ''), 'incluido_factura');
  if v_flete not in ('incluido_factura', 'pago_separado') then
    raise exception 'Modo de pago del flete no válido.';
  end if;

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
    base_latitude = coalesce(p_base_latitude, c.base_latitude),
    base_longitude = coalesce(p_base_longitude, c.base_longitude),
    base_maps_url = coalesce(
      nullif(trim(coalesce(p_base_maps_url, '')), ''),
      c.base_maps_url
    ),
    accepted_pago_metodos = v_metodos,
    pago_metodo_instrucciones = v_instr,
    flete_pago_modo = v_flete,
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

-- Reparar coords de transportistas demo si se perdieron en ediciones previas.
update public.importer_carriers c
set
  base_latitude = 10.4969,
  base_longitude = -66.8488
where c.company_name = 'Envíos Rápidos Delta C.A.'
  and c.base_latitude is null;

update public.importer_carriers c
set
  base_latitude = 10.3440,
  base_longitude = -67.0430
where c.company_name = 'Motocargas Express'
  and c.base_latitude is null;
