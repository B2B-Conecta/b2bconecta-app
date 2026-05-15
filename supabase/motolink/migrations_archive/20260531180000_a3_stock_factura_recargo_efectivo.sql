-- A3: inventario al emitir factura MotoLink al aliado; recargo 4% si método de pago es efectivo.

alter table public.transaction_requests
  add column if not exists precio_base_aliado_total numeric(14, 2),
  add column if not exists stock_descontado_en timestamptz;

comment on column public.transaction_requests.precio_base_aliado_total is
  'Total aliado sin recargo por efectivo (base del pedido). precio_total incluye recargo si aplica.';
comment on column public.transaction_requests.stock_descontado_en is
  'Momento en que se descontó inventario (primera emisión de factura MotoLink al aliado).';

update public.transaction_requests
set precio_base_aliado_total = precio_total
where precio_base_aliado_total is null;

alter table public.transaction_requests
  alter column precio_base_aliado_total set not null;

-- Pedidos ya entregados con la lógica anterior: el stock ya se descontó al marcar entregado.
update public.transaction_requests
set stock_descontado_en = coalesce(at_entregado, updated_at)
where status = 'entregado'
  and stock_descontado_en is null;

-- Backfill: pedidos con factura MotoLink en curso (stock aún no descontado en esta tabla).
do $$
declare
  r record;
  n int;
begin
  for r in
    select id, product_id, owner_id, cantidad
    from public.transaction_requests
    where coalesce(trim(factura_aliado_storage_path), '') <> ''
      and stock_descontado_en is null
      and status in ('pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito')
  loop
    update public.products p
    set stock = p.stock - r.cantidad
    where p.id = r.product_id
      and p.owner_id = r.owner_id
      and p.stock >= r.cantidad;
    get diagnostics n = row_count;
    if n = 0 then
      raise exception
        'Backfill A3: stock insuficiente para pedido %. Ajuste inventario antes de aplicar la migración.',
        r.id;
    end if;
    update public.transaction_requests
    set stock_descontado_en = now()
    where id = r.id;
  end loop;
end;
$$;

-- Primera emisión de factura MotoLink al aliado: descuenta inventario (reemplazos de archivo no repiten).
create or replace function public.transaction_requests_deduct_stock_on_factura_aliado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
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

drop trigger if exists tr_transaction_requests_stock_on_factura_aliado
  on public.transaction_requests;
create trigger tr_transaction_requests_stock_on_factura_aliado
before update of factura_aliado_storage_path
on public.transaction_requests
for each row
execute procedure public.transaction_requests_deduct_stock_on_factura_aliado();

-- Entrega: ya no descuenta stock si ya se descontó al facturar.
create or replace function public.transaction_requests_on_entregado()
returns trigger
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
begin
  if new.status = 'entregado' and (old.status is distinct from 'entregado') then
    select
      coalesce(primeros_pedidos_contado_entregados, 0),
      business_name
    into pc_before, bn
    from public.profiles
    where id = new.aliado_id and role = 'aliado';

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

    update public.profiles
    set credit_score = least(coalesce(credit_score, 100) + 2, 100)
    where id = new.aliado_id
      and role = 'aliado';

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
    if pm = 'credito_sistema' and prev = 'aprobado' and add_cred > 0 then
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

-- Recargo 4% sobre precio_base al elegir efectivo; otros medios vuelven a la base.
create or replace function public.aliado_registra_comprobante_pago(
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
  n integer;
  base numeric;
  nuevo_total numeric;
begin
  if p_metodo not in (
    'pago_movil', 'zelle_divisas', 'transferencia', 'efectivo', 'credito_sistema'
  ) then
    raise exception 'Método de pago no válido.';
  end if;
  if p_metodo = 'credito_sistema' then
    raise exception 'El crédito del sistema se solicita con la acción dedicada, sin archivo de comprobante.';
  end if;
  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del comprobante.';
  end if;
  if p_storage_path not like p_request_id::text || '/%' then
    raise exception 'Ruta de archivo inválida.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if p_metodo = 'efectivo' then
    nuevo_total := round(base * 1.04, 2);
  else
    nuevo_total := base;
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = p_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = p_file_name,
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = nuevo_total,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique que exista la factura MotoLink al aliado, '
      'que el pedido no esté rechazado y que el pago no esté ya aprobado.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;

create or replace function public.aliado_declara_pago_efectivo(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  base numeric;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede declarar pago en efectivo.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'efectivo',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = round(base * 1.04, 2),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la declaración. Verifique que exista la factura MotoLink al aliado, '
      'que el pedido siga activo (no rechazado) y que pueda reenviar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo(uuid) to authenticated;

create or replace function public.aliado_declara_pago_credito_sistema(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  pc int;
  lim numeric;
  preact boolean;
  base numeric;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede solicitar pago con crédito del sistema.';
  end if;

  select
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_preactivado_por_admin, false)
  into pc, lim, preact
  from public.profiles
  where id = auth.uid();

  if pc < 3 and not preact then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = base,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Verifique que exista la factura MotoLink al aliado, '
      'que el pedido siga activo (no rechazado) y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_credito_sistema(uuid) to authenticated;
