-- Bloqueo de redefinición de plan si la cuota 1 ya tiene registro, y notificación al aliado al confirmar.

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
    and tr.status in (
      'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito'
    );

  if (v_exp + v_cons + v_total) > (v_lim + tol) then
    raise exception 'CUPO_INSUFICIENTE: el aliado no tiene cupo disponible para su exposición y crédito acumulado actuales.';
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

grant execute on function public.admin_confirm_order_credit_plan(uuid, numeric[]) to authenticated;
