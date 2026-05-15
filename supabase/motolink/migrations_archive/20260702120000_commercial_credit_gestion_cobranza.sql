-- T1: auditoría de cupo | T2–3: plan con montos a medida, pagos por cuota | T4: alertas T5: bloqueo efectivo de cupo

-- ---------------------------------------------------------------------------
-- Auditoría (solo lectura via RLS; escritura vía admin_set_aliado_credit_limit)
create table if not exists public.credit_audit_logs (
  id uuid primary key default gen_random_uuid(),
  aliado_id uuid not null references public.profiles (id) on delete cascade,
  admin_id uuid not null references public.profiles (id) on delete restrict,
  old_limit numeric(14, 2),
  new_limit numeric(14, 2) not null,
  reason text not null,
  created_at timestamptz not null default now(),
  check (char_length(trim(reason)) > 0)
);

create index if not exists credit_audit_logs_aliado_idx on public.credit_audit_logs (aliado_id, created_at desc);
alter table public.credit_audit_logs enable row level security;
drop policy if exists "cal_select_admin" on public.credit_audit_logs;
create policy "cal_select_admin" on public.credit_audit_logs
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'));

-- Campos de pago por fila (cuota)
alter table public.payment_schedule
  add column if not exists pago_metodo text,
  add column if not exists pago_comprobante_storage_path text,
  add column if not exists pago_comprobante_file_name text,
  add column if not exists pago_submitted_at timestamptz,
  add column if not exists pago_estado_revision text default 'pendiente',
  add column if not exists pago_comprobante_rechazo_nota text,
  add column if not exists pago_aprobado_at timestamptz,
  add column if not exists notif_7d_sent_at timestamptz,
  add column if not exists notif_vencida_sent_at timestamptz;

-- ---------------------------------------------------------------------------
-- Carga contra cupo de un pedido abierto (baja a medida se aprueban cuotas)
create or replace function public.transaction_request_effective_cupo_block(p_tr uuid) returns numeric
language sql
stable
set search_path = public
as $$
  select
    case
      when exists (select 1 from public.payment_schedule ps where ps.transaction_request_id = p_tr) then
        GREATEST(0, tr.precio_total - coalesce((
          select sum(ps.amount_usd) from public.payment_schedule ps
          where ps.transaction_request_id = p_tr
            and ps.pago_estado_revision = 'aprobado'
        ), 0))
      else
        tr.precio_total
    end
  from public.transaction_requests tr
  where tr.id = p_tr;
$$;

-- Cupo: suma de exposición *efectiva* + precio del nuevo (sin cuotas: bloquea total)
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
    select coalesce(
      sum(public.transaction_request_effective_cupo_block(tr.id))
    , 0) into exp
    from public.transaction_requests tr
    where tr.aliado_id = new.aliado_id
      and tr.status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'en_transito'
      );

    if (exp + cons + pt) > (lim + tol) then
      raise exception 'El pedido supera el límite de crédito disponible.';
    end if;
  end if;

  return new;
end;
$$;

-- Límite con motivo obligatorio y registro
drop function if exists public.admin_set_aliado_credit_limit(uuid, numeric, boolean);
create or replace function public.admin_set_aliado_credit_limit(
  p_aliado_id uuid,
  p_credit_limit numeric,
  p_credito_preactivado boolean default false,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  prev_preact boolean;
  prev_limit numeric;
  t text;
begin
  t := nullif(trim(coalesce(p_reason, '')), '');

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
  if t is null or char_length(t) = 0 then
    raise exception 'Debe indicar el motivo del ajuste de límite (registro de auditoría).';
  end if;

  select coalesce(credito_preactivado_por_admin, false), coalesce(credit_limit, 0)
  into prev_preact, prev_limit
  from public.profiles
  where id = p_aliado_id;

  insert into public.credit_audit_logs (aliado_id, admin_id, old_limit, new_limit, reason)
  values (p_aliado_id, auth.uid(), prev_limit, p_credit_limit, t);

  update public.profiles
  set
    credit_limit = p_credit_limit,
    credito_preactivado_por_admin = p_credito_preactivado
  where id = p_aliado_id;

  if p_credit_limit > 0
     and p_credito_preactivado
     and not coalesce(prev_preact, false) then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      p_aliado_id,
      'Línea de crédito MotoLink habilitada',
      'MotoLink le asignó un cupo de USD '
        || trim(to_char(p_credit_limit, 'FM999999990.00'))
        || ' y autorizó el uso de la línea de crédito en la plataforma desde ahora, '
        || 'incluso durante sus primeros pedidos. Revise su perfil y los métodos de pago al confirmar pedidos.',
      'kyc',
      p_aliado_id::text
    );
  end if;
