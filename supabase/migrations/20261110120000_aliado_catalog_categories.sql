-- Categorías distintas del catálogo visible para la tienda minorista.

create or replace function public.aliado_catalog_categories ()
returns table (category text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public._assert_importer_store_viewer ();

  return query
  select distinct btrim(pr.category) as category
  from public.products pr
  where pr.is_active = true
    and coalesce(pr.stock_covers_min_order, false) = true
    and nullif(btrim(pr.category), '') is not null
    and public._importer_store_is_public (pr.owner_id)
  order by 1;
end;
$$;

revoke all on function public.aliado_catalog_categories () from public, anon;
grant execute on function public.aliado_catalog_categories () to authenticated;

comment on function public.aliado_catalog_categories () is
  'Categorías distintas de products.category en el catálogo visible (activos, con stock de vitrina, mayorista público).';
