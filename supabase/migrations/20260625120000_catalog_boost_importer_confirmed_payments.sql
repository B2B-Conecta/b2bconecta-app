-- E1.1: boost de catálogo aliado según pedidos con pago confirmado por el importador (ventana configurable).
-- No incluye comisiones (commission_settlements) ni aprobaciones de pago solo por admin MotoLink.

insert into public.platform_settings (key, value)
values ('catalog_boost_window_days', '30'::jsonb)
on conflict (key) do nothing;

alter table public.profiles
  add column if not exists catalog_paid_orders_30d integer not null default 0;

comment on column public.profiles.catalog_paid_orders_30d is
  'Pedidos con pago aprobado por el importador (confirmado_por = importador_id) en la ventana catalog_boost_window_days.';

-- ---------------------------------------------------------------------------
-- Ventana en días (default 30).
-- ---------------------------------------------------------------------------
create or replace function public.catalog_boost_window_days ()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    1,
    coalesce(
      (
        select (ps.value #>> '{}')::int
        from public.platform_settings ps
        where ps.key = 'catalog_boost_window_days'
      ),
      30
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- ¿La línea cuenta para el boost del importador?
-- ---------------------------------------------------------------------------
create or replace function public.tr_counts_for_catalog_boost (p_row public.transaction_requests)
returns boolean
language sql
stable
as $$
  select
    p_row.pago_estado_revision = 'aprobado'
    and p_row.confirmado_por is not null
    and p_row.confirmado_por = p_row.importador_id
    and p_row.status is distinct from 'rechazado'
    and coalesce(p_row.cancelado_por_aliado, false) = false
    and coalesce(btrim(p_row.importador_cancelacion_motivo), '') = ''
    and coalesce(p_row.anulado_por_motolink, false) = false
    and coalesce(p_row.pago_aprobado_at, p_row.updated_at, p_row.created_at) >= (
      now() - (public.catalog_boost_window_days() || ' days')::interval
    );
$$;

-- ---------------------------------------------------------------------------
-- Recalcular agregado en profiles (solo importadores).
-- ---------------------------------------------------------------------------
create or replace function public.refresh_importer_catalog_boost (p_importador_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cnt int;
begin
  if p_importador_id is null then
    return;
  end if;

  select count(*)::int
    into v_cnt
  from public.transaction_requests tr
  where tr.importador_id = p_importador_id
    and public.tr_counts_for_catalog_boost (tr);

  update public.profiles p
  set catalog_paid_orders_30d = coalesce(v_cnt, 0)
  where p.id = p_importador_id
    and p.role = 'importador';
end;
$$;

create or replace function public.refresh_all_importer_catalog_boost ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  for v_id in
    select p.id
    from public.profiles p
    where p.role = 'importador'
  loop
    perform public.refresh_importer_catalog_boost (v_id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger: actualizar al cambiar pago / confirmación / cierre del pedido.
-- ---------------------------------------------------------------------------
create or replace function public.trg_transaction_requests_refresh_catalog_boost ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_importer_catalog_boost (old.importador_id);
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.importador_id is distinct from new.importador_id then
      perform public.refresh_importer_catalog_boost (old.importador_id);
    end if;
  end if;

  perform public.refresh_importer_catalog_boost (new.importador_id);
  return new;
end;
$$;

drop trigger if exists trg_tr_refresh_catalog_boost on public.transaction_requests;

create trigger trg_tr_refresh_catalog_boost
after insert
or update of
  importador_id,
  pago_estado_revision,
  confirmado_por,
  pago_aprobado_at,
  status,
  cancelado_por_aliado,
  importador_cancelacion_motivo,
  anulado_por_motolink,
  updated_at
or delete on public.transaction_requests
for each row
execute function public.trg_transaction_requests_refresh_catalog_boost ();

-- Backfill inicial
select public.refresh_all_importer_catalog_boost ();

grant execute on function public.catalog_boost_window_days () to authenticated;
grant execute on function public.refresh_importer_catalog_boost (uuid) to service_role;
