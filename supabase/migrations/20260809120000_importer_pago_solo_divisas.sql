-- Importador: modo solo pagos en divisas (USD). Sin descuento línea USD en productos.

alter table public.profiles
  add column if not exists pago_solo_divisas boolean not null default false;

comment on column public.profiles.pago_solo_divisas is
  'Importador: solo acepta pagos en divisas/USD; no ofrece Pago Móvil ni transferencia en Bs ni % descuento línea USD.';

create or replace function public.motoconecta_pago_metodos_bolivares ()
returns text[]
language sql
immutable
as $$
  select array['pago_movil', 'transferencia']::text[];
$$;

create or replace function public.motoconecta_strip_usd_payment_discount_rules (
  p_rules jsonb
)
returns jsonb
language sql
immutable
as $$
  select case
    when (
      coalesce(p_rules, '{}'::jsonb)
      - 'usd_payment_discount_pct'
      - 'applied_usd_payment_discount_pct'
      - 'applied_pago_metodo'
    ) = '{}'::jsonb then null
    else
      coalesce(p_rules, '{}'::jsonb)
      - 'usd_payment_discount_pct'
      - 'applied_usd_payment_discount_pct'
      - 'applied_pago_metodo'
  end;
$$;

create or replace function public.importador_set_pago_solo_divisas (
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
  v_clean text[];
  v_m text;
  v_instr jsonb;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar pagos en divisas';
  end if;

  if coalesce(p_enabled, false) then
    select coalesce(p.accepted_pago_metodos, public.motoconecta_all_pago_metodos ())
      into v_clean
    from public.profiles p
    where p.id = v_uid;

    v_clean := array(
      select m
      from unnest(v_clean) as m
      where not (m = any (v_bs))
    );

    if cardinality(v_clean) = 0 then
      raise exception
        'Active al menos un método en divisas (Zelle, Binance, USDT o efectivo) antes de deshabilitar pagos en Bs.';
    end if;

    select coalesce(p.pago_metodo_instrucciones, '{}'::jsonb)
      into v_instr
    from public.profiles p
    where p.id = v_uid;

    foreach v_m in array v_bs loop
      v_instr := v_instr - v_m;
    end loop;

    update public.products pr
    set
      discount_rules = public.motoconecta_strip_usd_payment_discount_rules (pr.discount_rules)
    where pr.owner_id = v_uid
      and coalesce((pr.discount_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0;

    update public.profiles
    set
      pago_solo_divisas = true,
      accepted_pago_metodos = v_clean,
      pago_metodo_instrucciones = v_instr
    where id = v_uid;
  else
    update public.profiles
    set pago_solo_divisas = false
    where id = v_uid;
  end if;
end;
$$;

grant execute on function public.importador_set_pago_solo_divisas (boolean) to authenticated;

create or replace function public.importador_set_accepted_pago_metodos (
  p_metodos text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_solo boolean;
  v_clean text[];
  v_m text;
  v_allowed text[] := public.motoconecta_all_pago_metodos ();
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, coalesce(p.pago_solo_divisas, false)
    into v_role, v_solo
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar métodos de pago';
  end if;

  if p_metodos is null or cardinality(p_metodos) = 0 then
    raise exception 'Seleccione al menos un método de pago';
  end if;

  v_clean := array[]::text[];

  foreach v_m in array p_metodos loop
    if trim(v_m) = any (v_allowed) then
      if v_solo and trim(v_m) = any (v_bs) then
        continue;
      end if;
      if not (trim(v_m) = any (v_clean)) then
        v_clean := array_append(v_clean, trim(v_m));
      end if;
    end if;
  end loop;

  if cardinality(v_clean) = 0 then
    raise exception 'Ningún método de pago válido';
  end if;

  update public.profiles
  set accepted_pago_metodos = v_clean
  where id = v_uid;
end;
$$;

create or replace function public.importador_bulk_set_usd_payment_discount (
  p_pct numeric,
  p_scope text default 'con_descuento'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_solo boolean;
  v_scope text := lower(trim(coalesce(p_scope, '')));
  v_count integer;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, coalesce(p.pago_solo_divisas, false)
    into v_role, v_solo
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden actualizar descuentos del catálogo';
  end if;

  if v_solo then
    raise exception
      'Con pagos solo en divisas (USD) no puede configurar descuento línea USD en productos.';
  end if;

  if v_scope not in ('con_descuento', 'todos') then
    raise exception 'Alcance no válido. Use con_descuento o todos.';
  end if;

  if p_pct is null or p_pct < 0 or p_pct >= 100 then
    raise exception 'Indique un porcentaje entre 0 y 100 (0 quita el descuento USD).';
  end if;

  if p_pct = 0 then
    update public.products pr
    set
      discount_rules = (
        select case
          when v_clean = '{}'::jsonb then null
          else v_clean
        end
        from (
          select
            coalesce(pr.discount_rules, '{}'::jsonb)
            - 'usd_payment_discount_pct'
            - 'applied_usd_payment_discount_pct'
            - 'applied_pago_metodo' as v_clean
        ) s
      )
    where pr.owner_id = v_uid
      and (
        v_scope = 'todos'
        or coalesce((pr.discount_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0
      );
  else
    update public.products pr
    set
      discount_rules = (
        coalesce(pr.discount_rules, '{}'::jsonb)
        - 'applied_usd_payment_discount_pct'
        - 'applied_pago_metodo'
      ) || jsonb_build_object('usd_payment_discount_pct', round(p_pct::numeric, 4))
    where pr.owner_id = v_uid
      and (
        v_scope = 'todos'
        or coalesce((pr.discount_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0
      );
  end if;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.aliado_registra_comprobante_pago (
  p_request_id uuid,
  p_metodo text,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_importador uuid;
  v_status text;
  v_pe text;
  v_metodo text;
  v_allowed_global text[] := public.motoconecta_all_pago_metodos ();
  v_accepted text[];
  v_solo_divisas boolean;
  v_cant integer;
  v_base numeric;
  v_total numeric;
  v_unit numeric;
  v_rules jsonb;
  v_rules_out jsonb;
  v_pct numeric;
  v_applied boolean;
  v_comm_rate numeric;
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  v_metodo := lower(trim(p_metodo));

  if v_metodo = '' or not (v_metodo = any (v_allowed_global)) then
    raise exception 'Método de pago no permitido';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    tr.pago_estado_revision,
    tr.cantidad,
    coalesce(tr.precio_base_aliado_total, tr.precio_total_usd),
    tr.discount_rules,
    tr.commission_rate_snapshot
  into
    v_aliado,
    v_importador,
    v_status,
    v_pe,
    v_cant,
    v_base,
    v_rules,
    v_comm_rate
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_aliado is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if v_status = 'rechazado' then
    raise exception 'El pedido está rechazado';
  end if;
  if v_pe is not null and trim(v_pe) = 'aprobado' then
    raise exception 'El pago ya fue confirmado; no puede modificar el comprobante';
  end if;

  select
    coalesce(p.accepted_pago_metodos, public.motoconecta_all_pago_metodos ()),
    coalesce(p.pago_solo_divisas, false)
  into v_accepted, v_solo_divisas
  from public.profiles p
  where p.id = v_importador;

  if coalesce(v_solo_divisas, false) and v_metodo = any (v_bs) then
    raise exception
      'Este importador solo acepta pagos en divisas (USD). Elija Zelle, Binance, USDT o efectivo.';
  end if;

  if not (v_metodo = any (v_accepted)) then
    raise exception
      'Este importador no acepta el método de pago seleccionado. Elija otro o acuerde con el proveedor.';
  end if;

  v_pct := public.motoconecta_usd_discount_pct (v_rules);
  v_applied := not coalesce(v_solo_divisas, false)
    and v_metodo = any (public.motoconecta_usd_discount_metodos ())
    and v_pct > 0;

  v_total := public.motoconecta_order_total_for_pago_metodo (
    v_base,
    v_rules,
    v_metodo
  );

  if coalesce(v_solo_divisas, false) then
    v_total := v_base;
  end if;

  v_unit := round(
    (v_total / greatest(coalesce(v_cant, 1), 1))::numeric,
    6
  );

  v_rules_out := public.motoconecta_enrich_discount_rules_pago_metodo (
    v_rules,
    v_metodo,
    v_applied
  );

  update public.transaction_requests
  set
    pago_metodo = v_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = nullif(trim(p_file_name), ''),
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    precio_base_aliado_total = v_base,
    precio_total_usd = v_total,
    precio_unitario_aliado = v_unit,
    discount_rules = v_rules_out,
    comision_devengada_usd = case
      when comision_devengada_at is null and coalesce(v_comm_rate, 0) > 0
        then round((v_total * v_comm_rate)::numeric, 2)
      else comision_devengada_usd
    end
  where id = p_request_id;

  perform public.aliado_register_pago_frecuente (v_importador, v_metodo);
end;
$$;
