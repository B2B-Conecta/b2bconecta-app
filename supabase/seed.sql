-- =============================================================================
-- MotoConecta — datos de desarrollo (seed)
-- =============================================================================
-- Requisito: ejecutar antes `supabase/motoconecta/schema.sql` en el mismo proyecto
-- Supabase (base greenfield MotoConecta).
--
-- Carga en SQL Editor (rol con permisos sobre auth y public) o:
--   supabase db query --linked -f supabase/seed.sql
--
-- Contraseña común (todos los seed): SeedPass123!
--   importador1@motoconecta.seed
--   aliado1@motoconecta.seed
--   admin@motoconecta.seed
--
-- Validación comisión: pedido de ejemplo `precio_total_usd = 1000` →
--   `comision_motoconecta` generada = 50.00 (5 %).
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- auth.users + identities (1 importador, 1 aliado, 1 admin)
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
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed')
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
cross join seed_users s
where not exists (
  select 1 from auth.users u where u.id = s.id or u.email = s.email
);

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
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

-- ---------------------------------------------------------------------------
-- Perfiles: 1 importador, 1 aliado, 1 admin (domicilio fiscal de referencia)
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
  created_at
)
values
  (
    'c1000001-0000-4000-8000-000000000001',
    'MotoConecta Import Delta C.A.',
    'J-401111111',
    'importador',
    '+58 424-1000001',
    null,
    'Distrito Capital',
    'Caracas',
    'Torre Empresarial Delta, Av. Francisco de Miranda, piso 4 ofic. 4-B, Urb. Los Palos Grandes, Caracas 1060 (referencia fiscal / almacén).',
    'https://www.google.com/maps?q=10.4969,-66.8488',
    10.4969,
    -66.8488,
    now()
  ),
  (
    'c2000001-0000-4000-8000-000000000001',
    'Taller Aliado Los Ruices',
    'J-501111111',
    'aliado',
    '+58 414-2000001',
    null,
    'Miranda',
    'Caracas',
    'Av. Francisco de Miranda, Los Ruices, local 14 (frente estación), sector fiscal Caracas 1070.',
    'https://www.google.com/maps?q=10.4289,-66.8092',
    10.4289,
    -66.8092,
    now()
  ),
  (
    'c3000001-0000-4000-8000-000000000001',
    'MotoConecta (Supervisor)',
    'J-300000001',
    'administrador',
    '+58 212-3000001',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
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
  longitude = excluded.longitude;

-- ---------------------------------------------------------------------------
-- Catálogo: 15 productos del único importador
-- ---------------------------------------------------------------------------
delete from public.transaction_request_messages
where transaction_request_id = 'e0000001-0000-4000-8000-000000000001'::uuid;

delete from public.transaction_requests
where id = 'e0000001-0000-4000-8000-000000000001'::uuid;

delete from public.products
where owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid;

insert into public.products (
  owner_id,
  name,
  sku,
  category,
  price_usd,
  stock,
  is_active
)
values
  ('c1000001-0000-4000-8000-000000000001', 'Kit embrague 125cc completo', 'MC1-01', 'Transmisión', 45.0000, 120, true),
  ('c1000001-0000-4000-8000-000000000001', 'Cadena 428 — 118 eslabones', 'MC1-02', 'Transmisión', 32.5000, 200, true),
  ('c1000001-0000-4000-8000-000000000001', 'Pastillas freno delantero orgánicas', 'MC1-03', 'Frenos', 18.7500, 85, true),
  ('c1000001-0000-4000-8000-000000000001', 'Disco freno delantero 245 mm', 'MC1-04', 'Frenos', 52.0000, 40, true),
  ('c1000001-0000-4000-8000-000000000001', 'Cable acelerador universal 1.2 m', 'MC1-05', 'Motor', 6.2000, 150, true),
  ('c1000001-0000-4000-8000-000000000001', 'Cable embrague reforzado', 'MC1-06', 'Transmisión', 7.8000, 130, true),
  ('c1000001-0000-4000-8000-000000000001', 'Aceite 4T 20W50 sintético (1 L)', 'MC1-07', 'Motor', 8.5000, 280, true),
  ('c1000001-0000-4000-8000-000000000001', 'Bujía NGK iridium CR7HSA', 'MC1-08', 'Motor', 5.2000, 320, true),
  ('c1000001-0000-4000-8000-000000000001', 'Filtro de aire espuma lavable', 'MC1-09', 'Motor', 9.9000, 140, true),
  ('c1000001-0000-4000-8000-000000000001', 'Batería 12N9-BS gel sellada', 'MC1-10', 'Motor', 62.0000, 35, true),
  ('c1000001-0000-4000-8000-000000000001', 'Bobina alta tensión CDI 2 pin', 'MC1-11', 'Motor', 24.9000, 70, true),
  ('c1000001-0000-4000-8000-000000000001', 'Regulador voltaje 12 V 8 cables', 'MC1-12', 'Motor', 19.5000, 60, true),
  ('c1000001-0000-4000-8000-000000000001', 'Amortiguador trasero 325 mm ajustable', 'MC1-13', 'Motor', 88.0000, 22, true),
  ('c1000001-0000-4000-8000-000000000001', 'Kit rodamiento rueda delantera', 'MC1-14', 'Transmisión', 16.4000, 100, true),
  ('c1000001-0000-4000-8000-000000000001', 'Silenciador deportivo 125 cc homologado', 'MC1-15', 'Motor', 95.0000, 12, true);

-- ---------------------------------------------------------------------------
-- Pedido de ejemplo (pendiente) — comisión 5 % generada
-- ---------------------------------------------------------------------------
insert into public.transaction_requests (
  id,
  aliado_id,
  importador_id,
  product_id,
  status,
  cantidad,
  precio_total_usd,
  factura_url,
  tiempo_estimado_envio
)
values (
  'e0000001-0000-4000-8000-000000000001',
  'c2000001-0000-4000-8000-000000000001',
  'c1000001-0000-4000-8000-000000000001',
  (select p.id from public.products p where p.sku = 'MC1-01' limit 1),
  'pendiente',
  20,
  1000.0000,
  null,
  null
)
on conflict (id) do update set
  aliado_id = excluded.aliado_id,
  importador_id = excluded.importador_id,
  product_id = excluded.product_id,
  status = excluded.status,
  cantidad = excluded.cantidad,
  precio_total_usd = excluded.precio_total_usd,
  factura_url = excluded.factura_url,
  tiempo_estimado_envio = excluded.tiempo_estimado_envio;

insert into public.transaction_request_messages (
  transaction_request_id,
  author_id,
  author_role,
  body
)
select
  'e0000001-0000-4000-8000-000000000001'::uuid,
  'c2000001-0000-4000-8000-000000000001'::uuid,
  'aliado',
  'Hola, confirmamos la solicitud de 20 unidades. Quedamos atentos a su preparación.'
where not exists (
  select 1 from public.transaction_request_messages m
  where m.transaction_request_id = 'e0000001-0000-4000-8000-000000000001'::uuid
    and m.author_id = 'c2000001-0000-4000-8000-000000000001'::uuid
    and m.body like 'Hola, confirmamos la solicitud%'
);
