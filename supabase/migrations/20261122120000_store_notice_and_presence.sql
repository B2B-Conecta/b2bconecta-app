-- Aviso diario del importador y presencia para el panel admin.
-- No hay organization_id: la empresa única es el RIF de profiles.
-- La presencia se consolida en profiles.last_seen_at (una fila por cuenta).

alter table public.profiles
  add column if not exists daily_store_notice_on date;

alter table public.profiles
  add column if not exists last_seen_at timestamptz;

comment on column public.profiles.daily_store_notice_on is
  'Día (America/Caracas) en que el importador ya vio el aviso de tiendas activas.';

comment on column public.profiles.last_seen_at is
  'Último heartbeat de la cuenta. Varias pestañas o la app móvil actualizan la misma fila.';

create index if not exists profiles_last_seen_at_idx
  on public.profiles (last_seen_at desc)
  where last_seen_at is not null;

-- Tiendas aliadas verificadas, una por RIF. Solo el importador autenticado.
create or replace function public.importer_daily_store_notice ()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
  v_seen date;
  v_today date;
  v_count integer;
begin
  if auth.uid () is null then
    return jsonb_build_object('show', false, 'store_count', null);
  end if;

  select p.role, p.daily_store_notice_on
    into v_role, v_seen
  from public.profiles p
  where p.id = auth.uid ();

  if v_role is distinct from 'importador' then
    return jsonb_build_object('show', false, 'store_count', null);
  end if;

  v_today := (timezone('America/Caracas', now()))::date;

  select count(distinct lower(btrim(p.rif)))
    into v_count
  from public.profiles p
  where p.role = 'aliado'
    and p.kyc_status = 'aprobado'
    and p.account_access_status = 'active'
    and p.deactivated_at is null
    and nullif(btrim(p.rif), '') is not null;

  return jsonb_build_object(
    'show', v_seen is distinct from v_today and coalesce(v_count, 0) > 0,
    'store_count', v_count,
    'seen_on', v_seen
  );
end;
$$;

create or replace function public.ack_importer_daily_store_notice ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    return;
  end if;

  update public.profiles p
  set daily_store_notice_on = (timezone('America/Caracas', now()))::date
  where p.id = auth.uid ()
    and p.role = 'importador';
end;
$$;

-- Un toque por cuenta. Se ignora si ya hubo actividad en los últimos 45 s.
create or replace function public.touch_my_presence ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    return;
  end if;

  update public.profiles p
  set last_seen_at = now()
  where p.id = auth.uid ()
    and (
      p.last_seen_at is null
      or p.last_seen_at < now() - interval '45 seconds'
    );
end;
$$;

-- Solo administrador. En línea = actividad en los últimos 5 minutos.
create or replace function public.list_admin_user_presence ()
returns table (
  profile_id uuid,
  display_name text,
  business_name text,
  role text,
  last_seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  return query
  select
    p.id,
    coalesce(
      nullif(btrim(p.legal_contact_name), ''),
      nullif(btrim(p.business_name), ''),
      'Usuario'
    ) as display_name,
    p.business_name,
    p.role,
    p.last_seen_at
  from public.profiles p
  where p.deactivated_at is null
    and p.role in ('aliado', 'importador', 'administrador')
  order by p.last_seen_at desc nulls last, p.business_name asc
  limit 500;
end;
$$;

revoke all on function public.importer_daily_store_notice () from public;
revoke all on function public.ack_importer_daily_store_notice () from public;
revoke all on function public.touch_my_presence () from public;
revoke all on function public.list_admin_user_presence () from public;

grant execute on function public.importer_daily_store_notice () to authenticated;
grant execute on function public.ack_importer_daily_store_notice () to authenticated;
grant execute on function public.touch_my_presence () to authenticated;
grant execute on function public.list_admin_user_presence () to authenticated;

comment on function public.list_admin_user_presence () is
  'Presencia de cuentas para Reportes / Usuarios. Rechaza aliado e importador vía _assert_administrador.';
