-- Mobile supplier payment: an explicit, atomic declaration with immutable
-- checkout currency/pricing. Existing desktop RPCs remain available.
alter table public.transaction_requests
  add column pago_declaracion jsonb not null default '{}'::jsonb
    check (jsonb_typeof(pago_declaracion)='object');

-- Authenticated users can write some order fields via existing RLS. The new
-- declaration may only be changed by a server-owned RPC after validation.
create function b2b_private.guard_payment_declaration() returns trigger
language plpgsql set search_path='' as $$
begin
  if current_user in ('authenticated','anon') and
    ((tg_op='INSERT' and new.pago_declaracion<>'{}'::jsonb) or
     (tg_op='UPDATE' and new.pago_declaracion is distinct from old.pago_declaracion)) then
    raise exception 'Registra el comprobante desde el flujo de pago.' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function b2b_private.guard_payment_declaration() from public,anon,authenticated;
create trigger guard_payment_declaration before insert or update of pago_declaracion
  on public.transaction_requests for each row execute function b2b_private.guard_payment_declaration();

create function public.aliado_submit_supplier_payment_v1(
  p_request_ids uuid[], p_metodo text, p_declaration jsonb,
  p_storage_path text default null, p_file_name text default null)
returns void language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_owner uuid; v_group uuid; v_ids uuid[];
  v_first public.transaction_requests%rowtype; v_row public.transaction_requests%rowtype;
  v_method text:=lower(trim(coalesce(p_metodo,''))); v_accepted text[];
  v_currency text; v_expected numeric:=0; v_total numeric; v_base numeric;
  v_rate numeric; v_decl jsonb; v_date date; v_amount numeric; v_cash boolean;
  v_versioned boolean; v_only boolean; v_count integer;
