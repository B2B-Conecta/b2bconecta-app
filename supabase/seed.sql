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
--
-- C1 comisiones: al final hay 2 pedidos «entregado» con devengo (importador1/2).
-- En admin → Comisiones → «Semana actual» para generar cortes de prueba.
--   importador1@motoconecta.seed
--   importador2@motoconecta.seed
--   aliado1@motoconecta.seed
--   admin@motoconecta.seed
--
-- Si falla profiles_id_fkey: suele ser (a) email seed ya en auth.users con OTRO id, y el
-- insert en auth se omite pero el perfil usa UUID fijo; o (b) typo en UUID (importador2
-- es c1000002…, no c1080802…). Este script limpia primero por email @motoconecta.seed.
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Limpieza re-seed: orden FK-safe; borra auth por email para eliminar duplicados
-- ---------------------------------------------------------------------------
delete from public.commission_settlements
where importador_id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000001'::uuid
)
   or id = 'e1000001-0000-4000-8000-000000000001'::uuid;

delete from public.transaction_request_messages
where transaction_request_id in (
  select tr.id
  from public.transaction_requests tr
  where tr.aliado_id in (
    'c2000001-0000-4000-8000-000000000001'::uuid,
    'c1000001-0000-4000-8000-000000000001'::uuid,
    'c1000002-0000-4000-8000-000000000001'::uuid
  )
     or tr.importador_id in (
    'c1000001-0000-4000-8000-000000000001'::uuid,
    'c1000002-0000-4000-8000-000000000001'::uuid
  )
);

delete from public.transaction_requests
where aliado_id in (
    'c2000001-0000-4000-8000-000000000001'::uuid,
    'c1000001-0000-4000-8000-000000000001'::uuid,
    'c1000002-0000-4000-8000-000000000001'::uuid
  )
   or importador_id in (
    'c1000001-0000-4000-8000-000000000001'::uuid,
    'c1000002-0000-4000-8000-000000000001'::uuid
  );

delete from public.notifications
where user_id in (
  select id
  from auth.users
  where email in (
    'importador1@motoconecta.seed',
    'importador2@motoconecta.seed',
    'aliado1@motoconecta.seed',
    'admin@motoconecta.seed'
  )
);

delete from public.products
where owner_id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000001'::uuid
);

delete from public.profiles
where id in (
  'c1000001-0000-4000-8000-000000000001'::uuid,
  'c1000002-0000-4000-8000-000000000001'::uuid,
  'c2000001-0000-4000-8000-000000000001'::uuid,
  'c3000001-0000-4000-8000-000000000001'::uuid
);

delete from auth.identities
where user_id in (
  select id from auth.users where email in (
    'importador1@motoconecta.seed',
    'importador2@motoconecta.seed',
    'aliado1@motoconecta.seed',
    'admin@motoconecta.seed'
  )
);

delete from auth.users
where email in (
  'importador1@motoconecta.seed',
  'importador2@motoconecta.seed',
  'aliado1@motoconecta.seed',
  'admin@motoconecta.seed'
);

-- ---------------------------------------------------------------------------
-- auth.users + identities (2 importadores, 1 aliado, 1 admin)
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
    ('c2000001-0000-4000-8000-000000000001'::uuid, 'aliado1@motoconecta.seed'),
    ('c3000001-0000-4000-8000-000000000001'::uuid, 'admin@motoconecta.seed')
) as s(id, email)
where exists (select 1 from auth.users u where u.id = s.id)
  and not exists (
    select 1 from auth.identities i
    where i.user_id = s.id and i.provider = 'email'
  );

