-- B4 Ingreso directo: pedidos entran en `aprobado_admin` sin cola de aprobación MotoLink;
-- notificaciones a importadores/aliado; checkout maestro alineado; timestamps al insertar.

-- ---------------------------------------------------------------------------
-- 1) Lifecycle: `at_aprobado_admin` al INSERT si ya viene aprobado.
-- ---------------------------------------------------------------------------
create or replace function public.transaction_requests_set_lifecycle_timestamps()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'aprobado_admin' and new.at_aprobado_admin is null then
      new.at_aprobado_admin := now();
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'aprobado_admin' and new.at_aprobado_admin is null then
      new.at_aprobado_admin := now();
    elsif new.status = 'rechazado' and new.at_rechazado is null then
      new.at_rechazado := now();
    elsif new.status = 'en_preparacion' and new.at_en_preparacion is null then
      new.at_en_preparacion := now();
    elsif new.status = 'pedido_listo' and new.at_pedido_listo is null then
      new.at_pedido_listo := now();
    elsif new.status = 'en_transito' and new.at_en_transito is null then
      new.at_en_transito := now();
    elsif new.status = 'entregado' and new.at_entregado is null then
      new.at_entregado := now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_timestamps on public.transaction_requests;
create trigger tr_transaction_requests_timestamps
  before insert or update of status on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_set_lifecycle_timestamps();