begin
  if not exists(select 1 from public.profiles where id=v_uid and role='aliado'
      and account_access_status='active' and deactivated_at is null and kyc_status='aprobado') then
    raise exception 'Acceso reservado a tiendas habilitadas.' using errcode='42501'; end if;
  if coalesce(cardinality(p_request_ids),0) not between 1 and 100
    or array_position(p_request_ids,null) is not null then
    raise exception 'Seleccione los productos de un proveedor.' using errcode='22023'; end if;
  select array_agg(distinct id order by id) into v_ids from unnest(p_request_ids) id;
  if cardinality(v_ids)<>cardinality(p_request_ids) then
    raise exception 'Hay productos repetidos en el pago.' using errcode='22023'; end if;
  select * into v_first from public.transaction_requests where id=v_ids[1];
  if v_first.aliado_id is distinct from v_uid then
    raise exception 'Pedido no disponible.' using errcode='42501'; end if;
  v_owner:=v_first.importador_id; v_group:=v_first.checkout_group_id;
  -- All entry points in this RPC acquire row locks in the same order.
  perform 1 from public.transaction_requests where id=any(v_ids) order by id for update;
  select count(*) into v_count from public.transaction_requests where id=any(v_ids)
    and aliado_id=v_uid and importador_id=v_owner and checkout_group_id is not distinct from v_group;
  if v_count<>cardinality(v_ids) or (v_group is null and v_count<>1) then
    raise exception 'El pago debe pertenecer a un único proveedor y pedido.' using errcode='22023'; end if;
  if v_group is not null and exists(select 1 from public.transaction_requests tr
    where tr.checkout_group_id=v_group and tr.importador_id=v_owner and tr.aliado_id=v_uid
      and tr.status<>'rechazado' and not coalesce(tr.cancelado_por_aliado,false)
      and not coalesce(tr.anulado_por_motolink,false)
      and not(tr.id=any(v_ids))) then
    raise exception 'Actualiza el pedido: deben incluirse todos los productos de este proveedor.' using errcode='22023'; end if;

  if jsonb_typeof(p_declaration) is distinct from 'object'
    or coalesce(p_declaration->>'submission_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or coalesce(p_declaration->>'paid_on','') !~ '^\d{4}-\d{2}-\d{2}$'
    or jsonb_typeof(p_declaration->'amount') is distinct from 'number' then
    raise exception 'Revisa los datos del comprobante.' using errcode='22023'; end if;
  v_date:=(p_declaration->>'paid_on')::date; v_amount:=(p_declaration->>'amount')::numeric;
  if v_date>(now() at time zone 'America/Caracas')::date or v_date<date '2000-01-01'
    or not(v_amount>0 and v_amount<=1000000000000) or v_amount<>round(v_amount,2)
    or length(coalesce(p_declaration->>'reference',''))>100
    or length(coalesce(p_declaration->>'note',''))>1000 then
    raise exception 'Revisa la fecha, referencia y monto pagado.' using errcode='22023'; end if;
  v_cash:=v_method='efectivo';
  if not v_cash and nullif(trim(p_declaration->>'reference'),'') is null then
    raise exception 'Indica la referencia del pago.' using errcode='22023'; end if;
  if not v_method=any(array['pago_movil','transferencia','zelle_divisas','usdt','efectivo']) then
    raise exception 'Método no disponible.' using errcode='22023'; end if;
  v_currency:=case when v_method in ('pago_movil','transferencia') then 'BS' else 'USD' end;
  if p_declaration->>'currency' is distinct from v_currency then
    raise exception 'La moneda no corresponde al método de pago.' using errcode='22023'; end if;
  v_decl:=jsonb_build_object('submission_id',p_declaration->>'submission_id',
    'reference',trim(coalesce(p_declaration->>'reference','')),'paid_on',v_date::text,
    'amount',v_amount,'currency',v_currency,'note',trim(coalesce(p_declaration->>'note','')));

  -- A repeated request is a read, including after the supplier approved it.
  if exists(select 1 from public.transaction_requests where id=any(v_ids)
      and pago_declaracion->>'submission_id'=v_decl->>'submission_id') then
    if exists(select 1 from public.transaction_requests where id=any(v_ids) and
        (pago_declaracion - 'expected_amount' <> v_decl or pago_metodo is distinct from v_method
        or comprobante_pago_storage_path is distinct from nullif(trim(p_storage_path),''))) then
      raise exception 'Esta referencia de envío ya tiene otros datos.' using errcode='22023'; end if;
    return;
  end if;
  if not exists(select 1 from public.transaction_requests where id=any(v_ids)
      and nullif(trim(proveedor_factura_storage_path),'') is not null) then
    raise exception 'Espera la factura del proveedor antes de registrar el pago.' using errcode='22023'; end if;
  if not v_cash and nullif(trim(p_storage_path),'') is null then
    raise exception 'Adjunta el comprobante de pago.' using errcode='22023'; end if;
  if nullif(trim(p_storage_path),'') is not null and (not exists(
      select 1 from storage.objects o where o.bucket_id='order-payment-proofs'
      and o.name=p_storage_path and split_part(o.name,'/',1)=any(v_ids::text[])
      and o.metadata->>'mimetype' in ('image/jpeg','image/png','image/webp','application/pdf')
      and (o.metadata->>'size')::bigint between 1 and 8388608)
      or nullif(trim(p_file_name),'') is null or length(p_file_name)>255) then
    raise exception 'El archivo no pertenece a este pedido o no terminó de cargarse.' using errcode='22023'; end if;
  select accepted_pago_metodos,coalesce(pago_solo_divisas,false) into v_accepted,v_only
    from public.profiles where id=v_owner;
  if coalesce(cardinality(v_accepted),0)>0 and not v_method=any(v_accepted)
    or (v_only and v_currency='BS') then
    raise exception 'El proveedor no acepta este método de pago.' using errcode='22023'; end if;
  for v_row in select * from public.transaction_requests where id=any(v_ids) order by id loop
    if v_row.status not in ('pendiente','aprobado_admin','en_preparacion','pedido_listo','en_transito','entregado')
      or coalesce(v_row.cancelado_por_aliado,false)
      or coalesce(v_row.anulado_por_motolink,false) or v_row.pago_estado_revision='aprobado' then
      raise exception 'El pago de este pedido ya no puede modificarse.' using errcode='22023'; end if;
    if v_row.pago_estado_revision='en_revision' and v_row.pago_metodo is distinct from v_method then
      raise exception 'Durante la revisión solo puedes corregir el comprobante del mismo método.' using errcode='22023'; end if;
    if v_row.metodo_pago_moneda in ('DIVISAS','BOLIVARES') and
      (v_row.metodo_pago_moneda='BOLIVARES')<>(v_currency='BS') then
      raise exception 'Conserva la moneda elegida para este proveedor.' using errcode='22023'; end if;
    v_versioned:=v_row.discount_rules->>'checkout_pricing_version'='1';
    v_base:=coalesce(v_row.precio_base_aliado_total,v_row.precio_total_usd);
    v_total:=case when v_versioned then v_row.precio_total_usd else
      public.motoconecta_order_total_for_pago_metodo(v_base,v_row.discount_rules,v_method) end;
    if v_currency='BS' then
      if v_versioned and v_row.total_bs is not null then v_expected:=v_expected+v_row.total_bs;
      elsif coalesce(v_row.tasa_bcv_aplicada,0)>0 then
        v_expected:=v_expected+round(v_total*v_row.tasa_bcv_aplicada,2);
      else raise exception 'El pedido no tiene tasa BCV aplicada. Consulta al proveedor.' using errcode='22023'; end if;
    else v_expected:=v_expected+v_total; end if;
    -- New checkout snapshots already contain credits and USD incentives.
    -- For legacy orders retain the established method-based calculation.
    if not coalesce(v_versioned,false) then
      update public.transaction_requests set precio_total_usd=v_total,
        precio_unitario_aliado=round(v_total/greatest(v_row.cantidad,1),6),
        precio_base_aliado_total=v_base,
        discount_rules=public.motoconecta_enrich_discount_rules_pago_metodo(v_row.discount_rules,v_method,v_total<v_base),
        comision_devengada_usd=case when comision_devengada_at is null and coalesce(v_row.commission_rate_snapshot,0)>0
          then round(v_total*v_row.commission_rate_snapshot,2) else comision_devengada_usd end
        where id=v_row.id;
    end if;
  end loop;
  update public.transaction_requests set pago_metodo=v_method,
    comprobante_pago_storage_path=nullif(trim(p_storage_path),''),
    comprobante_pago_file_name=nullif(trim(p_file_name),''), comprobante_pago_submitted_at=now(),
    pago_estado_revision='en_revision',pago_comprobante_rechazo_nota=null,
    pago_declaracion=v_decl||jsonb_build_object('expected_amount',round(v_expected,2))
    where id=any(v_ids);
  perform public._aliado_register_pago_frecuente(v_uid,v_owner,v_method);
end $$;
revoke all on function public.aliado_submit_supplier_payment_v1(uuid[],text,jsonb,text,text) from public,anon;
grant execute on function public.aliado_submit_supplier_payment_v1(uuid[],text,jsonb,text,text) to authenticated;
notify pgrst,'reload schema';
