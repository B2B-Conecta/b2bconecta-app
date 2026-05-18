-- Minuta #7 — Bloque C1: comisión variable, devengo al «Recibido», corte semanal por proveedor.

-- ---------------------------------------------------------------------------
-- 1) Configuración y tasa por importador
-- ---------------------------------------------------------------------------
create table if not exists public.platform_settings (
  key text not null primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.platform_settings (key, value)
values ('default_commission_rate', '0.05'::jsonb)
on conflict (key) do nothing;

alter table public.profiles
  add column if not exists commission_rate_pct numeric(8, 6)
    check (
      commission_rate_pct is null
      or (commission_rate_pct >= 0 and commission_rate_pct <= 1)
    );

comment on column public.profiles.commission_rate_pct is
  'Tasa MotoLink sobre venta (0.05 = 5 %). NULL usa platform_settings.default_commission_rate.';

-- ---------------------------------------------------------------------------
-- 2) Cortes de cuenta semanales por importador
-- ---------------------------------------------------------------------------
create table if not exists public.commission_settlements (
  id uuid not null default gen_random_uuid () primary key,
  importador_id uuid not null references public.profiles (id) on delete restrict,
  period_start date not null,
  period_end date not null,
  total_commission_usd numeric(14, 4) not null default 0
    check (total_commission_usd >= 0),
  line_count integer not null default 0 check (line_count >= 0),
  status text not null default 'borrador'
    check (status = any (array['borrador'::text, 'emitido'::text, 'pagado'::text, 'anulado'::text])),
  invoice_reference text,
  issued_at timestamptz,
  paid_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles (id),
  constraint commission_settlements_period_chk check (period_end >= period_start),
  constraint commission_settlements_importador_week_uniq unique (importador_id, period_start, period_end)
);

create index commission_settlements_importador_idx
  on public.commission_settlements (importador_id, period_start desc);

create index commission_settlements_status_idx
  on public.commission_settlements (status, period_start desc);

-- ---------------------------------------------------------------------------
-- 3) Pedidos: snapshot de tasa, devengo y vínculo al corte
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  add column if not exists commission_rate_snapshot numeric(8, 6);

alter table public.transaction_requests
  add column if not exists comision_devengada_usd numeric(14, 4);

alter table public.transaction_requests
  add column if not exists comision_devengada_at timestamptz;

alter table public.transaction_requests
  add column if not exists commission_settlement_id uuid references public.commission_settlements (id);

create index if not exists transaction_requests_commission_settlement_idx
  on public.transaction_requests (commission_settlement_id)
  where commission_settlement_id is not null;

create index if not exists transaction_requests_comision_devengada_idx
  on public.transaction_requests (comision_devengada_at desc)
  where comision_devengada_at is not null;

-- Migrar filas existentes antes de quitar la columna generada.
update public.transaction_requests tr
set commission_rate_snapshot = 0.05
where tr.commission_rate_snapshot is null;

update public.transaction_requests tr
set
  comision_devengada_usd = round(
    coalesce(
      tr.comision_motoconecta,
      tr.precio_total_usd * coalesce(tr.commission_rate_snapshot, 0.05)
    )::numeric,
    4
  ),
  comision_devengada_at = coalesce(tr.updated_at, tr.created_at)
where tr.status = 'entregado'::text
  and tr.comision_devengada_at is null;

alter table public.transaction_requests
  drop column if exists comision_motoconecta;

alter table public.transaction_requests
  alter column commission_rate_snapshot set default 0.05;

alter table public.transaction_requests
  alter column commission_rate_snapshot set not null;

comment on column public.transaction_requests.commission_rate_snapshot is
  'Tasa MotoLink al confirmar el carrito (fracción; 0.05 = 5 %).';

comment on column public.transaction_requests.comision_devengada_usd is
  'Comisión devengada al marcar Recibido; base del corte semanal.';

-- ---------------------------------------------------------------------------
-- 4) Helpers de tasa y autorización admin
-- ---------------------------------------------------------------------------
create or replace function public.motoconecta_default_commission_rate ()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select (ps.value #>> '{}')::numeric
      from public.platform_settings ps
      where ps.key = 'default_commission_rate'
    ),
    0.05::numeric
  );
$$;

create or replace function public.motoconecta_commission_rate_for_importador (p_importador_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.commission_rate_pct
      from public.profiles p
      where p.id = p_importador_id
        and p.role = 'importador'
    ),
    public.motoconecta_default_commission_rate ()
  );
$$;

create or replace function public._assert_administrador ()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.jwt () ->> 'role', '') = 'service_role'
     or coalesce(
       current_setting('request.jwt.claim.role', true),
       ''
     ) = 'service_role' then
    return;
  end if;
  if auth.uid () is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores' using errcode = '42501';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5) Devengo automático al pasar a entregado (Recibido)
