-- Multi-importador: pedido maestro (transaction_requests) + sub_pedidos + ítems.
-- Tasa BCV en snapshot del maestro + tabla app_global_config.
-- Sincronización de estado logístico del maestro a partir de sub_pedidos (bypass vía GUC).

-- ---------------------------------------------------------------------------
-- Config global (tasa BCV del día)
-- ---------------------------------------------------------------------------
create table if not exists public.app_global_config (
  key text primary key,
  value_numeric numeric(18, 8) not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_global_config is
  'Parámetros globales MotoLink (p. ej. tasa BCV oficial del día).';

insert into public.app_global_config (key, value_numeric)
values ('tasa_bcv', 36.0)
on conflict (key) do nothing;

alter table public.app_global_config enable row level security;

drop policy if exists "agc_select_authenticated" on public.app_global_config;
create policy "agc_select_authenticated"
on public.app_global_config
for select
to authenticated
using (true);

drop policy if exists "agc_all_admin" on public.app_global_config;
create policy "agc_all_admin"
on public.app_global_config
for all
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

-- ---------------------------------------------------------------------------
-- Maestro: bandera + snapshot BCV; líneas legacy siguen con product_id/owner_id
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  add column if not exists is_master_order boolean not null default false;

alter table public.transaction_requests
  add column if not exists tasa_bcv_snapshot numeric(18, 8);

comment on column public.transaction_requests.is_master_order is
  'True: contenedor de pedido multi-importador; product_id y owner_id nulos; líneas en order_items.';
comment on column public.transaction_requests.tasa_bcv_snapshot is
  'Tasa BCV (VES/USD u oficial usada) al confirmar el pedido; cálculos REF en app, BS solo UI.';

alter table public.transaction_requests
  drop constraint if exists transaction_requests_cantidad_check;

alter table public.transaction_requests
  add constraint transaction_requests_cantidad_check
  check (
    (coalesce(is_master_order, false) = true and cantidad = 0)
    or (coalesce(is_master_order, false) = false and cantidad > 0)
  );

alter table public.transaction_requests
  alter column product_id drop not null;

alter table public.transaction_requests
  alter column owner_id drop not null;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_master_line_chk;

alter table public.transaction_requests
  add constraint transaction_requests_master_line_chk
  check (
    (
      coalesce(is_master_order, false) = true
      and product_id is null
      and owner_id is null
    )
    or (
      coalesce(is_master_order, false) = false
      and product_id is not null
      and owner_id is not null
    )
  );

-- ---------------------------------------------------------------------------
-- sub_orders
-- ---------------------------------------------------------------------------
create table if not exists public.sub_orders (
  id uuid primary key default gen_random_uuid(),
  parent_order_id uuid not null references public.transaction_requests (id) on delete cascade,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'preparando', 'listo', 'en_ruta', 'entregado')),
  monto_subtotal numeric(14, 2) not null,
  items_count integer not null check (items_count > 0),
  proveedor_factura_storage_path text,
  proveedor_factura_file_name text,
  proveedor_factura_submitted_at timestamptz,
  transit_eta_days integer,
  transit_eta_hours integer,
  transit_eta_set_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists sub_orders_parent_idx on public.sub_orders (parent_order_id);
create index if not exists sub_orders_importador_idx on public.sub_orders (importador_id);

comment on table public.sub_orders is
  'Desglose logístico por importador bajo un transaction_requests maestro.';

-- ---------------------------------------------------------------------------
-- order_items
-- ---------------------------------------------------------------------------
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  sub_order_id uuid not null references public.sub_orders (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  cantidad integer not null check (cantidad > 0),
  precio_unitario_proveedor numeric(14, 4) not null,
  precio_unitario_aliado numeric(14, 4) not null,
  precio_line_total numeric(14, 2) not null,
  precio_base_aliado_line numeric(14, 2) not null,
  created_at timestamptz not null default now()
);

create index if not exists order_items_sub_order_idx on public.order_items (sub_order_id);
create index if not exists order_items_product_idx on public.order_items (product_id);

comment on table public.order_items is
  'Líneas de pedido bajo sub_orders (multi-importador).';

-- ---------------------------------------------------------------------------
-- RLS sub_orders / order_items
-- ---------------------------------------------------------------------------
alter table public.sub_orders enable row level security;

drop policy if exists "sub_orders_select_aliado" on public.sub_orders;
create policy "sub_orders_select_aliado"
on public.sub_orders
for select
to authenticated
using (
  exists (
    select 1 from public.transaction_requests tr
    where tr.id = sub_orders.parent_order_id
      and tr.aliado_id = auth.uid()
  )
);

