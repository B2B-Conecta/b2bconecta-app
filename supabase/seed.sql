-- =============================================================================
-- MotoLink — datos de desarrollo (seed)
-- =============================================================================
-- Aplicar al remoto enlazado (desde la raíz del repo, con `supabase link` hecho):
--   supabase db query --linked -f supabase/seed.sql
-- O pegar este archivo en Supabase → SQL Editor (rol con permisos sobre auth y public).
--
-- Contraseña común (11 usuarios): SeedPass123!
-- Importadores: importador1@motolink.seed … importador7@motolink.seed
-- Aliados:      aliado1@motolink.seed … aliado3@motolink.seed
-- Admin broker: admin@motolink.seed
--
-- Requiere migración `20260407120000_broker_transaction_requests.sql` (tabla transaction_requests).
-- Contenido: 11 usuarios auth + perfiles (estado, ciudad, direccion) + esquema
-- inventario (sku, is_active, category) + 140 productos. Sin pedidos predefinidos; KYC aliados en pendiente.
-- Re-ejecutar: aplica DDL idempotente, borra productos de importadores seed,
-- inserta productos; usuarios/perfiles solo si no existen.
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
    ('a1000004-0000-4000-8000-000000000004'::uuid, 'importador4@motolink.seed'),
    ('a1000005-0000-4000-8000-000000000005'::uuid, 'importador5@motolink.seed'),
    ('a1000006-0000-4000-8000-000000000006'::uuid, 'importador6@motolink.seed'),
    ('a1000007-0000-4000-8000-000000000007'::uuid, 'importador7@motolink.seed'),
    ('a2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motolink.seed'),
    ('a2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motolink.seed'),
    ('a2000003-0000-4000-8000-000000000003'::uuid, 'aliado3@motolink.seed'),
    ('a3000001-0000-4000-8000-000000000001'::uuid, 'admin@motolink.seed')
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
    ('a1000004-0000-4000-8000-000000000004'::uuid, 'importador4@motolink.seed'),
    ('a1000005-0000-4000-8000-000000000005'::uuid, 'importador5@motolink.seed'),
    ('a1000006-0000-4000-8000-000000000006'::uuid, 'importador6@motolink.seed'),
    ('a1000007-0000-4000-8000-000000000007'::uuid, 'importador7@motolink.seed'),
    ('a2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motolink.seed'),
    ('a2000002-0000-4000-8000-000000000002'::uuid, 'aliado2@motolink.seed'),
    ('a2000003-0000-4000-8000-000000000003'::uuid, 'aliado3@motolink.seed'),
    ('a3000001-0000-4000-8000-000000000001'::uuid, 'admin@motolink.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

alter table public.profiles
  add column if not exists credit_score integer not null default 100;
alter table public.profiles
  add column if not exists credit_limit numeric(14, 2);
alter table public.profiles
  add column if not exists kyc_status text;
alter table public.profiles
  add column if not exists primeros_pedidos_contado_entregados integer not null default 0;
alter table public.profiles
  drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('importador', 'aliado', 'administrador'));

alter table public.profiles
  add column if not exists estado text;
alter table public.profiles
  add column if not exists ciudad text;
alter table public.profiles
  add column if not exists direccion text;

