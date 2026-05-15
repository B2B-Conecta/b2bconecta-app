-- Primeros 3 pedidos en modalidad contado: máximo un pedido abierto hasta completar 3 entregas.

alter table public.profiles
  add column if not exists primeros_pedidos_contado_entregados integer not null default 0;

update public.profiles p
set primeros_pedidos_contado_entregados = least(
  coalesce(
    (
      select count(*)::integer
      from public.transaction_requests tr
      where tr.aliado_id = p.id
        and tr.status = 'entregado'
    ),
    0
  ),
  3
)
where p.role = 'aliado';

alter table public.profiles
  drop constraint if exists profiles_primeros_contado_range;

alter table public.profiles
  add constraint profiles_primeros_contado_range
  check (
    primeros_pedidos_contado_entregados >= 0
    and primeros_pedidos_contado_entregados <= 3
  );

-- Pedido nuevo: si aún faltan entregas en fase contado, solo un pedido activo.
create or replace function public.transaction_requests_check_aliado_credit_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lim numeric;
  exp numeric;
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

  select credit_limit into lim
  from public.profiles
  where id = new.aliado_id and role = 'aliado';
  if lim is null then
    raise exception 'El aliado no tiene límite de crédito autorizado.';
  end if;

  select coalesce(primeros_pedidos_contado_entregados, 0) into pc
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
  if (exp + new.precio_total) > lim + tol then
    raise exception 'El pedido supera el límite de crédito disponible.';
  end if;
  return new;
end;
$$;

-- Al entregar: incrementar contador de fase contado (máx. 3).
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

    update public.profiles
    set primeros_pedidos_contado_entregados = least(
      coalesce(primeros_pedidos_contado_entregados, 0) + 1,
      3
    )
    where id = new.aliado_id
      and role = 'aliado'
      and coalesce(primeros_pedidos_contado_entregados, 0) < 3;
  end if;
  return new;
end;
$$;
