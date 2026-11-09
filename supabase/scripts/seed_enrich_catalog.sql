-- =============================================================================
-- Enrichment del catálogo seed: campos completos, ofertas, variantes e imágenes.
-- =============================================================================
-- Requisito: supabase/seed.sql ya aplicado (productos demo presentes).
--
--   supabase db query --linked -f supabase/scripts/seed_enrich_catalog.sql
--
-- Imágenes: subir antes (o después) con:
--   bash scripts/upload_seed_product_images.sh staging
-- Las URLs apuntan al project ref DEV por defecto (override con seed.image_base).
-- =============================================================================

do $cfg$
begin
  perform set_config(
    'seed.image_base',
    coalesce(
      nullif(current_setting('seed.image_base', true), ''),
      'https://kdrccmqcrruixuworlmz.supabase.co/storage/v1/object/public/product-images/seed'
    ),
    true
  );
end;
$cfg$;

-- ---------------------------------------------------------------------------
-- 1) Completar filas seed existentes (descripciones, mínimos, oferta, garantía,
--    custom_fields e imagen por SKU o por categoría).
-- ---------------------------------------------------------------------------
with catalog (
  sku,
  image_file,
  sale_price_usd,
  min_order_qty,
  has_warranty,
  description,
  custom_fields
) as (
  values
    (
      'DELTA-EMB-125',
      'DELTA-EMB-125.jpg',
      41.5000::numeric,
      5,
      true,
      'Kit de embrague completo para motores 125 cc: discos, campana y resortes calibrados para uso urbano y mensajería.',
      '{"marca":"Delta","origen":"Importado","unidad":"kit"}'::jsonb
    ),
    (
      'DID-428-118',
      'DID-428-118.jpg',
      29.5000::numeric,
      5,
      true,
      'Cadena de transmisión 428 con 118 eslabones y retenes. Ideal para scooters y underbone 110–150 cc.',
      '{"marca":"DID","paso":"428","eslabones":"118"}'::jsonb
    ),
    (
      'FERODO-FP187',
      'FERODO-FP187.jpg',
      16.5000::numeric,
      10,
      false,
      'Par de pastillas delanteras compuesto orgánico. Bajo ruido y buen mordiente en frío.',
      '{"marca":"Ferodo","posicion":"delantero","compuesto":"organico"}'::jsonb
    ),
    (
      'EBC-MD2001',
      'EBC-MD2001.jpg',
      47.0000::numeric,
      5,
      true,
      'Disco de freno delantero 245 mm en acero inoxidable. Ranurado para mejor evacuación de calor.',
      '{"marca":"EBC","diametro_mm":"245","material":"inox"}'::jsonb
    ),
    (
      'ALL-BAL-120',
      'ALL-BAL-120.jpg',
      null::numeric,
      10,
      false,
      'Cable de acelerador 1.20 m con funda nylon. Extremos metálicos listos para instalación.',
      '{"largo_m":"1.20","uso":"acelerador"}'::jsonb
    ),
    (
      'ALL-CLU-120',
      'ALL-CLU-120.jpg',
      null::numeric,
      10,
      false,
      'Cable de embrague reforzado con recubrimiento teflón para menor fricción.',
      '{"largo_m":"1.20","uso":"embrague","revestimiento":"teflon"}'::jsonb
    ),
    (
      'MOB-4T-20W50-1L',
      'MOB-4T-20W50-1L.jpg',
      7.9000::numeric,
      12,
      false,
      'Aceite 4T 20W50 sintético API SL en presentación de 1 L. Protección térmica para motores refrigerados por aire.',
      '{"viscosidad":"20W50","presentacion":"1L","api":"SL"}'::jsonb
    ),
    (
      'NGK-CR7HSA',
      'NGK-CR7HSA.jpg',
      4.8000::numeric,
      20,
      true,
      'Bujía iridium CR7HSA. Encendido estable y mayor vida útil frente a la bujía estándar.',
      '{"marca":"NGK","tipo":"iridium","rosca":"CR7HSA"}'::jsonb
    ),
    (
      'K&N-RC-1200',
      'KN-RC-1200.jpg',
      11.0000::numeric,
      5,
      false,
      'Filtro de aire de espuma lavable alto flujo. Reutilizable con kit de mantenimiento.',
      '{"marca":"K&N","tipo":"espuma","mantenimiento":"lavable"}'::jsonb
    ),
    (
      'YUASA-12N9-BS',
      'YUASA-12N9-BS.jpg',
      57.0000::numeric,
      5,
      true,
      'Batería gel sellada 12N9-BS. Libre de mantenimiento, alta capacidad de arranque.',
      '{"marca":"Yuasa","tipo":"gel","referencia":"12N9-BS"}'::jsonb
    ),
    (
      'NGK-COP-2P',
      'NGK-COP-2P.jpg',
      null::numeric,
      5,
      true,
      'Bobina CDI de 2 pines alta tensión. Reemplazo directo en CG 125 y equivalentes.',
      '{"pines":"2","sistema":"CDI"}'::jsonb
    ),
    (
      'REG-12V-8C',
      'REG-12V-8C.jpg',
      17.5000::numeric,
      5,
      true,
      'Regulador/rectificador 12 V con 8 cables y tierra. Compatible con flotas 125–150 cc.',
      '{"voltaje":"12V","cables":"8"}'::jsonb
    ),
    (
      'YSS-325-ADJ',
      'YSS-325-ADJ.jpg',
      79.0000::numeric,
      5,
      true,
      'Amortiguador trasero 325 mm con 5 posiciones de precarga. Uso urbano y carga ligera.',
      '{"marca":"YSS","largo_mm":"325","ajustes":"5"}'::jsonb
    ),
    (
      'SKF-6202-2RS',
      'SKF-6202-2RS.jpg',
      14.5000::numeric,
      10,
      true,
      'Kit de rodamientos de rueda delantera sellados 6202-2RS (par).',
      '{"marca":"SKF","medida":"6202-2RS","contenido":"par"}'::jsonb
    ),
    (
      'PRO-EX-125',
      'PRO-EX-125.jpg',
      88.0000::numeric,
      5,
      true,
      'Silenciador homologado 125 cc en acero inoxidable. Mejora de flujo sin spoilear el sensor de ruido local.',
      '{"material":"inox","cilindrada":"125","homologado":"si"}'::jsonb
    )
)
update public.products p
set
  description = coalesce(c.description, p.description),
  sale_price_usd = c.sale_price_usd,
  min_order_qty = greatest(c.min_order_qty, 5),
  has_warranty = c.has_warranty,
  custom_fields = coalesce(p.custom_fields, '{}'::jsonb) || c.custom_fields,
  image_url = current_setting('seed.image_base') || '/' || c.image_file,
  image_urls = jsonb_build_array(
    current_setting('seed.image_base') || '/' || c.image_file
  ),
  is_active = true
