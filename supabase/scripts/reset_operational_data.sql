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
--   supabase db query --linked -f supabase/scripts/seed_catalog_stock.sql
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

do $t$
begin
  delete from public.order_ratings;
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

commit;

-- Restaurar stock canónico (SKUs alineados con supabase/seed.sql):
--   supabase db query --linked -f supabase/scripts/seed_catalog_stock.sql
