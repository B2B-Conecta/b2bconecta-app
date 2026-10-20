-- Un administrador puede ocultar o volver a mostrar productos de un mayorista.
-- La lista incluye los pausados para poder recuperarlos desde Reportes.

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
begin
  perform public._assert_administrador ();

  if p_product_ids is null or cardinality(p_product_ids) = 0 then
    return 0;
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

  return v_count;
end;
$$;

drop function if exists public.owner_list_importer_catalog (uuid);

create function public.owner_list_importer_catalog (p_importador_id uuid)
returns table (
  id uuid,
  name text,
  sku text,
  category text,
  price_usd numeric,
  sale_price_usd numeric,
  stock integer,
  min_order_qty integer,
  is_active boolean,
  created_at timestamptz,
  image_url text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Importador requerido' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles pr
    where pr.id = p_importador_id
      and pr.role = 'importador'
  ) then
    raise exception 'La cuenta no es un mayorista' using errcode = '22023';
  end if;

  return query
  select
    p.id,
    p.name,
    p.sku,
    p.category,
    p.price_usd,
    p.sale_price_usd,
    p.stock,
    p.min_order_qty,
    p.is_active,
    p.created_at,
    p.image_url
  from public.products p
  where p.owner_id = p_importador_id
  order by
    p.is_active desc,
    p.name;
end;
$$;

revoke all on function public.owner_list_importer_catalog (uuid) from public;
grant execute on function public.owner_list_importer_catalog (uuid) to authenticated;

comment on function public.owner_set_importer_products_active (uuid[], boolean) is
  'Administrador: publica u oculta SKUs de un mayorista.';
comment on function public.owner_list_importer_catalog (uuid) is
  'Administrador: productos de un importador, publicados y ocultos.';