drop policy if exists "sub_orders_select_importer" on public.sub_orders;
create policy "sub_orders_select_importer"
on public.sub_orders
for select
to authenticated
using (
  importador_id = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'importador'
  )
);

drop policy if exists "sub_orders_select_admin" on public.sub_orders;
create policy "sub_orders_select_admin"
on public.sub_orders
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

drop policy if exists "sub_orders_update_importer_own" on public.sub_orders;
create policy "sub_orders_update_importer_own"
on public.sub_orders
for update
to authenticated
using (
  importador_id = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'importador'
  )
)
with check (
  importador_id = auth.uid()
);

drop policy if exists "sub_orders_all_admin" on public.sub_orders;
create policy "sub_orders_all_admin"
on public.sub_orders
for all
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

alter table public.order_items enable row level security;

drop policy if exists "order_items_select" on public.order_items;
create policy "order_items_select"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1 from public.sub_orders so
    join public.transaction_requests tr on tr.id = so.parent_order_id
    where so.id = order_items.sub_order_id
      and (
        tr.aliado_id = auth.uid()
        or so.importador_id = auth.uid()
        or exists (
          select 1 from public.profiles p
          where p.id = auth.uid() and p.role = 'administrador'
        )
      )
  )
);

drop policy if exists "order_items_all_admin" on public.order_items;
create policy "order_items_all_admin"
on public.order_items
for all
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

-- Inserción de ítems solo vía RPC (service) — sin política insert para aliado.

-- ---------------------------------------------------------------------------
-- Insert maestro prohibido desde cliente (solo RPC checkout)
-- ---------------------------------------------------------------------------
drop policy if exists "tr_insert_aliado" on public.transaction_requests;

create policy "tr_insert_aliado"
on public.transaction_requests
for insert
to authenticated
with check (
  aliado_id = auth.uid()
  and coalesce(is_master_order, false) = false
  and exists (
    select 1
    from public.products p
    where p.id = transaction_requests.product_id
      and p.owner_id = transaction_requests.owner_id
  )
  and not coalesce(
    (
      select pr.pedidos_suspendidos_morosidad
      from public.profiles pr
      where pr.id = transaction_requests.aliado_id
    ),
    false
  )
);

-- ---------------------------------------------------------------------------
-- Helpers: ranking sub_order → estado maestro transaction_requests
-- ---------------------------------------------------------------------------
create or replace function public._sub_order_status_rank(st text)
returns integer
language sql
immutable
set search_path = public
as $$
  select case trim(lower(coalesce(st, '')))
    when 'pendiente' then 0
    when 'preparando' then 1
    when 'listo' then 2
    when 'en_ruta' then 3
    when 'entregado' then 4
    else -1
  end;
$$;

