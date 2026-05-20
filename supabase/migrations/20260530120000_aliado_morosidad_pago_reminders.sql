-- Morosidad aliado: recordatorios de pago cada 12 h tras cierre del pedido (entregado),
-- notificación al activar suspensión por morosidad, RPCs admin.

-- ---------------------------------------------------------------------------
-- 1) Marca temporal de entrega (para SLA de recordatorios)
-- ---------------------------------------------------------------------------
create or replace function public.tr_transaction_requests_set_at_entregado ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'entregado'::text
     and (old.status is distinct from 'entregado'::text) then
    new.at_entregado := coalesce(new.at_entregado, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_at_entregado on public.transaction_requests;

create trigger trg_set_at_entregado
before update of status on public.transaction_requests
for each row
execute function public.tr_transaction_requests_set_at_entregado ();

update public.transaction_requests tr
set at_entregado = coalesce(tr.at_entregado, tr.updated_at, now())
where tr.status = 'entregado'::text
  and tr.at_entregado is null;

-- ---------------------------------------------------------------------------
-- 2) ¿Pedido con pago pendiente tras entrega? (SQL, alineado con app)
-- ---------------------------------------------------------------------------
create or replace function public.tr_is_moroso_pago_pendiente (p_row public.transaction_requests)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_factura_ok boolean;
  v_cuotas_pend numeric;
begin
  if p_row.status <> 'entregado'::text then
    return false;
  end if;

  v_factura_ok := coalesce(p_row.factura_aliado_storage_path, '') <> '';

  if v_factura_ok
     and coalesce(p_row.pago_estado_revision, '') <> 'aprobado' then
    return true;
  end if;

  if p_row.credit_plan_type is not null
     and p_row.credit_plan_type between 1 and 3 then
    select coalesce(sum(ps.amount_usd), 0)
      into v_cuotas_pend
    from public.payment_schedule ps
    where ps.transaction_request_id = p_row.id
      and coalesce(ps.pago_estado_revision, 'pendiente') <> 'aprobado';

    if v_cuotas_pend > 0.0001 then
      return true;
    end if;
  end if;

  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Dedup recordatorios 12 h (por aliado + ancla de carrito / pedido)
-- ---------------------------------------------------------------------------
create table if not exists public.aliado_pago_pendiente_reminder_sent (
  aliado_id uuid not null references public.profiles (id) on delete cascade,
  anchor_id uuid not null,
  last_sent_at timestamptz not null default now(),
  primary key (aliado_id, anchor_id)
);

create index if not exists aliado_pago_pendiente_reminder_sent_last_idx
  on public.aliado_pago_pendiente_reminder_sent (last_sent_at);

alter table public.aliado_pago_pendiente_reminder_sent enable row level security;

-- Solo backend (cron / security definer)
drop policy if exists aliado_pago_reminder_no_client on public.aliado_pago_pendiente_reminder_sent;
create policy aliado_pago_reminder_no_client
on public.aliado_pago_pendiente_reminder_sent
for all
to authenticated
using (false)
with check (false);

-- ---------------------------------------------------------------------------
-- 4) Cron: recordatorio aliado cada 12 h tras cierre (entregado + pago pendiente)
-- ---------------------------------------------------------------------------
create or replace function public.run_aliado_pago_pendiente_reminders ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_count int := 0;
  v_anchor uuid;
  v_cerrado timestamptz;
  v_last timestamptz;
  v_pendientes int;
  v_body text;
begin
  perform set_config ('row_security', 'off', true);

  for rec in
    select distinct on (tr.aliado_id, public.mc_tr_notif_anchor_id (tr))
      tr.id,
      tr.aliado_id,
      public.mc_tr_notif_anchor_id (tr) as anchor_id,
      coalesce(tr.at_entregado, tr.updated_at, now()) as cerrado_at
    from public.transaction_requests tr
    where public.tr_is_moroso_pago_pendiente (tr)
    order by tr.aliado_id, public.mc_tr_notif_anchor_id (tr), tr.id
  loop
    v_anchor := rec.anchor_id;
    v_cerrado := rec.cerrado_at;

    if v_cerrado > now() - interval '12 hours' then
      continue;
    end if;

    select r.last_sent_at
      into v_last
    from public.aliado_pago_pendiente_reminder_sent r
    where r.aliado_id = rec.aliado_id
      and r.anchor_id = v_anchor;

    if v_last is not null and v_last > now() - interval '12 hours' then
      continue;
    end if;

    select count(*)::int
      into v_pendientes
    from public.transaction_requests tr2
    where tr2.aliado_id = rec.aliado_id
      and public.tr_is_moroso_pago_pendiente (tr2);

    v_body := format(
      'Tiene %s pedido(s) entregado(s) con pago pendiente ante MotoLink. '
      'Registre su comprobante en la app para evitar restricciones en su cuenta.',
      v_pendientes
    );

    perform public.mc_insert_notification (
      rec.aliado_id,
      'Recordatorio · pago pendiente',
      v_body,
      'morosidad',
      v_anchor::text
    );

    insert into public.aliado_pago_pendiente_reminder_sent (aliado_id, anchor_id, last_sent_at)
    values (rec.aliado_id, v_anchor, now())
    on conflict (aliado_id, anchor_id)
    do update set last_sent_at = excluded.last_sent_at;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.run_aliado_pago_pendiente_reminders () to service_role;

