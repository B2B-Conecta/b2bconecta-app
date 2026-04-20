-- A1: Fase contado — KYC completo no obligatorio (salvo rechazo); RIF + domicilio fiscal.
-- Post–fase contado: misma regla que antes (KYC aprobado + cupo).

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
  v_rif text;
  v_est text;
  v_ciu text;
  v_dir text;
  pt numeric;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  pt := coalesce(new.precio_total, 0);

  select
    kyc_status,
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_consumido_acumulado, 0),
    nullif(trim(rif), ''),
    nullif(trim(estado), ''),
    nullif(trim(ciudad), ''),
    nullif(trim(direccion), '')
  into ks, pc, lim, cons, v_rif, v_est, v_ciu, v_dir
  from public.profiles
  where id = new.aliado_id and role = 'aliado';

  if ks is null then
    raise exception 'No se encontró el perfil del aliado.';
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

  if ks is distinct from 'aprobado' then
    raise exception 'La verificación documental del aliado debe estar aprobada por MotoLink.';
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

  if (exp + cons + pt) > lim + tol then
    raise exception 'El pedido supera el límite de crédito disponible.';
  end if;
  return new;
end;
$$;