create or replace function public.sync_master_transaction_request_from_sub_orders(p_master uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  is_m boolean;
  cur_st text;
  mn int;
  mx int;
  ns text;
begin
  select coalesce(is_master_order, false), status
  into is_m, cur_st
  from public.transaction_requests
  where id = p_master
  for update;

  if not is_m then
    return;
  end if;
  if cur_st in ('rechazado', 'pendiente') then
    return;
  end if;

  select
    min(public._sub_order_status_rank(so.status)),
    max(public._sub_order_status_rank(so.status))
  into mn, mx
  from public.sub_orders so
  where so.parent_order_id = p_master;

  if mn is null then
    return;
  end if;

  if mn >= 4 then
    ns := 'entregado';
  elsif mx >= 3 then
    ns := 'en_transito';
  elsif mn >= 2 then
    ns := 'pedido_listo';
  elsif mx >= 1 then
    ns := 'en_preparacion';
  else
    ns := null;
  end if;

  if ns is null or ns is not distinct from cur_st then
    return;
  end if;

  perform set_config('motolink.sync_master_status', '1', true);
  update public.transaction_requests
  set
    status = ns,
    updated_at = now()
  where id = p_master;
  perform set_config('motolink.sync_master_status', '', true);
end;
$$;

create or replace function public.trg_sub_orders_after_mut_sync_master()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.sync_master_transaction_request_from_sub_orders(old.parent_order_id);
    return old;
  end if;
  perform public.sync_master_transaction_request_from_sub_orders(new.parent_order_id);
  return new;
end;
$$;

drop trigger if exists tr_sub_orders_sync_master on public.sub_orders;
create trigger tr_sub_orders_sync_master
after insert or update of status or delete
on public.sub_orders
for each row
execute procedure public.trg_sub_orders_after_mut_sync_master();

-- Bypass transición cuando la actualización viene del sync automático
create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
  is_aliado_owner boolean;
  v_days integer;
  v_hours integer;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if coalesce(current_setting('motolink.sync_master_status', true), '') = '1' then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  select
    new.aliado_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'aliado'
    )
  into is_aliado_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;

    if old.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito'
    ) and new.status = 'rechazado' then
      if coalesce(new.anulado_por_motolink, false) = true
         and new.motolink_anulacion_motivo is not null
         and char_length(trim(new.motolink_anulacion_motivo)) between 3 and 4000
      then
        return new;
      end if;
    end if;

    if old.status = 'pedido_listo' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;

      v_days := coalesce(new.transit_eta_days, 0);
      v_hours := coalesce(new.transit_eta_hours, 0);
      if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
        raise exception 'ETA inválido: días 0–365 y horas 0–23.';
      end if;

      return new;
    end if;

    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'pedido_listo' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'Adjunte la factura digital del proveedor antes de marcar pedido listo.';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  if is_aliado_owner then
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    if old.status = 'pendiente' and new.status = 'rechazado' then
      if coalesce(new.cancelado_por_aliado, false) = true
         and new.aliado_cancelacion_motivo is not null
         and char_length(trim(new.aliado_cancelacion_motivo)) > 0
         and char_length(trim(new.aliado_cancelacion_motivo)) <= 4000
      then
        return new;
      end if;
    end if;
    if old.status = 'aprobado_admin' and new.status = 'rechazado' then
      if coalesce(new.cancelado_por_aliado, false) = true
         and coalesce(new.is_master_order, false) = true
         and new.aliado_cancelacion_motivo is not null
         and char_length(trim(new.aliado_cancelacion_motivo)) > 0
         and char_length(trim(new.aliado_cancelacion_motivo)) <= 4000
      then
        return new;
      end if;
    end if;
    raise exception 'Transición de estado no permitida para el aliado';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

-- Stock al facturar: pedido maestro descuenta todas las líneas una sola vez
create or replace function public.transaction_requests_deduct_stock_on_factura_aliado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  r record;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if coalesce(trim(new.factura_aliado_storage_path), '') = '' then
    return new;
  end if;
  if coalesce(trim(old.factura_aliado_storage_path), '') <> '' then
    return new;
  end if;
  if new.stock_descontado_en is not null then
    return new;
  end if;

  if coalesce(new.is_master_order, false) then
    for r in
      select oi.product_id, oi.importador_id, oi.cantidad
      from public.order_items oi
      join public.sub_orders so on so.id = oi.sub_order_id
      where so.parent_order_id = new.id
    loop
      update public.products p
      set stock = p.stock - r.cantidad
      where p.id = r.product_id
        and p.owner_id = r.importador_id
        and p.stock >= r.cantidad;
      get diagnostics n = row_count;
      if n = 0 then
        raise exception 'Stock insuficiente al emitir la factura MotoLink al aliado (pedido multi-importador).';
      end if;
    end loop;
    new.stock_descontado_en := now();
    return new;
  end if;

  update public.products p
  set stock = p.stock - new.cantidad
  where p.id = new.product_id
    and p.owner_id = new.owner_id
    and p.stock >= new.cantidad;
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Stock insuficiente al emitir la factura MotoLink al aliado.';
  end if;

  new.stock_descontado_en := now();
  return new;
end;
$$;

-- Entrega: maestro sin deducción por fila; por sub_pedido al confirmar cada tramo
create or replace function public.transaction_requests_on_entregado() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  pc_before int;
  bn text;
  pm text;
  prev text;
  add_cred numeric;
  has_plan boolean;
