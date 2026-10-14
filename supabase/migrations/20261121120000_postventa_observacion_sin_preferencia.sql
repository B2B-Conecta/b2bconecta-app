-- La tienda registra la observación. El proveedor elige crédito o cambio en el chat.

create or replace function public.register_order_postventa_caso (
  p_request_id uuid,
  p_kind text,
  p_body text,
  p_affected_qty integer default null,
  p_requested_resolution text default null,
  p_evidence jsonb default '[]'::jsonb
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
  v_pref text := lower(btrim(coalesce(p_requested_resolution, '')));
  v_evidence jsonb := coalesce(p_evidence, '[]'::jsonb);
  v_anchor timestamptz;
  v_id uuid;
  v_at timestamptz := now();
  v_title text;
  v_qty integer;
  v_product_name text;
  v_message text;
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
  if not public.order_message_attachments_ok(v_evidence) then
    raise exception 'La evidencia no es válida. Use hasta 3 fotos o 1 video.';
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

  if v_kind = 'devolucion' and v_role <> 'aliado' then
    raise exception 'Solo la tienda puede registrar la observación.';
  end if;

  if v_tr.status <> 'entregado' then
    raise exception 'Solo se registra en un pedido entregado.';
  end if;

  v_anchor := coalesce(v_tr.at_entregado, v_tr.updated_at);
  if v_anchor is null or v_anchor < now() - interval '7 days' then
    raise exception 'El plazo de 7 días para una observación terminó.';
  end if;

  if exists (
    select 1
    from public.order_postventa_casos c
    where c.transaction_request_id = p_request_id
      and c.kind = v_kind
  ) then
    raise exception 'Eso ya quedó registrado en este pedido.';
  end if;

  if v_kind = 'devolucion' then
    if v_pref <> '' and v_pref not in ('credito', 'cambio') then
      raise exception 'La solución indicada no es válida.';
    end if;
    if jsonb_array_length(v_evidence) < 1 then
      raise exception 'Adjunte al menos una foto o un video.';
    end if;
    if exists (
      select 1
      from jsonb_array_elements(v_evidence) e
      where split_part(coalesce(e ->> 'path', ''), '/', 1)
        is distinct from p_request_id::text
    ) then
      raise exception 'La evidencia no corresponde a este pedido.';
    end if;
  else
    v_pref := '';
    v_evidence := '[]'::jsonb;
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
    affected_qty,
    requested_resolution,
    evidence,
    status
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
    v_qty,
    nullif(v_pref, ''),
    v_evidence,
    'abierta'
  )
  returning id into v_id;

  if v_kind = 'devolucion' then
    update public.transaction_requests
      set postventa_devolucion_at = v_at
      where id = p_request_id;
    v_title := 'Observación del pedido';
    v_message := v_title
      || '. Producto: '
      || v_product_name
      || '. Unidades: '
      || v_qty::text
      || '. '
      || v_body;
  else
    update public.transaction_requests
      set postventa_queja_at = v_at
      where id = p_request_id;
    v_title := 'Queja registrada';
    v_message := v_title
      || ' en este pedido. Producto: '
      || v_product_name
      || '. Unidades: '
      || v_qty::text
      || '. '
      || v_body;
  end if;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body,
    attachments
  )
  values (
    p_request_id,
    v_uid,
    v_role,
    v_message,
    v_evidence
  );

  return jsonb_build_object(
    'id', v_id,
    'kind', v_kind,
    'body', v_body,
    'opened_role', v_role,
    'created_at', v_at,
    'product_id', v_tr.product_id,
    'product_name', v_product_name,
    'affected_qty', v_qty,
    'requested_resolution', nullif(v_pref, ''),
    'status', 'abierta'
  );
end;
$$;
