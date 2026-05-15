-- Minuta #7: auditoría confirmado_por en pago, reglas de descuento (snapshot), SLA 12h por bloque
-- carrito+importador, recepción y cuestionario agrupados por importador en un checkout.

-- ---------------------------------------------------------------------------
-- 1) Columnas
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists discount_rules jsonb;

alter table public.transaction_requests
  add column if not exists discount_rules jsonb;

alter table public.transaction_requests
  add column if not exists confirmado_por uuid references public.profiles (id);

alter table public.transaction_requests
  add column if not exists aliado_experience_stars integer
    check (aliado_experience_stars is null or (aliado_experience_stars >= 1 and aliado_experience_stars <= 5));

alter table public.transaction_requests
  add column if not exists aliado_experience_comment text;

alter table public.transaction_requests
  add column if not exists aliado_experience_submitted_at timestamptz;

comment on column public.transaction_requests.confirmado_por is
  'UUID del operador (importador) que aprueba pago o primera transición de gestión auditada.';

comment on column public.transaction_requests.discount_rules is
  'Reglas comerciales snapshot (JSON) al confirmar el carrito; p. ej. tramos por volumen.';

-- Una alerta SLA por par (checkout_group_id, importador_id).
create table if not exists public.sla_importer_pending_alert_sent (
  checkout_group_id uuid not null,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (checkout_group_id, importador_id)
);

create index if not exists sla_importer_pending_alert_sent_sent_idx
  on public.sla_importer_pending_alert_sent (sent_at desc);

