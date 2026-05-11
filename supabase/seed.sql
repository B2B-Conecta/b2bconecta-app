-- =============================================================================
-- MotoConecta — datos de desarrollo (seed)
-- =============================================================================
-- Requisito: ejecutar antes `supabase/motoconecta/schema.sql` en el mismo proyecto
-- Supabase (base greenfield MotoConecta, sin migraciones legacy).
--
-- Carga en SQL Editor (rol con permisos sobre auth y public) o:
--   supabase db query --linked -f supabase/seed.sql
--
-- Contraseña común (todos los seed): SeedPass123!
--   admin@motoconecta.seed
--   importador1@motoconecta.seed · importador2@motoconecta.seed
--   aliado1@motoconecta.seed · aliado2@motoconecta.seed
--
-- Validación comisión: pedido de ejemplo `precio_total_usd = 1000` →
--   `comision_motoconecta` generada = 50.00 (5 %).
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- auth.users + identities (sin rol transportista)
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
    ('c1000002-0000-4000-8000-000000000002'::uuid, 'importador2@motoconecta.seed'),
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motoconecta.seed'),
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
    ('c1000002-0000-4000-8000-000000000002'::uuid, 'importador2@motoconecta.seed'),
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

-- ---------------------------------------------------------------------------
-- Perfiles de prueba: 2 importadores, 2 aliados, 1 admin
-- ---------------------------------------------------------------------------
insert into public.profiles (
  id,
  business_name,
  rif,
  role,
  phone,
  logo_storage_path,
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
    now()
  ),
  (
    'c1000002-0000-4000-8000-000000000002',
    'Repuestos MotoConecta Centro',
    'J-402222222',
    'importador',
    '+58 424-1000002',
    null,
    now()
  ),
  (
    'c2000001-0000-4000-8000-000000000001',
    'Taller Aliado Los Ruices',
    'J-501111111',
    'aliado',
    '+58 414-2000001',
    null,
    now()
  ),
  (
    'c2000002-0000-4000-8000-000000000002',
    'Servicio Rápido MotoConecta',
    'J-502222222',
    'aliado',
    '+58 414-2000002',
    null,
    now()
  ),
  (
    'c3000001-0000-4000-8000-000000000001',
    'MotoConecta (Supervisor)',
    'J-300000001',
    'administrador',
    '+58 212-3000001',
    null,
    now()
  )
on conflict (id) do update set
  business_name = excluded.business_name,
  rif = excluded.rif,
  role = excluded.role,
  phone = excluded.phone,
  logo_storage_path = excluded.logo_storage_path;

-- ---------------------------------------------------------------------------
-- Catálogo (productos por importador)
-- ---------------------------------------------------------------------------
delete from public.products
where owner_id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000002'::uuid
);

insert into public.products (owner_id, name, price_usd, stock, is_active)
values
  ('c1000001-0000-4000-8000-000000000001', 'Kit embrague 125cc', 45.0000, 120, true),
  ('c1000001-0000-4000-8000-000000000001', 'Cadena 428 — 118 eslabones', 32.5000, 200, true),
  ('c1000001-0000-4000-8000-000000000001', 'Pastillas freno delantero', 18.7500, 85, true),
  ('c1000002-0000-4000-8000-000000000002', 'Aceite 4T 20W50 (1 L)', 6.2500, 500, true),
  ('c1000002-0000-4000-8000-000000000002', 'Bujía NGK resistente', 4.1000, 300, true),
  ('c1000002-0000-4000-8000-000000000002', 'Filtro de aire espuma', 8.9000, 0, false);

-- ---------------------------------------------------------------------------
-- Pedido de ejemplo (pendiente) — comisión 5 % generada
-- ---------------------------------------------------------------------------
-- precio_total_usd 1000.00 → comision_motoconecta = 50.00
insert into public.transaction_requests (
  id,
  aliado_id,
  importador_id,
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
  'pendiente',
  20,
  1000.0000,
  null,
  null
)
on conflict (id) do update set
  aliado_id = excluded.aliado_id,
  importador_id = excluded.importador_id,
  status = excluded.status,
  cantidad = excluded.cantidad,
  precio_total_usd = excluded.precio_total_usd,
  factura_url = excluded.factura_url,
  tiempo_estimado_envio = excluded.tiempo_estimado_envio;

-- Mensaje de bienvenida al hilo del pedido (opcional)
insert into public.messages (transaction_id, sender_id, content)
select
  'e0000001-0000-4000-8000-000000000001'::uuid,
  'c2000001-0000-4000-8000-000000000001'::uuid,
  'Hola, confirmamos la solicitud de 20 unidades. Quedamos atentos a su preparación.'
where not exists (
  select 1 from public.messages m
  where m.transaction_id = 'e0000001-0000-4000-8000-000000000001'::uuid
    and m.sender_id = 'c2000001-0000-4000-8000-000000000001'::uuid
    and m.content like 'Hola, confirmamos la solicitud%'
);

-- Verificación rápida (dev): descomenta para ver filas en el editor
-- select id, precio_total_usd, comision_motoconecta, status
-- from public.transaction_requests
-- where id = 'e0000001-0000-4000-8000-000000000001';
