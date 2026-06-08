-- Admin: monitoreo de actividad B2B (ingresos + pedidos por aliado/importador).

create table if not exists public.user_login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  logged_in_at timestamptz not null default now(),
  source text not null default 'app'
    check (source in ('app', 'password', 'session_restore'))
);

create index if not exists user_login_events_user_at_idx
  on public.user_login_events (user_id, logged_in_at desc);

create index if not exists user_login_events_logged_in_at_idx
  on public.user_login_events (logged_in_at desc);

comment on table public.user_login_events is
  'Eventos de ingreso a la app (login explícito o restauración de sesión).';

alter table public.user_login_events enable row level security;

create policy user_login_events_insert_own on public.user_login_events
  for insert
  to authenticated
  with check (user_id = auth.uid ());

create policy user_login_events_select_admin on public.user_login_events
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

-- Registra ingreso del usuario autenticado (evita duplicados en ventana corta).
create or replace function public.log_user_login_event (p_source text default 'app')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source text;
begin
  if auth.uid () is null then
    return;
  end if;

  v_source := coalesce(nullif(trim(p_source), ''), 'app');
  if v_source not in ('app', 'password', 'session_restore') then
    v_source := 'app';
  end if;

  if exists (
    select 1
    from public.user_login_events e
    where e.user_id = auth.uid ()
      and e.logged_in_at > now() - interval '20 minutes'
  ) then
    return;
  end if;

  insert into public.user_login_events (user_id, source)
  values (auth.uid (), v_source);
end;
$$;

grant execute on function public.log_user_login_event (text) to authenticated;

comment on function public.log_user_login_event (text) is
  'Registra un ingreso del usuario actual (máx. uno cada 20 min).';

-- Estadísticas agregadas para panel admin.
create or replace function public.list_admin_user_activity_monitoring (
  p_role text default null,
  p_period text default 'week'
)
returns table (
  profile_id uuid,
  business_name text,
  rif text,
  role text,
  estado text,
  ciudad text,
  login_count_period bigint,
  login_count_today bigint,
  orders_count_period bigint,
  orders_delivered_period bigint,
  orders_volume_usd_period numeric,
  orders_in_progress_period bigint,
  last_login_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_role text;
  v_period text;
  v_day_start timestamptz;
  v_period_start timestamptz;
begin
  perform public._assert_administrador ();

  v_role := nullif(lower(trim(coalesce(p_role, ''))), '');
  if v_role is not null and v_role not in ('aliado', 'importador') then
    raise exception 'p_role debe ser aliado, importador o null'
      using errcode = '22023';
  end if;

  v_period := lower(trim(coalesce(p_period, 'week')));
  if v_period not in ('day', 'week') then
    raise exception 'p_period debe ser day o week' using errcode = '22023';
  end if;

  v_day_start :=
    date_trunc('day', timezone('America/Caracas', now()))
    at time zone 'America/Caracas';

  if v_period = 'day' then
    v_period_start := v_day_start;
  else
    v_period_start := v_day_start - interval '6 days';
  end if;

  return query
  with profiles_scope as (
    select p.*
    from public.profiles p
    where p.role in ('aliado', 'importador')
      and (v_role is null or p.role = v_role)
  ),
  login_stats as (
    select
      e.user_id,
      count(*) filter (
        where e.logged_in_at >= v_period_start
      )::bigint as login_count_period,
      count(*) filter (
        where e.logged_in_at >= v_day_start
      )::bigint as login_count_today,
      max(e.logged_in_at) as last_login_at
    from public.user_login_events e
    inner join profiles_scope ps on ps.id = e.user_id
    group by e.user_id
  ),
  order_stats as (
    select
      ps.id as profile_id,
      count(*) filter (
        where tr.created_at >= v_period_start
          and tr.status <> 'rechazado'
      )::bigint as orders_count_period,
      count(*) filter (
        where tr.created_at >= v_period_start
          and tr.status = 'entregado'
      )::bigint as orders_delivered_period,
      coalesce(
        sum(tr.precio_total_usd) filter (
          where tr.created_at >= v_period_start
            and tr.status = 'entregado'
        ),
        0
      )::numeric as orders_volume_usd_period,
      count(*) filter (
        where tr.created_at >= v_period_start
          and tr.status not in ('entregado', 'rechazado')
      )::bigint as orders_in_progress_period
    from profiles_scope ps
    left join public.transaction_requests tr on (
      (ps.role = 'aliado' and tr.aliado_id = ps.id)
      or (ps.role = 'importador' and tr.importador_id = ps.id)
    )
    group by ps.id
  )
  select
    ps.id,
    ps.business_name,
    ps.rif,
    ps.role,
    ps.estado,
    ps.ciudad,
    coalesce(ls.login_count_period, 0)::bigint,
    coalesce(ls.login_count_today, 0)::bigint,
    coalesce(os.orders_count_period, 0)::bigint,
    coalesce(os.orders_delivered_period, 0)::bigint,
    coalesce(os.orders_volume_usd_period, 0)::numeric,
    coalesce(os.orders_in_progress_period, 0)::bigint,
    ls.last_login_at
  from profiles_scope ps
  left join login_stats ls on ls.user_id = ps.id
  left join order_stats os on os.profile_id = ps.id
  order by
    coalesce(ls.login_count_period, 0) desc,
    coalesce(os.orders_count_period, 0) desc,
    ps.business_name nulls last;
end;
$$;

grant execute on function public.list_admin_user_activity_monitoring (text, text)
  to authenticated;

comment on function public.list_admin_user_activity_monitoring (text, text) is
  'Admin: ingresos y pedidos por aliado/importador (periodo día o semana, TZ Caracas).';