-- ---------------------------------------------------------------------------
-- 5) Notificar aliado al activar suspensión por morosidad
-- ---------------------------------------------------------------------------
create or replace function public.tr_notify_aliado_morosidad_suspend ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role <> 'aliado'::text then
    return new;
  end if;
  if coalesce(new.pedidos_suspendidos_morosidad, false)
     and not coalesce(old.pedidos_suspendidos_morosidad, false) then
    perform public.mc_insert_notification (
      new.id,
      'Cuenta en morosidad',
      'MotoLink suspendió la creación de nuevos pedidos por morosidad. '
        || 'Regularice los pagos pendientes de pedidos entregados para solicitar la reactivación.',
      'morosidad',
      new.id::text
    );
  elsif not coalesce(new.pedidos_suspendidos_morosidad, false)
        and coalesce(old.pedidos_suspendidos_morosidad, false) then
    perform public.mc_insert_notification (
      new.id,
      'Cuenta reactivada',
      'Puede volver a crear pedidos en MotoLink. Mantenga sus pagos al día.',
      'morosidad',
      new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_aliado_morosidad_suspend on public.profiles;

create trigger trg_notify_aliado_morosidad_suspend
after update of pedidos_suspendidos_morosidad on public.profiles
for each row
execute function public.tr_notify_aliado_morosidad_suspend ();

-- ---------------------------------------------------------------------------
-- 6) RPC admin: flags morosos + suspender pedidos
-- ---------------------------------------------------------------------------
create or replace function public.admin_aliados_pedidos_morosos_flags ()
returns table (
  aliado_id uuid,
  tiene_morosos boolean,
  pedidos_suspendidos_morosidad boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  return query
  select
    p.id,
    exists (
      select 1
      from public.transaction_requests tr
      where tr.aliado_id = p.id
        and public.tr_is_moroso_pago_pendiente (tr)
    ),
    coalesce(p.pedidos_suspendidos_morosidad, false)
  from public.profiles p
  where p.role = 'aliado'::text;
end;
$$;

create or replace function public.admin_set_aliado_pedidos_suspendidos_morosidad (
  p_aliado_id uuid,
  p_suspend boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_aliado_id
      and p.role = 'aliado'::text
  ) then
    raise exception 'Perfil aliado no encontrado' using errcode = 'P0001';
  end if;

  update public.profiles p
  set pedidos_suspendidos_morosidad = coalesce(p_suspend, false)
  where p.id = p_aliado_id;
end;
$$;

grant execute on function public.admin_aliados_pedidos_morosos_flags () to authenticated;
grant execute on function public.admin_set_aliado_pedidos_suspendidos_morosidad (uuid, boolean) to authenticated;

-- Limpiar dedup cuando el pedido deja de estar moroso
create or replace function public.tr_clear_aliado_pago_reminder_on_tr_update ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_anchor uuid;
begin
  if not public.tr_is_moroso_pago_pendiente (new) then
    v_anchor := public.mc_tr_notif_anchor_id (new);
    delete from public.aliado_pago_pendiente_reminder_sent r
    where r.aliado_id = new.aliado_id
      and r.anchor_id = v_anchor;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_clear_aliado_pago_reminder_tr on public.transaction_requests;

create trigger trg_clear_aliado_pago_reminder_tr
after update of status, pago_estado_revision, factura_aliado_storage_path
  on public.transaction_requests
for each row
execute function public.tr_clear_aliado_pago_reminder_on_tr_update ();

create or replace function public.tr_clear_aliado_pago_reminder_on_cuota_update ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tr public.transaction_requests;
  v_anchor uuid;
begin
  select tr.*
    into v_tr
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if not found then
    return new;
  end if;

  if not public.tr_is_moroso_pago_pendiente (v_tr) then
    v_anchor := public.mc_tr_notif_anchor_id (v_tr);
    delete from public.aliado_pago_pendiente_reminder_sent r
    where r.aliado_id = v_tr.aliado_id
      and r.anchor_id = v_anchor;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_clear_aliado_pago_reminder_cuota on public.payment_schedule;

create trigger trg_clear_aliado_pago_reminder_cuota
after update of pago_estado_revision on public.payment_schedule
for each row
execute function public.tr_clear_aliado_pago_reminder_on_cuota_update ();

-- ---------------------------------------------------------------------------
-- 7) pg_cron: recordatorios cada 15 min (ventana 12 h)
-- ---------------------------------------------------------------------------
do $cron$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when insufficient_privilege then
    raise notice 'pg_cron: sin privilegio para crear extensión (omitir en local).';
  when others then
    raise notice 'pg_cron: %', sqlerrm;
end;
$cron$;

do $schedule$
declare
  v_job_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_aliado_pago_pendiente_reminders manualmente.';
    return;
  end if;

  select jobid
  into v_job_id
  from cron.job
  where jobname = 'motoconecta_aliado_pago_pendiente_12h'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'motoconecta_aliado_pago_pendiente_12h',
    '*/15 * * * *',
    $cmd$select public.run_aliado_pago_pendiente_reminders();$cmd$
  );
exception
  when undefined_table then
    raise notice 'cron.job no disponible; omitiendo schedule recordatorios pago.';
  when others then
    raise notice 'pg_cron recordatorios pago: %', sqlerrm;
end;
$schedule$;
