-- El caso de postventa nombra el producto y las unidades afectadas.
-- En una devolución, el proveedor elige cambio o crédito para el próximo
-- pedido con esa tienda. El crédito queda anotado. No se descuenta solo
-- y no cambia transaction_requests.status.

alter table public.order_postventa_casos
  add column if not exists product_id uuid references public.products (id) on delete set null,
  add column if not exists product_name text,
  add column if not exists affected_qty integer,
  add column if not exists resolution text,
  add column if not exists credit_amount numeric(14, 4),
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references public.profiles (id);

comment on column public.order_postventa_casos.product_name is
  'Nombre del producto de esta línea al momento de registrar el caso.';
comment on column public.order_postventa_casos.affected_qty is
  'Unidades de ese producto que presentaron el inconveniente.';
comment on column public.order_postventa_casos.resolution is
  'Respuesta del proveedor en una devolución: cambio o credito.';
comment on column public.order_postventa_casos.credit_amount is
  'Monto REF anotado como crédito para el próximo pedido con este proveedor. No se resta solo.';

alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_affected_qty_chk;
alter table public.order_postventa_casos
  add constraint order_postventa_casos_affected_qty_chk
  check (affected_qty is null or affected_qty >= 1);

alter table public.order_postventa_casos
  drop constraint if exists order_postventa_casos_resolution_chk;
alter table public.order_postventa_casos
  add constraint order_postventa_casos_resolution_chk
  check (
    (
      resolution is null
      and credit_amount is null
      and resolved_at is null
    )
    or (
      resolution = 'cambio'
      and credit_amount is null
      and resolved_at is not null
    )
    or (
      resolution = 'credito'
      and credit_amount is not null
      and credit_amount >= 0
      and resolved_at is not null
    )
  );

alter table public.transaction_requests
  add column if not exists postventa_resolucion text,
  add column if not exists postventa_credito_monto numeric(14, 4);

comment on column public.transaction_requests.postventa_resolucion is
  'cambio o credito cuando el proveedor ya respondió la devolución. No cambia status.';
comment on column public.transaction_requests.postventa_credito_monto is
  'Crédito REF anotado para el próximo pedido con este proveedor.';

alter table public.transaction_requests
  drop constraint if exists transaction_requests_postventa_resolucion_chk;
alter table public.transaction_requests
  add constraint transaction_requests_postventa_resolucion_chk
  check (
    postventa_resolucion is null
    or (
      postventa_resolucion = 'cambio'
      and postventa_credito_monto is null
    )
    or (
      postventa_resolucion = 'credito'
      and postventa_credito_monto is not null
      and postventa_credito_monto >= 0
    )
  );

update public.order_postventa_casos c
set
  product_id = tr.product_id,
  product_name = coalesce(nullif(btrim(p.name), ''), 'Producto del pedido'),
  affected_qty = coalesce(nullif(tr.cantidad, 0), 1)
from public.transaction_requests tr
left join public.products p on p.id = tr.product_id
where tr.id = c.transaction_request_id
  and (
    c.product_name is null
    or c.affected_qty is null
  );

drop function if exists public.register_order_postventa_caso (uuid, text, text);

