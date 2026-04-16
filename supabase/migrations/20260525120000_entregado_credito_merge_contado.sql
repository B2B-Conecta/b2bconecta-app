-- Fusiona lógica de entrega: contado + notificación + imputación de crédito del sistema.
-- Corrige consumo de crédito usando coalesce(new, old) por si el UPDATE solo envía status.
-- Refuerza aliado_declara_pago_credito_sistema con validación de cupo (abierto + consumido).

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

    update public.profiles
    set primeros_pedidos_contado_entregados = least(
      coalesce(primeros_pedidos_contado_entregados, 0) + 1,
      3
    )
    where id = new.aliado_id
      and role = 'aliado'
      and coalesce(primeros_pedidos_contado_entregados, 0) < 3;

    -- Crédito MotoLink: sumar al acumulado al entregar (pago aprobado antes de tránsito).
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
  exp numeric;
  cons numeric;
  tol constant numeric := 0.01;
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
    coalesce(credito_consumido_acumulado, 0)
  into pc, lim, cons
  from public.profiles
  where id = auth.uid();

  if pc < 3 then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  select coalesce(sum(precio_total), 0) into exp
  from public.transaction_requests
  where aliado_id = auth.uid()
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito'
    );

  if (exp + cons) > lim + tol then
    raise exception
      'CUPO_INSUFICIENTE: Su línea no alcanza para los pedidos abiertos más el crédito ya utilizado en entregas. Elija Pago Móvil, Zelle, transferencia o efectivo, o consulte con MotoLink.';
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
