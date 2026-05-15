-- Alinea el texto del error con el mensaje mostrado en la app (CashPhaseException).

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
