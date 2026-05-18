-- Plan de cuotas (importador) + ETA obligatorio al marcar en tránsito (MotoConecta).

alter table public.transaction_requests
  add column if not exists credit_plan_type smallint,
  add column if not exists credit_plan_confirmed_at timestamptz,
  add column if not exists credit_monto_bloqueado numeric(14, 4),
  add column if not exists transit_eta_days integer,
  add column if not exists transit_eta_hours integer,
  add column if not exists transit_eta_set_at timestamptz,
  add column if not exists at_aprobado_admin timestamptz,
  add column if not exists at_rechazado timestamptz,
  add column if not exists at_en_preparacion timestamptz,
  add column if not exists at_pedido_listo timestamptz,
  add column if not exists at_en_transito timestamptz,
  add column if not exists at_entregado timestamptz,
  add column if not exists factura_aliado_storage_path text,
  add column if not exists factura_aliado_file_name text,
  add column if not exists factura_aliado_submitted_at timestamptz;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_credit_plan_type_check;

alter table public.transaction_requests
  add constraint transaction_requests_credit_plan_type_check
  check (credit_plan_type is null or credit_plan_type in (1, 2, 3));

create table if not exists public.payment_schedule (
  id uuid primary key default gen_random_uuid (),
  transaction_request_id uuid not null
    references public.transaction_requests (id) on delete cascade,
  installment_index int not null check (installment_index >= 1),
  amount_usd numeric(14, 4) not null,
  due_on date not null,
  created_at timestamptz not null default now (),
  pago_metodo text,
  pago_comprobante_storage_path text,
  pago_comprobante_file_name text,
  pago_submitted_at timestamptz,
  pago_estado_revision text default 'pendiente',
  pago_comprobante_rechazo_nota text,
  pago_aprobado_at timestamptz,
  unique (transaction_request_id, installment_index)
);

create index if not exists payment_schedule_tr_id_idx
  on public.payment_schedule (transaction_request_id);

alter table public.payment_schedule enable row level security;

drop policy if exists ps_select_admin on public.payment_schedule;
create policy ps_select_admin
on public.payment_schedule
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  )
);

drop policy if exists ps_select_aliado_own on public.payment_schedule;
create policy ps_select_aliado_own
on public.payment_schedule
for select
to authenticated
using (
  exists (
    select 1
    from public.transaction_requests tr
    where tr.id = payment_schedule.transaction_request_id
      and tr.aliado_id = auth.uid ()
  )
);

drop policy if exists ps_select_importador_own on public.payment_schedule;
create policy ps_select_importador_own
on public.payment_schedule
for select
to authenticated
using (
  exists (
    select 1
    from public.transaction_requests tr
    where tr.id = payment_schedule.transaction_request_id
      and tr.importador_id = auth.uid ()
  )
);

