-- Descuento divisas al declarar pago (Zelle, Binance, USDT, efectivo) + métodos aceptados por importador.

alter table public.profiles
  add column if not exists accepted_pago_metodos text[];

comment on column public.profiles.accepted_pago_metodos is
  'Importador: métodos de pago que el aliado puede elegir al registrar comprobante. NULL = todos los estándar.';

update public.profiles
set accepted_pago_metodos = array[
  'zelle_divisas',
  'pago_movil',
  'binance',
  'usdt',
  'transferencia',
  'efectivo'
]::text[]
where role = 'importador'
  and (accepted_pago_metodos is null or cardinality(accepted_pago_metodos) = 0);

-- ---------------------------------------------------------------------------
-- Helpers de precio / descuento divisas
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_usd_discount_metodos ()
returns text[]
language sql
immutable
as $$
  select array[
    'zelle_divisas',
    'binance',
    'usdt',
    'efectivo'
  ]::text[];
$$;

create or replace function public.motoconecta_all_pago_metodos ()
returns text[]
language sql
immutable
as $$
  select array[
    'zelle_divisas',
    'pago_movil',
    'binance',
    'usdt',
    'transferencia',
    'efectivo'
  ]::text[];
$$;

create or replace function public.motoconecta_usd_discount_pct (p_rules jsonb)
returns numeric
language sql
immutable
as $$
  select case
    when coalesce((p_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0
     and coalesce((p_rules ->> 'usd_payment_discount_pct')::numeric, 0) < 100
      then (p_rules ->> 'usd_payment_discount_pct')::numeric
    else 0::numeric
  end;
$$;

create or replace function public.motoconecta_order_total_for_pago_metodo (
  p_base_total numeric,
  p_discount_rules jsonb,
  p_metodo text
)
returns numeric
language sql
immutable
as $$
  select round(
    (
      coalesce(p_base_total, 0)
      * (
        1 - case
          when trim(coalesce(p_metodo, '')) = any (public.motoconecta_usd_discount_metodos ())
           and public.motoconecta_usd_discount_pct (p_discount_rules) > 0
            then public.motoconecta_usd_discount_pct (p_discount_rules) / 100.0
          else 0::numeric
        end
      )
    )::numeric,
    4
  );
$$;

create or replace function public.motoconecta_enrich_discount_rules_pago_metodo (
  p_discount_rules jsonb,
  p_metodo text,
  p_applied boolean
)
returns jsonb
language sql
immutable
as $$
  select
    coalesce(p_discount_rules, '{}'::jsonb)
    || case
      when coalesce(p_applied, false) then
        jsonb_build_object(
          'applied_usd_payment_discount_pct',
          public.motoconecta_usd_discount_pct (p_discount_rules),
          'applied_pago_metodo',
          trim(p_metodo)
        )
      else '{}'::jsonb
    end
    - case
      when not coalesce(p_applied, false) then
        array['applied_usd_payment_discount_pct', 'applied_pago_metodo']::text[]
      else array[]::text[]
    end;
$$;

-- ---------------------------------------------------------------------------
-- Importador: métodos de pago aceptados
-- ---------------------------------------------------------------------------
create or replace function public.importador_set_accepted_pago_metodos (
  p_metodos text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_clean text[];
  v_m text;
  v_allowed text[] := public.motoconecta_all_pago_metodos ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar métodos de pago';
  end if;

  if p_metodos is null or cardinality(p_metodos) = 0 then
    raise exception 'Seleccione al menos un método de pago';
  end if;

  v_clean := array[]::text[];

  foreach v_m in array p_metodos loop
    if trim(v_m) = any (v_allowed) then
      if not (trim(v_m) = any (v_clean)) then
        v_clean := array_append(v_clean, trim(v_m));
      end if;
    end if;
  end loop;

  if cardinality(v_clean) = 0 then
    raise exception 'Ningún método de pago válido';
  end if;

  update public.profiles
  set accepted_pago_metodos = v_clean
  where id = v_uid;
end;
$$;

grant execute on function public.importador_set_accepted_pago_metodos (text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Aliado: registrar comprobante + aplicar descuento divisas al total del pedido
-- ---------------------------------------------------------------------------
create or replace function public.aliado_registra_comprobante_pago (
  p_request_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_importador uuid;
  v_status text;
  v_pe text;
  v_metodo text;
  v_allowed_global text[] := public.motoconecta_all_pago_metodos ();
  v_accepted text[];
  v_cant integer;
  v_base numeric;
  v_total numeric;
  v_unit numeric;
  v_rules jsonb;
  v_rules_out jsonb;
  v_pct numeric;
  v_applied boolean;
  v_comm_rate numeric;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  v_metodo := lower(trim(p_metodo));

  if v_metodo = '' or not (v_metodo = any (v_allowed_global)) then
    raise exception 'Método de pago no permitido';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    tr.pago_estado_revision,
    tr.cantidad,
    coalesce(tr.precio_base_aliado_total, tr.precio_total_usd),
    tr.discount_rules,
    tr.commission_rate_snapshot
  into
    v_aliado,
    v_importador,
    v_status,
    v_pe,
    v_cant,
    v_base,
    v_rules,
    v_comm_rate
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_aliado is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if v_status = 'rechazado' then
    raise exception 'El pedido está rechazado';
  end if;
  if v_pe is not null and trim(v_pe) = 'aprobado' then
    raise exception 'El pago ya fue confirmado; no puede modificar el comprobante';
  end if;

  select coalesce(p.accepted_pago_metodos, public.motoconecta_all_pago_metodos ())
    into v_accepted
  from public.profiles p
  where p.id = v_importador;

  if not (v_metodo = any (v_accepted)) then
    raise exception
      'Este importador no acepta el método de pago seleccionado. Elija otro o acuerde con el proveedor.';
  end if;

  v_pct := public.motoconecta_usd_discount_pct (v_rules);
  v_applied := v_metodo = any (public.motoconecta_usd_discount_metodos ())
    and v_pct > 0;

  v_total := public.motoconecta_order_total_for_pago_metodo (
    v_base,
    v_rules,
    v_metodo
  );

  v_unit := round(
    (v_total / greatest(coalesce(v_cant, 1), 1))::numeric,
    6
  );

  v_rules_out := public.motoconecta_enrich_discount_rules_pago_metodo (
    v_rules,
    v_metodo,
    v_applied
  );

  update public.transaction_requests
  set
    pago_metodo = v_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = nullif(trim(p_file_name), ''),
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    precio_base_aliado_total = v_base,
    precio_total_usd = v_total,
    precio_unitario_aliado = v_unit,
    discount_rules = v_rules_out,
    comision_devengada_usd = case
      when comision_devengada_at is null and coalesce(v_comm_rate, 0) > 0
        then round((v_total * v_comm_rate)::numeric, 4)
      else comision_devengada_usd
    end,
    updated_at = now()
  where id = p_request_id;
end;
$$;

-- Checkout: fijar precio base REF (sin descuento divisas; se aplica al declarar pago).
create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null,
  p_promo_by_importador jsonb default '{}'::jsonb
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
  v_kyc text;
  v_psm boolean;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_sale numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_discount_snap jsonb;
  v_comm_rate numeric;
  v_promo_id uuid;
  v_promo_raw text;
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
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_kyc, v_psm
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

  for rec in
    with parsed as (
      select
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
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
      pr.sale_price_usd,
      pr.stock,
      pr.is_active
    into v_owner, v_price, v_sale, v_stock, v_active
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
        (elem ->> 'product_id')::uuid as product_id,
        (elem ->> 'cantidad')::integer as cantidad
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
      pr.sale_price_usd,
      pr.stock,
      pr.discount_rules
    into v_owner, v_price, v_sale, v_stock, v_discount
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;

    v_unit := public.motoconecta_aliado_unit_price_usd (
      v_price,
      v_sale,
      v_discount,
      rec.cantidad,
      false
    );
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_discount_snap := public.motoconecta_enrich_discount_rules_snapshot (
      v_discount,
      rec.cantidad
    );
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    v_promo_id := null;
    if p_promo_by_importador is not null
       and jsonb_typeof (p_promo_by_importador) = 'object' then
      v_promo_raw := p_promo_by_importador ->> v_owner::text;
      if v_promo_raw is not null and btrim(v_promo_raw) <> '' then
        select c.id
          into v_promo_id
        from public.promo_campaigns c
        where c.id = v_promo_raw::uuid
          and c.importador_id = v_owner
          and c.is_active = true
          and c.starts_at <= now()
          and c.ends_at >= now();
      end if;
    end if;

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      precio_base_aliado_total,
      precio_unitario_proveedor,
      precio_unitario_aliado,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot,
      promo_campaign_id
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      v_line_total,
      round(v_price::numeric, 6),
      round(v_unit::numeric, 6),
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount_snap,
      v_comm_rate,
      v_promo_id
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;
