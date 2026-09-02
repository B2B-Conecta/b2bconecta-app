-- Cantidad mínima de pedido por SKU (piso de plataforma = 5).
-- Catálogo aliado oculta si stock < min_order_qty.
-- El ajuste de cantidad en un pedido ya creado NO se valida aquí.

alter table public.products
  add column if not exists min_order_qty integer not null default 5;

alter table public.products
  drop constraint if exists products_min_order_qty_chk;

alter table public.products
  add constraint products_min_order_qty_chk check (min_order_qty >= 5);

comment on column public.products.min_order_qty is
  'Unidades mínimas para crear un pedido de este SKU. Piso de plataforma: 5. '
  'Piso (no múltiplos). El importador puede bajar cantidad en un pedido ya creado.';

alter table public.products
  add column if not exists stock_covers_min_order boolean
  generated always as (stock >= min_order_qty) stored;

comment on column public.products.stock_covers_min_order is
  'True si el stock alcanza el mínimo de pedido. El catálogo aliado filtra por esta columna.';

create index if not exists products_catalog_moq_idx
  on public.products (is_active, stock_covers_min_order)
  where is_active = true;

-- ---------------------------------------------------------------------------
-- Nuevo pedido: rechazar cantidad por debajo del mínimo.
-- No aplica a UPDATE (ajuste de negociación importador ↔ aliado).
-- ---------------------------------------------------------------------------
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
  select greatest(coalesce(pr.min_order_qty, 5), 5), pr.name
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

drop trigger if exists tr_enforce_min_order_qty on public.transaction_requests;
create trigger tr_enforce_min_order_qty
before insert on public.transaction_requests
for each row
execute function public.mc_tr_enforce_min_order_qty ();

-- ---------------------------------------------------------------------------
-- Aviso al importador cuando el SKU deja de ser pedible (stock < mínimo).
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_product_hidden_below_moq ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is null then
    return new;
  end if;
  if new.stock < new.min_order_qty
     and old.stock >= old.min_order_qty then
    perform public.mc_insert_notification (
      new.owner_id,
      'Producto oculto en catálogo',
      format(
        '«%s» quedó con %s unidad(es), por debajo del mínimo de pedido (%s). '
        'Los aliados no lo verán hasta que reponga inventario.',
        coalesce(
          nullif(trim(new.name), ''),
          coalesce(nullif(trim(new.sku), ''), 'SKU')
        ),
        new.stock,
        new.min_order_qty
      ),
      'inventario',
      new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists products_notify_hidden_below_moq_trg on public.products;
create trigger products_notify_hidden_below_moq_trg
after update of stock, min_order_qty on public.products
for each row
execute function public.mc_notify_product_hidden_below_moq ();

-- ---------------------------------------------------------------------------
-- Carga masiva: acepta min_order_qty (vacío = 5 en altas; en updates se conserva).
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
      );

      v_inserted := v_inserted + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'inserted', v_inserted,
    'updated', v_updated,
    'skipped', v_skipped,
    'errors', v_errors
  );
end;
$$;

grant execute on function public.importador_bulk_upsert_products (jsonb, jsonb) to authenticated;
