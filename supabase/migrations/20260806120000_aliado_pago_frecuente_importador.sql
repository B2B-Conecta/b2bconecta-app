-- Aliado: métodos de pago usados con frecuencia por importador (atajos en pedidos).

create table if not exists public.aliado_importador_pago_frecuente (
  aliado_id uuid not null references public.profiles (id) on delete cascade,
  importador_id uuid not null references public.profiles (id) on delete cascade,
  pago_metodo text not null,
  use_count integer not null default 1,
  last_used_at timestamptz not null default now(),
  primary key (aliado_id, importador_id, pago_metodo)
);

create index if not exists aliado_importador_pago_frecuente_lookup_idx
  on public.aliado_importador_pago_frecuente (aliado_id, importador_id, use_count desc);

comment on table public.aliado_importador_pago_frecuente is
  'Historial de métodos de pago del aliado por importador; atajos al pagar pedidos futuros.';

alter table public.aliado_importador_pago_frecuente enable row level security;

create policy aliado_importador_pago_frecuente_select_own
  on public.aliado_importador_pago_frecuente
  for select
  to authenticated
  using (aliado_id = auth.uid ());

grant select on public.aliado_importador_pago_frecuente to authenticated;

create or replace function public._aliado_register_pago_frecuente (
  p_aliado_id uuid,
  p_importador_id uuid,
  p_metodo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_metodo text := lower(trim(p_metodo));
begin
  if v_metodo = ''
     or not (v_metodo = any (public.motoconecta_all_pago_metodos ())) then
    return;
  end if;

  insert into public.aliado_importador_pago_frecuente (
    aliado_id,
    importador_id,
    pago_metodo,
    use_count,
    last_used_at
  )
  values (
    p_aliado_id,
    p_importador_id,
    v_metodo,
    1,
    now()
  )
  on conflict (aliado_id, importador_id, pago_metodo) do update
  set
    use_count = public.aliado_importador_pago_frecuente.use_count + 1,
    last_used_at = now();
end;
$$;

create or replace function public.aliado_list_pago_frecuente_importador (
  p_importador_id uuid
)
returns table (
  pago_metodo text,
  use_count integer,
  last_used_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  return query
  select
    f.pago_metodo,
    f.use_count,
    f.last_used_at
  from public.aliado_importador_pago_frecuente f
  where f.aliado_id = auth.uid ()
    and f.importador_id = p_importador_id
  order by f.use_count desc, f.last_used_at desc
  limit 6;
end;
$$;

grant execute on function public.aliado_list_pago_frecuente_importador (uuid) to authenticated;

-- Registrar uso al enviar comprobante de pago.
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
  v_cant integer;
  v_base numeric;
  v_total numeric;
  v_unit numeric;
  v_rules jsonb;
  v_rules_out jsonb;
  v_pct numeric;
  v_applied boolean;
  v_comm_rate numeric;
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

  select coalesce(p.accepted_pago_metodos, public.motoconecta_all_pago_metodos ())
    into v_accepted
  from public.profiles p
  where p.id = v_importador;

  if not (v_metodo = any (v_accepted)) then
    raise exception
      'Este importador no acepta el método de pago seleccionado. Elija otro o acuerde con el proveedor.';
  end if;

  v_pct := public.motoconecta_usd_discount_pct (v_rules);
  v_applied := v_metodo = any (public.motoconecta_usd_discount_metodos ())
    and v_pct > 0;

  v_total := public.motoconecta_order_total_for_pago_metodo (
    v_base,
    v_rules,
    v_metodo
  );

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
        then round((v_total * v_comm_rate)::numeric, 4)
      else comision_devengada_usd
    end,
    updated_at = now()
  where id = p_request_id;

  perform public._aliado_register_pago_frecuente (v_aliado, v_importador, v_metodo);
end;
$$;
