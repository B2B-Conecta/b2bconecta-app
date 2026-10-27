-- MOQ: el 5 es el valor por defecto si el proveedor no define mínimo.
-- Si lo define, esa cantidad manda (piso absoluto 1).

alter table public.products
  drop constraint if exists products_min_order_qty_chk;

alter table public.products
  add constraint products_min_order_qty_chk check (min_order_qty >= 1);

comment on column public.products.min_order_qty is
  'Unidades mínimas para crear un pedido de este SKU. '
  'Default de plataforma: 5 cuando el proveedor no define uno. '
  'Si el proveedor define un valor, ese manda (mínimo absoluto: 1).';

create or replace function public.mc_tr_enforce_min_order_qty ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_min integer;
  v_name text;
begin
  select
    case
      when pr.min_order_qty is null or pr.min_order_qty < 1 then 5
      else pr.min_order_qty
    end,
    pr.name
    into v_min, v_name
  from public.products pr
  where pr.id = new.product_id;

  if v_min is not null and new.cantidad < v_min then
    raise exception
      'Cantidad mínima de pedido para «%» es % unidad(es).',
      coalesce(nullif(trim(v_name), ''), 'este producto'),
      v_min;
  end if;
  return new;
end;
$$;

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
  v_parent text;
  v_attr_name text;
  v_attr_value text;
  v_variant_key text;
  v_variant_clash uuid;
  v_seen_variants jsonb := '{}'::jsonb;
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
      if v_min_qty < 1 then
        v_errors := v_errors || jsonb_build_array(jsonb_build_object(
          'row_index', v_row_index,
          'sku', v_sku,
          'code', 'INVALID_MIN_ORDER_QTY',
          'message', 'La cantidad mínima de pedido debe ser 1 o más'
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

    v_parent := nullif(lower(btrim(coalesce(v_row ->> 'parent_sku', ''))), '');
    v_attr_name := nullif(btrim(coalesce(v_row ->> 'variant_attribute_name', '')), '');
    v_attr_value := nullif(btrim(coalesce(v_row ->> 'variant_attribute_value', '')), '');

    if v_parent is not null and v_attr_value is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'row_index', v_row_index,
        'sku', v_sku,
        'code', 'REQUIRED_VARIANT_VALUE',
        'message', 'La variante necesita un valor (presentación, medida, color)'
      ));
      continue;
    end if;

    if v_parent is not null then
      v_variant_key := v_parent || '|' || lower(v_attr_value);
      if v_seen_variants ? v_variant_key then
        v_errors := v_errors || jsonb_build_array(jsonb_build_object(
          'row_index', v_row_index,
          'sku', v_sku,
          'code', 'DUPLICATE_VARIANT_IN_FILE',
          'message', 'Otra fila del lote ya usa esa opción para el mismo producto padre'
        ));
        continue;
      end if;
      v_seen_variants := v_seen_variants || jsonb_build_object(v_variant_key, true);
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

    if v_parent is not null then
      select pr.id
        into v_variant_clash
      from public.products pr
      where pr.owner_id = v_uid
        and pr.parent_sku = v_parent
        and lower(btrim(pr.variant_attribute_value)) = lower(v_attr_value)
        and pr.id is distinct from v_existing_id
      limit 1;

      if v_variant_clash is not null then
        v_errors := v_errors || jsonb_build_array(jsonb_build_object(
          'row_index', v_row_index,
          'sku', v_sku,
          'code', 'DUPLICATE_VARIANT_OPTION',
          'message', 'Esa opción ya existe en otro SKU del mismo producto padre'
        ));
        continue;
      end if;
    end if;

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
          custom_fields = coalesce(pr.custom_fields, '{}'::jsonb) || v_custom,
          parent_sku = case
            when v_row ? 'parent_sku' then v_parent
            else pr.parent_sku
          end,
          variant_attribute_name = case
            when v_row ? 'variant_attribute_name' then v_attr_name
            else pr.variant_attribute_name
          end,
          variant_attribute_value = case
            when v_row ? 'variant_attribute_value' then v_attr_value
            else pr.variant_attribute_value
          end
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
          custom_fields = coalesce(pr.custom_fields, '{}'::jsonb) || v_custom,
          parent_sku = case
            when v_row ? 'parent_sku' then v_parent
            else pr.parent_sku
          end,
          variant_attribute_name = case
            when v_row ? 'variant_attribute_name' then v_attr_name
            else pr.variant_attribute_name
          end,
          variant_attribute_value = case
            when v_row ? 'variant_attribute_value' then v_attr_value
            else pr.variant_attribute_value
          end
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
        custom_fields,
        parent_sku,
        variant_attribute_name,
        variant_attribute_value
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
        coalesce(v_custom, '{}'::jsonb),
        v_parent,
        v_attr_name,
        v_attr_value
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
