-- Keep the SKU minimum for when a product is removed from a combined group.
create table public.product_minimum_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  minimum_units integer not null check (minimum_units >= 2),
  unique (id, owner_id)
);

create index product_minimum_groups_owner_idx
  on public.product_minimum_groups (owner_id);
alter table public.product_minimum_groups enable row level security;
revoke all on public.product_minimum_groups from public, anon, authenticated;
grant select on public.product_minimum_groups to authenticated;
create policy "Suppliers read their combined minimums"
  on public.product_minimum_groups for select to authenticated
  using (owner_id = (select auth.uid()));

alter table public.products
  add column minimum_group_id uuid,
  add column combined_minimum jsonb,
  add constraint products_own_minimum_group
    foreign key (minimum_group_id, owner_id)
    references public.product_minimum_groups(id, owner_id) deferrable,
  add constraint products_minimum_group_requires_owner
    check (minimum_group_id is null or owner_id is not null);

create index products_minimum_group_idx
  on public.products (minimum_group_id, id) where minimum_group_id is not null;

alter table public.products
  alter column stock_covers_min_order set expression as (
    (stock - stock_reserved) >= case when minimum_group_id is null then min_order_qty else 1 end
  );

create or replace function public.mc_notify_product_hidden_below_moq()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_min integer := case when new.minimum_group_id is null then new.min_order_qty else 1 end;
begin
  if new.owner_id is not null and old.stock_covers_min_order and not new.stock_covers_min_order then
    perform public.mc_insert_notification(
      new.owner_id,
      'Producto oculto en catálogo',
      format('«%s» tiene %s unidad(es) disponibles y necesita al menos %s para venderse.',
        coalesce(nullif(btrim(new.name), ''), nullif(btrim(new.sku), ''), 'SKU'),
        greatest(new.stock - new.stock_reserved, 0), v_min),
      'inventario',
      new.id::text
    );
  end if;
  return new;
end;
$$;

-- Only checkout RPCs assign an order group. Single-product requests still
-- use the existing direct insert policy.
create policy tr_insert_requires_checkout_for_group
  on public.transaction_requests as restrictive for insert to authenticated
  with check (checkout_group_id is null);

create function b2b_private.sync_product_combined_minimum()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.combined_minimum := null;
  if new.minimum_group_id is not null then
    select jsonb_build_object('id', g.id, 'name', g.name, 'minimum_units', g.minimum_units)
      into new.combined_minimum
    from public.product_minimum_groups g
    where g.id = new.minimum_group_id and g.owner_id = new.owner_id;
  end if;
  return new;
end;
$$;
revoke all on function b2b_private.sync_product_combined_minimum() from public, anon, authenticated;
create trigger products_sync_combined_minimum
before insert or update of minimum_group_id, combined_minimum, owner_id on public.products
for each row execute function b2b_private.sync_product_combined_minimum();

create function b2b_private.save_product_minimum_group(
  p_group_id uuid, p_name text, p_minimum_units integer, p_product_ids uuid[]
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_group uuid := p_group_id;
  v_ids uuid[] := coalesce(p_product_ids, '{}'::uuid[]);
  v_name text := nullif(btrim(p_name), '');
begin
  -- Serialize rule edits for the same supplier and verify current ownership.
  if v_owner is null then
    raise exception 'Inicia sesión para gestionar mínimos de compra.' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('combined_minimum:' || v_owner::text, 0));
  if not exists (select 1 from public.profiles where id = v_owner and role = 'importador') then
    raise exception 'Solo el mayorista puede gestionar sus mínimos de compra.' using errcode = '42501';
  end if;
  if v_group is not null and not exists (
    select 1 from public.product_minimum_groups where id = v_group and owner_id = v_owner
  ) then
    raise exception 'El grupo ya no está disponible.' using errcode = '42501';
  end if;

  -- Lock affected products in a stable order before checking membership.
  perform p.id from public.products p
  where p.owner_id = v_owner and (p.id = any(v_ids) or p.minimum_group_id = v_group)
  order by p.id for update;

  if p_name is null and v_group is not null then
    update public.products set minimum_group_id = null
    where minimum_group_id = v_group and owner_id = v_owner;
    delete from public.product_minimum_groups where id = v_group and owner_id = v_owner;
    return v_group;
  end if;

  if v_name is null or char_length(v_name) > 60 or coalesce(p_minimum_units, 0) < 2 then
    raise exception 'Indica un nombre y un mínimo de al menos 2 unidades.' using errcode = '22023';
  end if;
  if cardinality(v_ids) < 1 or cardinality(v_ids) <> (
    select count(*) from public.products p
    where p.owner_id = v_owner and p.id = any(v_ids)
      and (p.minimum_group_id is null or p.minimum_group_id = v_group)
  ) then
    raise exception 'Selecciona referencias de tu inventario que estén disponibles para este grupo.'
      using errcode = '22023';
  end if;

  if v_group is null then
    insert into public.product_minimum_groups (owner_id, name, minimum_units)
    values (v_owner, v_name, p_minimum_units) returning id into v_group;
  else
    update public.product_minimum_groups set name = v_name, minimum_units = p_minimum_units
    where id = v_group and owner_id = v_owner;
  end if;

  update public.products set minimum_group_id = null
  where minimum_group_id = v_group and owner_id = v_owner and not (id = any(v_ids));
  update public.products set minimum_group_id = v_group
  where owner_id = v_owner and id = any(v_ids);
  return v_group;