-- ---------------------------------------------------------------------------
-- 2) Pago: registrar operador al aprobar comprobante
-- ---------------------------------------------------------------------------
create or replace function public.importador_set_pago_revision_estado (
  p_request_id uuid,
  p_nuevo_estado text,
  p_rechazo_nota text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_imp uuid;
  v_path text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;
  if trim(p_nuevo_estado) not in ('aprobado', 'rechazado') then
    raise exception 'Estado no válido';
  end if;

  select tr.importador_id, tr.comprobante_pago_storage_path
    into v_imp, v_path
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_imp is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_imp is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if trim(p_nuevo_estado) = 'aprobado' then
    if v_path is null or length(trim(v_path)) = 0 then
      raise exception 'No hay comprobante para aprobar';
    end if;
    update public.transaction_requests
    set
      pago_estado_revision = 'aprobado',
      pago_comprobante_rechazo_nota = null,
      pago_aprobado_at = now (),
      confirmado_por = auth.uid (),
      updated_at = now ()
    where id = p_request_id;
  else
    update public.transaction_requests
    set
      pago_estado_revision = 'rechazado',
      pago_comprobante_rechazo_nota = nullif(trim(p_rechazo_nota), ''),
      pago_aprobado_at = null,
      updated_at = now ()
    where id = p_request_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Primera transición pendiente → gestión: rellenar confirmado_por si sigue vacío
-- ---------------------------------------------------------------------------
create or replace function public.tr_transaction_requests_fill_confirmado_por ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.status is distinct from old.status
     and old.status = 'pendiente'
     and new.status in ('aprobado_admin', 'en_preparacion')
     and new.confirmado_por is null
     and auth.uid () is not null then
    new.confirmado_por := auth.uid ();
  end if;
  return new;
end;
$$;

drop trigger if exists tr_tr_fill_confirmado_por on public.transaction_requests;

create trigger tr_tr_fill_confirmado_por
before update on public.transaction_requests
for each row
execute function public.tr_transaction_requests_fill_confirmado_por ();

-- ---------------------------------------------------------------------------
-- 4) Aliado: marcar entregado todas las líneas del mismo importador en un carrito
-- ---------------------------------------------------------------------------
create or replace function public.aliado_marca_pedidos_entregados_importador_en_grupo (
  p_checkout_group_id uuid,
  p_importador_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.transaction_requests tr
  set
    status = 'entregado'::text,
    updated_at = now ()
  where tr.checkout_group_id = p_checkout_group_id
    and tr.importador_id = p_importador_id
    and tr.aliado_id = auth.uid ()
    and tr.status = any (array['en_transito'::text, 'enviado'::text]);

  get diagnostics v_n = row_count;
  if v_n < 1 then
    raise exception
      'No se puede marcar como entregado (estado o permiso inválido).'
      using errcode = 'P0001';
  end if;

  return v_n;
end;
$$;

grant execute on function public.aliado_marca_pedidos_entregados_importador_en_grupo (uuid, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Experiencia aliado: una sola valoración por importador y carrito
-- ---------------------------------------------------------------------------
create or replace function public.aliado_submit_order_experience (
  p_request_id uuid,
  p_stars integer,
  p_comment text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;

  update public.transaction_requests tr
  set
    aliado_experience_stars = p_stars,
    aliado_experience_comment = nullif(trim(p_comment), ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ()
    and tr.status = 'entregado'::text
    and tr.aliado_experience_submitted_at is null;

  if not found then
    raise exception 'No se puede registrar la valoración en este pedido.'
      using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.aliado_submit_order_experience (uuid, integer, text)
  to authenticated;

create or replace function public.aliado_submit_order_experience_importador_grupo (
  p_checkout_group_id uuid,
  p_importador_id uuid,
  p_stars integer,
  p_comment text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'Calificación inválida' using errcode = 'P0001';
  end if;

  update public.transaction_requests tr
  set
    aliado_experience_stars = p_stars,
    aliado_experience_comment = nullif(trim(p_comment), ''),
    aliado_experience_submitted_at = now (),
    updated_at = now ()
  where tr.checkout_group_id = p_checkout_group_id
    and tr.importador_id = p_importador_id
    and tr.aliado_id = auth.uid ()
    and tr.status = 'entregado'::text
    and tr.aliado_experience_submitted_at is null;

  get diagnostics v_n = row_count;
  if v_n < 1 then
    raise exception
      'No se puede registrar la valoración (pedidos no entregados o ya valorados).'
      using errcode = 'P0001';
  end if;

  return v_n;
end;
$$;

grant execute on function public.aliado_submit_order_experience_importador_grupo (
  uuid,
  uuid,
  integer,
  text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Checkout: copiar discount_rules del producto a cada línea
-- ---------------------------------------------------------------------------
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
  v_open_slots bigint;
  v_exposure numeric;
  v_sum_new numeric := 0;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_tol constant numeric := 0.01;
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
      discount_rules
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
      v_discount
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
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

-- ---------------------------------------------------------------------------
-- 7) SLA 12 h: un aviso a administradores por (checkout_group_id, importador_id)
--    Invocar periódicamente (pg_cron / Edge Function) como service_role.
-- ---------------------------------------------------------------------------
create or replace function public.run_importer_sla_admin_alerts ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
  rec record;
begin
  perform set_config ('row_security', 'off', true);

  for rec in
    with overdue as (
      select
        tr.checkout_group_id,
        tr.importador_id,
        min(tr.created_at) as first_at
      from public.transaction_requests tr
      where tr.checkout_group_id is not null
        and tr.status = 'pendiente'::text
      group by tr.checkout_group_id, tr.importador_id
      having min(tr.created_at) + interval '12 hours' < now()
    )
    select o.checkout_group_id, o.importador_id
    from overdue o
    where not exists (
      select 1
      from public.sla_importer_pending_alert_sent s
      where s.checkout_group_id = o.checkout_group_id
        and s.importador_id = o.importador_id
    )
  loop
    insert into public.sla_importer_pending_alert_sent (
      checkout_group_id,
      importador_id
    )
    values (rec.checkout_group_id, rec.importador_id);

    insert into public.notifications (
      user_id, title, body, type, related_id
    )
    select
      adm.id,
      'Supervisión · SLA proveedor (12 h)',
      format(
        'Importador %s: líneas pendientes del carrito %s sin confirmar tras el plazo de 12 h.',
        substring(rec.importador_id::text, 1, 8) || '…',
        substring(rec.checkout_group_id::text, 1, 8) || '…'
      ),
      'supervision',
      rec.checkout_group_id::text
    from public.profiles adm
    where adm.role = 'administrador';

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.run_importer_sla_admin_alerts () to service_role;
