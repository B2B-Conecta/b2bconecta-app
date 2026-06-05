-- =============================================================================
-- MotoConecta — datos de desarrollo (seed)
-- =============================================================================
-- Requisito: migraciones aplicadas (E1.1 catalog_boost, C4 ratings, bucket_v2, dimensiones rolling).
--
-- Carga:
--   supabase db query --linked -f supabase/seed.sql
--
-- Contraseña común (todos los seed): SeedPass123!
--
-- Incluye: 15 importadores (2 × 15 SKU + 10 × 5 SKU; 13–15 catálogo vacío para carga masiva),
-- 3 aliados (solo aliado1 con pedidos demo), 2 admins,
-- pedidos entregados con pago aprobado + método de pago y comprobante,
-- valoraciones bucket_v2 de demo (admin / reputación importador) y
-- E3 tramos comisión: importador11 ≈ 4 500 USD/mes (5 %), importador12 ≈ 10 500 USD/mes (3 %).
--
-- Flujo recomendado (re-carga limpia):
--   supabase db query --linked -f supabase/scripts/clean_database_for_seed.sql
--   supabase db query --linked -f supabase/seed.sql
--
-- Solo vaciar pedidos (conserva usuarios/catálogo):
--   supabase/scripts/reset_operational_data.sql
--   supabase/scripts/seed_catalog_stock.sql
--
-- Cuentas:
--   importador1@motoconecta.seed … importador15@motoconecta.seed
--   importador13–15: sin productos (plantilla carga masiva)
--   aliado1@motoconecta.seed … aliado3@motoconecta.seed (solo aliado1 con pedidos)
--   admin@motoconecta.seed, admin2@motoconecta.seed
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Limpieza re-seed (usuarios @motoconecta.seed + catálogo + pedidos demo)
-- En remoto/PRODUCTION preferir antes: scripts/clean_database_for_seed.sql
-- ---------------------------------------------------------------------------
delete from public.order_ratings
where importador_id::text like 'c100000%'
   or aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid;

delete from public.aliado_pago_pendiente_reminder_sent
where aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid;

delete from public.sla_importer_pending_alert_sent
where importador_id::text like 'c100000%';

update public.transaction_requests
set commission_settlement_id = null
where importador_id::text like 'c100000%'
   or aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid;

delete from public.commission_settlements
where importador_id::text like 'c100000%';

delete from public.transaction_requests
where aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
   or importador_id in (
     'c1000001-0000-4000-8000-000000000001'::uuid,
     'c1000002-0000-4000-8000-000000000001'::uuid,
     'c1000003-0000-4000-8000-000000000001'::uuid,
     'c1000004-0000-4000-8000-000000000001'::uuid,
     'c1000005-0000-4000-8000-000000000001'::uuid,
     'c1000006-0000-4000-8000-000000000001'::uuid,
     'c1000007-0000-4000-8000-000000000001'::uuid,
     'c1000008-0000-4000-8000-000000000001'::uuid,
     'c1000009-0000-4000-8000-000000000001'::uuid,
     'c100000a-0000-4000-8000-000000000001'::uuid,
     'c100000b-0000-4000-8000-000000000001'::uuid,
     'c100000c-0000-4000-8000-000000000001'::uuid,
     'c100000d-0000-4000-8000-000000000001'::uuid,
     'c100000e-0000-4000-8000-000000000001'::uuid,
     'c100000f-0000-4000-8000-000000000001'::uuid
   );

delete from public.notifications
where user_id in (
  select id
  from auth.users
  where email like '%@motoconecta.seed'
);

delete from public.products
where owner_id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000001'::uuid,
  'c1000003-0000-4000-8000-000000000001'::uuid,
  'c1000004-0000-4000-8000-000000000001'::uuid,
  'c1000005-0000-4000-8000-000000000001'::uuid,
  'c1000006-0000-4000-8000-000000000001'::uuid,
  'c1000007-0000-4000-8000-000000000001'::uuid,
  'c1000008-0000-4000-8000-000000000001'::uuid,
  'c1000009-0000-4000-8000-000000000001'::uuid,
  'c100000a-0000-4000-8000-000000000001'::uuid,
  'c100000b-0000-4000-8000-000000000001'::uuid,
  'c100000c-0000-4000-8000-000000000001'::uuid,
  'c100000d-0000-4000-8000-000000000001'::uuid,
  'c100000e-0000-4000-8000-000000000001'::uuid,
  'c100000f-0000-4000-8000-000000000001'::uuid
);

delete from public.profiles
where id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000001'::uuid,
  'c1000003-0000-4000-8000-000000000001'::uuid,
  'c1000004-0000-4000-8000-000000000001'::uuid,
  'c1000005-0000-4000-8000-000000000001'::uuid,
  'c1000006-0000-4000-8000-000000000001'::uuid,
  'c1000007-0000-4000-8000-000000000001'::uuid,
  'c1000008-0000-4000-8000-000000000001'::uuid,
  'c1000009-0000-4000-8000-000000000001'::uuid,
  'c100000a-0000-4000-8000-000000000001'::uuid,
  'c100000b-0000-4000-8000-000000000001'::uuid,
  'c100000c-0000-4000-8000-000000000001'::uuid,
  'c2000001-0000-4000-8000-000000000001'::uuid,
  'c2000002-0000-4000-8000-000000000001'::uuid,
  'c2000003-0000-4000-8000-000000000001'::uuid,
  'c3000001-0000-4000-8000-000000000001'::uuid,
  'c3000002-0000-4000-8000-000000000001'::uuid
);

delete from auth.identities
where user_id in (select id from auth.users where email like '%@motoconecta.seed');

delete from auth.users
where email like '%@motoconecta.seed';