begin
  if new.status = 'entregado' and (old.status is distinct from 'entregado') then
    select
      coalesce(primeros_pedidos_contado_entregados, 0),
      business_name
    into pc_before, bn
    from public.profiles
    where id = new.aliado_id and role = 'aliado';

    if not coalesce(new.is_master_order, false) then
      if new.stock_descontado_en is null then
        update public.products p
        set stock = p.stock - new.cantidad
        where p.id = new.product_id
          and p.owner_id = new.owner_id
          and p.stock >= new.cantidad;
        get diagnostics n = row_count;
        if n = 0 then
          raise exception 'Stock insuficiente para marcar entregado.';
        end if;
      end if;
    end if;

    update public.profiles
    set primeros_pedidos_contado_entregados = least(
      coalesce(primeros_pedidos_contado_entregados, 0) + 1,
      3
    )
    where id = new.aliado_id
      and role = 'aliado'
      and coalesce(primeros_pedidos_contado_entregados, 0) < 3;

    pm := nullif(lower(trim(coalesce(new.pago_metodo, old.pago_metodo, ''))), '');
    prev := nullif(lower(trim(coalesce(new.pago_estado_revision, old.pago_estado_revision, ''))), '');
    add_cred := coalesce(new.precio_total, old.precio_total, 0);
    select exists (select 1 from public.payment_schedule ps where ps.transaction_request_id = new.id)
    into has_plan;
    if pm = 'credito_sistema' and prev = 'aprobado' and add_cred > 0 and not has_plan then
      update public.profiles pr
      set credito_consumido_acumulado =
        coalesce(pr.credito_consumido_acumulado, 0) + add_cred
      where pr.id = new.aliado_id
        and pr.role = 'aliado';
    end if;

    if pc_before = 2 then
      perform public.notify_to_all_admins(
        'Fase contado completada',
        format(
          '%s completó los 3 pedidos en contado. Defina su línea de crédito en la pestaña Crédito.',
          coalesce(nullif(trim(bn), ''), 'Un aliado')
        ),
        'credito',
        new.aliado_id::text
      );
    end if;
  end if;
  return new;
end;
$$;

-- Stock multi-importador: solo al emitir factura MotoLink al aliado (trigger en transaction_requests).