-- Perfiles B2B (aliados: KYC pendiente, sin entregas contado prellenadas).
-- Campo direccion: domicilio fiscal / casa matriz (referencia para facturación; demo seed).
insert into public.profiles (
  id, business_name, rif, role, phone, credit_score, credit_limit, kyc_status,
  primeros_pedidos_contado_entregados, estado, ciudad, direccion, created_at
)
values
  ('a1000001-0000-4000-8000-000000000001', 'Importaciones Delta C.A.', 'J-401234567', 'importador', '+58 424-1000001', 100, 100000, null, 0, 'Distrito Capital', 'Caracas', 'Domicilio fiscal: Torre Empresarial Delta, Av. Francisco de Miranda, piso 4 ofic. 4-B, Urb. Los Palos Grandes, Caracas 1060 (mismo RIF J-401234567).', now()),
  ('a1000002-0000-4000-8000-000000000002', 'Repuestos El Ávila', 'J-402345678', 'importador', '+58 424-1000002', 100, 100000, null, 0, 'Miranda', 'Los Teques', 'Casa matriz fiscal: Calle Bolívar esq. Guaicaipuro, galpón 7, Zona Industrial La Mariposa, Los Teques 1201, Edo. Miranda.', now()),
  ('a1000003-0000-4000-8000-000000000003', 'MotoParts Venezuela', 'J-403456789', 'importador', '+58 424-1000003', 100, 100000, null, 0, 'Carabobo', 'Valencia', 'Domicilio fiscal: Av. Bolívar Norte, sector San Blas, nave 12 (galpón logístico), Valencia 2001, Edo. Carabobo.', now()),
  ('a1000004-0000-4000-8000-000000000004', 'LuzMoto Import C.A.', 'J-404567890', 'importador', '+58 424-1000004', 100, 100000, null, 0, 'Lara', 'Barquisimeto', 'Domicilio fiscal: Carrera 19 entre calles 7 y 8, edificio LuzMoto, piso PB local 2, Parroquia Concepción, Barquisimeto 3001.', now()),
  ('a1000005-0000-4000-8000-000000000005', 'ImportMotos Centro', 'J-405678901', 'importador', '+58 424-1000005', 100, 100000, null, 0, 'Aragua', 'Maracay', 'Casa matriz: Zona industrial San Jacinto, callejón B, nave 5 (acceso fiscal), Maracay 2103, Edo. Aragua.', now()),
  ('a1000006-0000-4000-8000-000000000006', 'Frenos y Transmisión VE', 'J-406789012', 'importador', '+58 424-1000006', 100, 100000, null, 0, 'Zulia', 'Maracaibo', 'Domicilio fiscal: Av. 5 de Julio, Edif. Industrial La Limpia, módulo 3, locales 301-302, Maracaibo 4005, Edo. Zulia.', now()),
  ('a1000007-0000-4000-8000-000000000007', 'MotorZone Distribuidora', 'J-407890123', 'importador', '+58 424-1000007', 100, 100000, null, 0, 'Táchira', 'San Cristóbal', 'Domicilio fiscal: Av. Principal de Capacho, galpón MotoZone (área de despacho y facturación), San Cristóbal 5001, Edo. Táchira.', now()),
  ('a2000001-0000-4000-8000-000000000001', 'Taller Los Ruices', 'J-501111111', 'aliado', '+58 414-2000001', 85, 50000, 'pendiente', 0, 'Miranda', 'Caracas', 'Domicilio fiscal del taller: Av. Francisco de Miranda, Los Ruices, local 14 (frente estación), sector fiscal Caracas 1070.', now()),
  ('a2000002-0000-4000-8000-000000000002', 'Servicio Rápido 2000', 'J-502222222', 'aliado', '+58 414-2000002', 72, 35000, 'pendiente', 0, 'Carabobo', 'Valencia', 'Casa matriz: Urb. El Trigal, calle 102 galpón 2, inscripción fiscal Valencia 2005, Edo. Carabobo.', now()),
  ('a2000003-0000-4000-8000-000000000003', 'Motos y Más', 'J-503333333', 'aliado', '+58 414-2000003', 90, 75000, 'pendiente', 0, 'Zulia', 'Maracaibo', 'Domicilio fiscal: Calle 72, sector Sabaneta, local Motos y Más (referencia mercado), Maracaibo 4002.', now()),
  ('a3000001-0000-4000-8000-000000000001', 'MotoLink (Broker)', 'J-300000001', 'administrador', '+58 212-3000001', 100, null, null, 0, null, null, null, now())
on conflict (id) do update set
  business_name = excluded.business_name,
  rif = excluded.rif,
  role = excluded.role,
  phone = excluded.phone,
  credit_score = excluded.credit_score,
  credit_limit = excluded.credit_limit,
  kyc_status = excluded.kyc_status,
  primeros_pedidos_contado_entregados = excluded.primeros_pedidos_contado_entregados,
  estado = excluded.estado,
  ciudad = excluded.ciudad,
  direccion = excluded.direccion;

-- =============================================================================
-- Esquema inventario B2B (idempotente). Debe existir antes de insertar productos.
-- (Mismo contenido que supabase/migrations/20260327120000_importer_inventory.sql)
-- =============================================================================

-- Inventario B2B: SKU, categoría, modo pausa.
-- (Solicitudes broker: migración 20260407120000_broker_transaction_requests.sql)

alter table public.products
  add column if not exists sku text,
  add column if not exists is_active boolean not null default true,
  add column if not exists category text;

-- Un SKU por importador (dueño).
create unique index if not exists products_owner_sku_unique
  on public.products (owner_id, sku)
  where sku is not null and btrim(sku) <> '';

update public.products
set sku = 'ML-' || replace(id::text, '-', '')
where sku is null or btrim(sku) = '';

-- Aliados solo ven productos activos; el dueño ve los suyos aunque estén pausados.
drop policy if exists "products_select_authenticated" on public.products;
create policy "products_select_authenticated"
on public.products
for select
to authenticated
using (is_active = true or owner_id = auth.uid());

-- Quitar productos seed previos de estos importadores (re-ejecución limpia)
delete from public.products
where owner_id in (
  'a1000001-0000-4000-8000-000000000001'::uuid,
  'a1000002-0000-4000-8000-000000000002'::uuid,
  'a1000003-0000-4000-8000-000000000003'::uuid,
  'a1000004-0000-4000-8000-000000000004'::uuid,
  'a1000005-0000-4000-8000-000000000005'::uuid,
  'a1000006-0000-4000-8000-000000000006'::uuid,
  'a1000007-0000-4000-8000-000000000007'::uuid
);

