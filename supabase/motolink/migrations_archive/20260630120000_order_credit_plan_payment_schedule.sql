-- Plan de cuotas comerciales: columnas en pedido, calendario de vencimientos, RPC admin.

alter table public.transaction_requests
  add column if not exists credit_plan_type smallint,
  add column if not exists credit_plan_confirmed_at timestamptz,
  add column if not exists credit_monto_bloqueado numeric(14, 2);

alter table public.transaction_requests
  drop constraint if exists transaction_requests_credit_plan_type_check;

alter table public.transaction_requests
  add constraint transaction_requests_credit_plan_type_check
  check (credit_plan_type is null or credit_plan_type in (1, 2, 3));

comment on column public.transaction_requests.credit_plan_type is
  '1 = contado (1 cuota), 2 o 3 cuotas cada 15 días, formalizado por MotoLink en el chat.';
comment on column public.transaction_requests.credit_monto_bloqueado is
  'Monto (USD) bloqueado contra el cupo al firmar el plan; copia de precio_total a la confirmación.';

create table if not exists public.payment_schedule (
  id uuid primary key default gen_random_uuid(),
  transaction_request_id uuid not null
    references public.transaction_requests (id) on delete cascade,
  installment_index int not null check (installment_index >= 1),
  amount_usd numeric(14, 2) not null,
  due_on date not null,
  created_at timestamptz not null default now(),
  unique (transaction_request_id, installment_index)
);

create index if not exists payment_schedule_tr_id_idx
  on public.payment_schedule (transaction_request_id);

comment on table public.payment_schedule is
  'Vencimientos y montos de cuotas acordados para el pedido; intervalo 15 días desde la fecha de región Venezuela.';

alter table public.payment_schedule enable row level security;

drop policy if exists "ps_select_admin" on public.payment_schedule;
create policy "ps_select_admin" on public.payment_schedule
  for select to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador')
  );

drop policy if exists "ps_select_aliado_own" on public.payment_schedule;
create policy "ps_select_aliado_own" on public.payment_schedule
  for select to authenticated
  using (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id = payment_schedule.transaction_request_id
        and tr.aliado_id = auth.uid()
    )
  );

-- Sin INSERT/UPDATE directo: solo a través de [admin_confirm_order_credit_plan] (security definer).

-- -----------------------------------------------------------------------------
create or replace function public.admin_confirm_order_credit_plan(
  p_request_id uuid,
  p_installments int
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
  v_cents bigint;
  v_per bigint;
  v_rem int;
  k int;
  v_cents_k bigint;
  v_amt numeric(14, 2);
  v_today_ccs date;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo un administrador MotoLink puede confirmar un plan de cuotas.';
  end if;

  if p_installments is null or p_installments not in (1, 2, 3) then
    raise exception 'Número de cuotas no válido (1, 2 o 3).';
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

  select coalesce(sum(tr2.precio_total), 0) into v_exp
  from public.transaction_requests tr2
  where tr2.aliado_id = v_aliado
    and tr2.status in (
      'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito'
    );

  if (v_exp + v_cons) > (v_lim + tol) then
    raise exception 'CUPO_INSUFICIENTE: el aliado no tiene cupo disponible para su exposición y crédito acumulado actuales.';
  end if;

  v_today_ccs := (now() at time zone 'America/Caracas')::date;

  delete from public.payment_schedule
  where transaction_request_id = p_request_id;

  v_cents := round(coalesce(v_total, 0) * 100)::bigint;
  if v_cents < 0 then
    v_cents := 0;
  end if;
  v_per := v_cents / p_installments;
  v_rem := (v_cents - (v_per * p_installments))::int;
  for k in 1..p_installments loop
    v_cents_k := v_per;
    if k <= v_rem then
      v_cents_k := v_cents_k + 1;
    end if;
    v_amt := (v_cents_k::numeric / 100.0);
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
    credit_plan_type = p_installments,
    credit_plan_confirmed_at = now(),
    credit_monto_bloqueado = coalesce(precio_total, 0),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_confirm_order_credit_plan(uuid, int) to authenticated;
