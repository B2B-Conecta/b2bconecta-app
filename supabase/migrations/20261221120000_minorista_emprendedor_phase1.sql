-- Fase 1: Minorista-Emprendedor
-- Campos de plazo/estado, sello admin interno, RPC de alta y bienvenida.

-- ---------------------------------------------------------------------------
-- 1) Columnas en profiles
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists retailer_tier text not null default 'standard',
  add column if not exists is_entrepreneur_badge boolean not null default false,
  add column if not exists entrepreneur_registered_at timestamptz,
  add column if not exists first_purchase_deadline timestamptz,
  add column if not exists kyc_completion_deadline timestamptz,
  add column if not exists entrepreneur_status text,
  add column if not exists has_seen_entrepreneur_welcome boolean not null default false,
  add column if not exists cedula text;

alter table public.profiles
  drop constraint if exists profiles_retailer_tier_check;

alter table public.profiles
  add constraint profiles_retailer_tier_check
  check (retailer_tier = any (array['standard'::text, 'entrepreneur'::text]));

alter table public.profiles
  drop constraint if exists profiles_entrepreneur_status_check;

alter table public.profiles
  add constraint profiles_entrepreneur_status_check
  check (
    entrepreneur_status is null
    or entrepreneur_status = any (
      array[
        'active_trial'::text,
        'pending_first_purchase_alert'::text,
        'kyc_in_progress'::text,
        'expired_locked'::text,
        'reactivation_requested'::text,
        'verified_standard'::text
      ]
    )
  );

comment on column public.profiles.retailer_tier is
  'standard = flujo formal; entrepreneur = minorista-emprendedor.';
comment on column public.profiles.is_entrepreneur_badge is
  'Sello interno admin. No exponer a mayoristas ni al propio minorista en UI pública.';
comment on column public.profiles.first_purchase_deadline is
  'Fin de ventana de 5 días hábiles para primera compra.';
comment on column public.profiles.kyc_completion_deadline is
  'Fin de ventana de 8 semanas (56 días) para expediente KYC restante.';
comment on column public.profiles.cedula is
  'Cédula de identidad (alta emprendedor / identificación personal).';

-- ---------------------------------------------------------------------------
-- 2) Helpers de plazos
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
    v_dow := extract(isodow from v_cursor)::integer; -- 1=lun … 7=dom
    if v_dow between 1 and 5 then
      v_left := v_left - 1;
    end if;
  end loop;
  return ((v_cursor::timestamp + time '23:59:59') at time zone 'America/Caracas');
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
    public.add_business_days(p_registered_at, 5),
    p_registered_at + interval '56 days';
$$;

-- ---------------------------------------------------------------------------
-- 3) Doc types KYC (alias lógico; valores ya usados en app)
-- ---------------------------------------------------------------------------
-- registro_mercantil, referencia_bancaria_1, referencia_bancaria_2,
-- referencia_comercial (= Registro comercial / carta de crédito).
-- Alias canónico adicional para futuros inserts:
comment on table public.profile_documents is
  'KYC docs. Emprendedor (8 semanas): registro_mercantil, referencia_bancaria_1/2, '
  'referencia_comercial (alias registro_comercial_carta_credito en app).';

-- ---------------------------------------------------------------------------
-- 4) Proteger sello admin (no updateable por cliente)
-- ---------------------------------------------------------------------------
create or replace function public._profiles_entrepreneur_guard ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ok boolean := false;
begin
  begin
    v_ok := coalesce(current_setting('b2b.profile_privilege_ok', true), '') = '1';
  exception when others then
    v_ok := false;
  end;

  if tg_op = 'UPDATE' and not v_ok then
    -- Clientes no pueden auto-asignarse el sello ni manipular deadlines/estado.
    new.is_entrepreneur_badge := old.is_entrepreneur_badge;
    if old.retailer_tier = 'entrepreneur' then
      new.retailer_tier := old.retailer_tier;
      new.entrepreneur_registered_at := old.entrepreneur_registered_at;
      new.first_purchase_deadline := old.first_purchase_deadline;
      new.kyc_completion_deadline := old.kyc_completion_deadline;
      -- Estado / welcome: solo vía RPC security definer (abajo).
      if new.entrepreneur_status is distinct from old.entrepreneur_status then
        new.entrepreneur_status := old.entrepreneur_status;
      end if;
      if new.has_seen_entrepreneur_welcome is distinct from old.has_seen_entrepreneur_welcome
         and new.has_seen_entrepreneur_welcome is not true then
        new.has_seen_entrepreneur_welcome := old.has_seen_entrepreneur_welcome;
      end if;
    elsif new.retailer_tier = 'entrepreneur' then
      -- No permitir convertirse en entrepreneur por update directo.
      new.retailer_tier := old.retailer_tier;
      new.is_entrepreneur_badge := old.is_entrepreneur_badge;
      new.entrepreneur_status := old.entrepreneur_status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_entrepreneur_guard on public.profiles;
