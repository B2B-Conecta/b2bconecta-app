-- 1) Restaurar tipo `credito` en notifications (p. ej. fase contado completada al confirmar entregas).
-- 2) Cola de generación automática de factura MotoLink al aliado cuando todas las facturas de importador están cargadas.
-- 3) Notificar a admins cuando la factura oficial queda publicada.

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'pago',
    'kyc',
    'mensaje',
    'envio',
    'validacion',
    'logistica',
    'credito'
  ));

alter table public.transaction_requests
  add column if not exists motolink_pending_auto_invoice boolean not null default false;

comment on column public.transaction_requests.motolink_pending_auto_invoice is
  'Si es true, el panel admin puede generar automáticamente la factura MotoLink al aliado al cargar Pedidos activos (todas las facturas de proveedor listas y preferencia de documento definida).';

-- ---------------------------------------------------------------------------
-- Pedido maestro: todas las sub_orders con factura de proveedor.
create or replace function public.tr_sub_orders_maybe_queue_motolink_auto_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent uuid;
  v_tr record;
  n_missing int;
  n_subs int;
  v_updated int;
begin
  v_parent := new.parent_order_id;
  if v_parent is null then
    return new;
  end if;

  select * into strict v_tr from public.transaction_requests tr where tr.id = v_parent;

  if not coalesce(v_tr.is_master_order, false) then
    return new;
  end if;

  select count(*)::int into n_subs
  from public.sub_orders so
  where so.parent_order_id = v_parent;

  if n_subs = 0 then
    return new;
  end if;

  select count(*)::int into n_missing
  from public.sub_orders so
  where so.parent_order_id = v_parent
    and coalesce(btrim(so.proveedor_factura_storage_path), '') = '';

  if n_missing > 0 then
    return new;
  end if;

  if coalesce(btrim(v_tr.factura_aliado_storage_path), '') <> '' then
    return new;
  end if;
  if v_tr.document_type_preference is null
     or btrim(v_tr.document_type_preference) = '' then
    return new;
  end if;

  update public.transaction_requests tr
  set motolink_pending_auto_invoice = true
  where tr.id = v_parent
    and coalesce(btrim(tr.factura_aliado_storage_path), '') = ''
    and coalesce(tr.motolink_pending_auto_invoice, false) = false;

  get diagnostics v_updated = row_count;
  if v_updated > 0 then
    perform public.notify_to_all_admins(
      'Facturas de importador completas',
      format(
        'Pedido %s: todas las facturas de proveedor están cargadas. La factura MotoLink al aliado se generará al abrir Pedidos activos o puede emitirla manualmente en la ficha.',
        left(v_parent::text, 8)
      ),
      'logistica',
      v_parent::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists tr_sub_orders_motolink_auto_invoice on public.sub_orders;
create trigger tr_sub_orders_motolink_auto_invoice
after insert or update of proveedor_factura_storage_path on public.sub_orders
for each row
execute function public.tr_sub_orders_maybe_queue_motolink_auto_invoice();

-- ---------------------------------------------------------------------------
-- Pedido simple: factura de proveedor en la fila maestra.
create or replace function public.tr_tr_proveedor_factura_maybe_queue_motolink_auto_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int;
begin
  if coalesce(new.is_master_order, false) then
    return new;
  end if;
  if coalesce(btrim(new.proveedor_factura_storage_path), '') = '' then
    return new;
  end if;
  if coalesce(btrim(new.factura_aliado_storage_path), '') <> '' then
    return new;
  end if;
  if new.document_type_preference is null
     or btrim(new.document_type_preference) = '' then
    return new;
  end if;

  update public.transaction_requests tr
  set motolink_pending_auto_invoice = true
  where tr.id = new.id
    and coalesce(btrim(tr.factura_aliado_storage_path), '') = ''
    and coalesce(tr.motolink_pending_auto_invoice, false) = false;

  get diagnostics v_updated = row_count;
  if v_updated > 0 then
    perform public.notify_to_all_admins(
      'Factura de proveedor lista',
      format(
        'Pedido %s: la factura del importador está cargada. La factura MotoLink al aliado se generará al abrir Pedidos activos o puede emitirla manualmente.',
        left(new.id::text, 8)
      ),
      'logistica',
      new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists tr_tr_proveedor_factura_motolink_auto_invoice on public.transaction_requests;
create trigger tr_tr_proveedor_factura_motolink_auto_invoice
after update of proveedor_factura_storage_path on public.transaction_requests
for each row
execute function public.tr_tr_proveedor_factura_maybe_queue_motolink_auto_invoice();

-- ---------------------------------------------------------------------------
create or replace function public.tr_tr_clear_motolink_pending_auto_invoice()
returns trigger
language plpgsql
as $$
begin
  if coalesce(btrim(new.factura_aliado_storage_path), '') <> '' then
    new.motolink_pending_auto_invoice := false;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_tr_factura_aliado_clears_auto_pending on public.transaction_requests;
create trigger tr_tr_factura_aliado_clears_auto_pending
before update of factura_aliado_storage_path on public.transaction_requests
for each row
execute function public.tr_tr_clear_motolink_pending_auto_invoice();

-- ---------------------------------------------------------------------------
create or replace function public.notify_factura_aliado_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_master boolean;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.factura_aliado_storage_path is distinct from new.factura_aliado_storage_path
     and coalesce(btrim(new.factura_aliado_storage_path), '') <> '' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Factura MotoLink disponible',
      'MotoLink publicó la factura oficial de su pedido. Ya puede revisarla y gestionar el pago en la ficha.',
      'pago',
      new.id::text
    );

    perform public.notify_to_all_admins(
      'Factura MotoLink publicada',
      format(
        'La factura oficial del pedido %s ya está disponible para el aliado.',
        left(new.id::text, 8)
      ),
      'pago',
      new.id::text
    );

    v_master := coalesce(new.is_master_order, false);
    perform public.notify_tr_importer_recipients(
      new.id,
      v_master,
      new.owner_id,
      'Factura MotoLink publicada',
      'MotoLink publicó la factura oficial al aliado para este pedido.',
      'pago',
      new.id::text
    );
  end if;

  return new;
end;
$$;
