-- Imputado a "crédito consumido" al CERRAR el plan (todas las cuotas aprobadas), una sola vez por pedido.
-- "Disponible" en app: límite − saldo activo (E) − imputado acumulado.
-- Inserción de pedidos: E + imputado + nuevo ≤ límite.
-- Nota: no duplicar archivos con el mismo prefijo 20260724120000_ (Supabase usa un solo registro de versión).

alter table public.transaction_requests
  add column if not exists cupo_plan_cerrado_imputado boolean not null default false;

comment on column public.transaction_requests.cupo_plan_cerrado_imputado is
  'true cuando ya se imputó precio_total a profiles.credito_consumido_acumulado (plan a cuotas totalmente aprobado).';

create or replace function public.admin_aprobar_pago_aliado_cuota(p_schedule_id uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p_tr uuid;
  n int;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores';
  end if;

  update public.payment_schedule
  set
    pago_estado_revision = 'aprobado',
    pago_aprobado_at = now()
  where id = p_schedule_id
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para esta cuota.';
  end if;

  select transaction_request_id into p_tr from public.payment_schedule where id = p_schedule_id;
  perform public._sync_tr_pago_if_all_instalments_ok(p_tr);

  with ok as (
    update public.transaction_requests tr
    set
      cupo_plan_cerrado_imputado = true,
      updated_at = now()
    where tr.id = p_tr
      and coalesce(tr.cupo_plan_cerrado_imputado, false) = false
      and exists (select 1 from public.payment_schedule ps where ps.transaction_request_id = tr.id)
      and not exists (
        select 1 from public.payment_schedule ps2
        where ps2.transaction_request_id = tr.id
          and coalesce(nullif(btrim(ps2.pago_estado_revision), ''), 'pendiente') <> 'aprobado'
      )
    returning tr.aliado_id, tr.precio_total
  )
  update public.profiles p
  set credito_consumido_acumulado = coalesce(p.credito_consumido_acumulado, 0) + coalesce(ok.precio_total, 0)
  from ok
  where p.id = ok.aliado_id
    and p.role = 'aliado'
    and coalesce(ok.precio_total, 0) > 0;
end;
$$;

create or replace function public.transaction_requests_check_aliado_credit_limit() returns trigger
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

  if lim is not null and lim > 0 then
    exp := public.aliado_effective_open_exposure(new.aliado_id);

    if (exp + cons + pt) > (lim + tol) then
      raise exception 'El pedido supera el límite de crédito disponible.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.admin_confirm_order_credit_plan(
  p_request_id uuid,
  p_amounts_usd numeric[]
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_total numeric(14, 2);
  v_st text;
  v_lim numeric;
  v_cons numeric;
  v_exp numeric;
  tol constant numeric := 0.01;
  v_today_ccs date;
  n int;
  i int;
  s numeric;
  v_amt numeric(14, 2);
  k int;
  v_cuerpo text;
  v_titulo text;
  v_ccs text;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo un administrador MotoLink puede confirmar un plan de cuotas.';
  end if;

  if p_amounts_usd is null or array_length(p_amounts_usd, 1) is null then
    raise exception 'Debe indicar al menos un monto de cuota.';
  end if;

  n := array_length(p_amounts_usd, 1);
  if n < 1 or n > 3 then
    raise exception 'Número de cuotas no válido (1 a 3).';
  end if;

  select
    tr.aliado_id,
    tr.precio_total,
    tr.status
  into v_aliado, v_total, v_st
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_st = 'rechazado' then
    raise exception 'No se puede firmar un plan de cuotas en un pedido rechazado.';
  end if;

  if exists (
    select 1
    from public.payment_schedule ps
    where ps.transaction_request_id = p_request_id
      and ps.installment_index = 1
      and (
        ps.pago_submitted_at is not null
        or (
          ps.pago_comprobante_storage_path is not null
          and btrim(ps.pago_comprobante_storage_path) <> ''
        )
        or coalesce(
          nullif(btrim(ps.pago_estado_revision), ''),
          'pendiente'
        ) <> 'pendiente'
      )
  ) then
    raise exception
      'PLAN_CUOTAS_BLOQUEADO: la primera cuota ya tiene comprobante o revisión; no se puede modificar el plan de cuotas.';
  end if;

  s := 0;
  for i in 1..n loop
    s := s + coalesce(p_amounts_usd[i], 0);
  end loop;

  if abs(s - v_total) > 0.02 then
    raise exception 'MONTOS_NO_COINCIDEN: la suma de las cuotas no coincide con el total del pedido (suma=%, total=%).', s, v_total;
  end if;

  select
    p.credit_limit,
    coalesce(p.credito_consumido_acumulado, 0)
  into v_lim, v_cons
  from public.profiles p
  where p.id = v_aliado and p.role = 'aliado';

  if v_lim is null or v_lim <= 0 then
    raise exception
      'El aliado no tiene línea de crédito MotoLink asignada. Asigne cupo antes de un plan a cuotas.';
  end if;

  select coalesce(
    sum(public.transaction_request_effective_cupo_block(tr.id))
  , 0) into v_exp
  from public.transaction_requests tr
  where tr.aliado_id = v_aliado
    and tr.id <> p_request_id
    and tr.status is distinct from 'rechazado';

  if (v_exp + v_cons + v_total) > (v_lim + tol) then
    raise exception 'CUPO_INSUFICIENTE: el aliado no tiene cupo disponible para su exposición e imputado actuales.';
  end if;

  v_today_ccs := (now() at time zone 'America/Caracas')::date;

  delete from public.payment_schedule
  where transaction_request_id = p_request_id;

  for k in 1..n loop
    v_amt := round(coalesce(p_amounts_usd[k], 0), 2);
    insert into public.payment_schedule (
      transaction_request_id, installment_index, amount_usd, due_on
    ) values (
      p_request_id,
      k,
      v_amt,
      v_today_ccs + ((k - 1) * 15) * interval '1 day'
    );
  end loop;

  update public.transaction_requests
  set
    credit_plan_type = n,
    credit_plan_confirmed_at = now(),
    credit_monto_bloqueado = coalesce(precio_total, 0),
    pago_estado_revision = 'pendiente',
    pago_aprobado_at = null,
    updated_at = now()
  where id = p_request_id;

  v_ccs := to_char(
    (now() at time zone 'America/Caracas'),
    'DD/MM/YYYY FMHH24:MI'
  );

  v_titulo := 'Plan de pago de MotoLink en su pedido';

  v_cuerpo :=
    'MotoLink fijó ' || n::text || ' cuota' || case when n = 1 then '' else 's' end
    || ' por $' || trim(to_char(v_total, 'FM999999990.00')) || ' USD en total. '
    || case when n > 1 then 'Vencimientos cada 15 días. ' else '' end
    || 'Hora de confirmación (Caracas): ' || v_ccs
    || '. Vea el detalle en Pago de este pedido.';

  insert into public.notifications (user_id, title, body, type, related_id)
  values (v_aliado, v_titulo, v_cuerpo, 'pago', p_request_id::text);
end;
$$;

comment on column public.profiles.credito_consumido_acumulado is
  'Imputado: entregas a crédito sin plan a cuotas (total al entregar) + total del pedido al aprobarse la última cuota de un plan.';

-- Sincronizar bandera y recompute (corrige conteos por-cuota antiguos)
update public.transaction_requests tr
set cupo_plan_cerrado_imputado = true
where exists (select 1 from public.payment_schedule ps where ps.transaction_request_id = tr.id)
  and not exists (
    select 1 from public.payment_schedule ps2
    where ps2.transaction_request_id = tr.id
      and coalesce(nullif(btrim(ps2.pago_estado_revision), ''), 'pendiente') <> 'aprobado'
  );

update public.profiles p
set credito_consumido_acumulado =
  coalesce((
    select sum(tr.precio_total) from public.transaction_requests tr
    where tr.aliado_id = p.id
      and tr.status = 'entregado'
      and tr.pago_metodo = 'credito_sistema'
      and coalesce(nullif(btrim(tr.pago_estado_revision), ''), 'pendiente') = 'aprobado'
      and not exists (select 1 from public.payment_schedule ps where ps.transaction_request_id = tr.id)
  ), 0)
  +
  coalesce((
    select sum(tr.precio_total) from public.transaction_requests tr
    where tr.aliado_id = p.id
      and coalesce(tr.cupo_plan_cerrado_imputado, false) = true
  ), 0)
where p.role = 'aliado';
