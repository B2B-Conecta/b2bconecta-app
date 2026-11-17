-- Run after 20261209130001 in a seeded SANDBOX, as the SQL editor/postgres role.
-- Every fixture, notification, credit mutation and stock movement is rolled back.
do $qa$
declare
  v_buyer constant uuid := 'c2000001-0000-4000-8000-000000000001';
  v_disc constant uuid := 'd1000004-0000-4000-8000-000000000002';
  v_led constant uuid := 'd100000b-0000-4000-8000-000000000004';
  v_supplier uuid; v_admin uuid; v_order uuid; v_other uuid; v_group text;
  v_stock integer; v_led_stock integer; v_before integer; v_mode text;
  v_line public.transaction_requests%rowtype;
  v_failed boolean; v_cases integer := 0; v_legacy integer;
  v_credit_off jsonb; v_definition text;
begin
  select stock, owner_id into strict v_stock, v_supplier from public.products where id=v_disc;
  select stock into strict v_led_stock from public.products where id=v_led;
  select id into strict v_admin from public.profiles where role='administrador' order by id limit 1;
  select count(*) into v_before from public.transaction_requests;
  v_credit_off := jsonb_build_object(v_supplier::text, false,
    (select owner_id::text from public.products where id=v_led), false);
  begin
    -- Defaults on the historical overloaded RPCs make a short SQL call
    -- ambiguous. Clone each exact installed body under a temporary unique name.
    create temporary table qa_stock_test_scope (id integer) on commit drop;
    foreach v_legacy in array array[4,5] loop
      v_definition := pg_get_functiondef(to_regprocedure(case when v_legacy=4
        then 'public.aliado_checkout_multi_importador(jsonb,boolean,text,text)'
        else 'public.aliado_checkout_multi_importador(jsonb,boolean,text,text,jsonb)' end));
      execute replace(v_definition,
        'CREATE OR REPLACE FUNCTION public.aliado_checkout_multi_importador(',
        format('CREATE OR REPLACE FUNCTION pg_temp.qa_legacy_checkout_%s(',v_legacy));
    end loop;
    foreach v_mode in array array['DIVISAS','BOLIVARES'] loop
      perform set_config('request.jwt.claim.sub',v_buyer::text,true);
      v_group := public.aliado_checkout_multi_importador_moneda(
        jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5),
          jsonb_build_object('product_id',v_led,'cantidad',5)),
        true,null,null,'{}','{}',v_credit_off,v_mode);
      select * into strict v_line from public.transaction_requests
        where checkout_group_id=v_group::uuid and product_id=v_disc;
      v_order := v_line.id;
      select id into strict v_other from public.transaction_requests
        where checkout_group_id=v_group::uuid and product_id=v_led;
      if (select stock from public.products where id=v_disc)<>v_stock-5
        or v_line.checkout_stock_debited_qty<>5 or v_line.metodo_pago_moneda<>v_mode then
        raise exception 'QA debit/currency mismatch';
      end if;
      -- A failing status update must roll back the stock restitution too.
      v_failed:=false;
      begin
        update public.transaction_requests set status='rechazado',precio_total_usd=-1 where id=v_order;
      exception when check_violation then v_failed:=true; end;
      if not v_failed or (select stock from public.products where id=v_disc)<>v_stock-5 then
        raise exception 'QA compensation was not atomic';
      end if;
      -- A caller cannot zero the bookkeeping before cancelling.
      update public.transaction_requests set checkout_stock_debited_qty=0 where id=v_order;
      if (select checkout_stock_debited_qty from public.transaction_requests where id=v_order)<>5 then
        raise exception 'QA bookkeeping was mutable';
      end if;
      perform public.aliado_cancela_pedido_pendiente(v_order,'QA sandbox: cancelar línea');
      if (select stock from public.products where id=v_disc)<>v_stock
        or (select stock from public.products where id=v_led)<>v_led_stock-5
        or (select checkout_stock_debited_qty from public.transaction_requests where id=v_order)<>0 then
        raise exception 'QA single-line cancellation mismatch';
      end if;
      v_failed:=false;
      begin perform public.aliado_cancela_pedido_pendiente(v_order,'QA reintento');
      exception when others then
        if sqlerrm not like '%cerrado%' then raise; end if;
        v_failed:=true;
      end;
      update public.transaction_requests set status='rechazado' where id=v_order;
      if not v_failed or (select stock from public.products where id=v_disc)<>v_stock then
        raise exception 'QA cancellation restored twice';
      end if;
      v_failed:=false;
      begin update public.transaction_requests set status='pendiente' where id=v_order;
      exception when others then
        if sqlerrm not like '%cerrado%' then raise; end if;
        v_failed:=true;
      end;
      if not v_failed then raise exception 'QA cancelled line reopened'; end if;
      perform set_config('request.jwt.claim.sub',
        (select importador_id::text from public.transaction_requests where id=v_other),true);
      perform public.importer_cancela_pedido_en_gestion(v_other,'QA sandbox: cancelar proveedor');
      if (select stock from public.products where id=v_led)<>v_led_stock then
        raise exception 'QA supplier cancellation mismatch';
      end if;
      v_cases:=v_cases+6;
    end loop;

    -- Accept 5 of 10: release 5 now; later cancel releases only the remaining 5.
    perform set_config('request.jwt.claim.sub',v_buyer::text,true);
    v_group := public.aliado_checkout_multi_importador_moneda(
      jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',10)),
      true,null,null,'{}','{}',v_credit_off,'DIVISAS');
    select id into strict v_order from public.transaction_requests where checkout_group_id=v_group::uuid;
    perform set_config('request.jwt.claim.sub',v_supplier::text,true);
    perform public.importer_propone_ajuste_cantidad(v_order,5,'QA menor cantidad');
    perform set_config('request.jwt.claim.sub',v_buyer::text,true);
    perform public.aliado_responde_ajuste_cantidad(v_order,true);
    select * into strict v_line from public.transaction_requests where id=v_order;
    if (select stock from public.products where id=v_disc)<>v_stock-5
      or v_line.checkout_stock_debited_qty<>5 or v_line.cantidad<>5
      or v_line.precio_total_usd<>240 or v_line.total_ref<>260
      or v_line.total_bs<>round(260*v_line.tasa_bcv_aplicada,2) then
      raise exception 'QA accepted quantity stock/quote mismatch';
    end if;
    perform public.aliado_cancela_pedido_pendiente(v_order,'QA cancelar tras ajuste');
    if (select stock from public.products where id=v_disc)<>v_stock then
      raise exception 'QA cancel after partial restitution mismatch';
    end if;
    v_cases:=v_cases+2;

    -- Reject a proposal: all originally deducted units must return.
    v_group := public.aliado_checkout_multi_importador_moneda(
      jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',10)),
      true,null,null,'{}','{}',v_credit_off,'BOLIVARES');
    select id into strict v_order from public.transaction_requests where checkout_group_id=v_group::uuid;
    perform set_config('request.jwt.claim.sub',v_supplier::text,true);
    perform public.importer_propone_ajuste_cantidad(v_order,5,'QA propuesta rechazada');
    perform set_config('request.jwt.claim.sub',v_buyer::text,true);
    perform public.aliado_responde_ajuste_cantidad(v_order,false);
    if (select stock from public.products where id=v_disc)<>v_stock then
      raise exception 'QA rejected proposal stock mismatch';
    end if;
    v_cases:=v_cases+1;

    -- Admin rejection uses the same compensation.
    v_group := public.aliado_checkout_multi_importador_moneda(
      jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5)),
      true,null,null,'{}','{}',v_credit_off,'DIVISAS');
    select id into strict v_order from public.transaction_requests where checkout_group_id=v_group::uuid;
    perform set_config('request.jwt.claim.sub',v_admin::text,true);
    update public.transaction_requests set status='aprobado_admin' where id=v_order;
    perform public.admin_anula_pedido_por_motolink(v_order,'QA anulación admin');
    if (select stock from public.products where id=v_disc)<>v_stock then
      raise exception 'QA admin cancellation mismatch';
    end if;
    v_cases:=v_cases+1;

    -- Delivery consumes stock; editing a delivered line must never restock it.
    perform set_config('request.jwt.claim.sub',v_buyer::text,true);
    v_group := public.aliado_checkout_multi_importador_moneda(
      jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5)),
      true,null,null,'{}','{}',v_credit_off,'DIVISAS');
    select id into strict v_order from public.transaction_requests where checkout_group_id=v_group::uuid;
    update public.transaction_requests set status='entregado' where id=v_order;
    v_failed:=false;
    begin update public.transaction_requests set status='rechazado' where id=v_order;
    exception when others then
      if sqlerrm not like '%postventa%' then raise; end if;
      v_failed:=true;
    end;
    if not v_failed or (select stock from public.products where id=v_disc)<>v_stock-5 then
      raise exception 'QA delivered stock was restored';
    end if;
    -- From this point the baseline includes that fulfilled, non-refundable line.
    v_stock:=v_stock-5;
    v_cases:=v_cases+1;

    -- Keep legacy checkout entry points working with exactly one stock debit.
    -- This historical RPC still enforces its former first-three-orders gate.
    -- Qualify only the fixture profile inside the rollback scope.
    update public.profiles set primeros_pedidos_contado_entregados=3 where id=v_buyer;
    for v_legacy in 4..7 loop
      if v_legacy=6 then continue; end if;
      perform set_config('request.jwt.claim.sub',v_buyer::text,true);
      if v_legacy=4 then
        execute 'select pg_temp.qa_legacy_checkout_4($1,true,null::text,null::text)'
          into v_group using jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5));
      elsif v_legacy=5 then
        execute 'select pg_temp.qa_legacy_checkout_5($1,true,null::text,null::text,''{}''::jsonb)'
          into v_group using jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5));
      else
        v_group := public.aliado_checkout_multi_importador(
          jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5)),true,null,null,'{}','{}',v_credit_off);
      end if;
      select id into strict v_order from public.transaction_requests where checkout_group_id=v_group::uuid;
      if (select stock from public.products where id=v_disc)<>v_stock-5 then
        raise exception 'QA legacy checkout deducted twice (%)',v_legacy;
      end if;
      perform public.aliado_cancela_pedido_pendiente(v_order,'QA cancelar checkout anterior');
      if (select stock from public.products where id=v_disc)<>v_stock then
        raise exception 'QA legacy cancellation mismatch';
      end if;
      v_cases:=v_cases+1;
    end loop;
    -- No stock can be sold if replacement reservations leave fewer than MOQ.
    update public.products set stock_reserved=stock-4 where id=v_disc;
    v_failed:=false;
    begin
      perform public.aliado_checkout_multi_importador_moneda(
        jsonb_build_array(jsonb_build_object('product_id',v_disc,'cantidad',5)),
        true,null,null,'{}','{}',v_credit_off,'DIVISAS');
    exception when others then
      if sqlerrm not like '%Stock insuficiente%' then raise; end if;
      v_failed:=true;
    end;
    if not v_failed or (select stock from public.products where id=v_disc)<>v_stock then
      raise exception 'QA reserved stock protection failed';
    end if;
    v_stock:=v_stock+5; -- Restore the original expectation after rolling back delivery.
    v_cases:=v_cases+1;
    raise exception using errcode='P9001',message='QA rollback intentional';
  exception when sqlstate 'P9001' then null;
  end;
  if (select count(*) from public.transaction_requests)<>v_before
    or (select stock from public.products where id=v_disc)<>v_stock
    or (select stock from public.products where id=v_led)<>v_led_stock then
    raise exception 'QA fixtures were not rolled back';
  end if;
  perform set_config('qa.checkout_stock_result',jsonb_build_object(
    'result','PASS','cases',v_cases,'all_fixtures_rolled_back',true,
    'order_count_unchanged',v_before,'disc_stock_unchanged',v_stock,
    'led_stock_unchanged',v_led_stock)::text,false);
end;
$qa$;
select current_setting('qa.checkout_stock_result')::jsonb as result;