-- ---------------------------------------------------------------------------
-- auth.users + identities (15 importadores, 3 aliados, 2 admins)
-- ---------------------------------------------------------------------------
with inst as (
  select coalesce(
    (select id from auth.instances limit 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ) as instance_id
),
seed_users (id, email) as (
  values
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'importador1@motoconecta.seed'),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'importador2@motoconecta.seed'),
    ('c1000003-0000-4000-8000-000000000001'::uuid, 'importador3@motoconecta.seed'),
    ('c1000004-0000-4000-8000-000000000001'::uuid, 'importador4@motoconecta.seed'),
    ('c1000005-0000-4000-8000-000000000001'::uuid, 'importador5@motoconecta.seed'),
    ('c1000006-0000-4000-8000-000000000001'::uuid, 'importador6@motoconecta.seed'),
    ('c1000007-0000-4000-8000-000000000001'::uuid, 'importador7@motoconecta.seed'),
    ('c1000008-0000-4000-8000-000000000001'::uuid, 'importador8@motoconecta.seed'),
    ('c1000009-0000-4000-8000-000000000001'::uuid, 'importador9@motoconecta.seed'),
    ('c100000a-0000-4000-8000-000000000001'::uuid, 'importador10@motoconecta.seed'),
    ('c100000b-0000-4000-8000-000000000001'::uuid, 'importador11@motoconecta.seed'),
    ('c100000c-0000-4000-8000-000000000001'::uuid, 'importador12@motoconecta.seed'),
    ('c100000d-0000-4000-8000-000000000001'::uuid, 'importador13@motoconecta.seed'),
    ('c100000e-0000-4000-8000-000000000001'::uuid, 'importador14@motoconecta.seed'),
    ('c100000f-0000-4000-8000-000000000001'::uuid, 'importador15@motoconecta.seed'),
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c2000002-0000-4000-8000-000000000001'::uuid, 'aliado2@motoconecta.seed'),
    ('c2000003-0000-4000-8000-000000000001'::uuid, 'aliado3@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed'),
    ('c3000002-0000-4000-8000-000000000001'::uuid, 'admin2@motoconecta.seed')
)
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
select
  inst.instance_id,
  s.id,
  'authenticated',
  'authenticated',
  s.email,
  crypt('SeedPass123!', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now(),
  '',
  '',
  '',
  ''
from inst
cross join seed_users s;

insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  s.id,
  jsonb_build_object(
    'sub', s.id::text,
    'email', s.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  s.email,
  now(),
  now(),
  now()
from (
  values
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'importador1@motoconecta.seed'),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'importador2@motoconecta.seed'),
    ('c1000003-0000-4000-8000-000000000001'::uuid, 'importador3@motoconecta.seed'),
    ('c1000004-0000-4000-8000-000000000001'::uuid, 'importador4@motoconecta.seed'),
    ('c1000005-0000-4000-8000-000000000001'::uuid, 'importador5@motoconecta.seed'),
    ('c1000006-0000-4000-8000-000000000001'::uuid, 'importador6@motoconecta.seed'),
    ('c1000007-0000-4000-8000-000000000001'::uuid, 'importador7@motoconecta.seed'),
    ('c1000008-0000-4000-8000-000000000001'::uuid, 'importador8@motoconecta.seed'),
    ('c1000009-0000-4000-8000-000000000001'::uuid, 'importador9@motoconecta.seed'),
    ('c100000a-0000-4000-8000-000000000001'::uuid, 'importador10@motoconecta.seed'),
    ('c100000b-0000-4000-8000-000000000001'::uuid, 'importador11@motoconecta.seed'),
    ('c100000c-0000-4000-8000-000000000001'::uuid, 'importador12@motoconecta.seed'),
    ('c100000d-0000-4000-8000-000000000001'::uuid, 'importador13@motoconecta.seed'),
    ('c100000e-0000-4000-8000-000000000001'::uuid, 'importador14@motoconecta.seed'),
    ('c100000f-0000-4000-8000-000000000001'::uuid, 'importador15@motoconecta.seed'),
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c2000002-0000-4000-8000-000000000001'::uuid, 'aliado2@motoconecta.seed'),
    ('c2000003-0000-4000-8000-000000000001'::uuid, 'aliado3@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed'),
    ('c3000002-0000-4000-8000-000000000001'::uuid, 'admin2@motoconecta.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

-- ---------------------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------------------
insert into public.profiles (
  id,
  business_name,
  rif,
  role,
  phone,
  logo_storage_path,
  estado,
  ciudad,
  direccion,
  fiscal_maps_url,
  latitude,
  longitude,
  rating_avg_received,
  rating_count_received,
  created_at
)
values
  (
    'c1000001-0000-4000-8000-000000000001',
    'Repuestos Delta Caracas C.A.',
    'J-401234567',
    'importador',
    '+58 424-1000001',
    null,
    'Distrito Capital',
    'Caracas',
    'Torre Empresarial Delta, Av. Francisco de Miranda, piso 4 ofic. 4-B, Urb. Los Palos Grandes, Caracas 1060 (referencia fiscal / almacén).',
    'https://www.google.com/maps?q=10.4969,-66.8488',
    10.4969,
    -66.8488,
    4.60,
    18,
    now()
  ),
  (
    'c1000002-0000-4000-8000-000000000001',
    'Distribuidora Omega Maracay C.A.',
    'J-402345678',
    'importador',
    '+58 424-1000002',
    null,
    'Aragua',
    'Maracay',
    'Av. Bolívar Norte, galpón 7, zona industrial San Jacinto (referencia fiscal / almacén).',
    'https://www.google.com/maps?q=10.2442,-67.6061',
    10.2442,
    -67.6061,
    4.40,
    12,
    now()
  ),
  (
    'c1000003-0000-4000-8000-000000000001',
    'Motopartes Los Teques 2020 C.A.',
    'J-403456789',
    'importador',
    '+58 424-1000003',
    null,
    'Miranda',
    'Los Teques',
    'Av. Principal de Los Teques, galpón 2.',
    'https://www.google.com/maps?q=10.3440,-67.0430',
    10.3440,
    -67.0430,
    4.80,
    40,
    now()
  ),
  (
    'c1000004-0000-4000-8000-000000000001',
    'Importadora Valencia Motor C.A.',
    'J-404567890',
    'importador',
    '+58 424-1000004',
    null,
    'Carabobo',
    'Valencia',
    'Zona industrial Norte, nave 12.',
    'https://www.google.com/maps?q=10.1620,-68.0070',
    10.1620,
    -68.0070,
    4.70,
    28,
    now()
  ),
  (
    'c1000005-0000-4000-8000-000000000001',
    'Barquisimeto Repuestos Biker C.A.',
    'J-405678901',
    'importador',
    '+58 424-1000005',
    null,
    'Lara',
    'Barquisimeto',
    'Av. Rotaria, sector industrial.',
    'https://www.google.com/maps?q=10.0640,-69.3570',
    10.0640,
    -69.3570,
    4.50,
    15,
    now()
  ),
  (
    'c1000006-0000-4000-8000-000000000001',
    'Zulia Cadena y Freno C.A.',
    'J-406789012',
    'importador',
    '+58 424-1000006',
    null,
    'Zulia',
    'Maracaibo',
    'Circunvalación 2, local 8.',
    'https://www.google.com/maps?q=10.6660,-71.6120',
    10.6660,
    -71.6120,
    4.30,
    9,
    now()
  ),
  (
    'c1000007-0000-4000-8000-000000000001',
    'Oriente Eléctrica Moto C.A.',
    'J-407890123',
    'importador',
    '+58 424-1000007',
    null,
    'Anzoátegui',
    'Barcelona',
    'Av. El Ejército, bodega 3.',
    'https://www.google.com/maps?q=10.1360,-64.6860',
    10.1360,
    -64.6860,
    4.20,
    6,
    now()
  ),
  (
    'c1000008-0000-4000-8000-000000000001',
    'Guayana Lubricantes y Filtros C.A.',
    'J-408901234',
    'importador',
    '+58 424-1000008',
    null,
    'Bolívar',
    'Ciudad Guayana',
    'Av. Atlántico, sector industrial.',
    'https://www.google.com/maps?q=8.3500,-62.6300',
    8.3500,
    -62.6300,
    4.10,
    4,
    now()
  ),
  (
    'c1000009-0000-4000-8000-000000000001',
    'Andes Transmisión San Cristóbal C.A.',
    'J-409012345',
    'importador',
    '+58 424-1000009',
    null,
    'Táchira',
    'San Cristóbal',
    'Carretera Panamericana, galpón 5.',
    'https://www.google.com/maps?q=7.7660,-72.2250',
    7.7660,
    -72.2250,
    3.90,
    2,
    now()
  ),
  (
    'c100000a-0000-4000-8000-000000000001',
    'Maturín Motos Arranque S.R.L.',
    'J-410123456',
    'importador',
    '+58 424-1000010',
    null,
    'Monagas',
    'Maturín',
    'Av. Alirio Ugarte Pelayo, local 1.',
    'https://www.google.com/maps?q=9.7460,-63.1830',
    9.7460,
    -63.1830,
    4.00,
    1,
    now()
  ),
  (
    'c100000b-0000-4000-8000-000000000001',
    'Accesorios Punto Fijo C.A.',
    'J-411234567',
    'importador',
    '+58 424-1000011',
    null,
    'Falcón',
    'Punto Fijo',
    'Av. José Silva Bautista, bodega 2.',
    'https://www.google.com/maps?q=11.6910,-70.1990',
    11.6910,
    -70.1990,
    null,
    0,
    now()
  ),
  (
    'c100000c-0000-4000-8000-000000000001',
    'Margarita Moto Base C.A.',
    'J-412345678',
    'importador',
    '+58 424-1000012',
    null,
    'Nueva Esparta',
    'Porlamar',
    'Av. 4 de Mayo, sector comercial.',
    'https://www.google.com/maps?q=10.9570,-63.8700',
    10.9570,
    -63.8700,
    null,
    0,
    now()
  ),
  (
    'c2000001-0000-4000-8000-000000000001',
    'Taller Moto Ruices C.A.',
    'J-501234567',
    'aliado',
    '+58 414-2000001',
    null,
    'Miranda',
    'Caracas',
    'Av. Francisco de Miranda, Los Ruices, local 14 (frente estación), sector fiscal Caracas 1070.',
    'https://www.google.com/maps?q=10.4289,-66.8092',
    10.4289,
    -66.8092,
    null,
    0,
    now()
  ),
  (
    'c3000001-0000-4000-8000-000000000001',
    'MotoLink Operaciones C.A.',
    'J-300123456',
    'administrador',
    '+58 212-3000001',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    0,
    now()
  ),
  (
    'c100000d-0000-4000-8000-000000000001',
    'Cúcuta Motopartes Limpia C.A.',
    'J-413456789',
    'importador',
    '+58 424-1000013',
    null,
    'Táchira',
    'San Cristóbal',
    'Av. Universidad, galpón 1 (catálogo vacío; carga masiva desde plantilla).',
    'https://www.google.com/maps?q=7.7660,-72.2250',
    7.7660,
    -72.2250,
    null,
    0,
    now()
  ),
  (
    'c100000e-0000-4000-8000-000000000001',
    'Trujillo Cadena Express C.A.',
    'J-414567890',
    'importador',
    '+58 424-1000014',
    null,
    'Trujillo',
    'Valera',
    'Zona industrial Los Apamates, nave 4 (catálogo vacío; carga masiva).',
    'https://www.google.com/maps?q=9.3170,-70.6040',
    9.3170,
    -70.6040,
    null,
    0,
    now()
  ),
  (
    'c100000f-0000-4000-8000-000000000001',
    'Puerto Ordaz Lubricantes C.A.',
    'J-415678901',
    'importador',
    '+58 424-1000015',
    null,
    'Bolívar',
    'Puerto Ordaz',
    'Av. Venezuela, sector industrial (catálogo vacío; carga masiva).',
    'https://www.google.com/maps?q=8.2890,-62.7300',
    8.2890,
    -62.7300,
    null,
    0,
    now()
  ),
  (
    'c2000002-0000-4000-8000-000000000001',
    'Taller Moto La California C.A.',
    'J-502345678',
    'aliado',
    '+58 414-2000002',
    null,
    'Miranda',
    'Caracas',
    'Av. Francisco de Miranda, La California, local 3 (sin pedidos demo).',
    'https://www.google.com/maps?q=10.4750,-66.8350',
    10.4750,
    -66.8350,
    null,
    0,
    now()
  ),
  (
    'c2000003-0000-4000-8000-000000000001',
    'Servicio Biker El Hatillo C.A.',
    'J-503456789',
    'aliado',
    '+58 414-2000003',
    null,
    'Miranda',
    'El Hatillo',
    'Calle principal El Hatillo, local 7 (sin pedidos demo).',
    'https://www.google.com/maps?q=10.4250,-66.8250',
    10.4250,
    -66.8250,
    null,
    0,
    now()
  ),
  (
    'c3000002-0000-4000-8000-000000000001',
    'MotoLink Soporte Operaciones C.A.',
    'J-300234567',
    'administrador',
    '+58 212-3000002',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    0,
    now()
  )
on conflict (id) do update set
  business_name = excluded.business_name,
  rif = excluded.rif,
  role = excluded.role,
  phone = excluded.phone,
  logo_storage_path = excluded.logo_storage_path,
  estado = excluded.estado,
  ciudad = excluded.ciudad,
  direccion = excluded.direccion,
  fiscal_maps_url = excluded.fiscal_maps_url,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  rating_avg_received = excluded.rating_avg_received,
  rating_count_received = excluded.rating_count_received;

-- Demo E2.1: ventana rolling = histórico mientras no hay order_ratings en seed.
update public.profiles
set
  rating_avg_received_rolling100 = rating_avg_received,
  rating_count_received_rolling100 = rating_count_received
where rating_avg_received is not null;

-- ---------------------------------------------------------------------------
-- Catálogo: importador1/2 → 15 SKU; importador3–12 → 5 SKU; importador13–15 → vacío (plantilla Excel)
-- ---------------------------------------------------------------------------
insert into public.products (
  id,
  owner_id,
  name,
  description,
  compatibility,
  sku,
  category,
  price_usd,
  stock,
  is_active
)
values
  ('d1000001-0000-4000-8000-000000000001', 'c1000001-0000-4000-8000-000000000001', 'Kit embrague completo 125 cc', 'Juego disco, campana y resortes.', 'Honda CG 125 / Titan 150 / Wave 110', 'DELTA-EMB-125', 'Transmisión', 45.0000, 120, true),
  ('d1000001-0000-4000-8000-000000000002', 'c1000001-0000-4000-8000-000000000001', 'Cadena DID 428 × 118 eslabones', 'Cadena reforzada con retenes.', 'Empire Keeway Aragua 110–150 cc', 'DID-428-118', 'Transmisión', 32.0000, 200, true),
  ('d1000001-0000-4000-8000-000000000003', 'c1000001-0000-4000-8000-000000000001', 'Pastillas freno delantero Ferodo', 'Compuesto orgánico.', 'Yamaha YBR 125 / Crypton', 'FERODO-FP187', 'Frenos', 18.0000, 85, true),
  ('d1000001-0000-4000-8000-000000000004', 'c1000001-0000-4000-8000-000000000001', 'Disco freno delantero 245 mm', 'Acero inoxidable.', 'Suzuki GN 125 / Haojue 150', 'EBC-MD2001', 'Frenos', 52.0000, 40, true),
  ('d1000001-0000-4000-8000-000000000005', 'c1000001-0000-4000-8000-000000000001', 'Cable acelerador 1.20 m', 'Nylon interior.', 'Universal 125–150 cc', 'ALL-BAL-120', 'Transmisión', 6.0000, 150, true),
  ('d1000001-0000-4000-8000-000000000006', 'c1000001-0000-4000-8000-000000000001', 'Cable embrague reforzado', 'Recubierto teflón.', 'Universal 125–150 cc', 'ALL-CLU-120', 'Transmisión', 8.0000, 130, true),
  ('d1000001-0000-4000-8000-000000000007', 'c1000001-0000-4000-8000-000000000001', 'Aceite Mobil 4T 20W50 1 L', 'Sintético API SL.', '4T 125–200 cc', 'MOB-4T-20W50-1L', 'Motor', 8.5000, 280, true),
  ('d1000001-0000-4000-8000-000000000008', 'c1000001-0000-4000-8000-000000000001', 'Bujía NGK Iridium CR7HSA', 'Encendido estable.', 'Honda Wave / Biz 125', 'NGK-CR7HSA', 'Motor', 5.2000, 320, true),
  ('d1000001-0000-4000-8000-000000000009', 'c1000001-0000-4000-8000-000000000001', 'Filtro aire espuma K&N', 'Lavable.', 'CG 125 / Titan', 'K&N-RC-1200', 'Transmisión', 12.0000, 140, true),
  ('d1000001-0000-4000-8000-000000000010', 'c1000001-0000-4000-8000-000000000001', 'Batería Yuasa 12N9-BS gel', 'Sellada.', '125–150 cc estándar', 'YUASA-12N9-BS', 'Motor', 62.0000, 35, true),
  ('d1000001-0000-4000-8000-000000000011', 'c1000001-0000-4000-8000-000000000001', 'Bobina CDI 2 pin', 'Alta tensión.', 'CG 125 / Yamaha 125', 'NGK-COP-2P', 'Motor', 5.2000, 70, true),
  ('d1000001-0000-4000-8000-000000000012', 'c1000001-0000-4000-8000-000000000001', 'Regulador 12 V 8 cables', 'Con tierra.', 'Universal chino 125–150', 'REG-12V-8C', 'Motor', 19.0000, 60, true),
  ('d1000001-0000-4000-8000-000000000013', 'c1000001-0000-4000-8000-000000000001', 'Amortiguador trasero 325 mm', '5 posiciones.', 'Underbone 125–150', 'YSS-325-ADJ', 'Motor', 88.0000, 22, true),
  ('d1000001-0000-4000-8000-000000000014', 'c1000001-0000-4000-8000-000000000001', 'Kit rodamiento rueda delantera', 'Par sellado.', 'Honda CG / Yamaha YBR', 'SKF-6202-2RS', 'Transmisión', 16.0000, 100, true),
  ('d1000001-0000-4000-8000-000000000015', 'c1000001-0000-4000-8000-000000000001', 'Silenciador 125 cc homologado', 'Acero inox.', 'CG 125 / Empire', 'PRO-EX-125', 'Transmisión', 95.0000, 12, true),
  ('d1000002-0000-4000-8000-000000000001', 'c1000002-0000-4000-8000-000000000001', 'Kit embrague 150 cc reforzado', 'Uso comercial.', 'Bera Sbr 150 / Owen 150', 'OMEGA-EMB-150', 'Transmisión', 45.0000, 120, true),
  ('d1000002-0000-4000-8000-000000000002', 'c1000002-0000-4000-8000-000000000001', 'Cadena RK 520 O-ring 120 eslab.', 'Alta resistencia.', 'TVS Apache 160 / Pulsar 150', 'RK-520-120', 'Transmisión', 35.0000, 200, true),
  ('d1000002-0000-4000-8000-000000000003', 'c1000002-0000-4000-8000-000000000001', 'Pastillas sinterizadas delanteras', 'Brembo compatible.', 'Pulsar 135 / FZ 150', 'BREMBO-SIN-03', 'Frenos', 45.0000, 85, true),
  ('d1000002-0000-4000-8000-000000000004', 'c1000002-0000-4000-8000-000000000001', 'Disco flotante 260 mm', 'Acero flotante.', 'Pulsar 160 / NS 160', 'GALFER-DF260', 'Frenos', 18.0000, 40, true),
  ('d1000002-0000-4000-8000-000000000005', 'c1000002-0000-4000-8000-000000000001', 'Cable acelerador 1.35 m', 'Reforzado.', '150–200 cc', 'ALL-BAL-135', 'Transmisión', 6.0000, 150, true),
  ('d1000002-0000-4000-8000-000000000006', 'c1000002-0000-4000-8000-000000000001', 'Cable embrague teflón', 'Baja fricción.', '150 cc', 'ALL-CLU-TEF', 'Transmisión', 8.0000, 130, true),
  ('d1000002-0000-4000-8000-000000000007', 'c1000002-0000-4000-8000-000000000001', 'Aceite Shell Advance 15W50', 'Semi-sintético 1 L.', '4T 150–200 cc', 'SHELL-15W50-1L', 'Motor', 9.1000, 280, true),
  ('d1000002-0000-4000-8000-000000000008', 'c1000002-0000-4000-8000-000000000001', 'Bujía NGK Platino CR8E', 'Mayor duración.', 'Pulsar / FZ / Gixxer', 'NGK-CR8E', 'Motor', 5.2000, 320, true),
  ('d1000002-0000-4000-8000-000000000009', 'c1000002-0000-4000-8000-000000000001', 'Filtro aire Mann C 14', 'Papel alto flujo.', 'Pulsar 150', 'MANN-C-14', 'Transmisión', 10.5000, 140, true),
  ('d1000002-0000-4000-8000-000000000010', 'c1000002-0000-4000-8000-000000000001', 'Batería Yuasa 12N12-BS AGM', 'Mayor CCA.', '150–180 cc', 'YUASA-12N12', 'Motor', 62.0000, 35, true),
  ('d1000002-0000-4000-8000-000000000011', 'c1000002-0000-4000-8000-000000000001', 'Bobina 3 pin performance', 'CDI racing.', 'Pulsar NS / RS', 'NGK-COP-3P', 'Motor', 5.2000, 70, true),
  ('d1000002-0000-4000-8000-000000000012', 'c1000002-0000-4000-8000-000000000001', 'Rectificador 11 cables', 'Completo.', '150–200 cc', 'REG-12V-11C', 'Motor', 19.0000, 60, true),
  ('d1000002-0000-4000-8000-000000000013', 'c1000002-0000-4000-8000-000000000001', 'Amortiguador gas 330 mm', 'Nitrógeno.', 'Underbone 150', 'YSS-330-GAS', 'Motor', 88.0000, 22, true),
  ('d1000002-0000-4000-8000-000000000014', 'c1000002-0000-4000-8000-000000000001', 'Rodamiento rueda trasera', 'Par 6301.', 'Pulsar / FZ', 'SKF-6301-2RS', 'Transmisión', 16.0000, 100, true),
  ('d1000002-0000-4000-8000-000000000015', 'c1000002-0000-4000-8000-000000000001', 'Escape corto 150 cc', 'Deportivo.', 'Pulsar 150', 'PRO-EX-150', 'Transmisión', 95.0000, 12, true),
  ('d1000003-0000-4000-8000-000000000001', 'c1000003-0000-4000-8000-000000000001', 'Cadena DID 428 estándar', '118 eslabones.', 'CG 125 / Aragua', 'LTEK-DID-428', 'Transmisión', 32.0000, 80, true),
  ('d1000003-0000-4000-8000-000000000002', 'c1000003-0000-4000-8000-000000000001', 'Pastillas Ferodo delanteras', 'Orgánico.', 'YBR 125', 'LTEK-FER-FP', 'Frenos', 18.0000, 90, true),
  ('d1000003-0000-4000-8000-000000000003', 'c1000003-0000-4000-8000-000000000001', 'Aceite Mobil 4T 1 L', '20W50.', '125 cc', 'LTEK-MOB-1L', 'Motor', 8.5000, 120, true),
  ('d1000003-0000-4000-8000-000000000004', 'c1000003-0000-4000-8000-000000000001', 'Bujía NGK CR7HSA', 'Iridium.', 'Wave / Biz', 'LTEK-NGK-7', 'Motor', 5.2000, 150, true),
  ('d1000003-0000-4000-8000-000000000005', 'c1000003-0000-4000-8000-000000000001', 'Filtro espuma K&N', 'Lavable.', 'CG / Titan', 'LTEK-KN-FOAM', 'Transmisión', 9.9000, 100, true),
  ('d1000004-0000-4000-8000-000000000001', 'c1000004-0000-4000-8000-000000000001', 'Cadena RK 520 O-ring', '120 eslabones.', '150–160 cc', 'VAL-RK-520', 'Transmisión', 35.0000, 80, true),
  ('d1000004-0000-4000-8000-000000000002', 'c1000004-0000-4000-8000-000000000001', 'Disco EBC 245 mm', 'Inox.', 'GN 125', 'VAL-EBC-245', 'Frenos', 52.0000, 90, true),
  ('d1000004-0000-4000-8000-000000000003', 'c1000004-0000-4000-8000-000000000001', 'Cable acelerador 1.35 m', 'Universal.', '150 cc', 'VAL-BAL-135', 'Transmisión', 6.0000, 120, true),
  ('d1000004-0000-4000-8000-000000000004', 'c1000004-0000-4000-8000-000000000001', 'Batería 12N9-BS gel', 'Sellada.', '125–150', 'VAL-YUA-12N9', 'Motor', 62.0000, 150, true),
  ('d1000004-0000-4000-8000-000000000005', 'c1000004-0000-4000-8000-000000000001', 'Bobina CDI 2 pin', 'OEM tipo.', 'CG 125', 'VAL-CDI-2P', 'Motor', 12.0000, 100, true),
  ('d1000005-0000-4000-8000-000000000001', 'c1000005-0000-4000-8000-000000000001', 'Kit embrague 125', 'Completo.', 'CG / Empire', 'BAR-EMB-125', 'Transmisión', 45.0000, 80, true),
  ('d1000005-0000-4000-8000-000000000002', 'c1000005-0000-4000-8000-000000000001', 'Pastillas sinterizadas', 'Delantero.', 'Pulsar 135', 'BAR-SIN-PAD', 'Frenos', 12.0000, 90, true),
  ('d1000005-0000-4000-8000-000000000003', 'c1000005-0000-4000-8000-000000000001', 'Aceite Shell 15W50 1 L', 'Semi-sintético.', '150 cc', 'BAR-SHL-15W', 'Transmisión', 12.0000, 120, true),
  ('d1000005-0000-4000-8000-000000000004', 'c1000005-0000-4000-8000-000000000001', 'Regulador 8 cables', '12 V.', '125–150', 'BAR-REG-8C', 'Motor', 19.0000, 150, true),
  ('d1000005-0000-4000-8000-000000000005', 'c1000005-0000-4000-8000-000000000001', 'Rodamiento 6202 2RS', 'Par delantero.', 'CG / YBR', 'BAR-SKF-6202', 'Transmisión', 16.0000, 100, true),
  ('d1000006-0000-4000-8000-000000000001', 'c1000006-0000-4000-8000-000000000001', 'Cadena 520 reforzada', '120 eslab.', '150 cc', 'ZUL-RK-520', 'Transmisión', 35.0000, 80, true),
  ('d1000006-0000-4000-8000-000000000002', 'c1000006-0000-4000-8000-000000000001', 'Pastillas orgánicas Ferodo', 'Delantero.', '125 cc', 'ZUL-FER-ORG', 'Frenos', 18.0000, 90, true),
  ('d1000006-0000-4000-8000-000000000003', 'c1000006-0000-4000-8000-000000000001', 'Aceite mineral 4T 1 L', '20W50.', '125–150', 'ZUL-MIN-1L', 'Motor', 12.0000, 120, true),
  ('d1000006-0000-4000-8000-000000000004', 'c1000006-0000-4000-8000-000000000001', 'Bujía NGK CR7HS', 'Estándar.', 'Universal', 'ZUL-NGK-STD', 'Motor', 5.2000, 150, true),
  ('d1000006-0000-4000-8000-000000000005', 'c1000006-0000-4000-8000-000000000001', 'Filtro aceite Mann', 'Cartucho.', 'CG / Smash', 'ZUL-OIL-FIL', 'Transmisión', 12.0000, 100, true),
  ('d1000007-0000-4000-8000-000000000001', 'c1000007-0000-4000-8000-000000000001', 'Bobina 3 pin', 'Alta tensión.', 'Pulsar', 'ORI-COP-3P', 'Motor', 24.0000, 80, true),
  ('d1000007-0000-4000-8000-000000000002', 'c1000007-0000-4000-8000-000000000001', 'CDI digital', 'Programable.', '150 cc', 'ORI-CDI-DIG', 'Motor', 12.0000, 90, true),
  ('d1000007-0000-4000-8000-000000000003', 'c1000007-0000-4000-8000-000000000001', 'Batería 12N12 AGM', 'Sellada.', '150–180', 'ORI-YUA-12N12', 'Motor', 62.0000, 120, true),
  ('d1000007-0000-4000-8000-000000000004', 'c1000007-0000-4000-8000-000000000001', 'Relé arranque 12 V', '4 patas.', 'Universal', 'ORI-REL-ARR', 'Motor', 12.0000, 150, true),
  ('d1000007-0000-4000-8000-000000000005', 'c1000007-0000-4000-8000-000000000001', 'Kit fusibles moto', '10 piezas.', '12 V', 'ORI-FUS-KIT', 'Motor', 12.0000, 100, true),
  ('d1000008-0000-4000-8000-000000000001', 'c1000008-0000-4000-8000-000000000001', 'Aceite Mobil 20W50 1 L', '4T.', '125–200', 'GUY-MOB-20W50', 'Motor', 8.5000, 80, true),
  ('d1000008-0000-4000-8000-000000000002', 'c1000008-0000-4000-8000-000000000001', 'Filtro aire espuma', 'Lavable.', 'CG', 'GUY-KN-FOAM', 'Motor', 9.9000, 90, true),
  ('d1000008-0000-4000-8000-000000000003', 'c1000008-0000-4000-8000-000000000001', 'Filtro aceite Mann', 'Cartucho.', 'Smash / CG', 'GUY-MANN-OIL', 'Motor', 10.5000, 120, true),
  ('d1000008-0000-4000-8000-000000000004', 'c1000008-0000-4000-8000-000000000001', 'Tapón cárter 14 mm', 'Magnético.', 'Universal', 'GUY-TAP-14', 'Motor', 12.0000, 150, true),
  ('d1000008-0000-4000-8000-000000000005', 'c1000008-0000-4000-8000-000000000001', 'Aditivo 4T 60 ml', 'Anti-desgaste.', '4T', 'GUY-ADD-4T', 'Motor', 12.0000, 100, true),
  ('d1000009-0000-4000-8000-000000000001', 'c1000009-0000-4000-8000-000000000001', 'Piñón 15 dientes', 'Acero.', '428 cadena', 'AND-PIN-15T', 'Transmisión', 12.0000, 80, true),
  ('d1000009-0000-4000-8000-000000000002', 'c1000009-0000-4000-8000-000000000001', 'Corona 38 dientes', 'Acero.', 'CG / YBR', 'AND-COR-38T', 'Transmisión', 12.0000, 90, true),
  ('d1000009-0000-4000-8000-000000000003', 'c1000009-0000-4000-8000-000000000001', 'Cadena 428H reforzada', '110 eslab.', '125 cc', 'AND-CHN-428H', 'Transmisión', 32.0000, 120, true),
  ('d1000009-0000-4000-8000-000000000004', 'c1000009-0000-4000-8000-000000000001', 'Tensor cadena', 'Tornillo.', 'Underbone', 'AND-TEN-110', 'Transmisión', 12.0000, 150, true),
  ('d1000009-0000-4000-8000-000000000005', 'c1000009-0000-4000-8000-000000000001', 'Kit retenes horquilla', '35 mm.', '125 cc', 'AND-RET-KIT', 'Transmisión', 12.0000, 100, true),
  ('d100000a-0000-4000-8000-000000000001', 'c100000a-0000-4000-8000-000000000001', 'Bendix arranque 125', 'OEM tipo.', 'CG / Wave', 'MAT-BEN-125', 'Motor', 12.0000, 80, true),
  ('d100000a-0000-4000-8000-000000000002', 'c100000a-0000-4000-8000-000000000001', 'Solenoide arranque', '12 V.', '125–150', 'MAT-SOL-12V', 'Motor', 12.0000, 90, true),
  ('d100000a-0000-4000-8000-000000000003', 'c100000a-0000-4000-8000-000000000001', 'Motor de arranque', '12 V 0.9 kW.', 'CG 125', 'MAT-STR-MTR', 'Motor', 12.0000, 120, true),
  ('d100000a-0000-4000-8000-000000000004', 'c100000a-0000-4000-8000-000000000001', 'Cable batería 30 cm', 'Par.', 'Universal', 'MAT-CBL-BAT', 'Motor', 12.0000, 150, true),
  ('d100000a-0000-4000-8000-000000000005', 'c100000a-0000-4000-8000-000000000001', 'Porta fusibles inline', 'Con tapa.', '12 V', 'MAT-FUS-HLD', 'Motor', 12.0000, 100, true),
  ('d100000b-0000-4000-8000-000000000001', 'c100000b-0000-4000-8000-000000000001', 'Espejo retrovisor izquierdo', 'Rosca 10 mm.', 'Universal', 'PFJ-MIR-L', 'Accesorios', 12.0000, 80, true),
  ('d100000b-0000-4000-8000-000000000002', 'c100000b-0000-4000-8000-000000000001', 'Manilla freno derecha', 'Aluminio.', '125 cc', 'PFJ-LEV-R', 'Frenos', 12.0000, 90, true),
  ('d100000b-0000-4000-8000-000000000003', 'c100000b-0000-4000-8000-000000000001', 'Grip 22 mm par', 'Goma.', 'Universal', 'PFJ-GRP-22', 'Accesorios', 12.0000, 120, true),
  ('d100000b-0000-4000-8000-000000000004', 'c100000b-0000-4000-8000-000000000001', 'LED stop 12 V', 'Homologado.', '125–150', 'PFJ-LED-STP', 'Accesorios', 12.0000, 150, true),
  ('d100000b-0000-4000-8000-000000000005', 'c100000b-0000-4000-8000-000000000001', 'Tapa tanque gasolina', 'Con llave.', 'CG / Smash', 'PFJ-CAP-GAS', 'Accesorios', 12.0000, 100, true),
  ('d100000c-0000-4000-8000-000000000001', 'c100000c-0000-4000-8000-000000000001', 'Tuerca eje 12 mm', 'Grado 8.', 'Rueda delantera', 'NEM-NUT-12', 'Transmisión', 12.0000, 80, true),
  ('d100000c-0000-4000-8000-000000000002', 'c100000c-0000-4000-8000-000000000001', 'Arandela plana 10 mm', 'Inox ×10.', 'Universal', 'NEM-WSH-10', 'Transmisión', 12.0000, 90, true),
  ('d100000c-0000-4000-8000-000000000003', 'c100000c-0000-4000-8000-000000000001', 'Grasa litio 500 g', 'Multiuso.', 'Rodamientos', 'NEM-GRE-LI', 'Motor', 12.0000, 120, true),
  ('d100000c-0000-4000-8000-000000000004', 'c100000c-0000-4000-8000-000000000001', 'Limpiador cadena 400 ml', 'Aerosol.', '428 / 520', 'NEM-CHN-CLN', 'Transmisión', 12.0000, 150, true),
  ('d100000c-0000-4000-8000-000000000005', 'c100000c-0000-4000-8000-000000000001', 'Kit tornillos M6', '50 pzas.', 'Carrocería', 'NEM-BLT-KIT', 'Transmisión', 12.0000, 100, true)
on conflict (id) do update set
  owner_id = excluded.owner_id,
  name = excluded.name,
  description = excluded.description,
  compatibility = excluded.compatibility,
  sku = excluded.sku,
  category = excluded.category,
  price_usd = excluded.price_usd,
  stock = excluded.stock,
  is_active = excluded.is_active;

-- E4 demo: oferta directa y/o tramos por unidades (importadores 1–12)
with seed_e4_pricing (
  product_id,
  sale_price_usd,
  discount_rules
) as (
  values
    -- importador1 (15 SKU en catálogo; aquí 8 con política comercial)
    (
      'd1000001-0000-4000-8000-000000000001'::uuid,
      41.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3},{"min_units":20,"percent_discount":6}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000002'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5},{"min_units":48,"percent_discount":10}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000003'::uuid,
      15.5000,
      '{"volume_tiers":[{"min_units":10,"percent_discount":8}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000007'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":24,"percent_discount":5},{"min_units":72,"percent_discount":8}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000008'::uuid,
      4.2000,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5},{"min_units":48,"percent_discount":8}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000009'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000011'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":15,"percent_discount":4}]}'::jsonb
    ),
    (
      'd1000001-0000-4000-8000-000000000014'::uuid,
      14.0000,
      '{"volume_tiers":[{"min_units":8,"percent_discount":6}]}'::jsonb
    ),
    -- importador2 (8 productos)
    (
      'd1000002-0000-4000-8000-000000000001'::uuid,
      42.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3},{"min_units":18,"percent_discount":7}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000002'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":5},{"min_units":40,"percent_discount":9}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000003'::uuid,
      40.0000,
      '{"volume_tiers":[{"min_units":8,"percent_discount":7}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000007'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":20,"percent_discount":5},{"min_units":60,"percent_discount":8}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000008'::uuid,
      4.5000,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000009'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":6}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000012'::uuid,
      17.0000,
      '{"volume_tiers":[{"min_units":10,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000002-0000-4000-8000-000000000014'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":6,"percent_discount":4},{"min_units":24,"percent_discount":8}]}'::jsonb
    ),
    -- importador3 (3 SKU)
    (
      'd1000003-0000-4000-8000-000000000001'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5},{"min_units":48,"percent_discount":9}]}'::jsonb
    ),
    (
      'd1000003-0000-4000-8000-000000000002'::uuid,
      16.5000,
      '{"volume_tiers":[{"min_units":8,"percent_discount":4}]}'::jsonb
    ),
    (
      'd1000003-0000-4000-8000-000000000004'::uuid,
      4.9000,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}'::jsonb
    ),
    -- importador4
    (
      'd1000004-0000-4000-8000-000000000001'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000004-0000-4000-8000-000000000002'::uuid,
      48.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3}]}'::jsonb
    ),
    (
      'd1000004-0000-4000-8000-000000000003'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":20,"percent_discount":4}]}'::jsonb
    ),
    -- importador5
    (
      'd1000005-0000-4000-8000-000000000001'::uuid,
      42.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3},{"min_units":18,"percent_discount":6}]}'::jsonb
    ),
    (
      'd1000005-0000-4000-8000-000000000002'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":15,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000005-0000-4000-8000-000000000005'::uuid,
      14.5000,
      '{"volume_tiers":[{"min_units":8,"percent_discount":5}]}'::jsonb
    ),
    -- importador6
    (
      'd1000006-0000-4000-8000-000000000002'::uuid,
      16.0000,
      '{"volume_tiers":[{"min_units":10,"percent_discount":7}]}'::jsonb
    ),
    (
      'd1000006-0000-4000-8000-000000000003'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":24,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000006-0000-4000-8000-000000000004'::uuid,
      4.8000,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}'::jsonb
    ),
    -- importador7
    (
      'd1000007-0000-4000-8000-000000000001'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":8,"percent_discount":4}]}'::jsonb
    ),
    (
      'd1000007-0000-4000-8000-000000000003'::uuid,
      58.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3}]}'::jsonb
    ),
    (
      'd1000007-0000-4000-8000-000000000005'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":20,"percent_discount":6}]}'::jsonb
    ),
    -- importador8
    (
      'd1000008-0000-4000-8000-000000000001'::uuid,
      7.8000,
      '{"volume_tiers":[{"min_units":24,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000008-0000-4000-8000-000000000002'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":5}]}'::jsonb
    ),
    (
      'd1000008-0000-4000-8000-000000000003'::uuid,
      9.5000,
      '{"volume_tiers":[{"min_units":12,"percent_discount":4}]}'::jsonb
    ),
    -- importador9
    (
      'd1000009-0000-4000-8000-000000000001'::uuid,
      11.0000,
      '{"volume_tiers":[{"min_units":15,"percent_discount":4}]}'::jsonb
    ),
    (
      'd1000009-0000-4000-8000-000000000003'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5},{"min_units":36,"percent_discount":8}]}'::jsonb
    ),
    (
      'd1000009-0000-4000-8000-000000000004'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":20,"percent_discount":5}]}'::jsonb
    ),
    -- importador10
    (
      'd100000a-0000-4000-8000-000000000001'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}'::jsonb
    ),
    (
      'd100000a-0000-4000-8000-000000000002'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":4}]}'::jsonb
    ),
    (
      'd100000a-0000-4000-8000-000000000003'::uuid,
      11.0000,
      '{"volume_tiers":[{"min_units":6,"percent_discount":3}]}'::jsonb
    ),
    -- importador11
    (
      'd100000b-0000-4000-8000-000000000002'::uuid,
      10.5000,
      '{"volume_tiers":[{"min_units":8,"percent_discount":5}]}'::jsonb
    ),
    (
      'd100000b-0000-4000-8000-000000000004'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":15,"percent_discount":6}]}'::jsonb
    ),
    (
      'd100000b-0000-4000-8000-000000000005'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":10,"percent_discount":4}]}'::jsonb
    ),
    -- importador12
    (
      'd100000c-0000-4000-8000-000000000003'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":12,"percent_discount":5}]}'::jsonb
    ),
    (
      'd100000c-0000-4000-8000-000000000004'::uuid,
      null::numeric,
      '{"volume_tiers":[{"min_units":18,"percent_discount":7}]}'::jsonb
    ),
    (
      'd100000c-0000-4000-8000-000000000005'::uuid,
      10.0000,
      '{"volume_tiers":[{"min_units":20,"percent_discount":5}]}'::jsonb
    )
)
update public.products p
set
  sale_price_usd = v.sale_price_usd,
  discount_rules = v.discount_rules