create or replace function public.register_order_postventa_caso (
  p_request_id uuid,
  p_kind text,
  p_body text,
  p_affected_qty integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tr public.transaction_requests%rowtype;
  v_role text;
  v_kind text := lower(btrim(coalesce(p_kind, '')));
  v_body text := btrim(coalesce(p_body, ''));
  v_anchor timestamptz;
  v_id uuid;
  v_at timestamptz := now();
  v_title text;
  v_qty integer;
  v_product_name text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_kind not in ('devolucion', 'queja') then
    raise exception 'Indique si es una devolución o una queja.';
  end if;
  if char_length(v_body) < 3 then
    raise exception 'Escriba qué ocurrió (mínimo 3 caracteres).';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_tr.aliado_id = v_uid then
    v_role := 'aliado';
  elsif v_tr.importador_id = v_uid then
    v_role := 'importador';
  else
    raise exception 'Solo la tienda o el proveedor de este pedido pueden registrarlo.';
  end if;

  if v_tr.status <> 'entregado' then
    raise exception 'Solo se registra en un pedido entregado.';
  end if;

  v_anchor := coalesce(v_tr.at_entregado, v_tr.updated_at);
  if v_anchor is null or v_anchor < now() - interval '7 days' then
    raise exception 'El plazo de 7 días para una devolución o una queja terminó.';
  end if;

  if exists (
    select 1
    from public.order_postventa_casos c
    where c.transaction_request_id = p_request_id
      and c.kind = v_kind
  ) then
    raise exception 'Eso ya quedó registrado en este pedido.';
  end if;

  v_qty := coalesce(p_affected_qty, nullif(v_tr.cantidad, 0), 1);
  if v_qty < 1 then
    v_qty := 1;
  end if;
  if coalesce(v_tr.cantidad, 0) > 0 and v_qty > v_tr.cantidad then
    raise exception 'La cantidad no puede superar las unidades de este producto en el pedido.';
  end if;

  select nullif(btrim(p.name), '')
    into v_product_name
  from public.products p
  where p.id = v_tr.product_id;

  if v_product_name is null then
    v_product_name := 'Producto del pedido';
  end if;

  insert into public.order_postventa_casos (
    transaction_request_id,
    kind,
    body,
    opened_by,
    opened_role,
    created_at,
    product_id,
    product_name,
    affected_qty
  )
  values (
    p_request_id,
    v_kind,
    v_body,
    v_uid,
    v_role,
    v_at,
    v_tr.product_id,
    v_product_name,
    v_qty
  )
  returning id into v_id;

  if v_kind = 'devolucion' then
    update public.transaction_requests
      set postventa_devolucion_at = v_at
      where id = p_request_id;
    v_title := 'Devolución registrada';
  else
    update public.transaction_requests
      set postventa_queja_at = v_at
      where id = p_request_id;
    v_title := 'Queja registrada';
  end if;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    v_role,
    v_title
      || ' en este pedido. Producto: '
      || v_product_name
      || '. Unidades: '
      || v_qty::text
      || '. '
      || v_body
  );

  return jsonb_build_object(
    'id', v_id,
    'kind', v_kind,
    'body', v_body,
    'opened_role', v_role,
    'created_at', v_at,
    'product_id', v_tr.product_id,
    'product_name', v_product_name,
    'affected_qty', v_qty
  );
end;
$$;

revoke all on function public.register_order_postventa_caso (uuid, text, text, integer) from public;
grant execute on function public.register_order_postventa_caso (uuid, text, text, integer) to authenticated;

create or replace function public.resolve_order_postventa_caso (
  p_request_id uuid,
  p_resolution text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tr public.transaction_requests%rowtype;
  v_caso public.order_postventa_casos%rowtype;
  v_resolution text := lower(btrim(coalesce(p_resolution, '')));
  v_qty integer;
  v_unit numeric;
  v_credit numeric(14, 4);
  v_at timestamptz := now();
  v_product text;
  v_amount_label text;
  v_body text;
  v_title text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_resolution not in ('cambio', 'credito') then
    raise exception 'Indique si es un cambio de producto o un crédito.';
  end if;

  select *
    into v_tr
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if not found then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_tr.importador_id is distinct from v_uid then
    raise exception 'Solo el proveedor de este pedido puede elegir el cambio o el crédito.';
  end if;

  select *
    into v_caso
  from public.order_postventa_casos c
  where c.transaction_request_id = p_request_id
    and c.kind = 'devolucion';

  if not found then
    raise exception 'Primero tiene que existir una devolución registrada.';
  end if;

  if v_caso.resolution is not null then
    raise exception 'Esta devolución ya tiene una respuesta.';
  end if;

  v_qty := coalesce(v_caso.affected_qty, nullif(v_tr.cantidad, 0), 1);
  if v_qty < 1 then
    v_qty := 1;
  end if;

  v_unit := coalesce(v_tr.precio_unitario_aliado, 0);
  if v_unit <= 0 and coalesce(v_tr.cantidad, 0) > 0 then
    v_unit := coalesce(v_tr.precio_total_usd, 0) / v_tr.cantidad;
  end if;
  if v_unit < 0 then
    v_unit := 0;
  end if;

  if v_resolution = 'credito' then
    v_credit := round(v_unit * v_qty, 4);
    v_title := 'Crédito para el próximo pedido';
  else
    v_credit := null;
    v_title := 'Cambio de producto';
  end if;

  v_product := coalesce(nullif(btrim(v_caso.product_name), ''), 'el producto');
  v_amount_label := trim(to_char(coalesce(v_credit, 0), 'FM999999990.00'));

  update public.order_postventa_casos
    set
      resolution = v_resolution,
      credit_amount = v_credit,
      resolved_at = v_at,
      resolved_by = v_uid
    where id = v_caso.id;

  update public.transaction_requests
    set
      postventa_resolucion = v_resolution,
      postventa_credito_monto = v_credit
    where id = p_request_id;

  if v_resolution = 'credito' then
    v_body := 'Crédito de '
      || v_amount_label
      || ' REF para el próximo pedido de esta tienda con este proveedor. Producto: '
      || v_product
      || '. Unidades: '
      || v_qty::text
      || '. El pedido sigue entregado y el crédito no se descuenta solo.';
  else
    v_body := 'El proveedor atenderá esta devolución con un cambio de producto. Producto: '
      || v_product
      || '. Unidades: '
      || v_qty::text
      || '. El pedido sigue entregado.';
  end if;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    'importador',
    v_body
  );

  perform public.mc_insert_notification (
    v_tr.aliado_id,
    v_title,
    v_body,
    'pedido',
    public.mc_tr_notif_anchor_id (v_tr)::text
  );

  return jsonb_build_object(
    'id', v_caso.id,
    'resolution', v_resolution,
    'credit_amount', v_credit,
    'resolved_at', v_at,
    'affected_qty', v_qty,
    'product_name', v_product
  );
