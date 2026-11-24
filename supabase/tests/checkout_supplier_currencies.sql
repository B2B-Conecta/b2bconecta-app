-- Run ONLY on the sandbox inside this rollback transaction.
-- Requires an enabled QA retailer with a complete fiscal address in the replica.
begin;
do $test$
declare
  v_ally uuid;
  v_one public.products%rowtype;
  v_two public.products%rowtype;
  v_group uuid;
  v_before integer;
  v_rejected boolean;
begin
  select id into v_ally from public.profiles
    where role='aliado' and account_access_status='active' and deactivated_at is null
      and kyc_status='aprobado' and nullif(rif,'') is not null
      and nullif(estado,'') is not null and nullif(ciudad,'') is not null
      and nullif(direccion,'') is not null and nullif(fiscal_maps_url,'') is not null
    order by id limit 1;
  if v_ally is null then raise exception 'Missing QA retailer fixture'; end if;
  perform set_config('request.jwt.claim.sub',v_ally::text,true);
  select * into v_one from public.products p where p.is_active
    and p.owner_id<>v_ally and public._importer_store_is_public(p.owner_id)
    order by p.id limit 1;
  select * into v_two from public.products p where p.is_active
    and p.owner_id<>v_ally and p.owner_id<>v_one.owner_id
    and public._importer_store_is_public(p.owner_id) order by p.id limit 1;
  if v_one.id is null or v_two.id is null then raise exception 'Missing two QA supplier fixtures'; end if;
  -- Fixture changes, stock, orders and notifications are all rolled back below.
  update public.profiles set min_order_amount_ref=0, pago_solo_divisas=false
    where id in (v_one.owner_id,v_two.owner_id);
  update public.products set stock=100,stock_reserved=0,min_order_qty=5,
    price_usd=100,sale_price_usd=null,discount_rules='{"usd_payment_discount_pct":10}'::jsonb
    where id in (v_one.id,v_two.id);
  update public.app_global_config set value_numeric=10 where key='tasa_bcv';
  v_group := public.aliado_checkout_proveedores_v1(
    p_lines=>jsonb_build_array(jsonb_build_object('product_id',v_one.id,'cantidad',5),jsonb_build_object('product_id',v_two.id,'cantidad',5)),
    p_destino_entrega_usa_perfil=>true,
    p_moneda_by_importador=>jsonb_build_object(v_one.owner_id::text,'DIVISAS',v_two.owner_id::text,'BOLIVARES'))::uuid;
  if (select count(*) from public.transaction_requests where checkout_group_id=v_group)<>2 then
    raise exception 'Expected one master order with two supplier lines'; end if;
  if exists(select 1 from public.transaction_requests where checkout_group_id=v_group
    and (metodo_pago_moneda is distinct from case when importador_id=v_one.owner_id then 'DIVISAS' else 'BOLIVARES' end
      or discount_rules->>'checkout_payment_currency' is distinct from metodo_pago_moneda)) then
    raise exception 'Supplier currency snapshot mismatch'; end if;
  if exists(select 1 from public.transaction_requests where checkout_group_id=v_group and importador_id=v_one.owner_id and precio_total_usd<>450) then
    raise exception 'USD discount not applied independently'; end if;
  if exists(select 1 from public.transaction_requests where checkout_group_id=v_group and importador_id=v_two.owner_id and precio_total_usd<>500) then
    raise exception 'Bolivares product was discounted incorrectly'; end if;
  if exists(select 1 from public.products where id in (v_one.id,v_two.id) and stock<>95) then
    raise exception 'Stock must be debited once per requested unit'; end if;
  select stock into v_before from public.products where id=v_one.id;
  v_rejected := false;
  begin
    perform public.aliado_checkout_proveedores_v1(
      p_lines=>jsonb_build_array(jsonb_build_object('product_id',v_one.id,'cantidad',5),jsonb_build_object('product_id',v_two.id,'cantidad',5)),
      p_destino_entrega_usa_perfil=>true,
      p_moneda_by_importador=>jsonb_build_object(v_one.owner_id::text,'DIVISAS'));
  exception when invalid_parameter_value then v_rejected:=true;
  end;
  if not v_rejected or (select stock from public.products where id=v_one.id)<>v_before then
    raise exception 'Missing supplier currency must fail without stock changes'; end if;
  update public.profiles set pago_solo_divisas=true where id=v_two.owner_id;
  v_rejected:=false;
  begin
    perform public.aliado_checkout_proveedores_v1(
      p_lines=>jsonb_build_array(jsonb_build_object('product_id',v_one.id,'cantidad',5),jsonb_build_object('product_id',v_two.id,'cantidad',5)),
      p_destino_entrega_usa_perfil=>true,
      p_moneda_by_importador=>jsonb_build_object(v_one.owner_id::text,'DIVISAS',v_two.owner_id::text,'BOLIVARES'));
  exception when raise_exception then v_rejected:=true;
  end;
  if not v_rejected or (select stock from public.products where id=v_one.id)<>v_before then
    raise exception 'USD-only validation must roll back every supplier'; end if;
end;
$test$;
rollback;
select 'supplier_currency_assertions_passed_and_rolled_back' as verification;