end;
$$;
revoke all on function b2b_private.save_product_minimum_group(uuid,text,integer,uuid[]) from public, anon, authenticated;
grant usage on schema b2b_private to authenticated;
grant execute on function b2b_private.save_product_minimum_group(uuid,text,integer,uuid[]) to authenticated;

create function public.save_product_minimum_group(
  p_group_id uuid, p_name text, p_minimum_units integer, p_product_ids uuid[]
) returns uuid language sql security invoker set search_path = ''
as $$ select b2b_private.save_product_minimum_group($1, $2, $3, $4); $$;
revoke all on function public.save_product_minimum_group(uuid,text,integer,uuid[]) from public, anon, authenticated;
grant execute on function public.save_product_minimum_group(uuid,text,integer,uuid[]) to authenticated;

-- The same line guard is shared by the cart RPCs and standalone order inserts.
create or replace function public.mc_tr_enforce_min_order_qty()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_min integer;
  v_name text;
  v_group_id uuid;
  v_owner uuid;
begin
  select case
    when g.id is null then greatest(coalesce(p.min_order_qty, 1), 1)
    when new.checkout_group_id is null then g.minimum_units
    else 1 end, coalesce(g.name, p.name), g.id, p.owner_id
    into v_min, v_name, v_group_id, v_owner
  from public.products p
  left join public.product_minimum_groups g on g.id = p.minimum_group_id and g.owner_id = p.owner_id
  where p.id = new.product_id;

  if v_group_id is not null and new.importador_id is distinct from v_owner then
    raise exception 'El producto no corresponde al proveedor del pedido.' using errcode = '23514';
  end if;
  if new.cantidad < v_min then
    raise exception 'Cantidad mínima de pedido para «%» es % unidad(es).', v_name, v_min;
  end if;
  return new;
end;
$$;

create function b2b_private.enforce_checkout_combined_minimum()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_group public.product_minimum_groups%rowtype;
  v_units bigint;
begin
  select g.* into v_group from public.products p
  join public.product_minimum_groups g on g.id = p.minimum_group_id and g.owner_id = p.owner_id
  where p.id = new.product_id and p.owner_id = new.importador_id;
  if not found then return null; end if;

  select coalesce(sum(tr.cantidad), 0) into v_units
  from public.transaction_requests tr
  join public.products p on p.id = tr.product_id and p.owner_id = tr.importador_id
  where tr.checkout_group_id = new.checkout_group_id and tr.aliado_id = new.aliado_id
    and tr.importador_id = v_group.owner_id and p.minimum_group_id = v_group.id;
  if v_units < v_group.minimum_units then
    raise exception 'El mínimo combinado de «%» es % unidades. Llevas %.',
      v_group.name, v_group.minimum_units, v_units
      using errcode = '23514';
  end if;
  return null;
end;
$$;
revoke all on function b2b_private.enforce_checkout_combined_minimum() from public, anon, authenticated;
create constraint trigger tr_checkout_combined_minimum
after insert on public.transaction_requests deferrable initially deferred
for each row when (new.checkout_group_id is not null)
execute function b2b_private.enforce_checkout_combined_minimum();

-- The mixed-currency RPC still has a historical floor of five. Use the shared
-- insert guard here as well, preserving its checkout and pricing logic.
do $migration$
declare
  v_signature constant regprocedure :=
    'public.aliado_checkout_proveedores_v1(jsonb,boolean,text,text,jsonb,jsonb,jsonb,text,jsonb)'::regprocedure;
  v_definition text := pg_get_functiondef(v_signature);
  v_pattern constant text :=
    'if rec\.cantidad < \(select greatest\(coalesce\(p\.min_order_qty,\s*5\),\s*5\) from public\.products p where p\.id\s*=\s*rec\.product_id\) then\s+raise exception ''No se alcanza el mínimo de unidades del producto\.'';\s+end if;';
begin
  if (select count(*) from regexp_matches(v_definition, v_pattern, 'gi')) <> 1 then
    raise exception 'Revise el mínimo por producto en % antes de migrar.', v_signature;
  end if;
  execute regexp_replace(v_definition, v_pattern, '-- Validado por tr_enforce_min_order_qty al insertar.', 'i');
end;
$migration$;

create or replace function public._public_shared_product_json(
  p_product public.products, p_profile public.profiles
) returns jsonb language sql stable set search_path = ''
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
    'stock_reserved', p_product.stock_reserved,
    'min_order_qty', p_product.min_order_qty,
    'combined_minimum', p_product.combined_minimum,
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

notify pgrst, 'reload schema';