-- ---------------------------------------------------------------------------
-- Perfiles: 2 importadores, 1 aliado, 1 admin (domicilio fiscal de referencia)
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
    'c1000002-0000-4000-8000-000000000001',
    'MotoConecta Import Omega C.A.',
    'J-402222222',
    'importador',
    '+58 424-1000002',
    null,
    'Aragua',
    'Maracay',
    'Av. Bolívar Norte, galpón 7, zona industrial San Jacinto (referencia fiscal / almacén).',
    'https://www.google.com/maps?q=10.2442,-67.6061',
    10.2442,
    -67.6061,
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
-- Catálogo: 15 productos por importador (30 filas en total)
-- (Pedido, mensajes y productos seed ya se vacían al inicio del script.)
-- ---------------------------------------------------------------------------
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
  ('c1000001-0000-4000-8000-000000000001', 'Silenciador deportivo 125 cc homologado', 'MC1-15', 'Motor', 95.0000, 12, true),
  ('c1000002-0000-4000-8000-000000000001', 'Kit embrague 150cc reforzado', 'MC2-01', 'Transmisión', 48.5000, 95, true),
  ('c1000002-0000-4000-8000-000000000001', 'Cadena 520 — 120 eslabones O-ring', 'MC2-02', 'Transmisión', 35.2000, 175, true),
  ('c1000002-0000-4000-8000-000000000001', 'Pastillas freno delantero sinterizado', 'MC2-03', 'Frenos', 21.0000, 72, true),
  ('c1000002-0000-4000-8000-000000000001', 'Disco freno delantero 260 mm flotante', 'MC2-04', 'Frenos', 55.5000, 38, true),
  ('c1000002-0000-4000-8000-000000000001', 'Cable acelerador reforzado 1.35 m', 'MC2-05', 'Motor', 6.9000, 140, true),
  ('c1000002-0000-4000-8000-000000000001', 'Cable embrague teflonado', 'MC2-06', 'Transmisión', 8.4000, 118, true),
  ('c1000002-0000-4000-8000-000000000001', 'Aceite 4T 15W50 semi-sintético (1 L)', 'MC2-07', 'Motor', 9.1000, 260, true),
  ('c1000002-0000-4000-8000-000000000001', 'Bujía NGK platino CR8E', 'MC2-08', 'Motor', 5.8000, 300, true),
  ('c1000002-0000-4000-8000-000000000001', 'Filtro de aire papel de alto flujo', 'MC2-09', 'Motor', 10.5000, 135, true),
  ('c1000002-0000-4000-8000-000000000001', 'Batería 12N12-BS AGM', 'MC2-10', 'Motor', 66.0000, 30, true),
  ('c1000002-0000-4000-8000-000000000001', 'Bobina alta tensión performance 3 pin', 'MC2-11', 'Motor', 27.5000, 58, true),
  ('c1000002-0000-4000-8000-000000000001', 'Rectificador regulador 12 V 11 cables', 'MC2-12', 'Motor', 21.8000, 52, true),
  ('c1000002-0000-4000-8000-000000000001', 'Amortiguador trasero 330 mm gas', 'MC2-13', 'Motor', 91.0000, 20, true),
  ('c1000002-0000-4000-8000-000000000001', 'Kit rodamiento rueda trasera', 'MC2-14', 'Transmisión', 17.9000, 92, true),
  ('c1000002-0000-4000-8000-000000000001', 'Escape corto homologado 150 cc', 'MC2-15', 'Motor', 99.5000, 10, true);

-- ---------------------------------------------------------------------------
-- C1 (Minuta #7): pedidos entregados con comisión devengada (prueba de cortes)
-- Admin → Comisiones → «Semana actual (prueba)» o «semana anterior»; o emitir el corte demo abajo.
-- ---------------------------------------------------------------------------
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
  destino_entrega_usa_perfil,
  created_at,
  updated_at
)
values
  (
    'd1000001-0000-4000-8000-000000000001'::uuid,
    'c2000001-0000-4000-8000-000000000001'::uuid,
    'c1000001-0000-4000-8000-000000000001'::uuid,
    (
      select p.id
      from public.products p
      where p.owner_id = 'c1000001-0000-4000-8000-000000000001'::uuid
        and p.sku = 'MC1-01'
      limit 1
    ),
    'entregado',
    2,
    90.0000,
    0.05,
    4.5000,
    now(),
    true,
    now(),
    now()
  ),
  (
    'd1000002-0000-4000-8000-000000000002'::uuid,
    'c2000001-0000-4000-8000-000000000001'::uuid,
    'c1000002-0000-4000-8000-000000000001'::uuid,
    (
      select p.id
      from public.products p
      where p.owner_id = 'c1000002-0000-4000-8000-000000000001'::uuid
        and p.sku = 'MC2-01'
      limit 1
    ),
    'entregado',
    1,
    48.5000,
    0.05,
    2.4250,
    now(),
    true,
    now(),
    now()
  )
on conflict (id) do update set
  status = excluded.status,
  precio_total_usd = excluded.precio_total_usd,
  commission_rate_snapshot = excluded.commission_rate_snapshot,
  comision_devengada_usd = excluded.comision_devengada_usd,
  comision_devengada_at = excluded.comision_devengada_at,
  commission_settlement_id = null,
  updated_at = now();

-- Corte demo emitido (importador Delta) — pedido d1000001 incluido; PDF al emitir desde admin.
insert into public.commission_settlements (
  id,
  importador_id,
  period_start,
  period_end,
  total_commission_usd,
  line_count,
  status,
  invoice_reference,
  issued_at,
  created_by
)
values (
  'e1000001-0000-4000-8000-000000000001'::uuid,
  'c1000001-0000-4000-8000-000000000001'::uuid,
  (date_trunc('week', current_date))::date,
  (date_trunc('week', current_date) + interval '6 days')::date,
  4.5000,
  1,
  'emitido',
  'ML-COM-SEED-000001',
  now(),
  'c3000001-0000-4000-8000-000000000001'::uuid
)
on conflict (id) do update set
  status = excluded.status,
  invoice_reference = excluded.invoice_reference,
  issued_at = excluded.issued_at,
  total_commission_usd = excluded.total_commission_usd,
  line_count = excluded.line_count;

update public.transaction_requests tr
set commission_settlement_id = 'e1000001-0000-4000-8000-000000000001'::uuid
where tr.id = 'd1000001-0000-4000-8000-000000000001'::uuid;