-- Bloque de cupo para planes (precio_total_usd en MotoConecta).
create or replace function public.transaction_request_effective_cupo_block (p_tr uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when tr.status = 'rechazado' then
        0::numeric
      when exists (
        select 1
        from public.payment_schedule ps
        where ps.transaction_request_id = p_tr
      ) then
        greatest(
          0::numeric,
          coalesce(tr.precio_total_usd, 0) - coalesce(
            (
              select sum(ps.amount_usd)
              from public.payment_schedule ps
              where ps.transaction_request_id = p_tr
                and ps.pago_estado_revision = 'aprobado'
            ),
            0
          )
        )
      when tr.status = 'entregado' then
        0::numeric
      else
        coalesce(tr.precio_total_usd, 0)
    end
  from public.transaction_requests tr
  where tr.id = p_tr;
$$;

grant execute on function public.transaction_request_effective_cupo_block (uuid) to authenticated;

-- Importador: acuerda plan de 1–3 cuotas con el aliado.
create or replace function public.importer_confirm_order_credit_plan (
  p_request_id uuid,
  p_amounts_usd numeric[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_importador uuid;
  v_total numeric(14, 4);
  v_st text;
  v_lim numeric;
  v_exp numeric;
  tol constant numeric := 0.01;
  v_today_ccs date;
  n int;
  i int;
  s numeric;
  v_amt numeric(14, 4);
  k int;
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'importador'
  ) then
    raise exception 'Solo el importador del pedido puede confirmar el plan de cuotas.';
  end if;

  if p_amounts_usd is null or array_length(p_amounts_usd, 1) is null then
    raise exception 'Debe indicar al menos un monto de cuota.';
  end if;

  n := array_length(p_amounts_usd, 1);
  if n < 1 or n > 3 then
    raise exception 'Número de cuotas no válido (1 a 3).';
  end if;

  select tr.aliado_id, tr.importador_id, tr.precio_total_usd, tr.status
    into v_aliado, v_importador, v_total, v_st
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_importador is distinct from auth.uid () then
    raise exception 'No autorizado para este pedido.';
  end if;

  if v_st = 'rechazado' then
    raise exception 'No se puede firmar un plan en un pedido rechazado.';
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
        or coalesce(nullif(btrim(ps.pago_estado_revision), ''), 'pendiente') <> 'pendiente'
      )
  ) then
    raise exception
      'PLAN_CUOTAS_BLOQUEADO: la primera cuota ya tiene comprobante o revisión; no se puede modificar el plan.';
  end if;

  s := 0;
  for i in 1..n loop
    s := s + coalesce(p_amounts_usd[i], 0);
  end loop;

  if abs(s - coalesce(v_total, 0)) > 0.02 then
    raise exception
      'MONTOS_NO_COINCIDEN: la suma de las cuotas no coincide con el total del pedido.';
  end if;

  select p.credit_limit
    into v_lim
  from public.profiles p
  where p.id = v_aliado
    and p.role = 'aliado';

  if v_lim is not null and v_lim > 0 then
    select coalesce(
      sum(public.transaction_request_effective_cupo_block(tr.id)),
      0
    )
      into v_exp
    from public.transaction_requests tr
    where tr.aliado_id = v_aliado
      and tr.id <> p_request_id
      and tr.status is distinct from 'rechazado';

    if (v_exp + coalesce(v_total, 0)) > (v_lim + tol) then
      raise exception 'CUPO_INSUFICIENTE: el aliado no tiene cupo disponible para este plan.';
    end if;
  end if;

  v_today_ccs := (now() at time zone 'America/Caracas')::date;

  delete from public.payment_schedule
  where transaction_request_id = p_request_id;

  for k in 1..n loop
    v_amt := round(coalesce(p_amounts_usd[k], 0), 2);
    insert into public.payment_schedule (
      transaction_request_id,
      installment_index,
      amount_usd,
      due_on
    )
    values (
      p_request_id,
      k,
      v_amt,
      v_today_ccs + ((k - 1) * 15)
    );
  end loop;

  update public.transaction_requests
  set
    credit_plan_type = n,
    credit_plan_confirmed_at = now(),
    credit_monto_bloqueado = coalesce(precio_total_usd, 0),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.importer_confirm_order_credit_plan (uuid, numeric[]) to authenticated;

-- Importador: pedido listo → en tránsito con ETA obligatorio.
create or replace function public.importer_marca_pedido_en_transito (
  p_request_id uuid,
  p_transit_eta_days integer,
  p_transit_eta_hours integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_importador uuid;
  st text;
  inv text;
  v_days integer;
  v_hours integer;
begin
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'importador'
  ) then
    raise exception 'Solo importadores pueden marcar en tránsito.';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);

  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'ETA inválido: días 0–365, horas 0–23.';
  end if;

  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día o una hora de tránsito estimado.';
  end if;

  select tr.importador_id, tr.status, tr.proveedor_factura_storage_path
    into v_importador, st, inv
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_importador is null then
    raise exception 'Pedido no encontrado.';
  end if;

  if v_importador is distinct from auth.uid () then
    raise exception 'No autorizado para este pedido.';
  end if;

  if st is distinct from 'pedido_listo' then
    raise exception 'Solo pedidos listos para despacho pueden pasar a en tránsito.';
  end if;

  if coalesce(btrim(inv), '') = '' then
    raise exception 'Adjunte la factura del proveedor antes de marcar en tránsito.';
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    at_en_transito = coalesce(at_en_transito, now()),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.importer_marca_pedido_en_transito (uuid, integer, integer) to authenticated;
