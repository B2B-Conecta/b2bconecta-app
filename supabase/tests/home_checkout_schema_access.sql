-- Read-only regression: execute as the API role, not as postgres.
-- All role and JWT settings are rolled back; no customer/order data is changed.
begin;
do $test$
declare
  v_retailer uuid;
  v_importer uuid;
  v_selection jsonb;
  v_denied boolean;
begin
  select id into v_retailer from public.profiles
    where role='aliado' and account_access_status='active'
      and deactivated_at is null and kyc_status='aprobado'
    order by id limit 1;
  select id into v_importer from public.profiles
    where role='importador' order by id limit 1;
  if v_retailer is null or v_importer is null then
    raise exception 'Missing enabled retailer/importer fixtures';
  end if;
  if has_schema_privilege('anon','b2b_private','USAGE')
    or has_function_privilege('anon','public.aliado_home_product_selection()','EXECUTE') then
    raise exception 'Home ranking must not be available anonymously';
  end if;
  if not (select relrowsecurity from pg_class
      where oid='b2b_private.checkout_attempts'::regclass) then
    raise exception 'Checkout attempt RLS must stay enabled';
  end if;
  if has_table_privilege('authenticated','b2b_private.checkout_attempts','SELECT')
    or has_table_privilege('authenticated','b2b_private.checkout_attempts','INSERT')
    or has_table_privilege('authenticated','b2b_private.checkout_attempts','UPDATE')
    or has_table_privilege('authenticated','b2b_private.checkout_attempts','DELETE') then
    raise exception 'Schema USAGE must not grant checkout attempt access';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_retailer::text,true);
  v_selection := public.aliado_home_product_selection();
  if jsonb_typeof(v_selection->'buy_again') is distinct from 'array'
    or jsonb_typeof(v_selection->'best_sellers') is distinct from 'array' then
    raise exception 'Home ranking did not return both product selections';
  end if;

  v_denied := false;
  begin
    perform 1 from b2b_private.checkout_attempts limit 1;
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'Private checkout table became readable'; end if;

  perform set_config('request.jwt.claim.sub',v_importer::text,true);
  v_denied := false;
  begin
    perform public.aliado_home_product_selection();
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'Home ranking accepted a non-retailer'; end if;
  execute 'reset role';
end;
$test$;
rollback;
