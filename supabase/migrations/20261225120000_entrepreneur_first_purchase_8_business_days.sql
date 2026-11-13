-- Mecánica plazos primera compra: 8 días hábiles, advertencia al 5.º, bloqueo al 8.º.

-- ---------------------------------------------------------------------------
-- 1) Nuevo estado pending_warning_period
-- ---------------------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_entrepreneur_status_check;

alter table public.profiles
  add constraint profiles_entrepreneur_status_check
  check (
    entrepreneur_status is null
    or entrepreneur_status = any (
      array[
        'active_trial'::text,
        'pending_warning_period'::text,
        'pending_first_purchase_alert'::text, -- legado (se migra abajo)
        'kyc_in_progress'::text,
        'expired_locked'::text,
        'reactivation_requested'::text,
        'verified_standard'::text
      ]
    )
  );

comment on column public.profiles.first_purchase_deadline is
  'Fin de ventana de 8 días hábiles para primera compra (America/Caracas).';

-- ---------------------------------------------------------------------------
-- 2) Helpers días hábiles
-- ---------------------------------------------------------------------------
create or replace function public.add_business_days (
  p_from timestamptz,
  p_days integer
)
returns timestamptz
language plpgsql
immutable
as $$
declare
  v_cursor date := (p_from at time zone 'America/Caracas')::date;
  v_left integer := greatest(coalesce(p_days, 0), 0);
  v_dow integer;
begin
  if v_left = 0 then
    return p_from;
  end if;
  while v_left > 0 loop
    v_cursor := v_cursor + 1;
    v_dow := extract(isodow from v_cursor)::integer;
    if v_dow between 1 and 5 then
      v_left := v_left - 1;
    end if;
  end loop;
  return ((v_cursor::timestamp + time '23:59:59') at time zone 'America/Caracas');
end;
$$;

-- Días hábiles transcurridos desde p_from hasta p_to (incluye día inicial si hábil).
create or replace function public.count_business_days_elapsed (
  p_from timestamptz,
  p_to timestamptz default now()
)
returns integer
language plpgsql
immutable
as $$
declare
  v_start date := (p_from at time zone 'America/Caracas')::date;
  v_end date := (p_to at time zone 'America/Caracas')::date;
  v_cursor date;
  v_count integer := 0;
  v_dow integer;
begin
  if v_end < v_start then
    return 0;
  end if;
  v_cursor := v_start;
  while v_cursor <= v_end loop
    v_dow := extract(isodow from v_cursor)::integer;
    if v_dow between 1 and 5 then
      v_count := v_count + 1;
    end if;
    v_cursor := v_cursor + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.entrepreneur_deadlines_from (
  p_registered_at timestamptz
)
returns table (
  first_purchase_deadline timestamptz,
  kyc_completion_deadline timestamptz
)
language sql
immutable
as $$
  select
    public.add_business_days(p_registered_at, 8),
    p_registered_at + interval '56 days';
$$;

create or replace function public.entrepreneur_first_purchase_warning_at (
  p_registered_at timestamptz
)
returns timestamptz
language sql
immutable
as $$
  select public.add_business_days(p_registered_at, 5);
$$;

-- ---------------------------------------------------------------------------
-- 3) Backfill plazos y estados legado
-- ---------------------------------------------------------------------------
update public.profiles p
set first_purchase_deadline = public.add_business_days(
  coalesce(p.entrepreneur_registered_at, p.created_at, now()),
  8
)
where p.retailer_tier = 'entrepreneur'
  and p.entrepreneur_status in (
    'active_trial',
    'pending_first_purchase_alert',
    'pending_warning_period'
  );

-- Sin compra y ya venció el plazo de 8 → bloqueo
update public.profiles p
set entrepreneur_status = 'expired_locked'
where p.retailer_tier = 'entrepreneur'
  and p.entrepreneur_status in (
    'active_trial',
    'pending_first_purchase_alert',
    'pending_warning_period'
  )
  and p.first_purchase_deadline is not null
  and p.first_purchase_deadline < now()
  and not exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = p.id
      and coalesce(tr.pago_estado_revision, '') = 'aprobado'
  );

-- En ventana de advertencia (pasó día 5, no el 8)
update public.profiles p
set entrepreneur_status = 'pending_warning_period'
where p.retailer_tier = 'entrepreneur'
  and p.entrepreneur_status in ('active_trial', 'pending_first_purchase_alert')
  and coalesce(p.entrepreneur_registered_at, p.created_at) is not null
  and public.entrepreneur_first_purchase_warning_at(
        coalesce(p.entrepreneur_registered_at, p.created_at)
      ) < now()
  and (p.first_purchase_deadline is null or p.first_purchase_deadline >= now())
  and not exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = p.id
      and coalesce(tr.pago_estado_revision, '') = 'aprobado'
  );

