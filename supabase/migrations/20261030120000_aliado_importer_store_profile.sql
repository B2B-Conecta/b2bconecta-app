-- Perfil de mayorista para tiendas minoristas: solo importador activo y su catálogo.

create index if not exists products_owner_active_category_idx
  on public.products (owner_id, category)
  where is_active = true;

create or replace function public._importer_store_is_public (p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_id
      and p.role = 'importador'::text
      and p.deactivated_at is null
      and coalesce(nullif(btrim(p.account_access_status), ''), 'active') = 'active'
  );
$$;

create or replace function public._assert_importer_store_viewer ()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if auth.uid () is null then
    raise exception 'No hay sesión activa' using errcode = '42501';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = auth.uid ();

  if v_role is distinct from 'aliado'::text
     and v_role is distinct from 'administrador'::text then
    raise exception 'Solo tiendas minoristas pueden abrir el perfil del mayorista'
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.aliado_importer_store_profile (p_importador_id uuid)
returns table (
  id uuid,
  business_name text,
  rif text,
  phone text,
  estado text,
  ciudad text,
  direccion text,
  fiscal_maps_url text,
  logo_storage_path text,
  rating_avg_received_rolling100 numeric,
  rating_count_received_rolling100 integer,
  min_order_amount_ref numeric,
  min_order_currency text,
  catalog_featured_until timestamptz,
  pago_solo_divisas boolean,
  accepted_pago_metodos text[]
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public._assert_importer_store_viewer ();

  if p_importador_id is null or not public._importer_store_is_public (p_importador_id) then
    return;
  end if;

  return query
  select
    p.id,
    p.business_name,
    p.rif,
    p.phone,
    p.estado,
    p.ciudad,
    p.direccion,
    p.fiscal_maps_url,
    p.logo_storage_path,
    p.rating_avg_received_rolling100,
    p.rating_count_received_rolling100,
    p.min_order_amount_ref,
    p.min_order_currency,
    p.catalog_featured_until,
    coalesce(p.pago_solo_divisas, false),
    p.accepted_pago_metodos
  from public.profiles p
  where p.id = p_importador_id;
end;
$$;

create or replace function public.aliado_importer_store_categories (p_importador_id uuid)
returns table (category text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public._assert_importer_store_viewer ();

  if p_importador_id is null or not public._importer_store_is_public (p_importador_id) then
    return;
  end if;

  return query
  select distinct pr.category as category
  from public.products pr
  where pr.owner_id = p_importador_id
    and pr.is_active = true
    and coalesce(pr.stock_covers_min_order, false) = true
    and nullif(btrim(pr.category), '') is not null
  order by 1;
end;
$$;

revoke all on function public._importer_store_is_public (uuid) from public, anon, authenticated;
revoke all on function public._assert_importer_store_viewer () from public, anon, authenticated;
revoke all on function public.aliado_importer_store_profile (uuid) from public, anon;
revoke all on function public.aliado_importer_store_categories (uuid) from public, anon;

grant execute on function public._importer_store_is_public (uuid) to postgres, service_role;
grant execute on function public._assert_importer_store_viewer () to postgres, service_role;
grant execute on function public.aliado_importer_store_profile (uuid) to authenticated;
grant execute on function public.aliado_importer_store_categories (uuid) to authenticated;

comment on function public.aliado_importer_store_profile (uuid) is
  'Tienda minorista: ficha pública de un mayorista activo. Vacío = no existe o no es visible.';

comment on function public.aliado_importer_store_categories (uuid) is
  'Categorías distintas de products.category del mayorista (solo activos y con stock de vitrina).';
