-- Owner: catálogo completo de un mayorista (incluye SKUs en pausa).
-- RLS de products solo deja ver is_active = true a terceros.

create or replace function public.owner_list_importer_catalog (p_importador_id uuid)
returns table (
  id uuid,
  name text,
  sku text,
  category text,
  price_usd numeric,
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
  perform public._assert_owner ();

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

comment on function public.owner_list_importer_catalog (uuid) is
  'Owner: listado de productos de un importador, incluyendo pausados.';
