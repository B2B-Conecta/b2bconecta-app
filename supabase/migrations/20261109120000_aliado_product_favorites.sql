-- Favoritos de la tienda minorista. Un SKU de un importador es un favorito.
-- La lista incluye productos pausados: el catálogo público los oculta por RLS.

create table if not exists public.aliado_product_favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists aliado_product_favorites_user_idx
  on public.aliado_product_favorites (user_id, created_at desc);

alter table public.aliado_product_favorites enable row level security;

create policy aliado_product_favorites_select_own
  on public.aliado_product_favorites for select
  to authenticated
  using (auth.uid() = user_id);

create policy aliado_product_favorites_delete_own
  on public.aliado_product_favorites for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, delete on public.aliado_product_favorites to authenticated;

create or replace function public._caller_is_aliado()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'aliado'
  );
$$;

revoke all on function public._caller_is_aliado() from public;
grant execute on function public._caller_is_aliado() to authenticated;

create or replace function public.set_aliado_product_favorite(
  p_product_id uuid,
  p_saved boolean
)
returns boolean
language plpgsql
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
    raise exception 'Solo la tienda minorista puede guardar favoritos';
  end if;
  if p_product_id is null then
    raise exception 'Producto requerido';
  end if;

  if p_saved then
    if not exists (
      select 1
      from public.products pr
      where pr.id = p_product_id
        and pr.is_active = true
    ) then
      raise exception 'Este producto no está disponible para guardar';
    end if;
    insert into public.aliado_product_favorites (user_id, product_id)
    values (v_uid, p_product_id)
    on conflict (user_id, product_id) do nothing;
    return true;
  end if;

  delete from public.aliado_product_favorites
  where user_id = v_uid
    and product_id = p_product_id;
  return false;
end;
$$;

revoke all on function public.set_aliado_product_favorite(uuid, boolean) from public;
grant execute on function public.set_aliado_product_favorite(uuid, boolean) to authenticated;

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
