-- Moroso: entregado sin pago aprobado (sin exigir factura ya emitida).
-- Notificaciones de ciclo de pedido más detalladas (producto, partes, estado legible).

-- ---------------------------------------------------------------------------
-- 1) Moroso (alineado con app)
-- ---------------------------------------------------------------------------
create or replace function public.tr_is_moroso_pago_pendiente (p_row public.transaction_requests)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_row.status <> 'entregado'::text then
    return false;
  end if;
  return coalesce(p_row.pago_estado_revision, '') <> 'aprobado';
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Etiquetas legibles de estado (notificaciones)
-- ---------------------------------------------------------------------------
create or replace function public.mc_tr_status_label_es (p_status text)
returns text
language sql
immutable
as $$
  select case p_status
    when 'pendiente' then 'Pendiente'
    when 'aprobado_admin' then 'Aprobado por MotoLink'
    when 'en_preparacion' then 'En preparación'
    when 'pedido_listo' then 'Listo para despacho'
    when 'en_transito' then 'En tránsito'
    when 'enviado' then 'Enviado'
    when 'entregado' then 'Entregado / recibido'
    when 'rechazado' then 'Rechazado / cerrado'
    else coalesce(p_status, 'Actualización')
  end;
$$;

create or replace function public.mc_tr_pago_estado_label_es (p_estado text)
returns text
language sql
immutable
as $$
  select case coalesce(p_estado, 'pendiente')
    when 'pendiente' then 'pendiente de comprobante'
    when 'en_revision' then 'comprobante en revisión'
    when 'aprobado' then 'aprobado'
    when 'rechazado' then 'rechazado'
    else p_estado
  end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Cambio de estado → notificaciones detalladas
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_aliado_name text;
  v_anchor text;
  v_product text;
  v_old_es text;
  v_new_es text;
  v_body_aliado text;
  v_body_imp text;
  v_body_admin text;
  v_title_aliado text;
begin
  perform set_config ('row_security', 'off', true);

  if old.status is not distinct from new.status then
    return new;
  end if;

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := coalesce(nullif(trim(new.product_name), ''), 'Producto');
  v_old_es := public.mc_tr_status_label_es (old.status);
  v_new_es := public.mc_tr_status_label_es (new.status);

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  )
  then
    v_title_aliado := case new.status
      when 'en_preparacion' then 'Pedido en preparación'
      when 'pedido_listo' then 'Listo para despacho'
      when 'en_transito' then 'Pedido en tránsito'
      else 'Actualización de envío'
    end;

    v_body_aliado := format(
      '%s · %s uds · %s REF — %s confirmó y el pedido pasó a «%s».',
      v_product,
      new.cantidad,
      round(new.precio_total_usd::numeric, 2),
      coalesce(v_imp_name, 'El importador'),
      v_new_es
    );

    if public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        v_title_aliado,
        v_body_aliado,
        'pedido',
        v_anchor
      );
    end if;

  elsif new.status = 'entregado'::text then
  v_body_imp := format(
      '%s recibió «%s» (%s uds, %s REF). Pago MotoLink: %s.',
      coalesce(v_aliado_name, 'El aliado'),
      v_product,
      new.cantidad,
      round(new.precio_total_usd::numeric, 2),
      public.mc_tr_pago_estado_label_es (new.pago_estado_revision)
    );

    perform public.mc_insert_notification (
      new.importador_id,
      'Pedido recibido en taller',
      v_body_imp,
      'pedido',
      v_anchor
    );

  elsif new.status = 'rechazado'::text then
    if public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
      perform public.mc_insert_notification (
        new.aliado_id,
        'Pedido cerrado',
        format(
          '«%s» pasó a «%s» (antes: %s). Revise el detalle en Pedidos.',
          v_product,
          v_new_es,
          v_old_es
        ),
        'pedido',
        v_anchor
      );
    end if;
  end if;

  v_body_admin := format(
    '«%s» · Aliado %s · Importador %s — %s → %s (%s uds, %s REF).',
    v_product,
    coalesce(v_aliado_name, substring(new.aliado_id::text, 1, 8)),
    coalesce(v_imp_name, substring(new.importador_id::text, 1, 8)),
    v_old_es,
    v_new_es,
    new.cantidad,
    round(new.precio_total_usd::numeric, 2)
  );

  perform public.mc_notify_all_admins (
    'Supervisión · ' || v_new_es,
    v_body_admin,
    'supervision',
    v_anchor
  );

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Nuevo pedido → importador (detalle)
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado_name text;
  v_product text;
  v_anchor text;
