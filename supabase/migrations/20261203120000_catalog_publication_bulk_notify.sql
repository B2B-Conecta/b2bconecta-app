-- La publicación de catálogo avisaba por cada fila que pasaba a visible.
-- En una carga masiva (o al activar muchos SKU a la vez) eso agota el tiempo
-- de la transacción. Durante un lote se marca b2b.catalog_bulk y se envía
-- un solo aviso al terminar.

create or replace function public.mc_notify_catalog_published (
  p_owner uuid,
  p_count integer,
  p_product_name text default null,
  p_product_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_is_importer boolean := false;
  v_product text;
  v_user uuid;
  v_first boolean := false;
begin
  if p_owner is null or coalesce(p_count, 0) < 1 then
    return;
  end if;

  perform set_config('row_security', 'off', true);

  select p.role = 'importador', public.mc_profile_label(p.id)
    into v_is_importer, v_name
  from public.profiles p
  where p.id = p_owner;

  if v_is_importer is distinct from true then
    return;
  end if;

  v_product := coalesce(nullif(btrim(p_product_name), ''), 'un repuesto');

  update public.profiles
  set catalog_announced_at = now()
  where id = p_owner
    and catalog_announced_at is null;

  v_first := found;

  if v_first then
    for v_user in
      select p.id
      from public.profiles p
      where p.role = 'aliado'
        and p.deactivated_at is null
        and coalesce(p.account_access_status, 'active') = 'active'
        and p.id <> p_owner
    loop
      perform public.mc_insert_notification(
        v_user,
        v_name || ' publicó su catálogo',
        'Ya puedes ver sus repuestos en B2B Conecta.',
        'catalogo',
        p_owner::text
      );
    end loop;
    return;
  end if;

  for v_user in
    select distinct audience.user_id
    from (
      select tr.aliado_id as user_id
      from public.transaction_requests tr
      where tr.importador_id = p_owner
      union
      select f.user_id
      from public.aliado_product_favorites f
      join public.products pr on pr.id = f.product_id
      where pr.owner_id = p_owner
    ) audience
    join public.profiles p on p.id = audience.user_id
    where p.role = 'aliado'
      and p.deactivated_at is null
      and coalesce(p.account_access_status, 'active') = 'active'
      and p.id <> p_owner
  loop
    perform public.mc_insert_notification(
      v_user,
      v_name,
      case
        when p_count = 1 then 'Nuevo en su catálogo: ' || v_product || '.'
        else 'Publicó ' || p_count::text || ' productos nuevos en su catálogo.'
      end,
      'catalogo',
      case
        when p_count = 1 and p_product_id is not null then p_product_id::text
        else p_owner::text
      end
    );
  end loop;
end;
$$;

revoke all on function public.mc_notify_catalog_published (uuid, integer, text, uuid) from public;

comment on function public.mc_notify_catalog_published (uuid, integer, text, uuid) is
  'Un aviso de catálogo por lote: el estreno va a todas las tiendas; después, un resumen a compradores y favoritos.';

create or replace function public.mc_notify_catalog_publication ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('b2b.catalog_bulk', true), '') = '1' then
    return new;
  end if;

  if new.is_active is distinct from true or new.owner_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.is_active is true then
    return new;
  end if;

  perform public.mc_notify_catalog_published(
    new.owner_id,
    1,
    new.name,
    new.id
  );

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Carga masiva: el alta visible no dispara un aviso por cada SKU.
-- ---------------------------------------------------------------------------
create or replace function public.importador_bulk_upsert_products (
  p_rows jsonb,
  p_options jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_solo_divisas boolean;
  v_upsert_mode text := lower(coalesce(p_options ->> 'upsert_mode', 'update_all'));
  v_new_active boolean := coalesce((p_options ->> 'new_products_active')::boolean, false);
  v_row jsonb;
  v_sku text;
  v_name text;
  v_price numeric;
  v_stock integer;
  v_min_qty integer;
  v_has_min boolean;
  v_sale numeric;
  v_desc text;
  v_category text;
  v_compat text;
  v_image text;
  v_warranty boolean;
  v_custom jsonb;
  v_discount jsonb;
  v_row_index integer;
  v_existing_id uuid;
  v_inserted integer := 0;
  v_updated integer := 0;
  v_skipped integer := 0;
  v_errors jsonb := '[]'::jsonb;
  v_seen_skus jsonb := '{}'::jsonb;
  v_sku_key text;
  v_last_name text;
  v_last_id uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, coalesce(p.pago_solo_divisas, false)
    into v_role, v_solo_divisas
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden importar productos';
  end if;

  if v_upsert_mode not in ('update_all', 'insert_only', 'price_stock_only') then
    raise exception 'upsert_mode inválido. Use update_all, insert_only o price_stock_only.';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows debe ser un arreglo JSON';
  end if;

  perform set_config('b2b.catalog_bulk', '1', true);

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    v_row_index := coalesce((v_row ->> 'row_index')::integer, 0);
    v_sku := trim(coalesce(v_row ->> 'sku', ''));
    v_name := trim(coalesce(v_row ->> 'name', ''));
    v_price := nullif(v_row ->> 'price_usd', '')::numeric;
    v_stock := nullif(v_row ->> 'stock', '')::integer;
    v_has_min := v_row ? 'min_order_qty';
    v_min_qty := null;
    if v_has_min then
      v_min_qty := coalesce(nullif(trim(v_row ->> 'min_order_qty'), '')::integer, 5);
      if v_min_qty < 5 then
        v_errors := v_errors || jsonb_build_array(jsonb_build_object(
          'row_index', v_row_index,
          'sku', v_sku,
          'code', 'INVALID_MIN_ORDER_QTY',
          'message', 'La cantidad mínima de pedido debe ser 5 o más'
        ));
        continue;
      end if;
    end if;
    v_sale := nullif(v_row ->> 'sale_price_usd', '')::numeric;
    v_desc := nullif(trim(v_row ->> 'description'), '');
    v_category := nullif(trim(v_row ->> 'category'), '');
    v_compat := nullif(trim(v_row ->> 'compatibility'), '');
    v_image := nullif(trim(v_row ->> 'image_url'), '');
    v_warranty := coalesce((v_row ->> 'has_warranty')::boolean, false);
    v_custom := coalesce(v_row -> 'custom_fields', '{}'::jsonb);
    v_discount := v_row -> 'discount_rules';

    if v_sku = '' then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'REQUIRED_SKU',
        'message', 'SKU obligatorio'
      ));
      continue;
    end if;

    v_sku_key := lower(v_sku);
    if v_seen_skus ? v_sku_key then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'DUPLICATE_SKU_IN_FILE',
        'message', 'SKU duplicado en el mismo lote'
      ));
      continue;
    end if;
    v_seen_skus := v_seen_skus || jsonb_build_object(v_sku_key, true);

    if v_name = '' then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'REQUIRED_NAME',
        'message', 'Nombre obligatorio'
      ));
      continue;
    end if;

    if v_price is null or v_price < 0 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'INVALID_PRICE',
        'message', 'Precio inválido'
      ));
      continue;
    end if;

    if v_stock is null or v_stock < 0 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'INVALID_STOCK',
        'message', 'Stock inválido'
      ));
      continue;
    end if;

    if v_sale is not null and (v_sale <= 0 or v_sale >= v_price) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'INVALID_SALE_PRICE',
        'message', 'Precio oferta debe ser mayor a 0 y menor que precio lista'
      ));
      continue;
    end if;

    if v_solo_divisas and v_discount is not null then
      v_discount := v_discount - 'usd_payment_discount_pct';
    end if;

    select pr.id
      into v_existing_id
    from public.products pr
    where pr.owner_id = v_uid
      and lower(trim(pr.sku)) = v_sku_key
    limit 1;

    if v_existing_id is not null then
      if v_upsert_mode = 'insert_only' then
        v_skipped := v_skipped + 1;
        continue;
      end if;

      if v_upsert_mode = 'price_stock_only' then
        update public.products pr
        set
          price_usd = v_price,
          stock = v_stock,
          min_order_qty = case
            when v_has_min then v_min_qty
            else pr.min_order_qty
          end,
          sale_price_usd = v_sale,
          discount_rules = case
            when v_discount is null then pr.discount_rules
            when v_discount = 'null'::jsonb then null
            else v_discount
          end,
          has_warranty = v_warranty,
          custom_fields = coalesce(pr.custom_fields, '{}'::jsonb) || v_custom
        where pr.id = v_existing_id;
      else
        update public.products pr
        set
          sku = v_sku,
          name = v_name,
          description = v_desc,
          price_usd = v_price,
          stock = v_stock,
          min_order_qty = case
            when v_has_min then v_min_qty
            else pr.min_order_qty
          end,
          sale_price_usd = v_sale,
          category = v_category,
          compatibility = v_compat,
          image_url = v_image,
          has_warranty = v_warranty,
          discount_rules = case
            when v_discount is null then pr.discount_rules
            when v_discount = 'null'::jsonb then null
            else v_discount
          end,
          custom_fields = coalesce(pr.custom_fields, '{}'::jsonb) || v_custom
        where pr.id = v_existing_id;
      end if;

      v_updated := v_updated + 1;
    else
      insert into public.products (
        owner_id,
        sku,
        name,
        description,
        price_usd,
        sale_price_usd,
        stock,
        min_order_qty,
        category,
        compatibility,
        image_url,
        is_active,
        has_warranty,
        discount_rules,
        custom_fields
      ) values (
        v_uid,
        v_sku,
        v_name,
        v_desc,
        v_price,
        v_sale,
        v_stock,
        coalesce(v_min_qty, 5),
        v_category,
        v_compat,
        v_image,
        v_new_active,
        v_warranty,
        case
          when v_discount is null or v_discount = 'null'::jsonb then null
          else v_discount
        end,
        coalesce(v_custom, '{}'::jsonb)
      )
      returning id into v_last_id;

      v_last_name := v_name;
      v_inserted := v_inserted + 1;
    end if;
  end loop;

  if v_new_active and v_inserted > 0 then
    perform public.mc_notify_catalog_published(
      v_uid,
      v_inserted,
      case when v_inserted = 1 then v_last_name else null end,
      case when v_inserted = 1 then v_last_id else null end
    );
  end if;

  return jsonb_build_object(
    'inserted', v_inserted,
    'updated', v_updated,
    'skipped', v_skipped,
    'errors', v_errors
  );
