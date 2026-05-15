-- Checkout carrito multi-línea (MotoConecta). Corrige PGRST202 al confirmar pedido desde la app.

-- Columnas de perfil que usa la app y la RPC (baseline antiguo puede no tenerlas).
alter table public.profiles
  add column if not exists primeros_pedidos_contado_entregados integer default 0,
  add column if not exists pedidos_suspendidos_morosidad boolean default false,
  add column if not exists kyc_status text,
  add column if not exists credit_limit numeric(14, 4),
  add column if not exists credito_consumido_acumulado numeric(14, 4) default 0;

-- Destino de entrega en pedido (opcional; la UI ya valida antes de llamar).
alter table public.transaction_requests
  add column if not exists destino_entrega_usa_perfil boolean default true,
  add column if not exists destino_entrega_texto text,
  add column if not exists destino_entrega_maps_url text;

-- Constantes alineadas a lib/utils/broker_pricing.dart y lib/models/cash_phase_policy.dart
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
  v_cl numeric;
  v_cca numeric;
  v_fase_contado boolean;
  v_open_cnt bigint;
  v_exposure numeric;
  v_sum_new numeric := 0;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_tol constant numeric := 0.01;
  -- fee 10 %, descuento fase contado 5 % sobre precio con comisión
  c_fee constant numeric := 0.10;
  c_desc_contado constant numeric := 0.05;
  c_entregas_req constant int := 3;
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
    coalesce(p.pedidos_suspendidos_morosidad, false),
    coalesce(p.credit_limit, 0::numeric),
    coalesce(p.credito_consumido_acumulado, 0::numeric)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_pce, v_kyc, v_psm, v_cl, v_cca
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
    into v_open_cnt
  from public.transaction_requests tr
  where tr.aliado_id = v_uid
    and tr.status <> all (array['entregado'::text, 'rechazado'::text]);

  if v_fase_contado and v_open_cnt >= 1 then
    raise exception
      'En los primeros %s pedidos en contado solo puede tener un pedido activo a la vez.',
      c_entregas_req;
  end if;

  -- Precio previo: suma en REF
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

    v_unit := v_price * (1 + c_fee);
    if v_fase_contado then
      v_unit := v_unit * (1 - c_desc_contado);
    end if;

    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_sum_new := v_sum_new + v_line_total;
  end loop;

  if v_cl > v_tol then
    v_exposure := public.aliado_effective_open_exposure (v_uid);
    if v_exposure + v_cca + v_sum_new > v_cl + v_tol then
      raise exception
        'Este pedido supera su límite de crédito autorizado. Reduzca el carrito o consulte con MotoLink.';
    end if;
  end if;

  -- Persistir pedidos y descontar stock
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
    select pr.owner_id, pr.price_usd, pr.stock
    into v_owner, v_price, v_stock
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

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url
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
      nullif(trim(p_destino_entrega_maps_url), '')
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return 'ok';
end;
$$;

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text
) to authenticated;

grant execute on function public.aliado_checkout_multi_importador (
  jsonb,
  boolean,
  text,
  text
) to service_role;