begin
  perform set_config ('row_security', 'off', true);

  if new.checkout_group_id is not null then
    if exists (
      select 1
      from public.transaction_requests tr
      where tr.checkout_group_id = new.checkout_group_id
        and tr.importador_id = new.importador_id
        and tr.id <> new.id
    ) then
      return new;
    end if;
  end if;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  v_product := coalesce(nullif(trim(new.product_name), ''), 'Producto');
  v_anchor := public.mc_tr_notif_anchor_id (new)::text;

  perform public.mc_insert_notification (
    new.importador_id,
    'Nuevo pedido',
    format(
      '%s solicitó «%s» — %s uds · %s REF. Estado: Pendiente. Revise en Pedidos.',
      coalesce(v_aliado_name, 'Un aliado'),
      v_product,
      new.cantidad,
      round(new.precio_total_usd::numeric, 2)
    ),
    'pedido',
    v_anchor
  );

  perform public.mc_notify_all_admins (
    'Nuevo pedido',
    format(
      '«%s» de %s hacia %s — %s uds · %s REF.',
      v_product,
      coalesce(v_aliado_name, 'aliado'),
      coalesce(
        (select nullif(trim(p.business_name), '') from public.profiles p where p.id = new.importador_id),
        'importador'
      ),
      new.cantidad,
      round(new.precio_total_usd::numeric, 2)
    ),
    'supervision',
    v_anchor
  );

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Moroso al entregar: texto alineado (sin exigir factura previa)
-- ---------------------------------------------------------------------------
create or replace function public.tr_notify_pedido_moroso_on_entregado ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_anchor text;
  v_product text;
  v_aliado_name text;
  v_imp_name text;
  v_pago_es text;
begin
  if new.status <> 'entregado'::text
     or old.status is not distinct from 'entregado'::text then
    return new;
  end if;

  if not public.tr_is_moroso_pago_pendiente (new) then
    return new;
  end if;

  select nullif(trim(p.business_name), '')
    into v_aliado_name
  from public.profiles p
  where p.id = new.aliado_id;

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := coalesce(nullif(trim(new.product_name), ''), 'Producto');
  v_pago_es := public.mc_tr_pago_estado_label_es (new.pago_estado_revision);

  if public.mc_tr_is_notification_anchor_row (new, 'aliado_importador') then
    perform public.mc_insert_notification (
      new.aliado_id,
      'Pedido moroso · pago pendiente',
      format(
        'Recibió «%s» (%s uds). El pedido figura como moroso: pago MotoLink %s. '
        'Registre su comprobante hasta que sea aprobado.',
        v_product,
        new.cantidad,
        v_pago_es
      ),
      'morosidad',
      v_anchor
    );
  end if;

  perform public.mc_insert_notification (
    new.importador_id,
    'Pedido moroso · pago pendiente',
    format(
      '«%s» fue recibido por %s con pago MotoLink %s. '
      'El aliado debe registrar comprobante; el pedido permanece moroso hasta la aprobación.',
      v_product,
      coalesce(v_aliado_name, 'el aliado'),
      v_pago_es
    ),
    'morosidad',
    v_anchor
  );

  for rec in
    select p.id
    from public.profiles p
    where p.role = 'administrador'::text
  loop
    perform public.mc_insert_notification (
      rec.id,
      'Pedido moroso',
      format(
        '«%s» entregado · %s → %s · pago %s.',
        v_product,
        coalesce(v_aliado_name, 'aliado'),
        coalesce(v_imp_name, 'importador'),
        v_pago_es
      ),
      'morosidad',
      v_anchor
    );
  end loop;

  return new;
end;
$$;