-- ---------------------------------------------------------------------------
-- Cancelación aliado: maestro pendiente y todos los sub en «pendiente»
-- ---------------------------------------------------------------------------
create or replace function public.aliado_cancela_pedido_pendiente(
  p_request_id uuid,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_st text;
  t text;
  is_m boolean;
  bad_sub int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;

  t := trim(coalesce(p_motivo, ''));
  if t is null or char_length(t) < 3 then
    raise exception 'Debe indicar un motivo de cancelación (al menos 3 caracteres).';
  end if;
  if char_length(t) > 4000 then
    raise exception 'El motivo no puede superar 4000 caracteres.';
  end if;

  select tr.aliado_id, tr.status, coalesce(tr.is_master_order, false)
  into v_aliado, v_st, is_m
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado.';
  end if;
  if v_aliado is distinct from auth.uid() then
    raise exception 'Solo el aliado dueño del pedido puede cancelarlo.';
  end if;

  if not is_m then
    if v_st is distinct from 'pendiente' then
      raise exception 'Solo puede cancelar mientras el pedido está pendiente de aprobación de MotoLink.';
    end if;
  else
    if v_st not in ('pendiente', 'aprobado_admin') then
      raise exception
        'Solo puede cancelar antes de que el pedido avance a preparación o facturación.';
    end if;
    select count(*)::integer into bad_sub
    from public.sub_orders so
    where so.parent_order_id = p_request_id
      and so.status is distinct from 'pendiente';
    if bad_sub > 0 then
      raise exception
        'No puede cancelar: algún importador ya inició la gestión de un sub-pedido.';
    end if;
  end if;

  delete from public.sub_orders where parent_order_id = p_request_id;

  update public.transaction_requests
  set
    status = 'rechazado',
    cancelado_por_aliado = true,
    aliado_cancelacion_motivo = t,
    updated_at = now()
  where id = p_request_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: tasa BCV
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_tasa_bcv(p_tasa numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar la tasa BCV.';
  end if;
  if p_tasa is null or p_tasa <= 0 then
    raise exception 'La tasa debe ser un número positivo.';
  end if;

  insert into public.app_global_config (key, value_numeric, updated_at)
  values ('tasa_bcv', p_tasa, now())
  on conflict (key) do update
  set value_numeric = excluded.value_numeric,
      updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.admin_set_tasa_bcv(numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Checkout multi-importador (split automático por importador)
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
    coalesce(pedidos_suspendidos_morosidad, false)
  into ks, pc, lim, cons, v_rif, v_est, v_ciu, v_dir, sus
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

  if coalesce(p_destino_entrega_usa_perfil, true) = false then
    if dest_text is null then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
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
    'pendiente',
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

-- Importador: avanza sub-pedido (pendiente → preparando → listo)
create or replace function public.importer_advance_sub_order(
  p_sub_order_id uuid,
  p_new_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  so record;
  inv text;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'importador'
  ) then
    raise exception 'Solo importadores pueden actualizar este sub-pedido.';
  end if;

  select
    so.id,
    so.importador_id,
    so.status,
    so.proveedor_factura_storage_path,
    tr.status as master_status
  into so
  from public.sub_orders so
  join public.transaction_requests tr on tr.id = so.parent_order_id
  where so.id = p_sub_order_id
  for update of so;

  if so.id is null then
    raise exception 'Sub-pedido no encontrado.';
  end if;
  if so.importador_id is distinct from auth.uid() then
    raise exception 'Este sub-pedido no pertenece a su inventario.';
  end if;
  if so.master_status is distinct from 'aprobado_admin' then
    raise exception 'El pedido maestro aún no fue aprobado por MotoLink.';
  end if;

  if so.status = 'pendiente' and p_new_status = 'preparando' then
    update public.sub_orders
    set status = 'preparando', updated_at = now()
    where id = p_sub_order_id;
    return;
  end if;

  if so.status = 'preparando' and p_new_status = 'listo' then
    inv := coalesce(trim(so.proveedor_factura_storage_path), '');
    if inv = '' then
      raise exception 'Adjunte la factura digital del proveedor antes de marcar listo.';
    end if;
    update public.sub_orders
    set status = 'listo', updated_at = now()
    where id = p_sub_order_id;
    return;
  end if;

  raise exception 'Transición de sub-pedido no permitida.';
end;
$$;

grant execute on function public.importer_advance_sub_order(uuid, text) to authenticated;

-- Admin: marcar sub-pedido en ruta (tras listo + facturas a nivel maestro)
create or replace function public.admin_marca_sub_order_en_transito(
  p_sub_order_id uuid,
  p_transit_eta_days integer,
  p_transit_eta_hours integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_so_id uuid;
  v_so_status text;
  v_inv text;
  v_fa text;
  v_days integer;
  v_hours integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden marcar en tránsito.';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);
  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'Valores inválidos: días 0–365, horas 0–23.';
  end if;
  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día u hora de ETA.';
  end if;

  select
    so.id,
    so.status,
    so.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path
  into v_so_id, v_so_status, v_inv, v_fa
  from public.sub_orders so
  join public.transaction_requests tr on tr.id = so.parent_order_id
  where so.id = p_sub_order_id
  for update of so;

  if v_so_id is null then
    raise exception 'Sub-pedido no encontrado';
  end if;
  if v_so_status is distinct from 'listo' then
    raise exception 'Solo sub-pedidos en estado listo pueden pasar a en ruta.';
  end if;
  if coalesce(trim(v_inv), '') = '' then
    raise exception 'Falta la factura del proveedor en este sub-pedido.';
  end if;

  if coalesce(trim(v_fa), '') = '' then
    raise exception 'Debe existir la factura MotoLink al aliado en el pedido maestro.';
  end if;

  update public.sub_orders
  set
    status = 'en_ruta',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    updated_at = now()
  where id = p_sub_order_id;
end;
$$;

grant execute on function public.admin_marca_sub_order_en_transito(uuid, integer, integer)
  to authenticated;

-- Aliado: confirma entrega de un sub-pedido en ruta
create or replace function public.aliado_marca_sub_order_entregado(p_sub_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  n int;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede confirmar la entrega.';
  end if;

  update public.sub_orders so
  set
    status = 'entregado',
    updated_at = now()
  from public.transaction_requests tr
  where so.id = p_sub_order_id
    and tr.id = so.parent_order_id
    and tr.aliado_id = auth.uid()
    and so.status = 'en_ruta';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo marcar como entregado. Verifique que el tramo esté en ruta y sea de su pedido.';
  end if;
end;
$$;

grant execute on function public.aliado_marca_sub_order_entregado(uuid) to authenticated;

-- Importador puede leer el pedido maestro si tiene un sub-pedido asociado (owner_id es null en maestro).
drop policy if exists "tr_select_importer_via_sub_order" on public.transaction_requests;
create policy "tr_select_importer_via_sub_order"
on public.transaction_requests
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'importador'
  )
  and exists (
    select 1 from public.sub_orders so
    where so.parent_order_id = transaction_requests.id
      and so.importador_id = auth.uid()
  )
  and status in (
    'aprobado_admin',
    'en_preparacion',
    'pedido_listo',
    'en_transito',
    'entregado'
  )
);