end;
$$;

grant execute on function public.importador_bulk_upsert_products (jsonb, jsonb) to authenticated;

-- Activar o pausar muchos SKU en el cuerpo del RPC, no en la URL.
create or replace function public.importador_set_products_active (
  p_ids uuid[],
  p_active boolean
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_count integer := 0;
  v_name text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden cambiar la visibilidad';
  end if;

  if p_active is null then
    raise exception 'p_active es obligatorio';
  end if;

  if p_ids is null or cardinality(p_ids) = 0 then
    return 0;
  end if;

  perform set_config('b2b.catalog_bulk', '1', true);

  with flipped as (
    update public.products pr
    set is_active = p_active
    where pr.owner_id = v_uid
      and pr.id = any (p_ids)
      and pr.is_active is distinct from p_active
    returning pr.id, pr.name
  )
  select
    count(*)::integer,
    (array_agg(flipped.name order by flipped.name))[1],
    (array_agg(flipped.id order by flipped.name))[1]
    into v_count, v_name, v_id
  from flipped;

  if p_active and v_count > 0 then
    perform public.mc_notify_catalog_published(
      v_uid,
      v_count,
      case when v_count = 1 then v_name else null end,
      case when v_count = 1 then v_id else null end
    );
  end if;

  return v_count;
end;
$$;

revoke all on function public.importador_set_products_active (uuid[], boolean) from public;
grant execute on function public.importador_set_products_active (uuid[], boolean) to authenticated;

comment on function public.importador_set_products_active (uuid[], boolean) is
  'Importador: activa o pausa sus productos y avisa el catálogo una sola vez.';

-- El administrador también publica varios SKU en un solo update.
create or replace function public.owner_set_importer_products_active (
  p_product_ids uuid[],
  p_is_active boolean
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_rec record;
  v_launches jsonb := '[]'::jsonb;
begin
  perform public._assert_administrador ();
  perform set_config('b2b.catalog_bulk', '1', true);

  if p_product_ids is null or cardinality(p_product_ids) = 0 then
    return 0;
  end if;

  if p_is_active is true then
    select coalesce(jsonb_agg(jsonb_build_object(
      'owner_id', g.owner_id,
      'n', g.n,
      'name', g.product_name,
      'product_id', g.product_id
    )), '[]'::jsonb)
      into v_launches
    from (
      select
        p.owner_id,
        count(*)::integer as n,
        (array_agg(p.name order by p.name))[1] as product_name,
        (array_agg(p.id order by p.name))[1] as product_id
      from public.products p
      join public.profiles pr on pr.id = p.owner_id
      where p.id = any (p_product_ids)
        and pr.role = 'importador'
        and p.is_active is distinct from true
      group by p.owner_id
    ) g;
  end if;

  update public.products p
  set is_active = p_is_active
  from public.profiles pr
  where p.id = any (p_product_ids)
    and p.owner_id = pr.id
    and pr.role = 'importador';

  get diagnostics v_count = row_count;

  if v_count > 0 then
    for v_rec in
      select
        p.owner_id,
        string_agg(p.name, ', ' order by p.name) as names,
        count(*)::integer as n
      from public.products p
      join public.profiles pr on pr.id = p.owner_id
      where p.id = any (p_product_ids)
        and pr.role = 'importador'
      group by p.owner_id
    loop
      if p_is_active then
        perform public.mc_insert_notification (
          v_rec.owner_id,
          'Producto publicado',
          case
            when v_rec.n = 1 then
              format(
                'B2B Conecta volvió a publicar «%s» en el catálogo.',
                v_rec.names
              )
            else
              format(
                'B2B Conecta volvió a publicar %s productos en el catálogo.',
                v_rec.n
              )
          end,
          'inventario',
          v_rec.owner_id::text
        );
      else
        perform public.mc_insert_notification (
          v_rec.owner_id,
          'Producto en pausa',
          case
            when v_rec.n = 1 then
              format(
                'B2B Conecta ocultó «%s» del catálogo. Las tiendas no lo verán.',
                v_rec.names
              )
            else
              format(
                'B2B Conecta pausó %s productos de su catálogo.',
                v_rec.n
              )
          end,
          'inventario',
          v_rec.owner_id::text
        );
      end if;
    end loop;
  end if;

  for v_rec in
    select
      (item ->> 'owner_id')::uuid as owner_id,
      (item ->> 'n')::integer as n,
      item ->> 'name' as product_name,
      nullif(item ->> 'product_id', '')::uuid as product_id
    from jsonb_array_elements(v_launches) item
  loop
    perform public.mc_notify_catalog_published(
      v_rec.owner_id,
      v_rec.n,
      case when v_rec.n = 1 then v_rec.product_name else null end,
      case when v_rec.n = 1 then v_rec.product_id else null end
    );
  end loop;

  return v_count;
end;
$$;