create trigger profiles_entrepreneur_guard
before update on public.profiles
for each row
execute function public._profiles_entrepreneur_guard ();

-- ---------------------------------------------------------------------------
-- 5) RPC: completar alta emprendedor (tras Auth signup)
-- ---------------------------------------------------------------------------
create or replace function public.complete_entrepreneur_registration (
  p_phone text,
  p_rif text,
  p_cedula text,
  p_direccion text,
  p_business_name text default null,
  p_terms_version text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_name text;
  v_rif text := nullif(btrim(coalesce(p_rif, '')), '');
  v_cedula text := nullif(btrim(coalesce(p_cedula, '')), '');
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_dir text := nullif(btrim(coalesce(p_direccion, '')), '');
  v_terms text := nullif(btrim(coalesce(p_terms_version, '')), '');
  v_fp timestamptz;
  v_kyc timestamptz;
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if v_rif is null or v_cedula is null or v_phone is null or v_dir is null then
    raise exception 'missing_required_fields';
  end if;

  v_name := nullif(btrim(coalesce(p_business_name, '')), '');
  if v_name is null then
    v_name := 'Emprendedor ' || v_cedula;
  end if;

  perform set_config('b2b.profile_privilege_ok', '1', true);

  select d.first_purchase_deadline, d.kyc_completion_deadline
    into v_fp, v_kyc
  from public.entrepreneur_deadlines_from(v_now) as d;

  insert into public.profiles as p (
    id,
    business_name,
    rif,
    cedula,
    phone,
    direccion,
    role,
    account_access_status,
    retailer_tier,
    is_entrepreneur_badge,
    entrepreneur_registered_at,
    first_purchase_deadline,
    kyc_completion_deadline,
    entrepreneur_status,
    has_seen_entrepreneur_welcome,
    kyc_status,
    terms_accepted_at,
    terms_version
  ) values (
    v_uid,
    v_name,
    v_rif,
    v_cedula,
    v_phone,
    v_dir,
    'aliado',
    'active',
    'entrepreneur',
    true,
    v_now,
    v_fp,
    v_kyc,
    'active_trial',
    false,
    'pendiente',
    case when v_terms is null then null else v_now end,
    v_terms
  )
  on conflict (id) do update
  set
    business_name = excluded.business_name,
    rif = excluded.rif,
    cedula = excluded.cedula,
    phone = excluded.phone,
    direccion = excluded.direccion,
    role = 'aliado',
    account_access_status = 'active',
    retailer_tier = 'entrepreneur',
    is_entrepreneur_badge = true,
    entrepreneur_registered_at = coalesce(p.entrepreneur_registered_at, excluded.entrepreneur_registered_at),
    first_purchase_deadline = coalesce(p.first_purchase_deadline, excluded.first_purchase_deadline),
    kyc_completion_deadline = coalesce(p.kyc_completion_deadline, excluded.kyc_completion_deadline),
    entrepreneur_status = coalesce(p.entrepreneur_status, excluded.entrepreneur_status),
    kyc_status = coalesce(nullif(btrim(p.kyc_status), ''), 'pendiente'),
    terms_accepted_at = coalesce(p.terms_accepted_at, excluded.terms_accepted_at),
    terms_version = coalesce(nullif(btrim(p.terms_version), ''), excluded.terms_version)
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.complete_entrepreneur_registration (
  text, text, text, text, text, text
) from public;
grant execute on function public.complete_entrepreneur_registration (
  text, text, text, text, text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) RPC: marcar bienvenida vista
-- ---------------------------------------------------------------------------
create or replace function public.mark_entrepreneur_welcome_seen ()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  perform set_config('b2b.profile_privilege_ok', '1', true);
  update public.profiles
  set has_seen_entrepreneur_welcome = true
  where id = v_uid
    and retailer_tier = 'entrepreneur';
end;
$$;

revoke all on function public.mark_entrepreneur_welcome_seen () from public;
grant execute on function public.mark_entrepreneur_welcome_seen () to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Proyección pública: no exponer is_entrepreneur_badge en storefront RPC
--    (aliado_importer_store_profile ya usa whitelist — sin cambios requeridos).
--    Admin: incluir badge en listados vía owner_list cuando se amplíe en Fase 2.
-- ---------------------------------------------------------------------------