-- ---------------------------------------------------------------------------
create or replace function public.tr_transaction_requests_accrue_commission ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rate numeric;
begin
  if tg_op = 'UPDATE'
     and new.status = 'entregado'::text
     and old.status is distinct from 'entregado'::text then
    v_rate := coalesce(new.commission_rate_snapshot, public.motoconecta_default_commission_rate ());
    if new.comision_devengada_at is null then
      new.comision_devengada_usd := round((new.precio_total_usd * v_rate)::numeric, 4);
      new.comision_devengada_at := now ();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_tr_accrue_commission on public.transaction_requests;

create trigger tr_tr_accrue_commission
before update on public.transaction_requests
for each row
execute function public.tr_transaction_requests_accrue_commission ();

-- ---------------------------------------------------------------------------
-- 6) Checkout: snapshot de tasa por línea
-- ---------------------------------------------------------------------------
create or replace function public.aliado_checkout_multi_importador (
  p_lines jsonb,
  p_destino_entrega_usa_perfil boolean,
  p_destino_entrega_texto text default null,
  p_destino_entrega_maps_url text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_rif text;
  v_estado text;
  v_ciudad text;
  v_direccion text;
  v_fiscal_maps text;
  v_pce integer;
  v_kyc text;
  v_psm boolean;
  v_cl numeric;
  v_cca numeric;
  v_fase_contado boolean;
  v_open_slots bigint;
  v_exposure numeric;
  v_sum_new numeric := 0;
  rec record;
  v_owner uuid;
  v_price numeric;
  v_stock integer;
  v_active boolean;
  v_unit numeric;
  v_line_total numeric;
  v_discount jsonb;
  v_comm_rate numeric;
  v_tol constant numeric := 0.01;
  c_fee constant numeric := 0.10;
  c_desc_contado constant numeric := 0.05;
  c_entregas_req constant int := 3;
  v_group_id uuid := gen_random_uuid ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  if p_lines is null or jsonb_typeof (p_lines) <> 'array' or jsonb_array_length (p_lines) = 0 then
    raise exception 'El carrito está vacío';
  end if;

  select
    p.role,
    nullif(trim(p.rif), ''),
    nullif(trim(p.estado), ''),
    nullif(trim(p.ciudad), ''),
    nullif(trim(p.direccion), ''),
    nullif(trim(p.fiscal_maps_url), ''),
    coalesce(p.primeros_pedidos_contado_entregados, 0),
    nullif(lower(trim(p.kyc_status)), ''),
    coalesce(p.pedidos_suspendidos_morosidad, false),
    coalesce(p.credit_limit, 0::numeric),
    coalesce(p.credito_consumido_acumulado, 0::numeric)
  into
    v_role, v_rif, v_estado, v_ciudad, v_direccion, v_fiscal_maps,
    v_pce, v_kyc, v_psm, v_cl, v_cca
  from public.profiles p
  where p.id = v_uid;

  if v_role is null then
    raise exception 'Perfil no encontrado';
  end if;
  if v_role <> 'aliado' then
    raise exception 'Solo los aliados pueden confirmar el carrito';
  end if;
  if v_psm then
    raise exception
      'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad.';
  end if;
  if v_kyc is not null and v_kyc = 'rechazado' then
    raise exception
      'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.';
  end if;
  if v_rif is null then
    raise exception 'Registre su RIF comercial en Mi perfil para solicitar pedidos.';
  end if;
  if v_estado is null or v_ciudad is null or v_direccion is null then
    raise exception
      'Registre estado, ciudad y dirección fiscal en Mi perfil para poder solicitar pedidos.';
  end if;

  if p_destino_entrega_usa_perfil then
    if v_fiscal_maps is null then
      raise exception
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal.';
    end if;
  else
    if p_destino_entrega_texto is null
       or length(trim(p_destino_entrega_texto)) = 0 then
      raise exception 'Indique la dirección de entrega cuando el destino no es el del perfil.';
    end if;
    if p_destino_entrega_maps_url is null
       or p_destino_entrega_maps_url !~* '^https?://' then
      raise exception
        'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.';
    end if;
  end if;

  v_fase_contado := v_pce < c_entregas_req;

  select count(*)::bigint
    into v_open_slots
  from (
    select distinct coalesce(tr.checkout_group_id, tr.id) as slot_key
    from public.transaction_requests tr
    where tr.aliado_id = v_uid
      and tr.status <> all (array['entregado'::text, 'rechazado'::text])
  ) s;

  if v_fase_contado and v_open_slots >= 1 then
    raise exception
      'En los primeros %s pedidos en contado solo puede tener un pedido activo a la vez.',
      c_entregas_req;
  end if;

  for rec in
    with parsed as (
      select
        (elem->>'product_id')::uuid as product_id,
        (elem->>'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    if rec.cantidad is null or rec.cantidad < 1 then
      raise exception 'Cantidad inválida en el carrito';
    end if;

    select
      pr.owner_id,
      pr.price_usd,
      pr.stock,
      pr.is_active
    into v_owner, v_price, v_stock, v_active
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;
    if not v_active then
      raise exception
        'El producto % no está disponible en el catálogo.',
        rec.product_id;
    end if;
    if v_stock < rec.cantidad then
      raise exception
        'Stock insuficiente: hay %s unidad(es) disponible(s) para una línea del carrito.',
        v_stock;
    end if;

    v_unit := v_price * (1 + c_fee);
    if v_fase_contado then
      v_unit := v_unit * (1 - c_desc_contado);
    end if;

    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_sum_new := v_sum_new + v_line_total;
  end loop;

  if v_cl > v_tol then
    v_exposure := public.aliado_effective_open_exposure (v_uid);
    if v_exposure + v_cca + v_sum_new > v_cl + v_tol then
      raise exception
        'Este pedido supera su límite de crédito autorizado. Reduzca el carrito o consulte con MotoLink.';
    end if;
  end if;

  for rec in
    with parsed as (
      select
        (elem->>'product_id')::uuid as product_id,
        (elem->>'cantidad')::integer as cantidad
      from jsonb_array_elements (p_lines) as t (elem)
    ),
    agg as (
      select product_id, sum(cantidad)::integer as cantidad
      from parsed
      group by product_id
    )
    select * from agg
  loop
    select
      pr.owner_id,
      pr.price_usd,
      pr.stock,
      pr.discount_rules
    into v_owner, v_price, v_stock, v_discount
    from public.products pr
    where pr.id = rec.product_id
    for update;

    if v_owner is null then
      raise exception
        'Producto no encontrado o sin importador asignado (id: %).',
        rec.product_id;
    end if;

    v_unit := v_price * (1 + c_fee);
    if v_fase_contado then
      v_unit := v_unit * (1 - c_desc_contado);
    end if;
    v_line_total := round((v_unit * rec.cantidad)::numeric, 4);
    v_comm_rate := public.motoconecta_commission_rate_for_importador (v_owner);

    insert into public.transaction_requests (
      aliado_id,
      importador_id,
      product_id,
      status,
      cantidad,
      precio_total_usd,
      destino_entrega_usa_perfil,
      destino_entrega_texto,
      destino_entrega_maps_url,
      checkout_group_id,
      discount_rules,
      commission_rate_snapshot
    )
    values (
      v_uid,
      v_owner,
      rec.product_id,
      'pendiente',
      rec.cantidad,
      v_line_total,
      p_destino_entrega_usa_perfil,
      nullif(trim(p_destino_entrega_texto), ''),
      nullif(trim(p_destino_entrega_maps_url), ''),
      v_group_id,
      v_discount,
      v_comm_rate
    );

    update public.products
    set stock = stock - rec.cantidad
    where id = rec.product_id;
  end loop;

  return v_group_id::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Generar cortes semanales (líneas devengadas sin corte previo)
-- ---------------------------------------------------------------------------
create or replace function public.admin_generate_commission_settlements_week (
  p_week_start date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week_start date;
  v_week_end date;
  v_imp uuid;
  v_settlement_id uuid;
  v_total numeric;
  v_cnt int;
  v_created int := 0;
  v_result jsonb := '[]'::jsonb;
begin
  perform public._assert_administrador ();

  v_week_start := coalesce(
    p_week_start,
    (date_trunc('week', (current_date - interval '7 days')::timestamp))::date
  );
  v_week_end := v_week_start + 6;

  for v_imp in
    select distinct tr.importador_id
    from public.transaction_requests tr
    where tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.comision_devengada_usd > 0
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz
  loop
    if exists (
      select 1
      from public.commission_settlements cs
      where cs.importador_id = v_imp
        and cs.period_start = v_week_start
        and cs.period_end = v_week_end
        and cs.status <> 'anulado'::text
    ) then
      continue;
    end if;

    select
      coalesce(sum(tr.comision_devengada_usd), 0),
      count(*)::int
    into v_total, v_cnt
    from public.transaction_requests tr
    where tr.importador_id = v_imp
      and tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

    if v_cnt < 1 then
      continue;
    end if;

    insert into public.commission_settlements (
      importador_id,
      period_start,
      period_end,
      total_commission_usd,
      line_count,
      status,
      created_by
    )
    values (
      v_imp,
      v_week_start,
      v_week_end,
      v_total,
      v_cnt,
      'borrador',
      auth.uid ()
    )
    returning id into v_settlement_id;

    update public.transaction_requests tr
    set commission_settlement_id = v_settlement_id
    where tr.importador_id = v_imp
      and tr.status = 'entregado'::text
      and tr.comision_devengada_at is not null
      and tr.commission_settlement_id is null
      and tr.comision_devengada_at >= v_week_start::timestamptz
      and tr.comision_devengada_at < (v_week_end + 1)::timestamptz;

    v_created := v_created + 1;
    v_result := v_result || jsonb_build_object(
      'settlement_id', v_settlement_id,
      'importador_id', v_imp,
      'line_count', v_cnt,
      'total_commission_usd', v_total
    );
  end loop;

  return jsonb_build_object(
    'week_start', v_week_start,
    'week_end', v_week_end,
    'created_count', v_created,
    'settlements', v_result
  );
end;
$$;

create or replace function public.run_weekly_commission_settlements_auto ()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.admin_generate_commission_settlements_week (null);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8) Emitir factura MotoLink y marcar cobro
-- ---------------------------------------------------------------------------
create or replace function public.admin_issue_commission_settlement (
  p_settlement_id uuid,
  p_invoice_reference text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  if p_invoice_reference is null or length(trim(p_invoice_reference)) = 0 then
    raise exception 'Indique el número o referencia de la factura MotoLink.';
  end if;

  update public.commission_settlements cs
  set
    status = 'emitido',
    invoice_reference = trim(p_invoice_reference),
    issued_at = now (),
    notes = coalesce(cs.notes, '')
  where cs.id = p_settlement_id
    and cs.status = 'borrador';

  if not found then
    raise exception 'Corte no encontrado o ya fue emitido/anulado.';
  end if;
end;
$$;

create or replace function public.admin_mark_commission_settlement_paid (p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  update public.commission_settlements cs
  set
    status = 'pagado',
    paid_at = now ()
  where cs.id = p_settlement_id
    and cs.status = 'emitido';

  if not found then
    raise exception 'Solo se puede marcar pagado un corte en estado emitido.';
  end if;
end;
$$;

create or replace function public.admin_cancel_commission_settlement (p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  update public.transaction_requests tr
  set commission_settlement_id = null
  where tr.commission_settlement_id = p_settlement_id;

  update public.commission_settlements cs
  set status = 'anulado'
  where cs.id = p_settlement_id
    and cs.status = 'borrador';

  if not found then
    raise exception 'Solo se puede anular un corte en borrador.';
  end if;
end;
$$;

create or replace function public.admin_set_default_commission_rate (p_rate numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();
  if p_rate is null or p_rate < 0 or p_rate > 1 then
    raise exception 'La tasa debe estar entre 0 y 1 (ej. 0.05 = 5 %%).';
  end if;
  insert into public.platform_settings (key, value, updated_at)
  values ('default_commission_rate', to_jsonb (p_rate), now ())
  on conflict (key) do update
  set value = excluded.value, updated_at = now ();
end;
$$;

create or replace function public.admin_set_importador_commission_rate (
  p_importador_id uuid,
  p_rate numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();
  if p_rate is not null and (p_rate < 0 or p_rate > 1) then
    raise exception 'La tasa debe estar entre 0 y 1, o NULL para usar la tasa global.';
  end if;
  update public.profiles p
  set commission_rate_pct = p_rate
  where p.id = p_importador_id
    and p.role = 'importador';
  if not found then
    raise exception 'Importador no encontrado.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9) RLS
-- ---------------------------------------------------------------------------
alter table public.platform_settings enable row level security;
alter table public.commission_settlements enable row level security;

create policy platform_settings_select_admin
on public.platform_settings
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

create policy commission_settlements_select_admin
on public.commission_settlements
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

create policy commission_settlements_select_own_importador
on public.commission_settlements
for select
to authenticated
using (importador_id = auth.uid ());

-- ---------------------------------------------------------------------------
-- 10) Grants
-- ---------------------------------------------------------------------------
grant execute on function public.motoconecta_default_commission_rate () to authenticated;
grant execute on function public.motoconecta_commission_rate_for_importador (uuid) to authenticated;

grant execute on function public.admin_generate_commission_settlements_week (date) to authenticated;
grant execute on function public.admin_issue_commission_settlement (uuid, text) to authenticated;
grant execute on function public.admin_mark_commission_settlement_paid (uuid) to authenticated;
grant execute on function public.admin_cancel_commission_settlement (uuid) to authenticated;
grant execute on function public.admin_set_default_commission_rate (numeric) to authenticated;
grant execute on function public.admin_set_importador_commission_rate (uuid, numeric) to authenticated;

grant execute on function public.run_weekly_commission_settlements_auto () to service_role;