end;
$$;

revoke all on function public.resolve_order_postventa_caso (uuid, text) from public;
grant execute on function public.resolve_order_postventa_caso (uuid, text) to authenticated;

-- Al confirmar la recepción, la tienda también recibe el aviso de los 7 días.
create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp_name text;
  v_carrier_name text;
  v_anchor text;
  v_product text;
  v_has_carriers boolean;
  v_title text;
  v_body text;
  v_target uuid;
  v_aliado_title text;
  v_aliado_body text;
begin
  perform set_config ('row_security', 'off', true);

  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  select nullif(trim(p.business_name), '')
    into v_imp_name
  from public.profiles p
  where p.id = new.importador_id;

  select nullif(trim(ic.company_name), '')
    into v_carrier_name
  from public.importer_carriers ic
  where ic.id = new.importer_carrier_id;

  v_anchor := public.mc_tr_notif_anchor_id (new)::text;
  v_product := public.mc_tr_product_label (new);
  v_has_carriers := public.motoconecta_importador_has_active_carriers (new.importador_id);

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  ) then
    v_target := new.aliado_id;
    v_title := case new.status
      when 'en_preparacion' then 'Pedido en preparación'
      when 'pedido_listo' then 'Listo para despacho'
      when 'en_transito' then 'Pedido en tránsito'
      else 'Actualización de pedido'
    end;

    v_body := case new.status
      when 'en_preparacion' then format(
        '%s confirmó su solicitud y está preparando %s.',
        coalesce(v_imp_name, 'El importador'),
        v_product
      )
      when 'pedido_listo' then case
        when v_has_carriers then
          format(
            'Su pedido %s está listo en %s. Elija un transportista o deje la entrega a elección del importador.',
            v_product,
            coalesce(v_imp_name, 'el importador')
          )
        else
          format(
            'Su pedido %s está listo para despacho en %s.',
            v_product,
            coalesce(v_imp_name, 'el importador')
          )
      end
      when 'en_transito' then case
        when v_carrier_name is not null then
          format(
            '%s despachó %s con %s. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador'),
            v_product,
            v_carrier_name
          )
        else
          format(
            '%s marcó %s como en tránsito. Va en camino a su taller.',
            coalesce(v_imp_name, 'El importador'),
            v_product
          )
      end
      else 'Hay un cambio de estado en su pedido.'
    end;

  elsif new.status = 'entregado'::text then
    v_target := new.importador_id;
    v_title := 'Pedido recibido';
    v_body := format(
      'La tienda confirmó la recepción de %s. Durante 7 días puede registrar una devolución o una queja.',
      v_product
    );
    v_aliado_title := 'Pedido recibido';
    v_aliado_body := format(
      'Confirmó la recepción de %s. El pedido queda registrado. Durante 7 días puede pedir una devolución o presentar una queja desde el detalle del pedido.',
      v_product
    );

  elsif new.status = 'rechazado'::text then
    v_target := new.aliado_id;
    v_title := 'Pedido rechazado';
    v_body := format(
      'Su solicitud de %s fue rechazada. Revísela en Pedidos.',
      v_product
    );

  else
    return new;
  end if;

  if v_target is not null
     and not exists (
       select 1
       from public.notifications n
       where n.user_id = v_target
         and n.type = 'pedido'
         and n.related_id = v_anchor
         and n.title = v_title
         and n.created_at > now () - interval '3 minutes'
     ) then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_target,
      v_title,
      coalesce(nullif(trim(v_body), ''), v_title),
      'pedido',
      v_anchor
    );
  end if;

  if v_aliado_title is not null
     and new.aliado_id is not null
     and not exists (
       select 1
       from public.notifications n
       where n.user_id = new.aliado_id
         and n.type = 'pedido'
         and n.related_id = v_anchor
         and n.title = v_aliado_title
         and n.created_at > now () - interval '3 minutes'
     ) then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      v_aliado_title,
      v_aliado_body,
      'pedido',
      v_anchor
    );
  end if;

  return new;
end;
$$;
