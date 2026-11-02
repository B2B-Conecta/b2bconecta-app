-- Optional mobile creative. Existing desktop URLs, permissions and filters stay intact.
alter table public.promo_campaigns
  add column if not exists mobile_image_storage_path text,
  add column if not exists mobile_image_public_url text;

do $migration$
declare
  function_name text;
  definition text;
  anchor constant text := '''image_public_url'', c.image_public_url,';
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.promo_campaigns'::regclass and conname = 'promo_mobile_image_pair') then
    alter table public.promo_campaigns add constraint promo_mobile_image_pair check (
      (mobile_image_storage_path is null and mobile_image_public_url is null)
      or (mobile_image_storage_path is not null and mobile_image_public_url is not null
        and nullif(btrim(mobile_image_storage_path), '') is not null
        and nullif(btrim(mobile_image_public_url), '') is not null)
    );
  end if;
  -- Extend only the JSON projection of each existing function. Preserve its
  -- own audience/ownership filters, execution privileges, ordering and discounts.
  foreach function_name in array array[
    'get_active_promo_campaigns_for_aliado',
    'get_active_promo_campaigns_for_importador',
    'get_active_promo_campaigns_for_importador_ads'
  ] loop
    definition := pg_get_functiondef(to_regprocedure(format('public.%I()', function_name)));
    if definition is null then raise exception 'Missing promotion RPC: %', function_name; end if;
    if position('''mobile_image_public_url''' in definition) = 0 then
      if position(anchor in definition) = 0 then raise exception 'Unexpected promotion RPC projection: %', function_name; end if;
      execute replace(definition, anchor, anchor || E'\n        ''mobile_image_public_url'', c.mobile_image_public_url,');
    end if;
  end loop;
end;
$migration$;

notify pgrst, 'reload schema';
