-- Política de envío del proveedor para la vitrina.
-- NO_DEFINIDO no muestra badge. INCLUIDO y APARTE sí. A_CONVENIR avisa que se acuerda.

alter table public.profiles
  add column if not exists envio_tipo text not null default 'NO_DEFINIDO',
  add column if not exists monto_minimo_envio_gratis numeric(14, 2),
  add column if not exists transportistas_habilitados jsonb not null default '[]'::jsonb;

alter table public.profiles
  drop constraint if exists profiles_envio_tipo_chk;

alter table public.profiles
  add constraint profiles_envio_tipo_chk
  check (
    envio_tipo = any (
      array['INCLUIDO'::text, 'APARTE'::text, 'A_CONVENIR'::text, 'NO_DEFINIDO'::text]
    )
  );

alter table public.profiles
  drop constraint if exists profiles_monto_minimo_envio_gratis_chk;

alter table public.profiles
  add constraint profiles_monto_minimo_envio_gratis_chk
  check (monto_minimo_envio_gratis is null or monto_minimo_envio_gratis >= 0);

comment on column public.profiles.envio_tipo is
  'Política de flete en la vitrina: INCLUIDO, APARTE, A_CONVENIR o NO_DEFINIDO.';

comment on column public.profiles.monto_minimo_envio_gratis is
  'Monto opcional en USD/REF a partir del cual el envío es gratis.';

comment on column public.profiles.transportistas_habilitados is
  'Nombres de agencias que el proveedor ofrece (jsonb array de texto).';

create or replace function public.importador_set_envio_politica (
  p_tipo text,
  p_monto_minimo numeric,
  p_transportistas jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo text := upper(trim(coalesce(p_tipo, 'NO_DEFINIDO')));
  v_monto numeric;
  v_names jsonb := '[]'::jsonb;
  v_item text;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'importador'
      and p.deactivated_at is null
  ) then
    raise exception 'Solo el proveedor puede configurar el envío'
      using errcode = '42501';
  end if;

  if v_tipo not in ('INCLUIDO', 'APARTE', 'A_CONVENIR', 'NO_DEFINIDO') then
    raise exception 'Política de envío no válida';
  end if;

  if p_monto_minimo is null or p_monto_minimo <= 0 or v_tipo = 'NO_DEFINIDO' then
    v_monto := null;
  else
    v_monto := round(p_monto_minimo, 2);
  end if;

  if jsonb_typeof(coalesce(p_transportistas, '[]'::jsonb)) = 'array' then
    for v_item in
      select left(btrim(value), 40)
      from jsonb_array_elements_text(p_transportistas) as t(value)
      where length(btrim(value)) > 0
      limit 12
    loop
      if not v_names ? v_item then
        v_names := v_names || to_jsonb(v_item);
      end if;
    end loop;
  end if;

  if v_tipo = 'NO_DEFINIDO' then
    v_names := '[]'::jsonb;
  end if;

  update public.profiles
  set envio_tipo = v_tipo,
      monto_minimo_envio_gratis = v_monto,
      transportistas_habilitados = v_names
  where id = auth.uid();
end;
$$;

revoke all on function public.importador_set_envio_politica (text, numeric, jsonb) from public;
grant execute on function public.importador_set_envio_politica (text, numeric, jsonb) to authenticated;

create or replace function public.list_aliado_product_favorites()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if not public._caller_is_aliado() then
    raise exception 'Solo la tienda minorista puede ver favoritos';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        to_jsonb(p) || jsonb_build_object(
          'profiles', jsonb_build_object(
            'business_name', pr.business_name,
            'logo_storage_path', pr.logo_storage_path,
            'estado', pr.estado,
            'ciudad', pr.ciudad,
            'latitude', pr.latitude,
            'longitude', pr.longitude,
            'pago_solo_divisas', pr.pago_solo_divisas,
            'envio_tipo', pr.envio_tipo,
            'monto_minimo_envio_gratis', pr.monto_minimo_envio_gratis,
            'transportistas_habilitados', pr.transportistas_habilitados,
            'rating_avg_received_rolling100', pr.rating_avg_received_rolling100,
            'rating_count_received_rolling100', pr.rating_count_received_rolling100,
            'catalog_paid_orders_30d', pr.catalog_paid_orders_30d,
            'min_order_amount_ref', pr.min_order_amount_ref,
            'min_order_currency', pr.min_order_currency,
            'catalog_featured_until', pr.catalog_featured_until,
            'catalog_verified_at', pr.catalog_verified_at
          )
        )
        order by f.created_at desc
      )
      from public.aliado_product_favorites f
      join public.products p on p.id = f.product_id
      left join public.profiles pr on pr.id = p.owner_id
      where f.user_id = v_uid
    ),
    '[]'::jsonb
  );
end;
$$;

revoke all on function public.list_aliado_product_favorites() from public;
grant execute on function public.list_aliado_product_favorites() to authenticated;

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
      'envio_tipo', p_profile.envio_tipo,
      'monto_minimo_envio_gratis', p_profile.monto_minimo_envio_gratis,
      'transportistas_habilitados', p_profile.transportistas_habilitados,
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