from seed_e4_pricing v
where p.id = v.product_id;

-- E4 demo: descuento en línea USD (pago Zelle/divisas; % sobre precio REF del catálogo)
with seed_e4_usd_payment_discount (product_id, pct) as (
  values
    -- importador1
    ('d1000001-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000003'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000005'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000007'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000008'::uuid, 3.0),
    ('d1000001-0000-4000-8000-000000000009'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000011'::uuid, 2.0),
    ('d1000001-0000-4000-8000-000000000014'::uuid, 2.5),
    -- importador2
    ('d1000002-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000003'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000005'::uuid, 1.5),
    ('d1000002-0000-4000-8000-000000000007'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000008'::uuid, 3.0),
    ('d1000002-0000-4000-8000-000000000009'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000012'::uuid, 2.0),
    ('d1000002-0000-4000-8000-000000000014'::uuid, 2.0),
    -- importador3
    ('d1000003-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000003-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000003-0000-4000-8000-000000000004'::uuid, 2.5),
    ('d1000003-0000-4000-8000-000000000005'::uuid, 2.5),
    -- importador4
    ('d1000004-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000004-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000004-0000-4000-8000-000000000003'::uuid, 1.5),
    ('d1000004-0000-4000-8000-000000000004'::uuid, 3.0),
    -- importador5
    ('d1000005-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000005-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000005-0000-4000-8000-000000000005'::uuid, 2.0),
    -- importador6
    ('d1000006-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000006-0000-4000-8000-000000000003'::uuid, 2.0),
    ('d1000006-0000-4000-8000-000000000004'::uuid, 2.0),
    ('d1000006-0000-4000-8000-000000000005'::uuid, 1.5),
    -- importador7
    ('d1000007-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000007-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000007-0000-4000-8000-000000000003'::uuid, 2.0),
    ('d1000007-0000-4000-8000-000000000005'::uuid, 2.0),
    -- importador8
    ('d1000008-0000-4000-8000-000000000001'::uuid, 3.0),
    ('d1000008-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d1000008-0000-4000-8000-000000000003'::uuid, 2.0),
    -- importador9
    ('d1000009-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d1000009-0000-4000-8000-000000000003'::uuid, 2.5),
    ('d1000009-0000-4000-8000-000000000004'::uuid, 2.0),
    -- importador10
    ('d100000a-0000-4000-8000-000000000001'::uuid, 2.0),
    ('d100000a-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d100000a-0000-4000-8000-000000000003'::uuid, 2.0),
    -- importador11
    ('d100000b-0000-4000-8000-000000000002'::uuid, 2.0),
    ('d100000b-0000-4000-8000-000000000004'::uuid, 2.0),
    ('d100000b-0000-4000-8000-000000000005'::uuid, 2.0),
    -- importador12
    ('d100000c-0000-4000-8000-000000000003'::uuid, 4.0),
    ('d100000c-0000-4000-8000-000000000004'::uuid, 2.0),
    ('d100000c-0000-4000-8000-000000000005'::uuid, 2.0)
)
update public.products p
set
  discount_rules = coalesce(p.discount_rules, '{}'::jsonb)
    || jsonb_build_object('usd_payment_discount_pct', v.pct)
from seed_e4_usd_payment_discount v
where p.id = v.product_id;

-- ---------------------------------------------------------------------------
-- Pedidos demo E1.1: pago aprobado por importador (confirmado_por = importador_id)
-- paid_lines = líneas que cuentan en catalog_paid_orders_30d (ventana 30 días)
-- ---------------------------------------------------------------------------
with seed_boost_targets (importador_id, paid_lines) as (
  values
    ('c1000001-0000-4000-8000-000000000001'::uuid, 8),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 4),
    ('c1000003-0000-4000-8000-000000000001'::uuid, 14),
    ('c1000004-0000-4000-8000-000000000001'::uuid, 11),
    ('c1000005-0000-4000-8000-000000000001'::uuid, 9),
    ('c1000006-0000-4000-8000-000000000001'::uuid, 7),
    ('c1000007-0000-4000-8000-000000000001'::uuid, 5),
    ('c1000008-0000-4000-8000-000000000001'::uuid, 3),
    ('c1000009-0000-4000-8000-000000000001'::uuid, 2),
    ('c100000a-0000-4000-8000-000000000001'::uuid, 1),
    ('c100000b-0000-4000-8000-000000000001'::uuid, 0),
    ('c100000c-0000-4000-8000-000000000001'::uuid, 0)
),
paid_lines as (
  select
    t.importador_id,
    g.n as line_no
  from seed_boost_targets t
  cross join lateral generate_series(1, t.paid_lines) as g(n)
  where t.paid_lines > 0
),
product_pick as (
  select
    pl.importador_id,
    pl.line_no,
    pick.id as product_id,
    pick.price_usd as unit_price
  from paid_lines pl
  cross join lateral (
    select p.id, p.price_usd
    from public.products p
    where p.owner_id = pl.importador_id
    order by p.sku
    offset (
      (pl.line_no - 1) % greatest(
        (select count(*)::int from public.products p2 where p2.owner_id = pl.importador_id),
        1
      )
    )
    limit 1
  ) pick
)
insert into public.transaction_requests (
  aliado_id,
  importador_id,
  product_id,
  status,
  cantidad,
  precio_total_usd,
  commission_rate_snapshot,
  pago_metodo,
  comprobante_pago_storage_path,
  comprobante_pago_file_name,
  comprobante_pago_submitted_at,
  pago_estado_revision,
  confirmado_por,
  pago_aprobado_at,
  at_entregado,
  created_at,
  updated_at
)
select
  'c2000001-0000-4000-8000-000000000001'::uuid,
  pp.importador_id,
  pp.product_id,
  'entregado'::text,
  1 + (pp.line_no % 3),
  round((pp.unit_price * (1 + (pp.line_no % 3)))::numeric, 4),
  0.05,
  (array['transferencia', 'pago_movil', 'zelle_divisas', 'efectivo', 'binance'])[
    1 + (pp.line_no % 5)
  ],
  'seed/comprobantes/aliado-demo.pdf',
  'comprobante-seed.pdf',
  now() - ((pp.line_no % 25) || ' days')::interval + interval '3 hours',
  'aprobado'::text,
  pp.importador_id,
  now() - ((pp.line_no % 25) || ' days')::interval,
  now() - ((pp.line_no % 25) || ' days')::interval,
  now() - ((pp.line_no % 28) || ' days')::interval,
  now() - ((pp.line_no % 28) || ' days')::interval
from product_pick pp
where pp.product_id is not null;

-- Fuera de ventana 30d (cerrado y pagado; no suma al boost)
insert into public.transaction_requests (
  aliado_id,
  importador_id,
  product_id,
  status,
  cantidad,
  precio_total_usd,
  commission_rate_snapshot,
  pago_metodo,
  pago_estado_revision,
  confirmado_por,
  pago_aprobado_at,
  at_entregado,
  comprobante_pago_storage_path,
  comprobante_pago_file_name,
  comprobante_pago_submitted_at,
  created_at,
  updated_at
)
select
  'c2000001-0000-4000-8000-000000000001'::uuid,
  'c1000003-0000-4000-8000-000000000001'::uuid,
  p.id,
  'entregado',
  1,
  p.price_usd,
  0.05,
  'transferencia',
  'aprobado',
  'c1000003-0000-4000-8000-000000000001'::uuid,
  now() - interval '45 days',
  now() - interval '44 days',
  'seed/comprobantes/antiguo.pdf',
  'comprobante-antiguo.pdf',
  now() - interval '45 days' + interval '2 hours',
  now() - interval '46 days',
  now() - interval '44 days'
from public.products p
where p.owner_id = 'c1000003-0000-4000-8000-000000000001'::uuid
order by p.sku
limit 2;

-- ---------------------------------------------------------------------------
-- E3: tramos comisión por volumen mensual (mes en curso)
-- importador11 — Accesorios Punto Fijo: ~4 500 USD devengado → tramo 5 %
-- importador12 — Margarita Moto Base: ~10 500 USD devengado → tramo 3 %
-- Sin override en profiles.commission_rate_pct (NULL).
-- ---------------------------------------------------------------------------
with e3_month as (
  select
    (
      date_trunc('month', timezone('America/Caracas', now()))
      + interval '5 days'
    ) at time zone 'America/Caracas' as devengo_base
)
insert into public.transaction_requests (
  id,
  aliado_id,
  importador_id,
  product_id,
  status,
  cantidad,
  precio_total_usd,
  commission_rate_snapshot,
  comision_devengada_usd,
  comision_devengada_at,
  pago_metodo,
  comprobante_pago_storage_path,
  comprobante_pago_file_name,
  comprobante_pago_submitted_at,
  pago_estado_revision,
  confirmado_por,
  pago_aprobado_at,
  at_entregado,
  created_at,
  updated_at
)
select
  v.id,
  'c2000001-0000-4000-8000-000000000001'::uuid,
  v.importador_id,
  v.product_id,
  'entregado'::text,
  1,
  v.precio_total_usd,
  v.commission_rate_snapshot,
  round((v.precio_total_usd * v.commission_rate_snapshot)::numeric, 4),
  m.devengo_base + (v.line_no * interval '1 day'),
  (array['pago_movil', 'zelle_divisas', 'transferencia', 'efectivo', 'binance'])[
    1 + (v.line_no % 5)
  ],
  'seed/comprobantes/e3-tramo-demo.pdf',
  'comprobante-e3-tramo.pdf',
  m.devengo_base + (v.line_no * interval '1 day') - interval '8 hours',
  'aprobado'::text,
  v.importador_id,
  m.devengo_base + (v.line_no * interval '1 day') - interval '6 hours',
  m.devengo_base + (v.line_no * interval '1 day'),
  m.devengo_base + (v.line_no * interval '1 day') - interval '1 day',
  m.devengo_base + (v.line_no * interval '1 day')
from e3_month m
cross join (
  values
    (
      'e3b00001-0000-4000-8000-000000000001'::uuid,
      'c100000b-0000-4000-8000-000000000001'::uuid,
      'd100000b-0000-4000-8000-000000000001'::uuid,
      1,
      2000.0000::numeric,
      0.05::numeric
    ),
    (
      'e3b00002-0000-4000-8000-000000000002'::uuid,
      'c100000b-0000-4000-8000-000000000001'::uuid,
      'd100000b-0000-4000-8000-000000000002'::uuid,
      2,
      1500.0000::numeric,
      0.05::numeric
    ),
    (
      'e3b00003-0000-4000-8000-000000000003'::uuid,
      'c100000b-0000-4000-8000-000000000001'::uuid,
      'd100000b-0000-4000-8000-000000000003'::uuid,
      3,
      1000.0000::numeric,
      0.05::numeric
    ),
    (
      'e3c00001-0000-4000-8000-000000000001'::uuid,
      'c100000c-0000-4000-8000-000000000001'::uuid,
      'd100000c-0000-4000-8000-000000000001'::uuid,
      1,
      5500.0000::numeric,
      0.03::numeric
    ),
    (
      'e3c00002-0000-4000-8000-000000000002'::uuid,
      'c100000c-0000-4000-8000-000000000001'::uuid,
      'd100000c-0000-4000-8000-000000000002'::uuid,
      2,
      3000.0000::numeric,
      0.03::numeric
    ),
    (
      'e3c00003-0000-4000-8000-000000000003'::uuid,
      'c100000c-0000-4000-8000-000000000001'::uuid,
      'd100000c-0000-4000-8000-000000000003'::uuid,
      3,
      2000.0000::numeric,
      0.03::numeric
    )
) as v(id, importador_id, product_id, line_no, precio_total_usd, commission_rate_snapshot)
on conflict (id) do update set
  importador_id = excluded.importador_id,
  product_id = excluded.product_id,
  status = excluded.status,
  cantidad = excluded.cantidad,
  precio_total_usd = excluded.precio_total_usd,
  commission_rate_snapshot = excluded.commission_rate_snapshot,
  comision_devengada_usd = excluded.comision_devengada_usd,
  comision_devengada_at = excluded.comision_devengada_at,
  pago_metodo = excluded.pago_metodo,
  pago_estado_revision = excluded.pago_estado_revision,
  confirmado_por = excluded.confirmado_por,
  pago_aprobado_at = excluded.pago_aprobado_at,
  comprobante_pago_submitted_at = excluded.comprobante_pago_submitted_at,
  at_entregado = excluded.at_entregado,
  updated_at = now();

-- Asegurar factura importador, método y comprobante en pedidos demo entregados (aliado1)
update public.transaction_requests tr
set
  proveedor_factura_storage_path = coalesce(
    tr.proveedor_factura_storage_path,
    'seed/facturas/importador-demo.pdf'
  ),
  proveedor_factura_file_name = coalesce(
    tr.proveedor_factura_file_name,
    'factura-importador-seed.pdf'
  ),
  proveedor_factura_submitted_at = coalesce(
    tr.proveedor_factura_submitted_at,
    tr.created_at + interval '1 day',
    tr.updated_at
  ),
  pago_metodo = coalesce(
    tr.pago_metodo,
    (array['transferencia', 'pago_movil', 'zelle_divisas', 'efectivo', 'binance'])[
      1 + (abs(hashtext(tr.id::text)) % 5)
    ]
  ),
  pago_estado_revision = coalesce(tr.pago_estado_revision, 'aprobado'),
  comprobante_pago_storage_path = coalesce(
    tr.comprobante_pago_storage_path,
    'seed/comprobantes/aliado-demo.pdf'
  ),
  comprobante_pago_file_name = coalesce(
    tr.comprobante_pago_file_name,
    'comprobante-seed.pdf'
  ),
  comprobante_pago_submitted_at = coalesce(
    tr.comprobante_pago_submitted_at,
    tr.pago_aprobado_at - interval '4 hours',
    tr.at_entregado - interval '1 day'
  ),
  confirmado_por = coalesce(tr.confirmado_por, tr.importador_id),
  pago_aprobado_at = coalesce(
    tr.pago_aprobado_at,
    tr.at_entregado,
    tr.updated_at
  )
where tr.aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
  and tr.status = 'entregado';

-- Devengo C1 en el resto de pedidos entregados del seed (fechas históricas de at_entregado)
update public.transaction_requests tr
set
  commission_rate_snapshot = coalesce(tr.commission_rate_snapshot, 0.05),
  comision_devengada_usd = round(
    (tr.precio_total_usd * coalesce(tr.commission_rate_snapshot, 0.05))::numeric,
    4
  ),
  comision_devengada_at = coalesce(tr.comision_devengada_at, tr.at_entregado, tr.updated_at, now())
where tr.aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
  and tr.status = 'entregado'
  and tr.comision_devengada_at is null;

-- ---------------------------------------------------------------------------
-- Valoraciones demo (bucket_v2) — solo sobre pedidos entregados y pagados
-- ---------------------------------------------------------------------------
with seed_rate_targets as (
  select
    tr.id,
    tr.importador_id,
    tr.aliado_id,
    tr.at_entregado,
    tr.pago_aprobado_at,
    tr.created_at,
    row_number() over (
      partition by tr.importador_id
      order by tr.created_at desc
    ) as rn
  from public.transaction_requests tr
  where tr.aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
    and tr.status = 'entregado'
    and tr.pago_estado_revision = 'aprobado'
    and tr.confirmado_por = tr.importador_id
),
seed_rate_pick as (
  select *
  from seed_rate_targets t
  where (t.importador_id = 'c1000001-0000-4000-8000-000000000001'::uuid and t.rn <= 8)
     or (t.importador_id = 'c1000002-0000-4000-8000-000000000001'::uuid and t.rn <= 4)
     or (
       t.importador_id in (
         'c1000003-0000-4000-8000-000000000001'::uuid,
         'c1000004-0000-4000-8000-000000000001'::uuid,
         'c1000005-0000-4000-8000-000000000001'::uuid,
         'c1000006-0000-4000-8000-000000000001'::uuid,
         'c1000007-0000-4000-8000-000000000001'::uuid
       )
       and t.rn = 1
     )
)
insert into public.order_ratings (
  transaction_request_id,
  importador_id,
  aliado_id,
  rater_role,
  ratee_role,
  overall_stars,
  comment,
  questionnaire_version,
  answers,
  submitted_at
)
select
  p.id,
  p.importador_id,
  p.aliado_id,
  'aliado',
  'importador',
  case (p.rn % 3)
    when 0 then 5
    when 1 then 4
    else 5
  end,
  case (p.rn % 3)
    when 0 then 'Entrega puntual y producto conforme al catálogo.'
    when 1 then 'Buen despacho; empaque mejorable en una caja.'
    else 'Servicio B2B recomendable para el taller.'
  end,
  'bucket_v2',
  case (p.rn % 3)
    when 0 then '{
      "product_quality": 5,
      "dispatch_time": 5,
      "packaging_condition": 5,
      "communication": 5,
      "supplier_b2b_experience": 5
    }'::jsonb
    when 1 then '{
      "product_quality": 4,
      "dispatch_time": 4,
      "packaging_condition": 3,
      "communication": 4,
      "supplier_b2b_experience": 4
    }'::jsonb
    else '{
      "product_quality": 5,
      "dispatch_time": 4,
      "packaging_condition": 5,
      "communication": 5,
      "supplier_b2b_experience": 5
    }'::jsonb
  end,
  coalesce(p.at_entregado, p.pago_aprobado_at, p.created_at) + interval '12 hours'
from seed_rate_pick p
where not exists (
  select 1
  from public.order_ratings r
  where r.transaction_request_id = p.id
    and r.rater_role = 'aliado'
);

-- Valoración mutua importador → aliado (muestra admin)
with seed_imp_rate as (
  select
    tr.id,
    tr.importador_id,
    tr.aliado_id,
    tr.at_entregado,
    tr.pago_aprobado_at,
    tr.created_at,
    row_number() over (order by tr.created_at desc) as rn
  from public.transaction_requests tr
  where tr.aliado_id = 'c2000001-0000-4000-8000-000000000001'::uuid
    and tr.importador_id = 'c1000001-0000-4000-8000-000000000001'::uuid
    and tr.status = 'entregado'
    and tr.pago_estado_revision = 'aprobado'
    and tr.confirmado_por = tr.importador_id
  limit 2
)
insert into public.order_ratings (
  transaction_request_id,
  importador_id,
  aliado_id,
  rater_role,
  ratee_role,
  overall_stars,
  comment,
  questionnaire_version,
  answers,
  submitted_at
)
select
  s.id,
  s.importador_id,
  s.aliado_id,
  'importador',
  'aliado',
  4,
  'Aliado cumplió plazos de pago y comunicación clara.',
  'bucket_v2',
  '{"communication": 4, "payment_punctuality_transparency": 5}'::jsonb,
  coalesce(s.at_entregado, s.pago_aprobado_at, s.created_at) + interval '1 day'
from seed_imp_rate s
where not exists (
  select 1
  from public.order_ratings r
  where r.transaction_request_id = s.id
    and r.rater_role = 'importador'
);

update public.transaction_requests tr
set
  aliado_experience_stars = r.overall_stars,
  aliado_experience_comment = r.comment,
  aliado_experience_submitted_at = r.submitted_at,
  updated_at = greatest(tr.updated_at, r.submitted_at)
from public.order_ratings r
where r.transaction_request_id = tr.id
  and r.rater_role = 'aliado';

do $$
declare
  v_id uuid;
begin
  for v_id in
    select distinct p.id
    from public.profiles p
    where p.role in ('importador', 'aliado')
      and exists (
        select 1
        from public.order_ratings r
        where r.importador_id = p.id
           or r.aliado_id = p.id
      )
  loop
    perform public.refresh_profile_rating_aggregates(v_id);
  end loop;
end;
$$;

-- Reconciliar agregados E1 (por si triggers se omitieron en carga masiva)
select public.refresh_all_importer_catalog_boost ();

-- Referencia boost (catalog_paid_orders_30d) tras seed — importador3=14, importador4=11, … importador11/12=0:
-- select p.business_name, p.catalog_paid_orders_30d
-- from public.profiles p
-- where p.role = 'importador'
-- order by p.catalog_paid_orders_30d desc, p.business_name;
--
-- Referencia E3 tramos (volumen del mes + tasa efectiva):
-- select
--   p.business_name,
--   u.email,
--   public.motoconecta_importer_monthly_sales_volume_usd(p.id) as volumen_usd_mes,
--   public.motoconecta_commission_rate_for_importador(p.id) as tasa_efectiva
-- from public.profiles p
-- join auth.users u on u.id = p.id
-- where p.id in (
--   'c100000b-0000-4000-8000-000000000001'::uuid,
--   'c100000c-0000-4000-8000-000000000001'::uuid
-- );
-- Esperado: importador11 ~4500 → 0.05; importador12 ~10500 → 0.03
