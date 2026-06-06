-- =============================================================================
-- Limpieza completa del universo demo @motoconecta.seed (antes de volver a cargar seed)
-- =============================================================================
-- Elimina: pedidos, valoraciones, cortes, notificaciones demo, catálogo seed,
-- perfiles seed y usuarios auth @motoconecta.seed.
--
-- NO elimina: platform_settings, migraciones, usuarios que no sean @motoconecta.seed,
-- ni archivos en Storage (vacíe buckets manualmente si aplica).
--
-- Uso recomendado:
--   supabase db query --linked -f supabase/scripts/clean_database_for_seed.sql
--   supabase db query --linked -f supabase/seed.sql
--
-- Alternativa local:
--   supabase db reset   (aplica migraciones + seed.sql; el seed incluye limpieza inline)
-- =============================================================================

begin;

-- UUIDs fijos del seed (15 importadores, 3 aliados, 2 admins)
create temporary table _seed_profile_ids (id uuid primary key) on commit drop;

insert into _seed_profile_ids (id)
values
  ('c1000001-0000-4000-8000-000000000001'::uuid),
  ('c1000002-0000-4000-8000-000000000001'::uuid),
  ('c1000003-0000-4000-8000-000000000001'::uuid),
  ('c1000004-0000-4000-8000-000000000001'::uuid),
  ('c1000005-0000-4000-8000-000000000001'::uuid),
  ('c1000006-0000-4000-8000-000000000001'::uuid),
  ('c1000007-0000-4000-8000-000000000001'::uuid),
  ('c1000008-0000-4000-8000-000000000001'::uuid),
  ('c1000009-0000-4000-8000-000000000001'::uuid),
  ('c100000a-0000-4000-8000-000000000001'::uuid),
  ('c100000b-0000-4000-8000-000000000001'::uuid),
  ('c100000c-0000-4000-8000-000000000001'::uuid),
  ('c100000d-0000-4000-8000-000000000001'::uuid),
  ('c100000e-0000-4000-8000-000000000001'::uuid),
  ('c100000f-0000-4000-8000-000000000001'::uuid),
  ('c2000001-0000-4000-8000-000000000001'::uuid),
  ('c2000002-0000-4000-8000-000000000001'::uuid),
  ('c2000003-0000-4000-8000-000000000001'::uuid),
  ('c3000001-0000-4000-8000-000000000001'::uuid),
  ('c3000002-0000-4000-8000-000000000001'::uuid);

-- ---------------------------------------------------------------------------
-- 1) Devolver inventario descontado por pedidos seed (antes de borrar filas)
-- ---------------------------------------------------------------------------
update public.products p
set stock = p.stock + agg.qty_restored
from (
  select
    tr.product_id,
    sum(tr.cantidad)::int as qty_restored
  from public.transaction_requests tr
  where tr.product_id is not null
    and (
      tr.aliado_id in (select id from _seed_profile_ids)
      or tr.importador_id in (select id from _seed_profile_ids)
    )
  group by tr.product_id
) agg
where p.id = agg.product_id;

-- ---------------------------------------------------------------------------
-- 2) Desvincular cortes de comisión (seed importadores)
-- ---------------------------------------------------------------------------
update public.transaction_requests tr
set commission_settlement_id = null
where tr.importador_id in (select id from _seed_profile_ids)
   or tr.aliado_id in (select id from _seed_profile_ids);

delete from public.commission_settlements cs
where cs.importador_id in (select id from _seed_profile_ids);

-- ---------------------------------------------------------------------------
-- 3) Tablas auxiliares operativas (si existen; columnas alineadas a migraciones)
-- ---------------------------------------------------------------------------
do $t$
begin
  delete from public.order_ratings r
  where r.importador_id in (select id from _seed_profile_ids)
     or r.aliado_id in (select id from _seed_profile_ids);
exception
  when undefined_table then null;
end;
$t$;

-- aliado_pago_pendiente_reminder_sent: (aliado_id, anchor_id) — sin transaction_request_id
do $t$
begin
  delete from public.aliado_pago_pendiente_reminder_sent
  where aliado_id in (select id from _seed_profile_ids);
exception
  when undefined_table then null;
end;
$t$;

-- sla_importer_pending_alert_sent: (checkout_group_id, importador_id)
do $t$
begin
  delete from public.sla_importer_pending_alert_sent
  where importador_id in (select id from _seed_profile_ids);
exception
  when undefined_table then null;
end;
$t$;

do $t$
begin
  delete from public.payment_schedule ps
  using public.transaction_requests tr
  where ps.transaction_request_id = tr.id
    and (
      tr.aliado_id in (select id from _seed_profile_ids)
      or tr.importador_id in (select id from _seed_profile_ids)
    );
exception
  when undefined_table or undefined_column then null;
end;
$t$;

-- Mensajes de pedido (por si no hay ON DELETE CASCADE)
do $t$
begin
  delete from public.transaction_request_messages m
  using public.transaction_requests tr
  where m.transaction_request_id = tr.id
    and (
      tr.aliado_id in (select id from _seed_profile_ids)
      or tr.importador_id in (select id from _seed_profile_ids)
    );
exception
  when undefined_table then null;
end;
$t$;

-- ---------------------------------------------------------------------------
-- 4) Pedidos del universo demo
-- ---------------------------------------------------------------------------
delete from public.transaction_requests tr
where tr.aliado_id in (select id from _seed_profile_ids)
   or tr.importador_id in (select id from _seed_profile_ids);

-- ---------------------------------------------------------------------------
-- 5) Notificaciones de usuarios seed
-- ---------------------------------------------------------------------------
delete from public.notifications n
where n.user_id in (select id from _seed_profile_ids);

-- ---------------------------------------------------------------------------
-- 6) Campañas promocionales y datos auxiliares demo
-- ---------------------------------------------------------------------------
do $t$
begin
  delete from public.promo_campaigns;
exception
  when undefined_table then null;
end;
$t$;

do $t$
begin
  delete from public.aliado_pago_frecuente_importador
  where aliado_id in (select id from _seed_profile_ids)
     or importador_id in (select id from _seed_profile_ids);
exception
  when undefined_table then null;
end;
$t$;

-- ---------------------------------------------------------------------------
-- 7) Catálogo y perfiles seed
-- ---------------------------------------------------------------------------
delete from public.products p
where p.owner_id in (
  select id from _seed_profile_ids where id::text like 'c100000%'
);

delete from public.profiles pr
where pr.id in (select id from _seed_profile_ids);

-- ---------------------------------------------------------------------------
-- 8) Auth (@motoconecta.seed)
-- ---------------------------------------------------------------------------
delete from auth.identities i
where i.user_id in (
  select u.id from auth.users u where u.email like '%@motoconecta.seed'
);

delete from auth.users u
where u.email like '%@motoconecta.seed';

commit;

-- Verificación opcional (debe devolver 0 filas en perfiles seed):
-- select count(*) from public.profiles where id in (
--   'c1000001-0000-4000-8000-000000000001','c2000001-0000-4000-8000-000000000001'
-- );
