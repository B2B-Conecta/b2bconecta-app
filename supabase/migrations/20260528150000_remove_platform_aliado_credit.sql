-- MotoConecta: el crédito/cupo del aliado ya no se gestiona en plataforma.
-- Los planes de cuotas son acuerdo directo aliado ↔ importador (sin validación de credit_limit).

-- Importador: plan de cuotas sin bloqueo de cupo MotoLink.
create or replace function public.importer_confirm_order_credit_plan (
  p_request_id uuid,
  p_amounts_usd numeric[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_importador uuid;
  v_total numeric(14, 4);
  v_st text;
  v_today_ccs date;
  n int;
  i int;
  s numeric;
  v_amt numeric(14, 4);
  k int;
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'importador'
  ) then
    raise exception 'Solo el importador del pedido puede confirmar el plan de cuotas.';
  end if;

  if p_amounts_usd is null or array_length(p_amounts_usd, 1) is null then
    raise exception 'Debe indicar al menos un monto de cuota.';
  end if;

  n := array_length(p_amounts_usd, 1);
  if n < 1 or n > 3 then
    raise exception 'Número de cuotas no válido (1 a 3).';
  end if;

  select tr.aliado_id, tr.importador_id, tr.precio_total_usd, tr.status
    into v_aliado, v_importador, v_total, v_st
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_importador is distinct from auth.uid () then
    raise exception 'No autorizado para este pedido.';
  end if;

  if v_st = 'rechazado' then
    raise exception 'No se puede firmar un plan en un pedido rechazado.';
  end if;

  if exists (
    select 1
    from public.payment_schedule ps
    where ps.transaction_request_id = p_request_id
      and ps.installment_index = 1
      and (
        ps.pago_submitted_at is not null
        or (
          ps.pago_comprobante_storage_path is not null
          and btrim(ps.pago_comprobante_storage_path) <> ''
        )
        or coalesce(nullif(btrim(ps.pago_estado_revision), ''), 'pendiente') <> 'pendiente'
      )
  ) then
    raise exception
      'PLAN_CUOTAS_BLOQUEADO: la primera cuota ya tiene comprobante o revisión; no se puede modificar el plan.';
  end if;

  s := 0;
  for i in 1..n loop
    s := s + coalesce(p_amounts_usd[i], 0);
  end loop;

  if abs(s - coalesce(v_total, 0)) > 0.02 then
    raise exception
      'MONTOS_NO_COINCIDEN: la suma de las cuotas no coincide con el total del pedido.';
  end if;

  v_today_ccs := (now() at time zone 'America/Caracas')::date;

  delete from public.payment_schedule
  where transaction_request_id = p_request_id;

  for k in 1..n loop
    v_amt := round(coalesce(p_amounts_usd[k], 0), 2);
    insert into public.payment_schedule (
      transaction_request_id,
      installment_index,
      amount_usd,
      due_on
    )
    values (
      p_request_id,
      k,
      v_amt,
      v_today_ccs + ((k - 1) * 15)
    );
  end loop;

  update public.transaction_requests
  set
    credit_plan_type = n,
    credit_plan_confirmed_at = now(),
    credit_monto_bloqueado = null,
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.importer_confirm_order_credit_plan (uuid, numeric[]) to authenticated;

-- Checkout multi-importador: sin tope por credit_limit en plataforma.
create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_rif text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_fiscal_maps text;
  v_pce integer;
  v_kyc text;
  v_psm boolean;
  v_fase_contado boolean;
  v_open_slots bigint;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_comm_rate numeric;
  c_fee constant numeric := 0.10;
  c_desc_contado constant numeric := 0.05;
  c_entregas_req constant int := 3;
  v_group_id uuid := gen_random_uuid ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if p_lines is null or jsonb_typeof (p_lines) <> 'array' or jsonb_array_length (p_lines) = 0 then
    raise exception 'El carrito está vacío';
  end if;

  select
    p.role,
    nullif(trim(p.rif), ''),
    nullif(trim(p.estado), ''),
    nullif(trim(p.ciudad), ''),
    nullif(trim(p.direccion), ''),
    nullif(trim(p.fiscal_maps_url), ''),
    coalesce(p.primeros_pedidos_contado_entregados, 0),
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_pce, v_kyc, v_psm
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;
  if v_role <> 'aliado' then
    raise exception 'Solo los aliados pueden confirmar el carrito';
  end if;
  if v_psm then
    raise exception
      'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad.';
  end if;
  if v_kyc is not null and v_kyc = 'rechazado' then
    raise exception
      'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
  end if;
  if v_rif is null then
    raise exception 'Registre su RIF comercial en Mi perfil para solicitar pedidos.';
  end if;
  if v_estado is null or v_ciudad is null or v_direccion is null then
    raise exception
      'Registre estado, ciudad y dirección fiscal en Mi perfil para poder solicitar pedidos.';
  end if;

  if p_destino_entrega_usa_perfil then
    if v_fiscal_maps is null then
      raise exception
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal.';
    end if;
  else
    if p_destino_entrega_texto is null
       or length(trim(p_destino_entrega_texto)) = 0 then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
    end if;
    if p_destino_entrega_maps_url is null
       or p_destino_entrega_maps_url !~* '^https?://' then
      raise exception
        'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.';
    end if;
  end if;

  v_fase_contado := v_pce < c_entregas_req;

  select count(*)::bigint
    into v_open_slots
  from (
    select distinct coalesce(tr.checkout_group_id, tr.id) as slot_key
    from public.transaction_requests tr
    where tr.aliado_id = v_uid
      and tr.status <> all (array['entregado'::text, 'rechazado'::text])
  ) s;

  if v_fase_contado and v_open_slots >= 1 then
    raise exception
      'En los primeros %s pedidos en contado solo puede tener un pedido activo a la vez.',
      c_entregas_req;
  end if;

  for rec in
    with parsed as (
      select
        (elem->>'product_id')::uuid as product_id,
        (elem->>'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    if rec.cantidad is null or rec.cantidad < 1 then
      raise exception 'Cantidad inválida en el carrito';
    end if;

    select
      pr.owner_id,
      pr.price_usd,
      pr.stock,
      pr.is_active
    into v_owner, v_price, v_stock, v_active
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;
    if not v_active then
      raise exception
        'El producto % no está disponible en el catálogo.',
        rec.product_id;
    end if;
    if v_stock < rec.cantidad then
      raise exception
        'Stock insuficiente: hay %s unidad(es) disponible(s) para una línea del carrito.',
        v_stock;
    end if;
  end loop;

  for rec in
    with parsed as (
      select
        (elem->>'product_id')::uuid as product_id,
        (elem->>'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    select
      pr.owner_id,
      pr.price_usd,
      pr.stock,
      pr.discount_rules
    into v_owner, v_price, v_stock, v_discount
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;

    v_unit := v_price * (1 + c_fee);
    if v_fase_contado then
      v_unit := v_unit * (1 - c_desc_contado);
    end if;
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount,
      v_comm_rate
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;
