-- Directorio minorista: solo fichas públicas y compras del usuario conectado.
create or replace function public.aliado_supplier_directory(
  p_query text default '', p_filter text default 'all',
  p_estado text default null, p_category text default null,
  p_limit integer default 40, p_offset integer default 0
) returns jsonb
language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_query text := pg_catalog.translate(pg_catalog.lower(pg_catalog.left(pg_catalog.btrim(coalesce(p_query, '')), 120)), 'áéíóúüñ', 'aeiouun');
  v_result jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles me where me.id = auth.uid()
      and me.role in ('aliado', 'administrador')
  ) then
    raise exception 'Acceso no permitido' using errcode = '42501';
  end if;
  if p_filter is null or p_filter not in ('all', 'purchased', 'rated') then
    raise exception 'Filtro de proveedores inválido' using errcode = '22023';
  end if;

  with stores as materialized (
    select p.id, p.business_name, p.estado, p.ciudad, p.logo_storage_path,
      p.rating_avg_received_rolling100, p.rating_count_received_rolling100,
      p.catalog_verified_at, p.catalog_featured_until,
      coalesce((select pg_catalog.array_agg(distinct pg_catalog.btrim(x.category) order by pg_catalog.btrim(x.category))
        from public.products x where x.owner_id = p.id and x.is_active
        and nullif(pg_catalog.btrim(x.category), '') is not null), array[]::text[]) as categories,
      exists (select 1 from public.transaction_requests t
        where t.aliado_id = auth.uid() and t.importador_id = p.id
          and not coalesce(t.cancelado_por_aliado, false)
          and t.status not in ('rechazado', 'cancelado')
          and (t.status in ('aprobado_admin', 'en_preparacion', 'pedido_listo', 'en_transito', 'enviado', 'entregado')
               or t.pago_aprobado_at is not null)) as purchased
    from public.profiles p
    where p.role = 'importador' and p.deactivated_at is null
      and coalesce(nullif(pg_catalog.btrim(p.account_access_status), ''), 'active') = 'active'
      and exists (select 1 from public.products x where x.owner_id = p.id and x.is_active)
  ), matched as (
    select s.* from stores s
    where (p_filter <> 'purchased' or s.purchased)
      and (p_filter <> 'rated' or (s.rating_count_received_rolling100 > 0 and s.rating_avg_received_rolling100 is not null))
      and (nullif(p_estado, '') is null or s.estado = p_estado)
      and (nullif(p_category, '') is null or p_category = any(s.categories))
      and (v_query = '' or pg_catalog.strpos(pg_catalog.translate(pg_catalog.lower(pg_catalog.concat_ws(' ', s.business_name, s.estado, s.ciudad)), 'áéíóúüñ', 'aeiouun'), v_query) > 0
        or exists (select 1 from public.products x where x.owner_id = s.id and x.is_active
          and (pg_catalog.strpos(pg_catalog.translate(pg_catalog.lower(pg_catalog.concat_ws(' ', x.name, x.sku, x.description, x.category)), 'áéíóúüñ', 'aeiouun'), v_query) > 0
            or exists (select 1 from pg_catalog.jsonb_each_text(case when pg_catalog.jsonb_typeof(x.custom_fields) = 'object' then x.custom_fields else '{}'::jsonb end) brand
              where brand.key in ('marca', 'brand', 'col_marca', 'col_brand', 'marca_proveedor')
                and (case when pg_catalog.jsonb_typeof(x.custom_fields -> '_aliado_visible_keys') = 'array' then x.custom_fields -> '_aliado_visible_keys' else '[]'::jsonb end) ? brand.key
                and pg_catalog.strpos(pg_catalog.translate(pg_catalog.lower(brand.value), 'áéíóúüñ', 'aeiouun'), v_query) > 0))))
  ), page as (
    select m.* from matched m
    order by case when p_filter = 'all' then m.purchased end desc nulls last,
      case when p_filter = 'rated' then m.rating_avg_received_rolling100 end desc nulls last,
      case when p_filter = 'rated' then m.rating_count_received_rolling100 end desc nulls last,
      pg_catalog.lower(coalesce(m.business_name, '')), m.id
    limit greatest(1, least(coalesce(p_limit, 40), 100)) offset greatest(coalesce(p_offset, 0), 0)
  )
  select pg_catalog.jsonb_build_object(
    'items', coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(page)) from page), '[]'::jsonb),
    'total', (select count(*) from matched),
    'states', coalesce((select pg_catalog.jsonb_agg(e order by e) from (select distinct estado e from stores where nullif(pg_catalog.btrim(estado), '') is not null) a), '[]'::jsonb),
    'categories', coalesce((select pg_catalog.jsonb_agg(c order by c) from (select distinct pg_catalog.unnest(categories) c from stores) a), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.aliado_supplier_directory(text,text,text,text,integer,integer) from public, anon;
grant execute on function public.aliado_supplier_directory(text,text,text,text,integer,integer) to authenticated;
comment on function public.aliado_supplier_directory(text,text,text,text,integer,integer)
  is 'Directorio paginado, búsqueda de productos y marcas publicadas, historial personal; respeta RLS.';