from catalog c
where p.owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid
  and p.sku = c.sku;

-- Imágenes por categoría para el resto del catálogo seed (sin foto propia).
update public.products p
set
  image_url = current_setting('seed.image_base') || '/' || case
    when lower(coalesce(p.category, '')) like '%freno%' then 'CAT-FRENOS.jpg'
    when lower(coalesce(p.category, '')) like '%motor%' then 'CAT-MOTOR.jpg'
    else 'CAT-TRANSMISION.jpg'
  end,
  image_urls = jsonb_build_array(
    current_setting('seed.image_base') || '/' || case
      when lower(coalesce(p.category, '')) like '%freno%' then 'CAT-FRENOS.jpg'
      when lower(coalesce(p.category, '')) like '%motor%' then 'CAT-MOTOR.jpg'
      else 'CAT-TRANSMISION.jpg'
    end
  ),
  min_order_qty = greatest(coalesce(p.min_order_qty, 5), 5),
  custom_fields = coalesce(p.custom_fields, '{}'::jsonb) || jsonb_build_object(
    'seed_enriched',
    true,
    'foto',
    'categoria'
  )
where p.owner_id::text like 'c100000%'
  and (
    p.image_url is null
    or btrim(p.image_url) = ''
    or p.image_urls is null
    or p.image_urls = '[]'::jsonb
  );