-- ---------------------------------------------------------------------------
-- 4) Jobs: advertencia (5) y bloqueo primera compra (8)
-- ---------------------------------------------------------------------------
create or replace function public.entrepreneur_mark_first_purchase_warnings ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_count integer := 0;
  v_registered timestamptz;
begin
  perform set_config('b2b.profile_privilege_ok', '1', true);

  for v_row in
    select p.id, p.business_name, p.entrepreneur_registered_at, p.created_at
    from public.profiles p
    where p.retailer_tier = 'entrepreneur'
      and p.entrepreneur_status = 'active_trial'
      and coalesce(p.entrepreneur_registered_at, p.created_at) is not null
      and public.entrepreneur_first_purchase_warning_at(
            coalesce(p.entrepreneur_registered_at, p.created_at)
          ) < now()
      and (p.first_purchase_deadline is null or p.first_purchase_deadline >= now())
      and not exists (
        select 1
        from public.transaction_requests tr
        where tr.aliado_id = p.id
          and coalesce(tr.pago_estado_revision, '') = 'aprobado'
      )
  loop
    update public.profiles
    set entrepreneur_status = 'pending_warning_period'
    where id = v_row.id;

    perform public.mc_insert_notification(
      v_row.id,
      'Quedan 3 días hábiles',
      'Te quedan 3 días hábiles para realizar tu primera compra. '
        || 'De lo contrario, tu cuenta será bloqueada temporalmente.',
      'entrepreneur',
      v_row.id::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor en cuenta regresiva',
      coalesce(nullif(btrim(v_row.business_name), ''), 'Minorista')
        || ' entró en advertencia (día 5/8 hábiles) sin primera compra.',
      v_row.id::text
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.entrepreneur_mark_first_purchase_warnings () from public;
grant execute on function public.entrepreneur_mark_first_purchase_warnings () to service_role;

-- Reemplaza el job antiguo: al vencer los 8 días → expired_locked
create or replace function public.entrepreneur_mark_first_purchase_alerts ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_count integer := 0;
begin
  -- Primero aplicar advertencias del día 5
  perform public.entrepreneur_mark_first_purchase_warnings();

  perform set_config('b2b.profile_privilege_ok', '1', true);

  for v_row in
    select p.id, p.business_name, p.first_purchase_deadline
    from public.profiles p
    where p.retailer_tier = 'entrepreneur'
      and p.entrepreneur_status in (
        'active_trial',
        'pending_warning_period',
        'pending_first_purchase_alert'
      )
      and p.first_purchase_deadline is not null
      and p.first_purchase_deadline < now()
      and not exists (
        select 1
        from public.transaction_requests tr
        where tr.aliado_id = p.id
          and coalesce(tr.pago_estado_revision, '') = 'aprobado'
      )
  loop
    update public.profiles
    set entrepreneur_status = 'expired_locked'
    where id = v_row.id;

    perform public.mc_insert_notification(
      v_row.id,
      'Cuenta pausada temporalmente',
      'Se agotaron los 8 días hábiles sin una primera compra. '
        || 'Contacta con administración para reactivar tu acceso.',
      'entrepreneur',
      v_row.id::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor bloqueado (sin primera compra)',
      coalesce(nullif(btrim(v_row.business_name), ''), 'Minorista')
        || ' agotó los 8 días hábiles sin compra confirmada.',
      v_row.id::text
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Sync al login (advertencia + bloqueo primera compra + KYC)
-- ---------------------------------------------------------------------------
create or replace function public.sync_my_entrepreneur_expiry ()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_prof public.profiles%rowtype;
  v_registered timestamptz;
  v_has_paid boolean;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;

  select * into v_prof from public.profiles where id = v_uid;
  if not found then
    return null;
  end if;

  if coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    return v_prof.entrepreneur_status;
  end if;

  select exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = v_uid
      and coalesce(tr.pago_estado_revision, '') = 'aprobado'
  ) into v_has_paid;

  v_registered := coalesce(v_prof.entrepreneur_registered_at, v_prof.created_at);

  perform set_config('b2b.profile_privilege_ok', '1', true);

  -- Primera compra: bloqueo a los 8 días hábiles
  if not v_has_paid
     and coalesce(v_prof.entrepreneur_status, '') in (
       'active_trial',
       'pending_warning_period',
       'pending_first_purchase_alert'
     )
     and v_prof.first_purchase_deadline is not null
     and v_prof.first_purchase_deadline < now()
  then
    update public.profiles
    set entrepreneur_status = 'expired_locked'
    where id = v_uid;

    perform public.mc_insert_notification(
      v_uid,
      'Cuenta pausada temporalmente',
      'Se agotaron los 8 días hábiles sin una primera compra. '
        || 'Contacta con administración para reactivar tu acceso.',
      'entrepreneur',
      v_uid::text
    );

    return 'expired_locked';
  end if;

  -- Primera compra: advertencia al día 5
  if not v_has_paid
     and coalesce(v_prof.entrepreneur_status, '') = 'active_trial'
     and v_registered is not null
     and public.entrepreneur_first_purchase_warning_at(v_registered) < now()
     and (v_prof.first_purchase_deadline is null
          or v_prof.first_purchase_deadline >= now())
  then
    update public.profiles
    set entrepreneur_status = 'pending_warning_period'
    where id = v_uid;

    perform public.mc_insert_notification(
      v_uid,
      'Quedan 3 días hábiles',
      'Te quedan 3 días hábiles para realizar tu primera compra. '
        || 'De lo contrario, tu cuenta será bloqueada temporalmente.',
      'entrepreneur',
      v_uid::text
    );

    perform public._notify_admins_entrepreneur(
      'Emprendedor en cuenta regresiva',
      coalesce(nullif(btrim(v_prof.business_name), ''), 'Minorista')
        || ' entró en advertencia (día 5/8 hábiles) sin primera compra.',
      v_uid::text
    );

    return 'pending_warning_period';
  end if;

  -- KYC 8 semanas
  if coalesce(v_prof.entrepreneur_status, '') = 'kyc_in_progress'
     and v_prof.kyc_completion_deadline is not null
     and v_prof.kyc_completion_deadline < now()
     and not public.entrepreneur_deferred_docs_complete(v_uid)
  then
    update public.profiles
    set entrepreneur_status = 'expired_locked'
    where id = v_uid
      and entrepreneur_status = 'kyc_in_progress';

    perform public.mc_insert_notification(
      v_uid,
      'Plazo de documentación vencido',
      'Tu expediente de 8 semanas venció. Puedes seguir subiendo documentos '
        || 'y solicitar reactivación con un asesor.',
      'entrepreneur',
      v_uid::text
    );

    return 'expired_locked';
  end if;

  return v_prof.entrepreneur_status;
end;
$$;

revoke all on function public.sync_my_entrepreneur_expiry () from public;
grant execute on function public.sync_my_entrepreneur_expiry () to authenticated;

-- Primer pago también desbloquea desde pending_warning_period
create or replace function public._entrepreneur_on_first_paid_order ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prof public.profiles%rowtype;
  v_had_paid boolean;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if coalesce(old.pago_estado_revision, '') = 'aprobado' then
    return new;
  end if;
  if coalesce(new.pago_estado_revision, '') <> 'aprobado' then
    return new;
  end if;

  select * into v_prof from public.profiles where id = new.aliado_id;
  if not found then
    return new;
  end if;
  if coalesce(v_prof.retailer_tier, '') <> 'entrepreneur' then
    return new;
  end if;
  if coalesce(v_prof.entrepreneur_status, '') not in (
    'active_trial',
    'pending_warning_period',
    'pending_first_purchase_alert'
  ) then
    return new;
  end if;

  select exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = new.aliado_id
      and tr.id is distinct from new.id
      and coalesce(tr.pago_estado_revision, '') = 'aprobado'
  ) into v_had_paid;

  if v_had_paid then
    return new;
  end if;

  perform set_config('b2b.profile_privilege_ok', '1', true);

  update public.profiles
  set
    entrepreneur_status = 'kyc_in_progress',
    kyc_completion_deadline = coalesce(
      kyc_completion_deadline,
      now() + interval '56 days'
    )
  where id = new.aliado_id;

  perform public.mc_insert_notification(
    new.aliado_id,
    '¡Primera compra confirmada!',
    'Tienes 8 semanas para completar tu expediente comercial '
      || '(Registro Mercantil, 2 referencias bancarias y Registro Comercial / Carta de Crédito).',
    'entrepreneur',
    new.aliado_id::text
  );

  perform public._notify_admins_entrepreneur(
    'Emprendedor: primera compra',
    coalesce(nullif(btrim(v_prof.business_name), ''), 'Minorista')
      || ' confirmó su primera compra. Inicia plazo KYC de 8 semanas.',
    new.aliado_id::text
  );

  return new;
