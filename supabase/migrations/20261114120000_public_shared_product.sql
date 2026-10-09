-- Ficha pública de un producto activo, para quien abre un enlace sin sesión.
-- Solo datos de catálogo. Los campos ERP ocultos no salen. No permite pedidos.

create or replace function public._public_shared_custom_fields (p_fields jsonb)
returns jsonb
language sql
immutable
as $$
  select case
    when jsonb_typeof(coalesce(p_fields -> '_aliado_visible_keys', 'null'::jsonb)) = 'array'
      and jsonb_array_length(coalesce(p_fields -> '_aliado_visible_keys', '[]'::jsonb)) > 0
    then (
      select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb)
        || jsonb_build_object(
          '_aliado_visible_keys',
          p_fields -> '_aliado_visible_keys'
        )
      from jsonb_each(coalesce(p_fields, '{}'::jsonb)) e
      where (p_fields -> '_aliado_visible_keys') ? e.key
    )
    else '{}'::jsonb
  end;
$$;

create or replace function public._public_shared_product_json (
  p_product public.products,
  p_profile public.profiles
)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', p_product.id,
    'owner_id', p_product.owner_id,
    'name', p_product.name,
    'description', p_product.description,
    'compatibility', p_product.compatibility,
    'price_usd', p_product.price_usd,
    'sale_price_usd', p_product.sale_price_usd,
    'discount_rules', p_product.discount_rules,
    'stock', p_product.stock,
    'min_order_qty', p_product.min_order_qty,
    'image_url', p_product.image_url,
    'image_urls', p_product.image_urls,
    'sku', p_product.sku,
    'is_active', p_product.is_active,
    'category', p_product.category,
    'has_warranty', p_product.has_warranty,
    'custom_fields', public._public_shared_custom_fields(p_product.custom_fields),
    'profiles', jsonb_build_object(
      'business_name', p_profile.business_name,
      'logo_storage_path', p_profile.logo_storage_path,
      'estado', p_profile.estado,
      'ciudad', p_profile.ciudad,
      'latitude', p_profile.latitude,
      'longitude', p_profile.longitude,
      'pago_solo_divisas', p_profile.pago_solo_divisas,
      'rating_avg_received_rolling100', p_profile.rating_avg_received_rolling100,
      'rating_count_received_rolling100', p_profile.rating_count_received_rolling100,
      'catalog_paid_orders_30d', p_profile.catalog_paid_orders_30d,
      'min_order_amount_ref', p_profile.min_order_amount_ref,
      'min_order_currency', p_profile.min_order_currency,
      'catalog_featured_until', p_profile.catalog_featured_until,
      'catalog_verified_at', p_profile.catalog_verified_at
    )
  );
$$;

create or replace function public.public_shared_product (p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public._public_shared_product_json(pr, pf)
  from public.products pr
  join public.profiles pf on pf.id = pr.owner_id
  where pr.id = p_id
    and pr.is_active = true
    and pf.role = 'importador';
$$;

create or replace function public.public_shared_store (p_importador_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile public.profiles;
  v_products jsonb;
begin
  select pf.*
    into v_profile
  from public.profiles pf
  where pf.id = p_importador_id
    and pf.role = 'importador';

  if v_profile.id is null then
    return null;
  end if;

  select coalesce(jsonb_agg(item.payload), '[]'::jsonb)
    into v_products
  from (
    select public._public_shared_product_json(pr, v_profile) as payload
    from public.products pr
    where pr.owner_id = v_profile.id
      and pr.is_active = true
    order by pr.name
    limit 40
  ) item;

  return jsonb_build_object(
    'business_name', v_profile.business_name,
    'logo_storage_path', v_profile.logo_storage_path,
    'estado', v_profile.estado,
    'ciudad', v_profile.ciudad,
    'products', v_products
  );
end;
$$;

revoke all on function public._public_shared_custom_fields (jsonb) from public;
revoke all on function public._public_shared_product_json (public.products, public.profiles) from public;
revoke all on function public.public_shared_product (uuid) from public;
revoke all on function public.public_shared_store (uuid) from public;

grant execute on function public.public_shared_product (uuid) to anon, authenticated;
grant execute on function public.public_shared_store (uuid) to anon, authenticated;