-- ---------------------------------------------------------------------------
-- 2) INSERT: ingreso directo vs pendiente (legacy / admin manual).
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_transaction_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'aprobado_admin' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Pedido registrado',
      'Su pedido fue enviado al importador para confirmación de stock y preparación.',
      'envio',
      new.id::text
    );
    if coalesce(new.is_master_order, false) = false
       and new.owner_id is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.owner_id,
        'Pedido nuevo en su inventario',
        'Un aliado registró un pedido sobre su catálogo. Confirme disponibilidad para pasar a preparación.',
        'envio',
        new.id::text
      );
    end if;
    return new;
  end if;

  if coalesce(new.is_master_order, false) = false
     and new.owner_id is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.owner_id,
      'Nueva solicitud de pedido',
      'Un aliado creó una nueva solicitud sobre su inventario.',
      'envio',
      new.id::text
    );
  end if;

  perform public.notify_to_all_admins(
    'Nueva solicitud por validar',
    'Se creó una nueva solicitud de pedido pendiente de revisión.',
    'validacion',
    new.id::text
  );
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Sub-pedidos: mensaje según si el maestro ya está operativo (directo) o pendiente.
-- ---------------------------------------------------------------------------
create or replace function public.notify_sub_order_importer_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
begin
  if new.importador_id is null then
    return new;
  end if;

  select tr.status
  into st
  from public.transaction_requests tr
  where tr.id = new.parent_order_id;

  if st = 'aprobado_admin' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido nuevo en su inventario',
      'Un aliado registró un pedido que incluye su inventario. Confirme disponibilidad para pasar a preparación.',
      'envio',
      new.parent_order_id::text
    );
  else
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Nueva solicitud de pedido',
      'Un aliado creó una nueva solicitud que incluye su inventario.',
      'envio',
      new.parent_order_id::text
    );
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Checkout maestro: mismo cuerpo que 20260730140000; maestro en `aprobado_admin` (ingreso directo).
-- ---------------------------------------------------------------------------
create or replace function public.aliado_checkout_multi_importador(
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text,
  p_destino_entrega_maps_url text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  ks text;
  pc int;
  lim numeric;
  cons numeric;
  open_cnt int;
  v_rif text;
  v_est text;
  v_ciu text;
  v_dir text;
  sus boolean;
  tasa numeric;
  master_id uuid;
  line jsonb;
  pid uuid;
  qty int;
  imp uuid;
  pu numeric;
  ua numeric;
  lt numeric;
  lb numeric;
  sub_id uuid;
  sub_total numeric;
  sub_n int;
  grand_base numeric := 0;
  grand_total numeric := 0;
  fase_contado boolean;
  prod_stock int;
  expo numeric;
  tol constant numeric := 0.01;
  maps_trim text;
  dest_text text;
  r_imp record;
  v_fiscal_maps text;
begin
  v_aliado := auth.uid();
  if v_aliado is null then
    raise exception 'Sesión requerida.';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_aliado and p.role = 'aliado'
  ) then
    raise exception 'Solo los aliados pueden confirmar este pedido.';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'El carrito está vacío.';
  end if;

  select
    kyc_status,
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_consumido_acumulado, 0),
    nullif(trim(rif), ''),
    nullif(trim(estado), ''),
    nullif(trim(ciudad), ''),
    nullif(trim(direccion), ''),
    coalesce(pedidos_suspendidos_morosidad, false),
    nullif(trim(fiscal_maps_url), '')
  into ks, pc, lim, cons, v_rif, v_est, v_ciu, v_dir, sus, v_fiscal_maps
  from public.profiles
  where id = v_aliado and role = 'aliado';

  if ks is null then
    raise exception 'No se encontró el perfil del aliado.';
  end if;
  if sus then
    raise exception
      'Sus nuevos pedidos están suspendidos por morosidad. Regularice los pagos pendientes con MotoLink.';
  end if;

  if pc < 3 then
    if ks = 'rechazado' then
      raise exception
        'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
    end if;
    if v_rif is null then
      raise exception
        'Registre su RIF comercial en Mi perfil para solicitar pedidos en contado.';
    end if;
    if v_est is null or v_ciu is null or v_dir is null then
      raise exception
        'Registre estado, ciudad y dirección fiscal en Mi perfil para solicitar pedidos.';
    end if;

    select count(*)::integer into open_cnt
    from public.transaction_requests
    where aliado_id = v_aliado
      and status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'en_transito'
      );
    if open_cnt >= 1 then
      raise exception
        'En los primeros tres pedidos en contado solo puede tener un pedido activo a la vez.';
    end if;
  else
    if ks = 'rechazado' then
      raise exception
        'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
    end if;
    if v_rif is null then
      raise exception
        'Registre su RIF comercial en Mi perfil para solicitar pedidos.';
    end if;
    if v_est is null or v_ciu is null or v_dir is null then
      raise exception
        'Registre estado, ciudad y dirección fiscal en Mi perfil para solicitar pedidos.';
    end if;
  end if;

  fase_contado := pc < 3;

  select coalesce(value_numeric, 36.0) into tasa
  from public.app_global_config
  where key = 'tasa_bcv';

  maps_trim := nullif(trim(coalesce(p_destino_entrega_maps_url, '')), '');
  dest_text := nullif(trim(coalesce(p_destino_entrega_texto, '')), '');

  if coalesce(p_destino_entrega_usa_perfil, true) = true then
    if v_fiscal_maps is null or v_fiscal_maps !~* '^https?://' then
      raise exception
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal (URL http o https).';
    end if;
  else
    if dest_text is null then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
    end if;
    if maps_trim is null or maps_trim !~* '^https?://' then
      raise exception
        'Indique el enlace de Google Maps (http o https) de la ubicación de entrega alterna.';
    end if;
  end if;

  create temporary table _checkout_lines (
    product_id uuid not null,
    importador_id uuid not null,
    cantidad int not null,
    precio_unitario_proveedor numeric(14, 4) not null,
    precio_unitario_aliado numeric(14, 4) not null,
    precio_line_total numeric(14, 2) not null,
    precio_base_aliado_line numeric(14, 2) not null
  ) on commit drop;

  for line in select * from jsonb_array_elements(p_lines)
  loop
    pid := (line->>'product_id')::uuid;
    qty := coalesce((line->>'cantidad')::int, 0);
    if pid is null or qty < 1 then
      raise exception 'Cada línea debe incluir product_id y cantidad válidos.';
    end if;

    select p.owner_id, p.price_usd::numeric, p.stock::int
    into imp, pu, prod_stock
    from public.products p
    where p.id = pid;

    if imp is null then
      raise exception 'Producto no encontrado: %.', pid;
    end if;
    if qty > prod_stock then
      raise exception 'Stock insuficiente para el producto %. Disponible: %.', pid, prod_stock;
    end if;

    ua := round(
      pu * 1.10 * case when fase_contado then 0.95 else 1.0 end,
      4
    );
    lt := round(ua * qty, 2);
    lb := lt;

    grand_base := grand_base + lb;
    grand_total := grand_total + lt;

    insert into _checkout_lines values (
      pid,
      imp,
      qty,
      pu,
      ua,
      lt,
      lb
    );
  end loop;

  if lim is not null and lim > 0 and pc >= 3 then
    select coalesce(
      sum(public.transaction_request_effective_cupo_block(tr.id)),
      0
    ) into expo
    from public.transaction_requests tr
    where tr.aliado_id = v_aliado
      and tr.status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'pedido_listo',
        'en_transito'
      );

    if expo + cons + grand_total > lim + tol then
      raise exception
        'Este pedido supera el límite de crédito MotoLink asignado a su cuenta.';
    end if;
  end if;

  insert into public.transaction_requests (
    aliado_id,
    is_master_order,
    product_id,
    owner_id,
    status,
    cantidad,
    precio_unitario_proveedor,
    precio_unitario_aliado,
    precio_total,
    precio_base_aliado_total,
    tasa_bcv_snapshot,
    destino_entrega_usa_perfil,
    destino_entrega_texto,
    destino_entrega_maps_url
  ) values (
    v_aliado,
    true,
    null,
    null,
    'aprobado_admin',
    0,
    0,
    0,
    grand_total,
    grand_base,
    tasa,
    coalesce(p_destino_entrega_usa_perfil, true),
    case when coalesce(p_destino_entrega_usa_perfil, true) then null else dest_text end,
    case when coalesce(p_destino_entrega_usa_perfil, true) then null else maps_trim end
  )
  returning id into master_id;

  for r_imp in
    select distinct importador_id from _checkout_lines order by importador_id
  loop
    select
      coalesce(sum(precio_line_total), 0),
      count(*)::integer
    into sub_total, sub_n
    from _checkout_lines
    where importador_id = r_imp.importador_id;

    insert into public.sub_orders (
      parent_order_id,
      importador_id,
      status,
      monto_subtotal,
      items_count
    ) values (
      master_id,
      r_imp.importador_id,
      'pendiente',
      sub_total,
      sub_n
    )
    returning id into sub_id;

    insert into public.order_items (
      sub_order_id,
      product_id,
      importador_id,
      cantidad,
      precio_unitario_proveedor,
      precio_unitario_aliado,
      precio_line_total,
      precio_base_aliado_line
    )
    select
      sub_id,
      cl.product_id,
      cl.importador_id,
      cl.cantidad,
      cl.precio_unitario_proveedor,
      cl.precio_unitario_aliado,
      cl.precio_line_total,
      cl.precio_base_aliado_line
    from _checkout_lines cl
    where cl.importador_id = r_imp.importador_id;
  end loop;

  return master_id;
end;
$$;

grant execute on function public.aliado_checkout_multi_importador(jsonb, boolean, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Cola histórica: pedidos aún en `pendiente` pasan a operativos (dispara avisos UPDATE si aplica).
-- ---------------------------------------------------------------------------
update public.transaction_requests tr
set
  status = 'aprobado_admin',
  at_aprobado_admin = coalesce(tr.at_aprobado_admin, now()),
  updated_at = now()
where tr.status = 'pendiente'
  and coalesce(tr.anulado_por_motolink, false) = false
  and coalesce(tr.cancelado_por_aliado, false) = false;

comment on column public.transaction_requests.status is
  'Ciclo broker: pendiente (legacy), aprobado_admin (ingreso directo u aprobado), en_preparacion, pedido_listo, en_transito, entregado, rechazado.';