end;
$$;

-- Alertas admin: incluir cuenta regresiva
drop function if exists public.admin_list_entrepreneur_alerts ();

create function public.admin_list_entrepreneur_alerts ()
returns table (
  id uuid,
  business_name text,
  email text,
  phone text,
  entrepreneur_status text,
  first_purchase_deadline timestamptz,
  kyc_completion_deadline timestamptz,
  entrepreneur_registered_at timestamptz,
  created_at timestamptz,
  first_purchase_business_day integer
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
    p.business_name,
    u.email::text,
    p.phone,
    p.entrepreneur_status,
    p.first_purchase_deadline,
    p.kyc_completion_deadline,
    p.entrepreneur_registered_at,
    p.created_at,
    least(
      8,
      greatest(
        1,
        public.count_business_days_elapsed(
          coalesce(p.entrepreneur_registered_at, p.created_at, now()),
          now()
        )
      )
    )::integer as first_purchase_business_day
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.retailer_tier = 'entrepreneur'
    and p.entrepreneur_status in (
      'pending_warning_period',
      'pending_first_purchase_alert',
      'expired_locked',
      'reactivation_requested',
      'active_trial'
    )
    and p.deactivated_at is null
    and (
      p.entrepreneur_status in (
        'pending_warning_period',
        'pending_first_purchase_alert',
        'expired_locked',
        'reactivation_requested'
      )
      or (
        p.entrepreneur_status = 'active_trial'
        and public.count_business_days_elapsed(
              coalesce(p.entrepreneur_registered_at, p.created_at, now()),
              now()
            ) >= 4
      )
    )
  order by
    case p.entrepreneur_status
      when 'reactivation_requested' then 0
      when 'expired_locked' then 1
      when 'pending_warning_period' then 2
      when 'pending_first_purchase_alert' then 2
      else 3
    end,
    p.created_at desc nulls last;
end;
$$;

revoke all on function public.admin_list_entrepreneur_alerts () from public;
grant execute on function public.admin_list_entrepreneur_alerts () to authenticated;

-- owner_list: exponer día hábil actual
drop function if exists public.owner_list_profiles ();

create function public.owner_list_profiles ()
returns table (
  id uuid,
  business_name text,
  rif text,
  role text,
  phone text,
  email text,
  account_access_status text,
  account_review_note text,
  kyc_status text,
  is_owner boolean,
  deactivated_at timestamptz,
  deactivated_by uuid,
  created_at timestamptz,
  estado text,
  ciudad text,
  retailer_tier text,
  entrepreneur_status text,
  first_purchase_deadline timestamptz,
  kyc_completion_deadline timestamptz,
  is_entrepreneur_badge boolean,
  entrepreneur_registered_at timestamptz,
  first_purchase_business_day integer
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
    p.business_name,
    p.rif,
    p.role,
    p.phone,
    u.email::text,
    p.account_access_status,
    p.account_review_note,
    p.kyc_status,
    p.is_owner,
    p.deactivated_at,
    p.deactivated_by,
    p.created_at,
    p.estado,
    p.ciudad,
    coalesce(p.retailer_tier, 'standard') as retailer_tier,
    p.entrepreneur_status,
    p.first_purchase_deadline,
    p.kyc_completion_deadline,
    coalesce(p.is_entrepreneur_badge, false) as is_entrepreneur_badge,
    p.entrepreneur_registered_at,
    case
      when p.retailer_tier = 'entrepreneur'
        and coalesce(p.entrepreneur_registered_at, p.created_at) is not null
      then least(
        8,
        greatest(
          1,
          public.count_business_days_elapsed(
            coalesce(p.entrepreneur_registered_at, p.created_at),
            now()
          )
        )
      )::integer
      else null
    end as first_purchase_business_day
  from public.profiles p
  left join auth.users u on u.id = p.id
  order by
    p.is_owner desc,
    coalesce(p.business_name, u.email, p.rif, p.id::text);
end;
$$;

revoke all on function public.owner_list_profiles () from public;
grant execute on function public.owner_list_profiles () to authenticated;

-- Cron: mismo job diario (ya llama mark_first_purchase_alerts que incluye warning)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('entrepreneur_phase2_daily');
    exception
      when others then null;
    end;
    perform cron.schedule(
      'entrepreneur_phase2_daily',
      '15 8 * * *',
      $cron$
        select public.entrepreneur_mark_first_purchase_alerts();
        select public.entrepreneur_mark_kyc_expired();
      $cron$
    );
  end if;
exception
  when others then
    raise notice 'pg_cron no disponible; jobs via service_role.';
end;
$$;
