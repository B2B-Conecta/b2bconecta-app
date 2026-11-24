-- Sandbox: all orders, stock changes, object metadata and notifications roll back.
begin;
set local row_security=on;
do $test$
declare
  v_ally uuid; v_other uuid; v_product public.products%rowtype; v_second public.products%rowtype;
  v_one uuid:=gen_random_uuid(); v_two uuid:=gen_random_uuid(); v_foreign uuid:=gen_random_uuid();
  v_group uuid:=gen_random_uuid(); v_submission uuid:=gen_random_uuid(); v_decl jsonb;
  v_path text; v_denied boolean; v_count integer;
begin
  perform set_config('row_security','on',true);
  select id into v_ally from public.profiles where role='aliado' and account_access_status='active'
    and kyc_status='aprobado' and deactivated_at is null order by id limit 1;
  select id into v_other from public.profiles where id<>v_ally and role='aliado' order by id limit 1;
  select * into v_product from public.products where is_active and public._importer_store_is_public(owner_id) order by id limit 1;
  select * into v_second from public.products where is_active and owner_id<>v_product.owner_id
    and public._importer_store_is_public(owner_id) order by id limit 1;
  if v_ally is null or v_other is null or v_second.id is null then raise exception 'Missing QA fixtures'; end if;
  perform set_config('request.jwt.claim.sub',v_ally::text,true);
  update public.products set stock=1000,stock_reserved=0 where id in(v_product.id,v_second.id);
  update public.profiles set accepted_pago_metodos=array['zelle_divisas','efectivo','pago_movil','transferencia'],pago_solo_divisas=false where id=v_product.owner_id;
  insert into public.transaction_requests(id,aliado_id,importador_id,product_id,status,cantidad,
    precio_unitario_proveedor,precio_unitario_aliado,precio_total_usd,precio_base_aliado_total,
    checkout_group_id,metodo_pago_moneda,tasa_bcv_aplicada,total_ref,total_bs,discount_rules,proveedor_factura_storage_path)
  values
    (v_one,v_ally,v_product.owner_id,v_product.id,'pendiente',5,100,90,450,450,v_group,'DIVISAS',10,500,5000,
     '{"checkout_pricing_version":1,"checkout_payment_currency":"DIVISAS","checkout_ref_unit":100,"checkout_usd_unit":90}',v_one||'/invoice.pdf'),
    (v_two,v_ally,v_product.owner_id,v_product.id,'pendiente',5,40,40,200,200,v_group,'DIVISAS',10,200,2000,
     '{"checkout_pricing_version":1,"checkout_payment_currency":"DIVISAS","checkout_ref_unit":40,"checkout_usd_unit":40}',null),
    (v_foreign,v_ally,v_second.owner_id,v_second.id,'pendiente',5,100,100,500,500,v_group,'BOLIVARES',10,500,5000,
     '{"checkout_pricing_version":1,"checkout_payment_currency":"BOLIVARES","checkout_ref_unit":100,"checkout_usd_unit":90}',v_foreign||'/invoice.pdf');
  v_path:=v_one||'/payment_qa.pdf';
  insert into storage.objects(bucket_id,name,metadata) values('order-payment-proofs',v_path,'{"mimetype":"application/pdf","size":1024}');
  v_decl:=jsonb_build_object('submission_id',v_submission,'reference','00012345',
    'paid_on',(now() at time zone 'America/Caracas')::date,'amount',650,'currency','USD','note','Pago de ambos productos');
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);

  -- A partial supplier bundle must never leave a partial payment behind.
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one],'zelle_divisas',v_decl,v_path,'qa.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Partial bundle was accepted'; end if;
  if exists(select 1 from public.transaction_requests where id in(v_one,v_two) and pago_declaracion<>'{}') then raise exception 'Partial write'; end if;
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two,v_foreign],'zelle_divisas',v_decl,v_path,'qa.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Mixed suppliers accepted'; end if;

  -- Both declaration and expected amount belong to the supplier, not each line.
  perform public.aliado_submit_supplier_payment_v1(array[v_two,v_one],'zelle_divisas',v_decl,v_path,'qa.pdf');
  select count(*) into v_count from public.transaction_requests where id in(v_one,v_two)
    and pago_estado_revision='en_revision' and pago_metodo='zelle_divisas'
    and pago_declaracion->>'reference'='00012345' and (pago_declaracion->>'amount')::numeric=650
    and (pago_declaracion->>'expected_amount')::numeric=650 and comprobante_pago_storage_path=v_path;
  if v_count<>2 then raise exception 'Atomic declaration missing'; end if;
  if (select sum(precio_total_usd) from public.transaction_requests where id in(v_one,v_two))<>650 then
    raise exception 'Checkout was discounted twice'; end if;
  if (select pago_declaracion from public.transaction_requests where id=v_foreign)<>'{}'::jsonb then
    raise exception 'Another supplier was changed'; end if;
  perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl,v_path,'qa.pdf');
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl||'{"amount":1}',v_path,'qa.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Submission ID reused with different data'; end if;

  -- A user cannot forge declaration metadata through direct table writes.
  begin update public.transaction_requests set pago_declaracion='{"amount":0}' where id=v_one;
  exception when insufficient_privilege then null; end;
  if (select pago_declaracion->>'reference' from public.transaction_requests where id=v_one)<>'00012345' then
    raise exception 'Direct declaration edit succeeded'; end if;

  perform set_config('request.jwt.claim.sub',v_other::text,true);
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl,v_path,'qa.pdf');
  exception when insufficient_privilege then v_denied:=true; end;
  if not v_denied then raise exception 'Another retailer submitted a payment'; end if;
  perform set_config('request.jwt.claim.sub',v_ally::text,true);
  execute 'reset role';

  -- Rejected receipts can be corrected; mismatched currency and future dates fail.
  update public.transaction_requests set pago_estado_revision='rechazado',pago_comprobante_rechazo_nota='Ilegible' where id in(v_one,v_two);
  v_decl:=v_decl||jsonb_build_object('previous_submission_id',v_decl->>'submission_id','submission_id',gen_random_uuid());
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'pago_movil',v_decl||'{"currency":"BS"}',v_path,'qa.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Checkout currency changed'; end if;
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl||jsonb_build_object('paid_on',current_date+2),v_path,'qa.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Future payment accepted'; end if;
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl,null,null);
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Missing non-cash proof accepted'; end if;
  perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'zelle_divisas',v_decl||'{"amount":640}',v_path,'qa.pdf');
  if exists(select 1 from public.transaction_requests where id in(v_one,v_two) and pago_comprobante_rechazo_nota is not null) then raise exception 'Rejection was not cleared'; end if;
  execute 'reset role';

  -- Cash stays available in USD-only mode, without an obligatory photograph.
  update public.profiles set pago_solo_divisas=true where id=v_product.owner_id;
  update public.transaction_requests set pago_estado_revision='rechazado' where id in(v_one,v_two);
  v_decl:=v_decl||jsonb_build_object('previous_submission_id',v_decl->>'submission_id','submission_id',gen_random_uuid(),'reference','');
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);
  perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'efectivo',v_decl,null,null);
  execute 'reset role';
  update public.transaction_requests set pago_estado_revision='aprobado' where id in(v_one,v_two);
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);
  perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'efectivo',v_decl,null,null);
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_one,v_two],'efectivo',v_decl||jsonb_build_object('submission_id',gen_random_uuid()),null,null);
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Approved payment was modified'; end if;
  execute 'reset role';

  -- A different supplier keeps its own bolivar amount and selected currency.
  update public.profiles set accepted_pago_metodos=array['pago_movil'],pago_solo_divisas=false where id=v_second.owner_id;
  v_path:=v_foreign||'/payment_bs.pdf';
  insert into storage.objects(bucket_id,name,metadata) values('order-payment-proofs',v_path,'{"mimetype":"application/pdf","size":1024}');
  v_decl:=jsonb_build_object('submission_id',gen_random_uuid(),'reference','000987',
    'paid_on',(now() at time zone 'America/Caracas')::date,'amount',5000,'currency','BS','note','');
  execute 'set local role authenticated';
  perform set_config('row_security','on',true);
  perform public.aliado_submit_supplier_payment_v1(array[v_foreign],'pago_movil',v_decl,v_path,'bs.pdf');
  if not exists(select 1 from public.transaction_requests where id=v_foreign and metodo_pago_moneda='BOLIVARES'
    and precio_total_usd=500 and total_bs=5000 and pago_declaracion->>'currency'='BS'
    and (pago_declaracion->>'expected_amount')::numeric=5000) then raise exception 'Independent bolivar payment failed'; end if;
  v_denied:=false;
  begin perform public.aliado_submit_supplier_payment_v1(array[v_foreign],'pago_movil',v_decl||jsonb_build_object('submission_id',gen_random_uuid()),v_path,'bs.pdf');
  exception when invalid_parameter_value then v_denied:=true; end;
  if not v_denied then raise exception 'Stale correction was accepted'; end if;
  execute 'reset role';
  if has_function_privilege('anon','public.aliado_submit_supplier_payment_v1(uuid[],text,jsonb,text,text)','EXECUTE') then raise exception 'Anonymous payment execution enabled'; end if;
end;
$test$;
rollback;
