-- Método de pago "crédito del sistema" (post fase contado + cupo asignado).
-- Al entregar el pedido, se acumula en profiles.credito_consumido_acumulado.
-- El cupo disponible considera pedidos abiertos + crédito ya consumido en entregas.

alter table public.profiles
  add column if not exists credito_consumido_acumulado numeric(14, 2) not null default 0;

alter table public.profiles
  drop constraint if exists profiles_credito_consumido_acumulado_nonneg;

alter table public.profiles
  add constraint profiles_credito_consumido_acumulado_nonneg
  check (credito_consumido_acumulado >= 0);

comment on column public.profiles.credito_consumido_acumulado is
  'Suma de precio_total de pedidos entregados pagados con crédito del sistema (línea MotoLink).';

alter table public.transaction_requests
  drop constraint if exists transaction_requests_pago_metodo_check;

alter table public.transaction_requests
  add constraint transaction_requests_pago_metodo_check
  check (
    pago_metodo is null
    or pago_metodo in (
      'pago_movil',
      'zelle_divisas',
      'transferencia',
      'efectivo',
      'credito_sistema'
    )
  );

-- Cupo: exposición abierta + consumido acumulado (entregas a crédito) no deben superar credit_limit.
create or replace function public.transaction_requests_check_aliado_credit_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lim numeric;
  exp numeric;
  cons numeric;
  tol constant numeric := 0.01;
  ks text;
  pc int;
  open_cnt int;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  select kyc_status into ks
  from public.profiles
  where id = new.aliado_id and role = 'aliado';
  if ks is distinct from 'aprobado' then
    raise exception 'La verificación documental del aliado debe estar aprobada por MotoLink.';
  end if;

  select
    credit_limit,
    coalesce(primeros_pedidos_contado_entregados, 0),
    coalesce(credito_consumido_acumulado, 0)
  into lim, pc, cons
  from public.profiles
  where id = new.aliado_id and role = 'aliado';

  if pc < 3 then
    select count(*)::integer into open_cnt
    from public.transaction_requests
    where aliado_id = new.aliado_id
      and status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'en_transito'
      );
    if open_cnt >= 1 then
      raise exception
        'En los primeros tres pedidos en contado solo puede tener un pedido activo a la vez. Cuando el actual se entregue o lo cancele con MotoLink, podrá solicitar otro.';
    end if;
    return new;
  end if;

  if lim is null then
    raise exception 'El aliado no tiene límite de crédito autorizado.';
  end if;

  select coalesce(sum(precio_total), 0) into exp
  from public.transaction_requests
  where aliado_id = new.aliado_id
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito'
    );

  if (exp + cons + new.precio_total) > lim + tol then
    raise exception 'El pedido supera el límite de crédito disponible.';
  end if;
  return new;
end;
$$;

-- Aliado solicita pago con línea de crédito MotoLink (sin archivo; revisión admin).
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
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede solicitar pago con crédito del sistema.';
  end if;

  select
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit
  into pc, lim
  from public.profiles
  where id = auth.uid();

  if pc < 3 then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'en_preparacion'
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Verifique factura MotoLink, pedido en preparación '
      'y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_credito_sistema(uuid) to authenticated;

-- Incluye credio_sistema en RPC de comprobante (por si se reutiliza en el futuro).
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

  update public.transaction_requests tr
  set
    pago_metodo = p_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = p_file_name,
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'en_preparacion'
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique que exista la factura MotoLink, '
      'que el pedido esté en preparación y que el pago no esté ya aprobado.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;

create or replace function public.transaction_requests_on_entregado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if new.status = 'entregado' and (old.status is distinct from 'entregado') then
    update public.products p
    set stock = p.stock - new.cantidad
    where p.id = new.product_id
      and p.owner_id = new.owner_id
      and p.stock >= new.cantidad;
    get diagnostics n = row_count;
    if n = 0 then
      raise exception 'Stock insuficiente para marcar entregado.';
    end if;

    update public.profiles
    set credit_score = least(coalesce(credit_score, 100) + 2, 100)
    where id = new.aliado_id
      and role = 'aliado';

    if new.pago_metodo = 'credito_sistema'
       and coalesce(new.pago_estado_revision, '') = 'aprobado' then
      update public.profiles pr
      set credito_consumido_acumulado = coalesce(pr.credito_consumido_acumulado, 0) + new.precio_total
      where pr.id = new.aliado_id
        and pr.role = 'aliado';
    end if;
  end if;
  return new;
end;
$$;
