-- Owner: pausar / publicar / eliminar productos de un mayorista.
-- RLS de products no permite update/delete a terceros.

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
begin
  perform public._assert_owner ();

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
  return v_count;
end;
$$;

create or replace function public.owner_delete_importer_products (p_product_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  perform public._assert_owner ();

  if p_product_ids is null or cardinality(p_product_ids) = 0 then
    return 0;
  end if;

  delete from public.products p
  using public.profiles pr
  where p.id = any (p_product_ids)
    and p.owner_id = pr.id
    and pr.role = 'importador';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.owner_set_importer_products_active (uuid[], boolean) from public;
revoke all on function public.owner_delete_importer_products (uuid[]) from public;

grant execute on function public.owner_set_importer_products_active (uuid[], boolean) to authenticated;
grant execute on function public.owner_delete_importer_products (uuid[]) to authenticated;

comment on function public.owner_set_importer_products_active (uuid[], boolean) is
  'Owner: publica o pausa SKUs de un mayorista.';
comment on function public.owner_delete_importer_products (uuid[]) is
  'Owner: elimina SKUs de un mayorista. Pedidos conservan historial (product_id null).';