-- 20 productos por importador (140 filas): sku, is_active, category
insert into public.products (
  owner_id,
  name,
  description,
  price_usd,
  stock,
  compatibility,
  image_url,
  sku,
  is_active,
  category
)
values
('a1000001-0000-4000-8000-000000000001', 'Kit embrague completo', 'Disco y pastillas 125cc', 48.5, 12, 'Honda CB125 / Yamaha YBR125', null, 'IMP1-001', true, 'Transmisión'),
  ('a1000001-0000-4000-8000-000000000001', 'Cadena 428H 120 eslabones', 'Reforzada', 22.0, 40, 'Universal 125-150cc', null, 'IMP1-002', true, 'Transmisión'),
  ('a1000001-0000-4000-8000-000000000001', 'Bujía NGK CR8E', 'Estándar', 4.2, 0, '4T varios modelos', null, 'IMP1-003', true, 'Eléctrico'),
  ('a1000001-0000-4000-8000-000000000001', 'Filtro de aceite', 'Alto flujo', 6.9, 35, 'Honda XR150', null, 'IMP1-004', true, 'Motor'),
  ('a1000001-0000-4000-8000-000000000001', 'Pastillas freno delantero', 'Cerámicas', 14.75, 28, 'Bajaj Boxer 150', null, 'IMP1-005', true, 'Frenos'),
  ('a1000001-0000-4000-8000-000000000001', 'Espejo retrovisor par', 'Rosca M10', 11.3, 50, 'Universal', null, 'IMP1-006', true, 'Accesorios'),
  ('a1000001-0000-4000-8000-000000000001', 'Manillar deportivo', 'Aluminio', 32.0, 8, 'Street 150-200cc', null, 'IMP1-007', true, 'Chasis'),
  ('a1000001-0000-4000-8000-000000000001', 'Cable acelerador', 'OEM spec', 7.4, 45, 'Yamaha FZ16', null, 'IMP1-008', true, 'Transmisión'),
  ('a1000001-0000-4000-8000-000000000001', 'Batería 12V 7Ah', 'Sellada', 38.9, 15, '125-150cc', null, 'IMP1-009', true, 'Eléctrico'),
  ('a1000001-0000-4000-8000-000000000001', 'Llanta delantera 90/90-18', 'Tubeless', 55.0, 10, 'Honda Wave', null, 'IMP1-010', true, 'Motor'),
  ('a1000001-0000-4000-8000-000000000001', 'Amortiguador trasero', 'Hidráulico ajustable', 62.0, 14, 'CG150 / YBR125', null, 'IMP1-011', true, 'Chasis'),
  ('a1000001-0000-4000-8000-000000000001', 'Kit rodamientos rueda delantera', '2 unidades', 18.5, 22, 'Honda Wave 110', null, 'IMP1-012', true, 'Motor'),
  ('a1000001-0000-4000-8000-000000000001', 'Disco freno trasero 220mm', 'Acero inox', 24.9, 19, 'Bajaj Pulsar', null, 'IMP1-013', true, 'Frenos'),
  ('a1000001-0000-4000-8000-000000000001', 'Sensor velocidad digital', 'Con cable', 15.4, 30, 'Inyección 150cc', null, 'IMP1-014', true, 'Eléctrico'),
  ('a1000001-0000-4000-8000-000000000001', 'Relay arranque 12V', '40A', 6.2, 55, 'Universal 12V', null, 'IMP1-015', true, 'Eléctrico'),
  ('a1000001-0000-4000-8000-000000000001', 'Interruptor luces manillar', 'Izquierdo', 9.1, 40, 'CG125 genérica', null, 'IMP1-016', true, 'Eléctrico'),
  ('a1000001-0000-4000-8000-000000000001', 'Puño acelerador', 'Con funda', 12.0, 36, '22mm estándar', null, 'IMP1-017', true, 'Accesorios'),
  ('a1000001-0000-4000-8000-000000000001', 'Protector motor aluminio', 'CNC', 44.0, 11, 'Naked 200cc', null, 'IMP1-018', true, 'Chasis'),
  ('a1000001-0000-4000-8000-000000000001', 'Base espejo M10', 'Par rosca normal', 5.5, 70, 'Universal', null, 'IMP1-019', true, 'Accesorios'),
  ('a1000001-0000-4000-8000-000000000001', 'Tapón tanque cromado', 'Con llave', 16.8, 25, 'Rosca estándar', null, 'IMP1-020', false, 'Accesorios'),
  ('a1000002-0000-4000-8000-000000000002', 'Cilindro 150cc', 'Kit pistón + aros', 89.0, 6, 'CG150 genérica', null, 'IMP2-001', true, 'Transmisión'),
  ('a1000002-0000-4000-8000-000000000002', 'Carburador VM22', 'Mikuni style', 42.5, 14, 'Pit bike / 125', null, 'IMP2-002', true, 'Transmisión'),
  ('a1000002-0000-4000-8000-000000000002', 'Radiador aluminio', 'Incluye tapa', 67.2, 0, 'Naked 200cc', null, 'IMP2-003', true, 'Eléctrico'),
  ('a1000002-0000-4000-8000-000000000002', 'Bomba de gasolina', 'Eléctrica', 19.99, 22, 'Inyección 150cc', null, 'IMP2-004', true, 'Motor'),
  ('a1000002-0000-4000-8000-000000000002', 'Sensor TPS', '3 pines', 13.5, 18, 'Keihin', null, 'IMP2-005', true, 'Frenos'),
  ('a1000002-0000-4000-8000-000000000002', 'Escape deportivo', 'Acero inox', 95.0, 4, 'CB190R', null, 'IMP2-006', true, 'Accesorios'),
  ('a1000002-0000-4000-8000-000000000002', 'Tensor cadena', 'Ajustable', 9.8, 30, 'Universal', null, 'IMP2-007', true, 'Chasis'),
  ('a1000002-0000-4000-8000-000000000002', 'Cubre cadena', 'Plástico ABS', 12.4, 25, 'CG125', null, 'IMP2-008', true, 'Transmisión'),
  ('a1000002-0000-4000-8000-000000000002', 'Piñón 15 dientes', 'Acero', 8.9, 60, '428', null, 'IMP2-009', true, 'Eléctrico'),
  ('a1000002-0000-4000-8000-000000000002', 'Corona 43 dientes', 'Acero', 14.2, 40, '428', null, 'IMP2-010', true, 'Motor'),
  ('a1000002-0000-4000-8000-000000000002', 'Árbol de levas competición', 'Perfil agresivo', 112.0, 3, 'CG200 preparada', null, 'IMP2-011', true, 'Chasis'),
  ('a1000002-0000-4000-8000-000000000002', 'Válvulas admisión/ex escape', 'Juego 4', 28.0, 20, 'CG150', null, 'IMP2-012', true, 'Motor'),
  ('a1000002-0000-4000-8000-000000000002', 'Bomba de aceite', 'Completa', 34.5, 12, 'YBR125 / FZ16', null, 'IMP2-013', true, 'Frenos'),
  ('a1000002-0000-4000-8000-000000000002', 'Bobina alta tensión', 'Racing', 21.0, 28, 'CDI 4T', null, 'IMP2-014', true, 'Eléctrico'),
  ('a1000002-0000-4000-8000-000000000002', 'Regulador voltaje 12V', '8 cables', 17.3, 24, 'Chinas 150cc', null, 'IMP2-015', true, 'Eléctrico'),
  ('a1000002-0000-4000-8000-000000000002', 'Inyector combustible', 'OEM equivalente', 45.0, 15, 'FI 150-250cc', null, 'IMP2-016', true, 'Eléctrico'),
  ('a1000002-0000-4000-8000-000000000002', 'Cuerpo mariposa 28mm', 'Con sensor', 78.0, 7, 'Inyección deportiva', null, 'IMP2-017', true, 'Accesorios'),
  ('a1000002-0000-4000-8000-000000000002', 'Termostato 82°C', 'Con junta', 8.4, 40, 'Refrigeración líquida', null, 'IMP2-018', true, 'Chasis'),
  ('a1000002-0000-4000-8000-000000000002', 'Manguera radiador', 'Silicona roja', 11.9, 33, 'Universal cortar', null, 'IMP2-019', true, 'Accesorios'),
  ('a1000002-0000-4000-8000-000000000002', 'Tapa válvulas cromada', 'Aluminio', 19.0, 18, 'CG125 / 150', null, 'IMP2-020', false, 'Accesorios'),
  ('a1000003-0000-4000-8000-000000000003', 'Casco integral M', 'Homologado', 72.0, 9, 'N/A', null, 'IMP3-001', true, 'Transmisión'),
  ('a1000003-0000-4000-8000-000000000003', 'Guantes verano L', 'Malla', 16.5, 24, 'N/A', null, 'IMP3-002', true, 'Transmisión'),
  ('a1000003-0000-4000-8000-000000000003', 'Chaqueta textil XL', 'Impermeable', 88.0, 0, 'N/A', null, 'IMP3-003', true, 'Eléctrico'),
  ('a1000003-0000-4000-8000-000000000003', 'Candado disco 10mm', 'Con alarma', 24.0, 16, 'N/A', null, 'IMP3-004', true, 'Motor'),
  ('a1000003-0000-4000-8000-000000000003', 'Aceite 4T 20W50', '1L', 5.6, 100, '4T', null, 'IMP3-005', true, 'Frenos'),
  ('a1000003-0000-4000-8000-000000000003', 'Líquido frenos DOT4', '500ml', 4.1, 80, 'Universal', null, 'IMP3-006', true, 'Accesorios'),
  ('a1000003-0000-4000-8000-000000000003', 'Kit tornillería motor', 'Acero', 11.0, 33, 'CG150', null, 'IMP3-007', true, 'Chasis'),
  ('a1000003-0000-4000-8000-000000000003', 'Rodamiento 6205', 'SKF genérico', 6.3, 50, 'Rueda trasera varios', null, 'IMP3-008', true, 'Transmisión'),
  ('a1000003-0000-4000-8000-000000000003', 'Retén 25x40x7', 'NBR', 2.8, 120, 'Horquilla / ejes', null, 'IMP3-009', true, 'Eléctrico'),
  ('a1000003-0000-4000-8000-000000000003', 'Porta equipaje trasero', 'Tubo acero', 45.0, 11, 'Rack universal', null, 'IMP3-010', true, 'Motor'),
  ('a1000003-0000-4000-8000-000000000003', 'Pantalón cordura con protecciones', 'Talla 32', 95.0, 8, 'N/A', null, 'IMP3-011', true, 'Chasis'),
  ('a1000003-0000-4000-8000-000000000003', 'Botas touring 43', 'Impermeables', 118.0, 5, 'N/A', null, 'IMP3-012', true, 'Motor'),
  ('a1000003-0000-4000-8000-000000000003', 'Intercomunicador Bluetooth pareja', 'BT 5.0', 135.0, 4, 'N/A', null, 'IMP3-013', true, 'Frenos'),
  ('a1000003-0000-4000-8000-000000000003', 'Maleta lateral 35L', 'Par con soporte', 189.0, 3, 'Tubular rack', null, 'IMP3-014', true, 'Eléctrico'),
  ('a1000003-0000-4000-8000-000000000003', 'Grasa litio rodamientos', '400g', 7.2, 45, 'Mantenimiento', null, 'IMP3-015', true, 'Eléctrico'),
  ('a1000003-0000-4000-8000-000000000003', 'Limpiador cadena spray', '750ml', 6.5, 60, '4T', null, 'IMP3-016', true, 'Eléctrico'),
  ('a1000003-0000-4000-8000-000000000003', 'Kit juntas motor completo', 'Papel + metal', 26.0, 17, 'CG200', null, 'IMP3-017', true, 'Accesorios'),
  ('a1000003-0000-4000-8000-000000000003', 'Cinta aislar alta temp', 'Rollo 10m', 3.4, 90, 'Eléctrico', null, 'IMP3-018', true, 'Chasis'),
  ('a1000003-0000-4000-8000-000000000003', 'Pulsera anti-vibración', 'Gel', 8.9, 28, 'N/A', null, 'IMP3-019', true, 'Accesorios'),
  ('a1000003-0000-4000-8000-000000000003', 'Cubre maletero impermeable', 'XL', 22.0, 14, 'Equipaje', null, 'IMP3-020', false, 'Accesorios'),
  ('a1000004-0000-4000-8000-000000000004', 'Bombillo LED H4 6000K', 'Par', 28.0, 42, 'Faros estándar', null, 'IMP4-001', true, 'Transmisión'),
  ('a1000004-0000-4000-8000-000000000004', 'Tira LED flexible 30cm', 'Ambar', 12.5, 55, 'Defensa / carenado', null, 'IMP4-002', true, 'Transmisión'),
  ('a1000004-0000-4000-8000-000000000004', 'Estator alternador 8 bobinas', 'Cobre', 54.0, 0, 'CG150 / YBR', null, 'IMP4-003', true, 'Eléctrico'),
  ('a1000004-0000-4000-8000-000000000004', 'CDI programable racing', 'Curva agresiva', 68.0, 9, 'CDI 5 pines', null, 'IMP4-004', true, 'Motor'),
  ('a1000004-0000-4000-8000-000000000004', 'Pito eléctrico 12V', '115 dB', 14.0, 38, 'Universal', null, 'IMP4-005', true, 'Frenos'),
  ('a1000004-0000-4000-8000-000000000004', 'Cableado arnés principal', 'Completo', 39.0, 15, 'CG125 cable largo', null, 'IMP4-006', true, 'Accesorios'),
  ('a1000004-0000-4000-8000-000000000004', 'Interruptor emergencia', 'Corte motor', 11.2, 44, 'Manillar 22mm', null, 'IMP4-007', true, 'Chasis'),
  ('a1000004-0000-4000-8000-000000000004', 'Luz stop LED integrada', 'Roja', 19.8, 27, 'Colín deportivo', null, 'IMP4-008', true, 'Transmisión'),
  ('a1000004-0000-4000-8000-000000000004', 'Balastra xenon slim 35W', 'Kit', 46.0, 10, 'H4 / H7 según modelo', null, 'IMP4-009', true, 'Eléctrico'),
  ('a1000004-0000-4000-8000-000000000004', 'Fusible cuchilla 20A', 'Caja 10 uds', 4.5, 100, 'Tablero', null, 'IMP4-010', true, 'Motor'),
  ('a1000004-0000-4000-8000-000000000004', 'Conector impermeable 4 vías', 'Par', 7.8, 65, 'Luces auxiliares', null, 'IMP4-011', true, 'Chasis'),
  ('a1000004-0000-4000-8000-000000000004', 'Pulsador arranque', 'Cromado', 9.3, 50, '4T estándar', null, 'IMP4-012', true, 'Motor'),
  ('a1000004-0000-4000-8000-000000000004', 'Batería litio 12V 4Ah', 'Ligera', 95.0, 8, 'Competición 125', null, 'IMP4-013', true, 'Frenos'),
  ('a1000004-0000-4000-8000-000000000004', 'Medidor voltaje digital', 'Panel', 16.4, 31, '12V', null, 'IMP4-014', true, 'Eléctrico'),
  ('a1000004-0000-4000-8000-000000000004', 'Cable bujía silicona', '50cm', 5.2, 75, 'Alto voltaje', null, 'IMP4-015', true, 'Eléctrico'),
  ('a1000004-0000-4000-8000-000000000004', 'Sensor freno trasero', 'Hidráulico', 13.9, 22, 'Disco trasero', null, 'IMP4-016', true, 'Eléctrico'),
  ('a1000004-0000-4000-8000-000000000004', 'Luz matrícula LED', 'Homologación E', 10.5, 40, 'Universal', null, 'IMP4-017', true, 'Accesorios'),
  ('a1000004-0000-4000-8000-000000000004', 'Módulo intermitentes LED', 'Relé electrónico', 18.0, 29, 'LED 12V', null, 'IMP4-018', true, 'Chasis'),
  ('a1000004-0000-4000-8000-000000000004', 'Antena corta AM/FM', 'Fibra', 7.0, 18, 'Scooter', null, 'IMP4-019', true, 'Accesorios'),
  ('a1000004-0000-4000-8000-000000000004', 'Cargador USB 12V manillar', '2.1A', 12.0, 48, '22mm', null, 'IMP4-020', false, 'Accesorios'),
  ('a1000005-0000-4000-8000-000000000005', 'Asiento doble confort', 'Gel', 58.0, 14, 'CG150 / Boxer', null, 'IMP5-001', true, 'Transmisión'),
  ('a1000005-0000-4000-8000-000000000005', 'Parabrisas touring ahumado', 'Alto', 42.0, 11, 'Anclaje 4 tornillos', null, 'IMP5-002', true, 'Transmisión'),
  ('a1000005-0000-4000-8000-000000000005', 'Elevadores manillar 28mm', 'Aluminio', 24.5, 0, '28mm fat bar', null, 'IMP5-003', true, 'Eléctrico'),
  ('a1000005-0000-4000-8000-000000000005', 'Top case 45L con base', 'Negro', 89.0, 6, 'Portaequipaje universal', null, 'IMP5-004', true, 'Motor'),
  ('a1000005-0000-4000-8000-000000000005', 'Cubremanos invierno', 'Par', 19.9, 25, '22mm', null, 'IMP5-005', true, 'Frenos'),
  ('a1000005-0000-4000-8000-000000000005', 'Reposapiés trasero', 'Plegables', 31.0, 17, 'Street 150', null, 'IMP5-006', true, 'Accesorios'),
  ('a1000005-0000-4000-8000-000000000005', 'Caballete central', 'Reforzado', 36.0, 13, 'CG125', null, 'IMP5-007', true, 'Chasis'),
  ('a1000005-0000-4000-8000-000000000005', 'Protector depósito transparente', '3 capas', 15.0, 35, 'Tanque curvo', null, 'IMP5-008', true, 'Transmisión'),
  ('a1000005-0000-4000-8000-000000000005', 'Almohadilla tanque', 'Neopreno', 22.0, 22, 'Naked', null, 'IMP5-009', true, 'Eléctrico'),
  ('a1000005-0000-4000-8000-000000000005', 'Extensión pata lateral', '20mm', 9.5, 40, 'Rosca M10', null, 'IMP5-010', true, 'Motor'),
  ('a1000005-0000-4000-8000-000000000005', 'Barra antivuelco motor', 'Acero', 48.0, 9, 'Adventure 200', null, 'IMP5-011', true, 'Chasis'),
  ('a1000005-0000-4000-8000-000000000005', 'Cubre radiador malla', 'Negro', 18.4, 28, 'Radiador 200mm ancho', null, 'IMP5-012', true, 'Motor'),
  ('a1000005-0000-4000-8000-000000000005', 'Porta celular manillar', 'Impermeable', 14.2, 52, '6.5" max', null, 'IMP5-013', true, 'Frenos'),
  ('a1000005-0000-4000-8000-000000000005', 'Manta térmica motor', 'Invierno', 11.0, 16, '125-200cc', null, 'IMP5-014', true, 'Eléctrico'),
  ('a1000005-0000-4000-8000-000000000005', 'Pedal freno ampliado', 'CNC', 26.0, 19, 'Tornillo M8', null, 'IMP5-015', true, 'Eléctrico'),
  ('a1000005-0000-4000-8000-000000000005', 'Tirador asiento pasajero', 'Cromado', 8.8, 33, 'Universal', null, 'IMP5-016', true, 'Eléctrico'),
  ('a1000005-0000-4000-8000-000000000005', 'Red elástica equipaje', '80x80cm', 7.5, 44, 'Rack', null, 'IMP5-017', true, 'Accesorios'),
  ('a1000005-0000-4000-8000-000000000005', 'Cubre cadena completo', 'ABS negro', 21.0, 21, 'CG150', null, 'IMP5-018', true, 'Chasis'),
  ('a1000005-0000-4000-8000-000000000005', 'Soporte GPS RAM', '22mm', 34.0, 12, 'Manillar', null, 'IMP5-019', true, 'Accesorios'),
  ('a1000005-0000-4000-8000-000000000005', 'Kit tornillos carenado', 'Titanio look', 13.6, 30, 'M5/M6 surtido', null, 'IMP5-020', false, 'Accesorios'),
  ('a1000006-0000-4000-8000-000000000006', 'Disco freno delantero 260mm', 'Flotante', 45.5, 18, 'Naked 200 / 250', null, 'IMP6-001', true, 'Transmisión'),
  ('a1000006-0000-4000-8000-000000000006', 'Latiguillo freno acero', '90cm', 24.0, 24, 'Freno delantero', null, 'IMP6-002', true, 'Transmisión'),
  ('a1000006-0000-4000-8000-000000000006', 'Bomba freno radial 14mm', 'Izquierda', 72.0, 0, '22mm manillar', null, 'IMP6-003', true, 'Eléctrico'),
  ('a1000006-0000-4000-8000-000000000006', 'Pastillas sinterizadas', 'Alto coeficiente', 29.0, 26, 'CB190R', null, 'IMP6-004', true, 'Motor'),
  ('a1000006-0000-4000-8000-000000000006', 'Líquido frenos DOT5.1', '1L', 12.4, 35, 'Competición', null, 'IMP6-005', true, 'Frenos'),
  ('a1000006-0000-4000-8000-000000000006', 'Kit purgado frenos', 'Jeringa + tubo', 8.9, 50, 'Mantenimiento', null, 'IMP6-006', true, 'Accesorios'),
  ('a1000006-0000-4000-8000-000000000006', 'Eje rueda delantero', 'Acero cromado', 19.5, 15, 'Wave 110', null, 'IMP6-007', true, 'Chasis'),
  ('a1000006-0000-4000-8000-000000000006', 'Kit transmisión 520', 'Piñón+cadena+corona', 88.0, 10, 'Deportiva 250', null, 'IMP6-008', true, 'Transmisión'),
  ('a1000006-0000-4000-8000-000000000006', 'Guardapolvo horquilla', 'Par 41mm', 14.0, 32, 'Upside down', null, 'IMP6-009', true, 'Eléctrico'),
  ('a1000006-0000-4000-8000-000000000006', 'Aceite horquilla 1L', '10W', 18.0, 20, 'Barras 33-43mm', null, 'IMP6-010', true, 'Motor'),
  ('a1000006-0000-4000-8000-000000000006', 'Rodillo cadena guía', 'Nylon', 11.5, 40, 'Swing arm', null, 'IMP6-011', true, 'Chasis'),
  ('a1000006-0000-4000-8000-000000000006', 'Tensión cadena automático', 'Mecánico', 35.0, 14, 'Monocross', null, 'IMP6-012', true, 'Motor'),
  ('a1000006-0000-4000-8000-000000000006', 'Crapodina dirección', 'Juego', 27.0, 17, 'Columna 25x47', null, 'IMP6-013', true, 'Frenos'),
  ('a1000006-0000-4000-8000-000000000006', 'Pastillas freno trasero', 'Orgánicas', 16.8, 45, 'Drum 125cc', null, 'IMP6-014', true, 'Eléctrico'),
  ('a1000006-0000-4000-8000-000000000006', 'Cable embrague teflón', '120cm', 10.2, 38, 'Universal', null, 'IMP6-015', true, 'Eléctrico'),
  ('a1000006-0000-4000-8000-000000000006', 'Bieletas cambio', 'Par aluminio', 22.5, 23, 'Pit bike', null, 'IMP6-016', true, 'Eléctrico'),
  ('a1000006-0000-4000-8000-000000000006', 'Retén horquilla 41x53x8', 'Par', 9.9, 55, 'USD', null, 'IMP6-017', true, 'Accesorios'),
  ('a1000006-0000-4000-8000-000000000006', 'Disco freno trasero 220mm', 'Fijo', 32.0, 16, 'Sport 150', null, 'IMP6-018', true, 'Chasis'),
  ('a1000006-0000-4000-8000-000000000006', 'Maneta freno ajustable', 'Derecha', 21.0, 29, 'Bomba estándar', null, 'IMP6-019', true, 'Accesorios'),
  ('a1000006-0000-4000-8000-000000000006', 'Separadores cadena plástico', 'Kit 4', 6.4, 60, 'Off-road', null, 'IMP6-020', false, 'Accesorios'),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aire espuma lavable', 'Alto flujo', 13.5, 48, 'Pit / 125', null, 'IMP7-001', true, 'Transmisión'),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aceite papel', 'Juego 3', 10.8, 70, 'Honda/Yamaha surtido', null, 'IMP7-002', true, 'Transmisión'),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite sintético 10W40', '1L', 8.9, 0, '4T performance', null, 'IMP7-003', true, 'Eléctrico'),
  ('a1000007-0000-4000-8000-000000000007', 'Aditivo fricción caja', '125ml', 11.2, 42, 'Manual wet clutch', null, 'IMP7-004', true, 'Motor'),
  ('a1000007-0000-4000-8000-000000000007', 'Refrigerante orgánico', '1L', 5.4, 85, 'Mezcla 50/50', null, 'IMP7-005', true, 'Frenos'),
  ('a1000007-0000-4000-8000-000000000007', 'Limpiador carburador', '400ml', 6.0, 55, 'Aerosol', null, 'IMP7-006', true, 'Accesorios'),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro combustible en línea', 'Transparente', 3.8, 120, '6mm manguera', null, 'IMP7-007', true, 'Chasis'),
  ('a1000007-0000-4000-8000-000000000007', 'Junta tapa válvulas', 'Caucho', 4.2, 65, 'CG150', null, 'IMP7-008', true, 'Transmisión'),
  ('a1000007-0000-4000-8000-000000000007', 'Empaque culata 0.5mm', 'Fibra', 7.6, 40, '150cc OHV', null, 'IMP7-009', true, 'Eléctrico'),
  ('a1000007-0000-4000-8000-000000000007', 'Tapón drenaje magnético', 'M14x1.5', 9.1, 33, 'Carter aceite', null, 'IMP7-010', true, 'Motor'),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite horquilla 5W', '500ml', 12.0, 28, 'Barras delgadas', null, 'IMP7-011', true, 'Chasis'),
  ('a1000007-0000-4000-8000-000000000007', 'Grasa cardán', '250g', 8.3, 25, 'Eje', null, 'IMP7-012', true, 'Motor'),
  ('a1000007-0000-4000-8000-000000000007', 'Aditivo octanaje', '325ml', 14.5, 37, 'Nafta', null, 'IMP7-013', true, 'Frenos'),
  ('a1000007-0000-4000-8000-000000000007', 'Prefiltro aire exterior', 'Malla lavable', 5.2, 88, 'Admisión 38mm', null, 'IMP7-014', true, 'Eléctrico'),
  ('a1000007-0000-4000-8000-000000000007', 'Spray desengrasante', '600ml', 5.5, 75, 'Taller', null, 'IMP7-015', true, 'Eléctrico'),
  ('a1000007-0000-4000-8000-000000000007', 'Pasta selladora alta temp', '85g', 6.8, 44, 'Escape', null, 'IMP7-016', true, 'Eléctrico'),
  ('a1000007-0000-4000-8000-000000000007', 'Kit o-ring surtido', 'Caja 50', 9.4, 30, 'Carburador / aceite', null, 'IMP7-017', true, 'Accesorios'),
  ('a1000007-0000-4000-8000-000000000007', 'Indicador nivel aceite', 'Varilla cromada', 7.0, 52, 'CG125', null, 'IMP7-018', true, 'Chasis'),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite 2T mezcla', '1L', 7.2, 60, '2T aire', null, 'IMP7-019', true, 'Accesorios'),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aire papel OEM style', 'Rectangular', 11.0, 46, 'Scooter 150', null, 'IMP7-020', false, 'Accesorios');

-- Sin pedidos de ejemplo: limpia solicitudes previas de los aliados seed (re-ejecución idempotente).
delete from public.transaction_requests
where aliado_id in (
  'a2000001-0000-4000-8000-000000000001'::uuid,
  'a2000002-0000-4000-8000-000000000002'::uuid,
  'a2000003-0000-4000-8000-000000000003'::uuid
);
