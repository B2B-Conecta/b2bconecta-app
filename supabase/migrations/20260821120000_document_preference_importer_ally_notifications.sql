-- 1) Aliado elige nota vs factura fiscal → notificación a todos los administradores.
-- 2) Cuando ya están todas las facturas de importador(es) y aún falta la preferencia
--    → notificación in-app al aliado (crítico para emitir documento MotoLink).
--    Reutiliza document_type_nudge_sent_at para no duplicar avisos con otros triggers.

-- ---------------------------------------------------------------------------
create or replace function public.notify_ally_document_type_preference_after_importers_ready(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  tr record;
begin
  select
    id,
    aliado_id,
    status,
    document_type_preference,
    document_type_nudge_sent_at
  into tr
  from public.transaction_requests
  where id = p_request_id;

  if not found then
    return;
  end if;

  if tr.document_type_preference is not null
     and btrim(tr.document_type_preference) <> '' then
    return;
  end if;

  if tr.document_type_nudge_sent_at is not null then
    return;
  end if;

  if tr.status not in (
    'aprobado_admin',
    'en_preparacion',
    'pedido_listo',
    'en_transito',
    'entregado'
  ) then
    return;
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    tr.aliado_id,
    'MotoLink',
    'Los importadores ya cargaron la factura en su pedido. Elija nota de entrega simple o factura fiscal en la ficha; '
    'es necesario para que MotoLink emita su documento oficial.',
    'envio',
    tr.id::text
  );

  update public.transaction_requests
  set document_type_nudge_sent_at = now()
  where id = p_request_id
    and document_type_nudge_sent_at is null;
end;
$$;


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
    perform public.notify_ally_document_type_preference_after_importers_ready(v_parent);
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
    perform public.notify_ally_document_type_preference_after_importers_ready(new.id);
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


-- ---------------------------------------------------------------------------
-- Aliado: fija preferencia (solo si aún NULL; una sola vez) + aviso a administración.
-- Si las facturas de importador ya estaban cargadas, encola la factura MotoLink automática
-- (misma lógica que los triggers sobre proveedor_factura_storage_path).
create or replace function public.aliado_set_document_type_preference(
  p_request_id uuid,
  p_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_label text;
  v_tr record;
  n_subs int;
  n_missing int;
  v_updated int;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede registrar la preferencia de documento.';
  end if;

  if p_type is null or p_type not in ('nota_entrega', 'factura_fiscal') then
    raise exception 'Tipo de documento no válido.';
  end if;

  v_label := case p_type
    when 'nota_entrega' then 'nota de entrega simple'
    when 'factura_fiscal' then 'factura fiscal'
    else p_type
  end;

  update public.transaction_requests tr
  set
    document_type_preference = p_type,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
    and tr.document_type_preference is null;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo guardar la preferencia. Compruebe que el pedido sea suyo, que aún no haya elegido '
      'o que no esté cancelado/rechazado.';
  end if;

  perform public.notify_to_all_admins(
    'Preferencia de documento (aliado)',
    format(
      'Pedido %s: el aliado eligió %s para el documento oficial MotoLink.',
      left(p_request_id::text, 8),
      v_label
    ),
    'logistica',
    p_request_id::text
  );

  select * into strict v_tr
  from public.transaction_requests
  where id = p_request_id;

  if coalesce(btrim(v_tr.factura_aliado_storage_path), '') <> '' then
    return;
  end if;

  if coalesce(v_tr.is_master_order, false) then
    select count(*)::int into n_subs
    from public.sub_orders so
    where so.parent_order_id = p_request_id;
    if n_subs = 0 then
      return;
    end if;
    select count(*)::int into n_missing
    from public.sub_orders so
    where so.parent_order_id = p_request_id
      and coalesce(btrim(so.proveedor_factura_storage_path), '') = '';
    if n_missing > 0 then
      return;
    end if;
  else
    if coalesce(btrim(v_tr.proveedor_factura_storage_path), '') = '' then
      return;
    end if;
  end if;

  update public.transaction_requests tr
  set motolink_pending_auto_invoice = true
  where tr.id = p_request_id
    and coalesce(btrim(tr.factura_aliado_storage_path), '') = ''
    and coalesce(tr.motolink_pending_auto_invoice, false) = false;

  get diagnostics v_updated = row_count;
  if v_updated > 0 then
    if coalesce(v_tr.is_master_order, false) then
      perform public.notify_to_all_admins(
        'Facturas de importador completas',
        format(
          'Pedido %s: todas las facturas de proveedor están cargadas. La factura MotoLink al aliado se generará al abrir Pedidos activos o puede emitirla manualmente en la ficha.',
          left(p_request_id::text, 8)
        ),
        'logistica',
        p_request_id::text
      );
    else
      perform public.notify_to_all_admins(
        'Factura de proveedor lista',
        format(
          'Pedido %s: la factura del importador está cargada. La factura MotoLink al aliado se generará al abrir Pedidos activos o puede emitirla manualmente.',
          left(p_request_id::text, 8)
        ),
        'logistica',
        p_request_id::text
      );
    end if;
  end if;
end;
$$;
