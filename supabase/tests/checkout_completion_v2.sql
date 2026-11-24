-- Sandbox only. All orders, addresses, stock and notifications are rolled back.
begin;
set local row_security=on;
do $test$
declare
  v_ally uuid; v_other uuid; v_one public.products%rowtype; v_two public.products%rowtype;
  v_location uuid:=gen_random_uuid(); v_address uuid; v_request uuid:=gen_random_uuid(); v_cancelled uuid:=gen_random_uuid();
  v_group text; v_replay text; v_lines jsonb; v_currencies jsonb; v_delivery jsonb; v_rejected boolean;
begin
  select id into v_ally from public.profiles where role='aliado' and account_access_status='active'
    and deactivated_at is null and kyc_status='aprobado' and nullif(rif,'') is not null
    and nullif(estado,'') is not null and nullif(ciudad,'') is not null and nullif(direccion,'') is not null
    and nullif(fiscal_maps_url,'') is not null order by id limit 1;
  select id into v_other from public.profiles where id<>v_ally order by id limit 1;
  select * into v_one from public.products p where p.is_active and public._importer_store_is_public(p.owner_id) order by p.id limit 1;
  select * into v_two from public.products p where p.is_active and p.owner_id<>v_one.owner_id
    and public._importer_store_is_public(p.owner_id) order by p.id limit 1;
  if v_ally is null or v_other is null or v_two.id is null then raise exception 'Missing QA fixture'; end if;
  perform set_config('request.jwt.claim.sub',v_ally::text,true);
  update public.profiles set min_order_amount_ref=0,pago_solo_divisas=false where id in(v_one.owner_id,v_two.owner_id);
  update public.products set stock=100,stock_reserved=0,min_order_qty=5,price_usd=100,sale_price_usd=null,
    discount_rules='{"usd_payment_discount_pct":10}' where id in(v_one.id,v_two.id);
  update public.app_global_config set value_numeric=10 where key='tasa_bcv';
  v_address:=public.save_retailer_delivery_address('Almacén QA','Miranda','Caracas','Dirección original QA','https://maps.app.goo.gl/fixture',null,true);
  perform public.save_retailer_delivery_address('Otro almacén','Miranda','Caracas','Otra dirección','https://maps.app.goo.gl/fixture2',null,true);
  if (select count(*) from public.retailer_delivery_addresses where user_id=v_ally and is_default)<>1 then raise exception 'Default address not unique'; end if;
  insert into public.importer_pickup_locations(id,importador_id,label,estado,ciudad,direccion,maps_url,is_active,
    customer_pickup_enabled,customer_pickup_instructions)
    values(v_location,v_one.owner_id,'Retiro QA','Miranda','Caracas','Local de retiro QA','https://maps.app.goo.gl/pickup',true,true,'Lunes a viernes');
  if not exists(select 1 from public.list_customer_pickup_for_checkout(v_one.owner_id) where id=v_location) then raise exception 'Enabled pickup is missing'; end if;
  v_lines:=jsonb_build_array(jsonb_build_object('product_id',v_one.id,'cantidad',5),jsonb_build_object('product_id',v_two.id,'cantidad',5));
  v_currencies:=jsonb_build_object(v_one.owner_id::text,'DIVISAS',v_two.owner_id::text,'BOLIVARES');
  v_delivery:=jsonb_build_object(v_one.owner_id::text,jsonb_build_object('mode','PICKUP','location_id',v_location));
  v_group:=public.aliado_checkout_confirmar_v2(v_request,v_lines,true,p_moneda_by_importador=>v_currencies,
    p_delivery_by_importador=>v_delivery,p_saved_address_id=>v_address);
  if (select count(*) from public.transaction_requests where checkout_group_id=v_group::uuid)<>2 then raise exception 'Expected one master with two supplier lines'; end if;
  if not exists(select 1 from public.transaction_requests where checkout_group_id=v_group::uuid and importador_id=v_one.owner_id
    and customer_delivery_mode='PICKUP' and customer_pickup_location_id=v_location and carrier_fee_usd_snapshot=0 and shipping_cost_usd=0
    and importer_carrier_id is null and metodo_pago_moneda='DIVISAS' and precio_total_usd=450) then raise exception 'Pickup snapshot/pricing mismatch'; end if;
  if not exists(select 1 from public.transaction_requests where checkout_group_id=v_group::uuid and importador_id=v_two.owner_id
    and customer_delivery_mode='DELIVERY' and customer_delivery_snapshot->>'direccion'='Dirección original QA'
    and metodo_pago_moneda='BOLIVARES' and precio_total_usd=500) then raise exception 'Delivery snapshot/pricing mismatch'; end if;
  v_replay:=public.aliado_checkout_confirmar_v2(v_request,v_lines,true,p_moneda_by_importador=>v_currencies,
    p_delivery_by_importador=>v_delivery,p_saved_address_id=>v_address);
  if v_replay<>v_group or exists(select 1 from public.products where id in(v_one.id,v_two.id) and stock<>95)
    then raise exception 'Replay duplicated stock or order'; end if;
  if public.resolve_checkout_attempt(v_request)<>v_group then raise exception 'Lost response not recovered'; end if;
  perform public.resolve_checkout_attempt(v_cancelled);
  v_rejected:=false;
  begin
    perform public.aliado_checkout_confirmar_v2(v_cancelled,v_lines,true,p_moneda_by_importador=>v_currencies);
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Cancelled stale attempt was accepted'; end if;
  v_rejected:=false;
  begin
    perform public.aliado_checkout_confirmar_v2(v_request,jsonb_build_array(jsonb_build_object('product_id',v_one.id,'cantidad',10)),true,
      p_moneda_by_importador=>v_currencies,p_delivery_by_importador=>v_delivery,p_saved_address_id=>v_address);
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Different payload reused the request key'; end if;
  perform public.save_retailer_delivery_address('Almacén editado','Miranda','Caracas','Nueva dirección QA','https://maps.app.goo.gl/edited',v_address,false);
  update public.importer_pickup_locations set direccion='Local modificado' where id=v_location;
  if exists(select 1 from public.transaction_requests where checkout_group_id=v_group::uuid and importador_id=v_two.owner_id
    and customer_delivery_snapshot->>'direccion'<>'Dirección original QA') then raise exception 'Address changed inside placed order'; end if;
  v_rejected:=false;
  begin
    update public.transaction_requests set shipping_cost_usd=10 where checkout_group_id=v_group::uuid and importador_id=v_one.owner_id;
  exception when check_violation then v_rejected:=true; end;
  if not v_rejected then raise exception 'Pickup transport charge was accepted'; end if;
  update public.transaction_requests set status='pedido_listo' where checkout_group_id=v_group::uuid and importador_id=v_one.owner_id;
  perform public.aliado_marca_pedidos_entregados_importador_en_grupo(v_group::uuid,v_one.owner_id);
  if exists(select 1 from public.transaction_requests where checkout_group_id=v_group::uuid and importador_id=v_one.owner_id and status<>'entregado') then raise exception 'Customer could not confirm collection'; end if;
  update public.importer_pickup_locations set customer_pickup_enabled=false where id=v_location;
  v_rejected:=false;
  begin
    perform public.aliado_checkout_confirmar_v2(gen_random_uuid(),v_lines,true,p_moneda_by_importador=>v_currencies,p_delivery_by_importador=>v_delivery);
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Disabled pickup accepted'; end if;
  perform set_config('request.jwt.claim.sub',v_other::text,true);
  v_rejected:=false;
  begin
    perform public.aliado_checkout_confirmar_v2(gen_random_uuid(),v_lines,true,p_moneda_by_importador=>v_currencies,p_saved_address_id=>v_address);
  exception when invalid_parameter_value then v_rejected:=true; end;
  if not v_rejected then raise exception 'Another account address accepted'; end if;
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);
  if exists(select 1 from public.retailer_delivery_addresses where user_id=v_ally) then
    raise exception 'RLS exposed another customer address'; end if;
  delete from public.retailer_delivery_addresses where id=v_address;
  execute 'reset role';
  if not exists(select 1 from public.retailer_delivery_addresses where id=v_address) then
    raise exception 'RLS allowed deleting another customer address'; end if;
end $test$;
rollback;
select 'checkout_completion_v2_assertions_passed_and_rolled_back' as verification;
