-- =============================================================================
-- MotoLink Pro — datos de desarrollo (seed)
-- =============================================================================
-- Ejecutar en Supabase → SQL Editor (rol con permisos sobre auth y public).
--
-- Contraseña común (10 usuarios): SeedPass123!
-- Importadores: importador1@motolink.seed … importador7@motolink.seed
-- Aliados:      aliado1@motolink.seed … aliado3@motolink.seed
--
-- Contenido: 10 usuarios auth + perfiles + 140 productos (20 por importador).
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
    ('a1000004-0000-4000-8000-000000000004'::uuid, 'importador4@motolink.seed'),
    ('a1000005-0000-4000-8000-000000000005'::uuid, 'importador5@motolink.seed'),
    ('a1000006-0000-4000-8000-000000000006'::uuid, 'importador6@motolink.seed'),
    ('a1000007-0000-4000-8000-000000000007'::uuid, 'importador7@motolink.seed'),
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
    ('a1000004-0000-4000-8000-000000000004'::uuid, 'importador4@motolink.seed'),
    ('a1000005-0000-4000-8000-000000000005'::uuid, 'importador5@motolink.seed'),
    ('a1000006-0000-4000-8000-000000000006'::uuid, 'importador6@motolink.seed'),
    ('a1000007-0000-4000-8000-000000000007'::uuid, 'importador7@motolink.seed'),
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
  ('a1000004-0000-4000-8000-000000000004', 'LuzMoto Import C.A.', 'J-404567890', 'importador', '+58 424-1000004', now()),
  ('a1000005-0000-4000-8000-000000000005', 'ImportMotos Centro', 'J-405678901', 'importador', '+58 424-1000005', now()),
  ('a1000006-0000-4000-8000-000000000006', 'Frenos y Transmisión VE', 'J-406789012', 'importador', '+58 424-1000006', now()),
  ('a1000007-0000-4000-8000-000000000007', 'MotorZone Distribuidora', 'J-407890123', 'importador', '+58 424-1000007', now()),
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
  'a1000003-0000-4000-8000-000000000003'::uuid,
  'a1000004-0000-4000-8000-000000000004'::uuid,
  'a1000005-0000-4000-8000-000000000005'::uuid,
  'a1000006-0000-4000-8000-000000000006'::uuid,
  'a1000007-0000-4000-8000-000000000007'::uuid
);

