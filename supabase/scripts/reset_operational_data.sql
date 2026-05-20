-- =============================================================================
-- Reset operativo MotoConecta (desarrollo / demo)
-- =============================================================================
-- Elimina pedidos, facturas, cortes de comisión, mensajes, cuotas y notificaciones
-- de pedidos; devuelve inventario descontado por checkout y fija stock seed.
--
-- NO borra: auth, perfiles, catálogo (filas de products), KYC ni platform_settings.
-- Archivos en Storage (facturas PDF, comprobantes) pueden quedar huérfanos:
--   vacíe manualmente buckets order-invoices y commission-settlement-invoices si aplica.
--
-- Uso:
--   supabase db query --linked -f supabase/scripts/reset_operational_data.sql
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1) Devolver stock descontado al crear pedidos (antes de borrar filas)
-- ---------------------------------------------------------------------------
update public.products p
set stock = p.stock + agg.qty_restored
from (
  select
    tr.product_id,
    sum(tr.cantidad)::int as qty_restored
  from public.transaction_requests tr
  where tr.product_id is not null
  group by tr.product_id
) agg
where p.id = agg.product_id;

-- ---------------------------------------------------------------------------
-- 2) Desvincular pedidos de cortes de comisión
-- ---------------------------------------------------------------------------
update public.transaction_requests
set commission_settlement_id = null
where commission_settlement_id is not null;

-- ---------------------------------------------------------------------------
-- 3) Tablas operativas (orden FK-safe)
-- ---------------------------------------------------------------------------
delete from public.commission_settlements;

do $t$
begin
  delete from public.aliado_pago_pendiente_reminder_sent;
exception
  when undefined_table then null;
end;
$t$;

do $t$
begin
  delete from public.sla_importer_pending_alert_sent;
exception
  when undefined_table then null;
end;
$t$;

do $t$
begin
  delete from public.motolink_ally_document_emissions;
exception
  when undefined_table then null;
end;
$t$;

-- payment_schedule y transaction_request_messages → ON DELETE CASCADE con pedidos
delete from public.transaction_requests;

-- Notificaciones ligadas a pedidos / cortes / pagos (conserva KYC u otras si las hay)
delete from public.notifications
where type in (
  'pago',
  'comision',
  'envio',
  'validacion',
  'supervision',
  'mensaje',
  'morosidad'
)
   or related_id is not null;

-- ---------------------------------------------------------------------------
-- 4) Stock canónico del catálogo seed (owner + SKU)
--    Valores alineados con supabase/seed.sql
-- ---------------------------------------------------------------------------
with seed_stock (owner_id, sku, stock) as (
  values
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-01', 120),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-02', 200),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-03', 85),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-04', 40),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-05', 150),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-06', 130),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-07', 280),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-08', 320),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-09', 140),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-10', 35),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-11', 70),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-12', 60),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-13', 22),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-14', 100),
    ('c1000001-0000-4000-8000-000000000001'::uuid, 'MC1-15', 12),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-01', 95),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-02', 175),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-03', 72),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-04', 38),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-05', 140),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-06', 118),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-07', 260),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-08', 300),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-09', 135),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-10', 30),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-11', 58),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-12', 52),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-13', 20),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-14', 92),
    ('c1000002-0000-4000-8000-000000000001'::uuid, 'MC2-15', 10)
)
update public.products p
set stock = s.stock
from seed_stock s
where p.owner_id = s.owner_id
  and p.sku = s.sku;

commit;
