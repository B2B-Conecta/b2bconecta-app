-- Fase 1: broker asigna credit_limit a aliados; nuevos pedidos validan cupo abierto.

create or replace function public.admin_set_aliado_credit_limit(
  p_aliado_id uuid,
  p_credit_limit numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden actualizar el límite de crédito';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_aliado_id and role = 'aliado'
  ) then
    raise exception 'El perfil indicado no es un aliado';
  end if;
  update public.profiles
  set credit_limit = p_credit_limit
  where id = p_aliado_id;
end;
$$;

grant execute on function public.admin_set_aliado_credit_limit(uuid, numeric) to authenticated;

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
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;
  select credit_limit into lim
  from public.profiles
  where id = new.aliado_id and role = 'aliado';
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
  if (exp + new.precio_total) > lim + tol then
    raise exception 'El pedido supera el límite de crédito disponible.';
  end if;
  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_check_credit on public.transaction_requests;
create trigger tr_transaction_requests_check_credit
  before insert on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_check_aliado_credit_limit();
