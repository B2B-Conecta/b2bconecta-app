-- Fix aliado_registra_comprobante_pago: call _aliado_register_pago_frecuente (3 args),
-- not the non-existent aliado_register_pago_frecuente(uuid, text).

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

  perform public._aliado_register_pago_frecuente (v_aliado, v_importador, v_metodo);
end;
$$;