-- 20 productos por importador (140 filas)
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
  -- ========== Importador 1 — Importaciones Delta C.A. ==========
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
  ('a1000001-0000-4000-8000-000000000001', 'Amortiguador trasero', 'Hidráulico ajustable', 62.00, 14, 'CG150 / YBR125', null),
  ('a1000001-0000-4000-8000-000000000001', 'Kit rodamientos rueda delantera', '2 unidades', 18.50, 22, 'Honda Wave 110', null),
  ('a1000001-0000-4000-8000-000000000001', 'Disco freno trasero 220mm', 'Acero inox', 24.90, 19, 'Bajaj Pulsar', null),
  ('a1000001-0000-4000-8000-000000000001', 'Sensor velocidad digital', 'Con cable', 15.40, 30, 'Inyección 150cc', null),
  ('a1000001-0000-4000-8000-000000000001', 'Relay arranque 12V', '40A', 6.20, 55, 'Universal 12V', null),
  ('a1000001-0000-4000-8000-000000000001', 'Interruptor luces manillar', 'Izquierdo', 9.10, 40, 'CG125 genérica', null),
  ('a1000001-0000-4000-8000-000000000001', 'Puño acelerador', 'Con funda', 12.00, 36, '22mm estándar', null),
  ('a1000001-0000-4000-8000-000000000001', 'Protector motor aluminio', 'CNC', 44.00, 11, 'Naked 200cc', null),
  ('a1000001-0000-4000-8000-000000000001', 'Base espejo M10', 'Par rosca normal', 5.50, 70, 'Universal', null),
  ('a1000001-0000-4000-8000-000000000001', 'Tapón tanque cromado', 'Con llave', 16.80, 25, 'Rosca estándar', null),

  -- ========== Importador 2 — Repuestos El Ávila ==========
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
  ('a1000002-0000-4000-8000-000000000002', 'Árbol de levas competición', 'Perfil agresivo', 112.00, 3, 'CG200 preparada', null),
  ('a1000002-0000-4000-8000-000000000002', 'Válvulas admisión/ex escape', 'Juego 4', 28.00, 20, 'CG150', null),
  ('a1000002-0000-4000-8000-000000000002', 'Bomba de aceite', 'Completa', 34.50, 12, 'YBR125 / FZ16', null),
  ('a1000002-0000-4000-8000-000000000002', 'Bobina alta tensión', 'Racing', 21.00, 28, 'CDI 4T', null),
  ('a1000002-0000-4000-8000-000000000002', 'Regulador voltaje 12V', '8 cables', 17.30, 24, 'Chinas 150cc', null),
  ('a1000002-0000-4000-8000-000000000002', 'Inyector combustible', 'OEM equivalente', 45.00, 15, 'FI 150-250cc', null),
  ('a1000002-0000-4000-8000-000000000002', 'Cuerpo mariposa 28mm', 'Con sensor', 78.00, 7, 'Inyección deportiva', null),
  ('a1000002-0000-4000-8000-000000000002', 'Termostato 82°C', 'Con junta', 8.40, 40, 'Refrigeración líquida', null),
  ('a1000002-0000-4000-8000-000000000002', 'Manguera radiador', 'Silicona roja', 11.90, 33, 'Universal cortar', null),
  ('a1000002-0000-4000-8000-000000000002', 'Tapa válvulas cromada', 'Aluminio', 19.00, 18, 'CG125 / 150', null),

  -- ========== Importador 3 — MotoParts Venezuela ==========
  ('a1000003-0000-4000-8000-000000000003', 'Casco integral M', 'Homologado', 72.00, 9, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Guantes verano L', 'Malla', 16.50, 24, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Chaqueta textil XL', 'Impermeable', 88.00, 7, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Candado disco 10mm', 'Con alarma', 24.00, 16, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Aceite 4T 20W50', '1L', 5.60, 100, '4T', null),
  ('a1000003-0000-4000-8000-000000000003', 'Líquido frenos DOT4', '500ml', 4.10, 80, 'Universal', null),
  ('a1000003-0000-4000-8000-000000000003', 'Kit tornillería motor', 'Acero', 11.00, 33, 'CG150', null),
  ('a1000003-0000-4000-8000-000000000003', 'Rodamiento 6205', 'SKF genérico', 6.30, 50, 'Rueda trasera varios', null),
  ('a1000003-0000-4000-8000-000000000003', 'Retén 25x40x7', 'NBR', 2.80, 120, 'Horquilla / ejes', null),
  ('a1000003-0000-4000-8000-000000000003', 'Porta equipaje trasero', 'Tubo acero', 45.00, 11, 'Rack universal', null),
  ('a1000003-0000-4000-8000-000000000003', 'Pantalón cordura con protecciones', 'Talla 32', 95.00, 8, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Botas touring 43', 'Impermeables', 118.00, 5, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Intercomunicador Bluetooth pareja', 'BT 5.0', 135.00, 4, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Maleta lateral 35L', 'Par con soporte', 189.00, 3, 'Tubular rack', null),
  ('a1000003-0000-4000-8000-000000000003', 'Grasa litio rodamientos', '400g', 7.20, 45, 'Mantenimiento', null),
  ('a1000003-0000-4000-8000-000000000003', 'Limpiador cadena spray', '750ml', 6.50, 60, '4T', null),
  ('a1000003-0000-4000-8000-000000000003', 'Kit juntas motor completo', 'Papel + metal', 26.00, 17, 'CG200', null),
  ('a1000003-0000-4000-8000-000000000003', 'Cinta aislar alta temp', 'Rollo 10m', 3.40, 90, 'Eléctrico', null),
  ('a1000003-0000-4000-8000-000000000003', 'Pulsera anti-vibración', 'Gel', 8.90, 28, 'N/A', null),
  ('a1000003-0000-4000-8000-000000000003', 'Cubre maletero impermeable', 'XL', 22.00, 14, 'Equipaje', null),

  -- ========== Importador 4 — LuzMoto Import C.A. (eléctrico / luces) ==========
  ('a1000004-0000-4000-8000-000000000004', 'Bombillo LED H4 6000K', 'Par', 28.00, 42, 'Faros estándar', null),
  ('a1000004-0000-4000-8000-000000000004', 'Tira LED flexible 30cm', 'Ambar', 12.50, 55, 'Defensa / carenado', null),
  ('a1000004-0000-4000-8000-000000000004', 'Estator alternador 8 bobinas', 'Cobre', 54.00, 12, 'CG150 / YBR', null),
  ('a1000004-0000-4000-8000-000000000004', 'CDI programable racing', 'Curva agresiva', 68.00, 9, 'CDI 5 pines', null),
  ('a1000004-0000-4000-8000-000000000004', 'Pito eléctrico 12V', '115 dB', 14.00, 38, 'Universal', null),
  ('a1000004-0000-4000-8000-000000000004', 'Cableado arnés principal', 'Completo', 39.00, 15, 'CG125 cable largo', null),
  ('a1000004-0000-4000-8000-000000000004', 'Interruptor emergencia', 'Corte motor', 11.20, 44, 'Manillar 22mm', null),
  ('a1000004-0000-4000-8000-000000000004', 'Luz stop LED integrada', 'Roja', 19.80, 27, 'Colín deportivo', null),
  ('a1000004-0000-4000-8000-000000000004', 'Balastra xenon slim 35W', 'Kit', 46.00, 10, 'H4 / H7 según modelo', null),
  ('a1000004-0000-4000-8000-000000000004', 'Fusible cuchilla 20A', 'Caja 10 uds', 4.50, 100, 'Tablero', null),
  ('a1000004-0000-4000-8000-000000000004', 'Conector impermeable 4 vías', 'Par', 7.80, 65, 'Luces auxiliares', null),
  ('a1000004-0000-4000-8000-000000000004', 'Pulsador arranque', 'Cromado', 9.30, 50, '4T estándar', null),
  ('a1000004-0000-4000-8000-000000000004', 'Batería litio 12V 4Ah', 'Ligera', 95.00, 8, 'Competición 125', null),
  ('a1000004-0000-4000-8000-000000000004', 'Medidor voltaje digital', 'Panel', 16.40, 31, '12V', null),
  ('a1000004-0000-4000-8000-000000000004', 'Cable bujía silicona', '50cm', 5.20, 75, 'Alto voltaje', null),
  ('a1000004-0000-4000-8000-000000000004', 'Sensor freno trasero', 'Hidráulico', 13.90, 22, 'Disco trasero', null),
  ('a1000004-0000-4000-8000-000000000004', 'Luz matrícula LED', 'Homologación E', 10.50, 40, 'Universal', null),
  ('a1000004-0000-4000-8000-000000000004', 'Módulo intermitentes LED', 'Relé electrónico', 18.00, 29, 'LED 12V', null),
  ('a1000004-0000-4000-8000-000000000004', 'Antena corta AM/FM', 'Fibra', 7.00, 18, 'Scooter', null),
  ('a1000004-0000-4000-8000-000000000004', 'Cargador USB 12V manillar', '2.1A', 12.00, 48, '22mm', null),

  -- ========== Importador 5 — ImportMotos Centro (chasis / comodidad) ==========
  ('a1000005-0000-4000-8000-000000000005', 'Asiento doble confort', 'Gel', 58.00, 14, 'CG150 / Boxer', null),
  ('a1000005-0000-4000-8000-000000000005', 'Parabrisas touring ahumado', 'Alto', 42.00, 11, 'Anclaje 4 tornillos', null),
  ('a1000005-0000-4000-8000-000000000005', 'Elevadores manillar 28mm', 'Aluminio', 24.50, 20, '28mm fat bar', null),
  ('a1000005-0000-4000-8000-000000000005', 'Top case 45L con base', 'Negro', 89.00, 6, 'Portaequipaje universal', null),
  ('a1000005-0000-4000-8000-000000000005', 'Cubremanos invierno', 'Par', 19.90, 25, '22mm', null),
  ('a1000005-0000-4000-8000-000000000005', 'Reposapiés trasero', 'Plegables', 31.00, 17, 'Street 150', null),
  ('a1000005-0000-4000-8000-000000000005', 'Caballete central', 'Reforzado', 36.00, 13, 'CG125', null),
  ('a1000005-0000-4000-8000-000000000005', 'Protector depósito transparente', '3 capas', 15.00, 35, 'Tanque curvo', null),
  ('a1000005-0000-4000-8000-000000000005', 'Almohadilla tanque', 'Neopreno', 22.00, 22, 'Naked', null),
  ('a1000005-0000-4000-8000-000000000005', 'Extensión pata lateral', '20mm', 9.50, 40, 'Rosca M10', null),
  ('a1000005-0000-4000-8000-000000000005', 'Barra antivuelco motor', 'Acero', 48.00, 9, 'Adventure 200', null),
  ('a1000005-0000-4000-8000-000000000005', 'Cubre radiador malla', 'Negro', 18.40, 28, 'Radiador 200mm ancho', null),
  ('a1000005-0000-4000-8000-000000000005', 'Porta celular manillar', 'Impermeable', 14.20, 52, '6.5" max', null),
  ('a1000005-0000-4000-8000-000000000005', 'Manta térmica motor', 'Invierno', 11.00, 16, '125-200cc', null),
  ('a1000005-0000-4000-8000-000000000005', 'Pedal freno ampliado', 'CNC', 26.00, 19, 'Tornillo M8', null),
  ('a1000005-0000-4000-8000-000000000005', 'Tirador asiento pasajero', 'Cromado', 8.80, 33, 'Universal', null),
  ('a1000005-0000-4000-8000-000000000005', 'Red elástica equipaje', '80x80cm', 7.50, 44, 'Rack', null),
  ('a1000005-0000-4000-8000-000000000005', 'Cubre cadena completo', 'ABS negro', 21.00, 21, 'CG150', null),
  ('a1000005-0000-4000-8000-000000000005', 'Soporte GPS RAM', '22mm', 34.00, 12, 'Manillar', null),
  ('a1000005-0000-4000-8000-000000000005', 'Kit tornillos carenado', 'Titanio look', 13.60, 30, 'M5/M6 surtido', null),

  -- ========== Importador 6 — Frenos y Transmisión VE ==========
  ('a1000006-0000-4000-8000-000000000006', 'Disco freno delantero 260mm', 'Flotante', 45.50, 18, 'Naked 200 / 250', null),
  ('a1000006-0000-4000-8000-000000000006', 'Latiguillo freno acero', '90cm', 24.00, 24, 'Freno delantero', null),
  ('a1000006-0000-4000-8000-000000000006', 'Bomba freno radial 14mm', 'Izquierda', 72.00, 7, '22mm manillar', null),
  ('a1000006-0000-4000-8000-000000000006', 'Pastillas sinterizadas', 'Alto coeficiente', 29.00, 26, 'CB190R', null),
  ('a1000006-0000-4000-8000-000000000006', 'Líquido frenos DOT5.1', '1L', 12.40, 35, 'Competición', null),
  ('a1000006-0000-4000-8000-000000000006', 'Kit purgado frenos', 'Jeringa + tubo', 8.90, 50, 'Mantenimiento', null),
  ('a1000006-0000-4000-8000-000000000006', 'Eje rueda delantero', 'Acero cromado', 19.50, 15, 'Wave 110', null),
  ('a1000006-0000-4000-8000-000000000006', 'Kit transmisión 520', 'Piñón+cadena+corona', 88.00, 10, 'Deportiva 250', null),
  ('a1000006-0000-4000-8000-000000000006', 'Guardapolvo horquilla', 'Par 41mm', 14.00, 32, 'Upside down', null),
  ('a1000006-0000-4000-8000-000000000006', 'Aceite horquilla 1L', '10W', 18.00, 20, 'Barras 33-43mm', null),
  ('a1000006-0000-4000-8000-000000000006', 'Rodillo cadena guía', 'Nylon', 11.50, 40, 'Swing arm', null),
  ('a1000006-0000-4000-8000-000000000006', 'Tensión cadena automático', 'Mecánico', 35.00, 14, 'Monocross', null),
  ('a1000006-0000-4000-8000-000000000006', 'Crapodina dirección', 'Juego', 27.00, 17, 'Columna 25x47', null),
  ('a1000006-0000-4000-8000-000000000006', 'Pastillas freno trasero', 'Orgánicas', 16.80, 45, 'Drum 125cc', null),
  ('a1000006-0000-4000-8000-000000000006', 'Cable embrague teflón', '120cm', 10.20, 38, 'Universal', null),
  ('a1000006-0000-4000-8000-000000000006', 'Bieletas cambio', 'Par aluminio', 22.50, 23, 'Pit bike', null),
  ('a1000006-0000-4000-8000-000000000006', 'Retén horquilla 41x53x8', 'Par', 9.90, 55, 'USD', null),
  ('a1000006-0000-4000-8000-000000000006', 'Disco freno trasero 220mm', 'Fijo', 32.00, 16, 'Sport 150', null),
  ('a1000006-0000-4000-8000-000000000006', 'Maneta freno ajustable', 'Derecha', 21.00, 29, 'Bomba estándar', null),
  ('a1000006-0000-4000-8000-000000000006', 'Separadores cadena plástico', 'Kit 4', 6.40, 60, 'Off-road', null),

  -- ========== Importador 7 — MotorZone Distribuidora (filtros / lubricantes) ==========
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aire espuma lavable', 'Alto flujo', 13.50, 48, 'Pit / 125', null),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aceite papel', 'Juego 3', 10.80, 70, 'Honda/Yamaha surtido', null),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite sintético 10W40', '1L', 8.90, 90, '4T performance', null),
  ('a1000007-0000-4000-8000-000000000007', 'Aditivo fricción caja', '125ml', 11.20, 42, 'Manual wet clutch', null),
  ('a1000007-0000-4000-8000-000000000007', 'Refrigerante orgánico', '1L', 5.40, 85, 'Mezcla 50/50', null),
  ('a1000007-0000-4000-8000-000000000007', 'Limpiador carburador', '400ml', 6.00, 55, 'Aerosol', null),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro combustible en línea', 'Transparente', 3.80, 120, '6mm manguera', null),
  ('a1000007-0000-4000-8000-000000000007', 'Junta tapa válvulas', 'Caucho', 4.20, 65, 'CG150', null),
  ('a1000007-0000-4000-8000-000000000007', 'Empaque culata 0.5mm', 'Fibra', 7.60, 40, '150cc OHV', null),
  ('a1000007-0000-4000-8000-000000000007', 'Tapón drenaje magnético', 'M14x1.5', 9.10, 33, 'Carter aceite', null),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite horquilla 5W', '500ml', 12.00, 28, 'Barras delgadas', null),
  ('a1000007-0000-4000-8000-000000000007', 'Grasa cardán', '250g', 8.30, 25, 'Eje', null),
  ('a1000007-0000-4000-8000-000000000007', 'Aditivo octanaje', '325ml', 14.50, 37, 'Nafta', null),
  ('a1000007-0000-4000-8000-000000000007', 'Prefiltro aire exterior', 'Malla lavable', 5.20, 88, 'Admisión 38mm', null),
  ('a1000007-0000-4000-8000-000000000007', 'Spray desengrasante', '600ml', 5.50, 75, 'Taller', null),
  ('a1000007-0000-4000-8000-000000000007', 'Pasta selladora alta temp', '85g', 6.80, 44, 'Escape', null),
  ('a1000007-0000-4000-8000-000000000007', 'Kit o-ring surtido', 'Caja 50', 9.40, 30, 'Carburador / aceite', null),
  ('a1000007-0000-4000-8000-000000000007', 'Indicador nivel aceite', 'Varilla cromada', 7.00, 52, 'CG125', null),
  ('a1000007-0000-4000-8000-000000000007', 'Aceite 2T mezcla', '1L', 7.20, 60, '2T aire', null),
  ('a1000007-0000-4000-8000-000000000007', 'Filtro aire papel OEM style', 'Rectangular', 11.00, 46, 'Scooter 150', null);