end;
$$;
grant execute on function public.admin_set_aliado_credit_limit(uuid, numeric, boolean, text) to authenticated;

-- Reemplaza plan: montos fijos (1–3 posiciones) que suman precio_total
drop function if exists public.admin_confirm_order_credit_plan(uuid, int);
drop function if exists public.admin_confirm_order_credit_plan(uuid, int[]);
drop function if exists public.admin_confirm_order_credit_plan(uuid, numeric[]);

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
end;
$$;

grant execute on function public.admin_confirm_order_credit_plan(uuid, numeric[]) to authenticated;

-- Sincroniza pago a nivel de pedido cuando todas las cuotas aprobadas
create or replace function public._sync_tr_pago_if_all_instalments_ok(p_request_id uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  tot int;
  ap int;
  has_ps boolean;
begin
  select exists (
    select 1 from public.payment_schedule ps
    where ps.transaction_request_id = p_request_id
  ) into has_ps;
  if not has_ps then
    return;
  end if;

  select coalesce(count(*)::int,0), coalesce((
    select count(*) from public.payment_schedule
    where transaction_request_id = p_request_id and pago_estado_revision = 'aprobado'
  )::int,0)
  into tot, ap
  from public.payment_schedule
  where transaction_request_id = p_request_id;

  if tot > 0 and tot = ap then
    update public.transaction_requests
    set
      pago_estado_revision = 'aprobado',
      pago_aprobado_at = now(),
      updated_at = now()
    where id = p_request_id
      and pago_estado_revision is distinct from 'aprobado';
  elsif exists (
    select 1 from public.payment_schedule
    where transaction_request_id = p_request_id
      and pago_estado_revision = 'en_revision'
  ) then
    update public.transaction_requests
    set
      pago_estado_revision = 'en_revision',
      pago_comprobante_rechazo_nota = null,
      pago_aprobado_at = null,
      updated_at = now()
    where id = p_request_id
      and pago_estado_revision is distinct from 'en_revision';
  else
    update public.transaction_requests
    set
      pago_estado_revision = 'pendiente',
      pago_aprobado_at = null,
      updated_at = now()
    where id = p_request_id
      and pago_aprobado_at is not null;
  end if;
end;
$$;

-- Aliado: comprobante por id de fila (cuota)
create or replace function public.aliado_registra_comprobante_pago_cuota(
  p_schedule_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_tr uuid;
  v_aliado uuid;
  st text;
  v_fact text;
  base numeric;
  base_now numeric;
begin
  if p_metodo = 'credito_sistema' then
    raise exception 'El crédito del sistema se declara a nivel de pedido con la acción dedicada, sin comprobante por cuota.';
  end if;
  if p_metodo not in (
    'pago_movil', 'zelle_divisas', 'transferencia', 'efectivo'
  ) then
    raise exception 'Método de pago no válido.';
  end if;
  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del comprobante.';
  end if;

  select
    ps.transaction_request_id,
    tr.aliado_id,
    tr.status,
    tr.factura_aliado_storage_path,
    tr.precio_base_aliado_total,
    tr.precio_total
  into
    v_tr, v_aliado, st, v_fact, base, base_now
  from public.payment_schedule ps
  join public.transaction_requests tr on tr.id = ps.transaction_request_id
  where ps.id = p_schedule_id;

  if v_tr is null or v_aliado is null then
    raise exception 'Cuota no encontrada.';
  end if;
  if v_aliado <> auth.uid() then
    raise exception 'No autorizado a registrar pago de esta cuota.';
  end if;
  if st = 'rechazado' then
    raise exception 'Pedido rechazado: no se puede subir comprobante.';
  end if;
  if coalesce(nullif(trim(v_fact), ''), '') = '' then
    raise exception 'Debe existir factura MotoLink al aliado para registrar el pago.';
  end if;

  if p_storage_path not like (v_tr::text || '/%') then
    raise exception 'Ruta de archivo inválida.';
  end if;

  update public.payment_schedule ps
  set
    pago_metodo = p_metodo,
    pago_comprobante_storage_path = p_storage_path,
    pago_comprobante_file_name = p_file_name,
    pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null
  where ps.id = p_schedule_id
    and coalesce(ps.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado', 'en_revision');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No se pudo actualizar la cuota (puede que ya esté aprobada).';
  end if;

  update public.transaction_requests
  set pago_estado_revision = 'en_revision', pago_comprobante_rechazo_nota = null, updated_at = now()
  where id = v_tr
    and status in (
      'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito', 'entregado'
    );
end;
$$;
grant execute on function public.aliado_registra_comprobante_pago_cuota(uuid, text, text, text) to authenticated;

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
end;
$$;

create or replace function public.admin_rechazar_comprobante_pago_cuota(
  p_schedule_id uuid,
  p_nota text
) returns void
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
    pago_estado_revision = 'rechazado',
    pago_comprobante_rechazo_nota = nullif(trim(p_nota), '')
  where id = p_schedule_id
    and pago_estado_revision = 'en_revision';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No se pudo rechazar esta cuota.';
  end if;

  select transaction_request_id into p_tr from public.payment_schedule where id = p_schedule_id;
  perform public._sync_tr_pago_if_all_instalments_ok(p_tr);
end;
$$;
grant execute on function public.admin_rechazar_comprobante_pago_cuota(uuid, text) to authenticated;

-- Alertas diarias (in-app: `notifications`, type `pago`) — idempotente por fila
create or replace function public.run_payment_installment_cobranza_alerts() returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  c int := 0;
  r record;
  d0 date;
  t7 date;
  body1 text;
  body2 text;
begin
  d0 := (now() at time zone 'America/Caracas')::date;
  t7 := d0 + 7;

  for r in
    select
      ps.id,
      ps.transaction_request_id,
      tr.aliado_id,
      ps.amount_usd,
      ps.due_on,
      ps.pago_estado_revision,
      ps.notif_7d_sent_at,
      ps.notif_vencida_sent_at
    from public.payment_schedule ps
    join public.transaction_requests tr on tr.id = ps.transaction_request_id
    where
      coalesce(ps.pago_estado_revision, 'pendiente') is distinct from 'aprobado'
      and tr.status in (
        'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito', 'entregado'
      )
  loop
    if r.due_on = t7
       and r.due_on > d0
       and r.notif_7d_sent_at is null
    then
      body1 := 'Recordatorio: tu cuota de $'
        || trim(to_char(r.amount_usd, 'FM999999990.00'))
        || ' para el pedido '
        || r.transaction_request_id::text
        || ' vence en 1 semana. Prepara tu pago.';

      insert into public.notifications (user_id, title, body, type, related_id)
      values (r.aliado_id, 'Pago de cuota MotoLink', body1, 'pago', r.transaction_request_id::text);

      update public.payment_schedule
      set notif_7d_sent_at = now()
      where id = r.id;
      c := c + 1;
    end if;

    if r.due_on < d0
       and r.notif_vencida_sent_at is null
       and coalesce(r.pago_estado_revision, 'pendiente') is distinct from 'aprobado'
    then
      body2 := 'Cuota vencida: $'
        || trim(to_char(r.amount_usd, 'FM999999990.00'))
        || ' en el pedido '
        || r.transaction_request_id::text
        || '. Contacta a MotoLink para regularizar.';

      insert into public.notifications (user_id, title, body, type, related_id)
      values (r.aliado_id, 'Cuota vencida', body2, 'pago', r.transaction_request_id::text);

      update public.payment_schedule
      set notif_vencida_sent_at = now()
      where id = r.id;
      c := c + 1;
    end if;
  end loop;

  return c;
end;
$$;

grant execute on function public.run_payment_installment_cobranza_alerts() to service_role;

-- Suma de cupo retenida por pedidos abiertos (misma lógica que en validación al crear pedido)
create or replace function public.aliado_effective_open_exposure(p_aliado_id uuid) returns numeric
language sql
stable
set search_path = public
as $$
  select coalesce(
    sum(public.transaction_request_effective_cupo_block(tr.id))
  , 0)
  from public.transaction_requests tr
  where tr.aliado_id = p_aliado_id
    and tr.status in (
      'pendiente', 'aprobado_admin', 'en_preparacion', 'en_transito'
    );
$$;

grant execute on function public.aliado_effective_open_exposure(uuid) to authenticated;
grant execute on function public.admin_aprobar_pago_aliado_cuota(uuid) to authenticated;