-- Ofertas suaves en importador2 (sin pisar las ya definidas).
update public.products
set
  sale_price_usd = round(price_usd * 0.92, 4),
  has_warranty = coalesce(has_warranty, false) or category in ('Frenos', 'Motor'),
  min_order_qty = greatest(coalesce(min_order_qty, 5), 5),
  description = coalesce(
    nullif(btrim(description), ''),
    name || ' — stock mayorista listo para reposición semanal.'
  )
where owner_id = 'c1000002-0000-4000-8000-000000000001'::uuid
  and sale_price_usd is null
  and price_usd > 8;

-- ---------------------------------------------------------------------------
-- 2) Variantes reales (Aceite Mobil 1L/4L y Pastillas delantero/trasero).
-- ---------------------------------------------------------------------------

-- Aceite: la fila 1L pasa a ser variante del maestro mobil-4t-20w50.
update public.products
set
  parent_sku = 'mobil-4t-20w50',
  variant_attribute_name = 'Presentación',
  variant_attribute_value = '1 Litro',
  variant_attributes = '{"Presentación":"1 Litro"}'::jsonb,
  name = 'Aceite Mobil 4T 20W50',
  description = 'Aceite 4T 20W50 sintético API SL. Elija presentación 1 L o 4 L.'
where owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid
  and sku = 'MOB-4T-20W50-1L';

insert into public.products (
  id,
  owner_id,
  name,
  description,
  compatibility,
  sku,
  category,
  price_usd,
  sale_price_usd,
  stock,
  min_order_qty,
  is_active,
  has_warranty,
  image_url,
  image_urls,
  custom_fields,
  parent_sku,
  variant_attribute_name,
  variant_attribute_value,
  variant_attributes
)
values (
  'd1000001-0000-4000-8000-000000000101',
  'c1000001-0000-4000-8000-000000000001',
  'Aceite Mobil 4T 20W50',
  'Aceite 4T 20W50 sintético API SL. Presentación económica de 4 litros para talleres.',
  '4T 125–200 cc',
  'MOB-4T-20W50-4L',
  'Motor',
  29.5000,
  27.0000,
  90,
  5,
  true,
  false,
  current_setting('seed.image_base') || '/MOB-4T-20W50-1L.jpg',
  jsonb_build_array(current_setting('seed.image_base') || '/MOB-4T-20W50-1L.jpg'),
  '{"viscosidad":"20W50","presentacion":"4L","api":"SL"}'::jsonb,
  'mobil-4t-20w50',
  'Presentación',
  '4 Litros',
  '{"Presentación":"4 Litros"}'::jsonb
)
on conflict (id) do update set
  price_usd = excluded.price_usd,
  sale_price_usd = excluded.sale_price_usd,
  stock = excluded.stock,
  image_url = excluded.image_url,
  image_urls = excluded.image_urls,
  parent_sku = excluded.parent_sku,
  variant_attribute_name = excluded.variant_attribute_name,
  variant_attribute_value = excluded.variant_attribute_value,
  variant_attributes = excluded.variant_attributes,
  custom_fields = excluded.custom_fields,
  is_active = true;

-- Pastillas: delantero existente + trasero nuevo.
update public.products
set
  parent_sku = 'ferodo-pastillas-125',
  variant_attribute_name = 'Posición',
  variant_attribute_value = 'Delantero',
  variant_attributes = '{"Posición":"Delantero"}'::jsonb,
  name = 'Pastillas freno Ferodo'
where owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid
  and sku = 'FERODO-FP187';

insert into public.products (
  id,
  owner_id,
  name,
  description,
  compatibility,
  sku,
  category,
  price_usd,
  sale_price_usd,
  stock,
  min_order_qty,
  is_active,
  has_warranty,
  image_url,
  image_urls,
  custom_fields,
  parent_sku,
  variant_attribute_name,
  variant_attribute_value,
  variant_attributes
)
values (
  'd1000001-0000-4000-8000-000000000102',
  'c1000001-0000-4000-8000-000000000001',
  'Pastillas freno Ferodo',
  'Par de pastillas traseras compuesto orgánico Ferodo para 125 cc.',
  'Yamaha YBR 125 / Crypton / CG 125',
  'FERODO-RP188',
  'Frenos',
  15.0000,
  13.5000,
  70,
  10,
  true,
  false,
  current_setting('seed.image_base') || '/FERODO-FP187.jpg',
  jsonb_build_array(current_setting('seed.image_base') || '/FERODO-FP187.jpg'),
  '{"marca":"Ferodo","posicion":"trasero","compuesto":"organico"}'::jsonb,
  'ferodo-pastillas-125',
  'Posición',
  'Trasero',
  '{"Posición":"Trasero"}'::jsonb
)
on conflict (id) do update set
  price_usd = excluded.price_usd,
  sale_price_usd = excluded.sale_price_usd,
  stock = excluded.stock,
  image_url = excluded.image_url,
  image_urls = excluded.image_urls,
  parent_sku = excluded.parent_sku,
  variant_attribute_name = excluded.variant_attribute_name,
  variant_attribute_value = excluded.variant_attribute_value,
  variant_attributes = excluded.variant_attributes,
  custom_fields = excluded.custom_fields,
  is_active = true;

-- Bujías: iridium existente + estándar como segunda variante.
update public.products
set
  parent_sku = 'ngk-bujia-125',
  variant_attribute_name = 'Tipo',
  variant_attribute_value = 'Iridium',
  variant_attributes = '{"Tipo":"Iridium"}'::jsonb,
  name = 'Bujía NGK 125'
where owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid
  and sku = 'NGK-CR7HSA';

insert into public.products (
  id,
  owner_id,
  name,
  description,
  compatibility,
  sku,
  category,
  price_usd,
  sale_price_usd,
  stock,
  min_order_qty,
  is_active,
  has_warranty,
  image_url,
  image_urls,
  custom_fields,
  parent_sku,
  variant_attribute_name,
  variant_attribute_value,
  variant_attributes
)
values (
  'd1000001-0000-4000-8000-000000000103',
  'c1000001-0000-4000-8000-000000000001',
  'Bujía NGK 125',
  'Bujía NGK estándar CR7HS para reposición económica en flotas 125 cc.',
  'Honda Wave / Biz 125 / CG 125',
  'NGK-CR7HS-STD',
  'Motor',
  3.2000,
  null,
  400,
  20,
  true,
  false,
  current_setting('seed.image_base') || '/NGK-CR7HSA.jpg',
  jsonb_build_array(current_setting('seed.image_base') || '/NGK-CR7HSA.jpg'),
  '{"marca":"NGK","tipo":"estandar","rosca":"CR7HS"}'::jsonb,
  'ngk-bujia-125',
  'Tipo',
  'Estándar',
  '{"Tipo":"Estándar"}'::jsonb
)
on conflict (id) do update set
  price_usd = excluded.price_usd,
  stock = excluded.stock,
  image_url = excluded.image_url,
  image_urls = excluded.image_urls,
  parent_sku = excluded.parent_sku,
  variant_attribute_name = excluded.variant_attribute_name,
  variant_attribute_value = excluded.variant_attribute_value,
  variant_attributes = excluded.variant_attributes,
  custom_fields = excluded.custom_fields,
  is_active = true;
