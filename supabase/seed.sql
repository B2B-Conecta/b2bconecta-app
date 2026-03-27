-- =============================================================================
-- MotoLink Pro — datos de desarrollo (seed)
-- =============================================================================
-- Ejecutar en Supabase → SQL Editor (rol con permisos sobre auth y public).
--
-- Contraseña común (6 usuarios): SeedPass123!
-- Importadores: importador1@motolink.seed … importador3@motolink.seed
-- Aliados:      aliado1@motolink.seed … aliado3@motolink.seed
--
-- Contenido: 6 usuarios auth + perfiles + 30 productos (10 por importador).
-- Re-ejecutar: borra productos seed de esos importadores y vuelve a insertarlos;
--              usuarios/perfiles solo se insertan si no existen.
-- =============================================================================

create extension if not exists pgcrypto;

-- instance_id: Supabase Cloud suele tener 1 fila en auth.instances; si no, UUID nulo-proyecto.
with inst as (
  select coalesce(
    (select id from auth.instances limit 1),
    '00000000-0000-0000-0000-000000000000'::uuid
  ) as instance_id
),
seed_users (id, email) as (
  values
    ('a1000001-0000-4000-8000-000000000001'::uuid, 'importador1@motolink.seed'),
    ('a1000002-0000-4000-8000-000000000002'::uuid, 'importador2@motolink.seed'),
    ('a1000003-0000-4000-8000-000000000003'::uuid, 'importador3@motolink.seed'),
    ('a2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motolink.seed'),
    ('a2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motolink.seed'),
    ('a2000003-0000-4000-8000-000000000003'::uuid, 'aliado3@motolink.seed')
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

-- Identidades email (necesarias para login con contraseña)
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
    ('a1000001-0000-4000-8000-000000000001'::uuid, 'importador1@motolink.seed'),
    ('a1000002-0000-4000-8000-000000000002'::uuid, 'importador2@motolink.seed'),
    ('a1000003-0000-4000-8000-000000000003'::uuid, 'importador3@motolink.seed'),
    ('a2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motolink.seed'),
    ('a2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motolink.seed'),
    ('a2000003-0000-4000-8000-000000000003'::uuid, 'aliado3@motolink.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

-- Perfiles B2B
insert into public.profiles (id, business_name, rif, role, phone, created_at)
values
  ('a1000001-0000-4000-8000-000000000001', 'Importaciones Delta C.A.', 'J-401234567', 'importador', '+58 424-1000001', now()),
  ('a1000002-0000-4000-8000-000000000002', 'Repuestos El Ávila', 'J-402345678', 'importador', '+58 424-1000002', now()),
  ('a1000003-0000-4000-8000-000000000003', 'MotoParts Venezuela', 'J-403456789', 'importador', '+58 424-1000003', now()),
  ('a2000001-0000-4000-8000-000000000001', 'Taller Los Ruices', 'J-501111111', 'aliado', '+58 414-2000001', now()),
  ('a2000002-0000-4000-8000-000000000002', 'Servicio Rápido 2000', 'J-502222222', 'aliado', '+58 414-2000002', now()),
  ('a2000003-0000-4000-8000-000000000003', 'Motos y Más', 'J-503333333', 'aliado', '+58 414-2000003', now())
on conflict (id) do update set
  business_name = excluded.business_name,
  rif = excluded.rif,
  role = excluded.role,
  phone = excluded.phone;

-- Quitar productos seed previos de estos importadores (re-ejecución limpia)
delete from public.products
where owner_id in (
  'a1000001-0000-4000-8000-000000000001'::uuid,
  'a1000002-0000-4000-8000-000000000002'::uuid,
  'a1000003-0000-4000-8000-000000000003'::uuid
);

-- 10 productos por importador (30 filas)
insert into public.products (
  owner_id,
  name,
  description,
  price_usd,
  stock,
  compatibility,
  image_url
)
values
  -- Importador 1
  ('a1000001-0000-4000-8000-000000000001', 'Kit embrague completo', 'Disco y pastillas 125cc', 48.50, 12, 'Honda CB125 / Yamaha YBR125', null),
  ('a1000001-0000-4000-8000-000000000001', 'Cadena 428H 120 eslabones', 'Reforzada', 22.00, 40, 'Universal 125-150cc', null),
  ('a1000001-0000-4000-8000-000000000001', 'Bujía NGK CR8E', 'Estándar', 4.20, 200, '4T varios modelos', null),
  ('a1000001-0000-4000-8000-000000000001', 'Filtro de aceite', 'Alto flujo', 6.90, 35, 'Honda XR150', null),
  ('a1000001-0000-4000-8000-000000000001', 'Pastillas freno delantero', 'Cerámicas', 14.75, 28, 'Bajaj Boxer 150', null),
  ('a1000001-0000-4000-8000-000000000001', 'Espejo retrovisor par', 'Rosca M10', 11.30, 50, 'Universal', null),
  ('a1000001-0000-4000-8000-000000000001', 'Manillar deportivo', 'Aluminio', 32.00, 8, 'Street 150-200cc', null),
  ('a1000001-0000-4000-8000-000000000001', 'Cable acelerador', 'OEM spec', 7.40, 45, 'Yamaha FZ16', null),
  ('a1000001-0000-4000-8000-000000000001', 'Batería 12V 7Ah', 'Sellada', 38.90, 15, '125-150cc', null),
  ('a1000001-0000-4000-8000-000000000001', 'Llanta delantera 90/90-18', 'Tubeless', 55.00, 10, 'Honda Wave', null),
  -- Importador 2
  ('a1000002-0000-4000-8000-000000000002', 'Cilindro 150cc', 'Kit pistón + aros', 89.00, 6, 'CG150 genérica', null),
  ('a1000002-0000-4000-8000-000000000002', 'Carburador VM22', 'Mikuni style', 42.50, 14, 'Pit bike / 125', null),
  ('a1000002-0000-4000-8000-000000000002', 'Radiador aluminio', 'Incluye tapa', 67.20, 5, 'Naked 200cc', null),
  ('a1000002-0000-4000-8000-000000000002', 'Bomba de gasolina', 'Eléctrica', 19.99, 22, 'Inyección 150cc', null),
  ('a1000002-0000-4000-8000-000000000002', 'Sensor TPS', '3 pines', 13.50, 18, 'Keihin', null),
  ('a1000002-0000-4000-8000-000000000002', 'Escape deportivo', 'Acero inox', 95.00, 4, 'CB190R', null),
  ('a1000002-0000-4000-8000-000000000002', 'Tensor cadena', 'Ajustable', 9.80, 30, 'Universal', null),
  ('a1000002-0000-4000-8000-000000000002', 'Cubre cadena', 'Plástico ABS', 12.40, 25, 'CG125', null),
  ('a1000002-0000-4000-8000-000000000002', 'Piñón 15 dientes', 'Acero', 8.90, 60, '428', null),
  ('a1000002-0000-4000-8000-000000000002', 'Corona 43 dientes', 'Acero', 14.20, 40, '428', null),
  -- Importador 3
  ('a1000003-0000-4000-8000-000000000003', 'Casco integral M', 'Homologado', 72.00, 9, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Guantes verano L', 'Malla', 16.50, 24, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Chaqueta textil XL', 'Impermeable', 88.00, 7, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Candado disco 10mm', 'Con alarma', 24.00, 16, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Aceite 4T 20W50', '1L', 5.60, 100, '4T', null),
  ('a1000003-0000-4000-8000-000000000003', 'Líquido frenos DOT4', '500ml', 4.10, 80, 'Universal', null),
  ('a1000003-0000-4000-8000-000000000003', 'Kit tornillería motor', 'Acero', 11.00, 33, 'CG150', null),
  ('a1000003-0000-4000-8000-000000000003', 'Rodamiento 6205', 'SKF genérico', 6.30, 50, 'Rueda trasera varios', null),
  ('a1000003-0000-4000-8000-000000000003', 'Retén 25x40x7', 'NBR', 2.80, 120, 'Horquilla / ejes', null),
  ('a1000003-0000-4000-8000-000000000003', 'Porta equipaje trasero', 'Tubo acero', 45.00, 11, 'Rack universal', null);
