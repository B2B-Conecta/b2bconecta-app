-- Motor de productos relacionados (fallback jerárquico).
-- Nivel 1: vinculaciones manuales (product_related_links).
-- Nivel 2: misma categoría (mismo proveedor primero).
-- Nivel 3: populares del proveedor → similitud nombre/SKU → destacados/rotación global.

-- ---------------------------------------------------------------------------
-- Vinculaciones explícitas (admin / importador puede poblar después).
-- ---------------------------------------------------------------------------
create table if not exists public.product_related_links (
  product_id uuid not null references public.products (id) on delete cascade,
  related_product_id uuid not null references public.products (id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (product_id, related_product_id),
  constraint product_related_links_no_self check (product_id <> related_product_id)
);

create index if not exists product_related_links_related_idx
  on public.product_related_links (related_product_id);

comment on table public.product_related_links is
  'Asociaciones manuales producto→producto para el carrusel de relacionados.';

alter table public.product_related_links enable row level security;

drop policy if exists product_related_links_select_authenticated
  on public.product_related_links;
create policy product_related_links_select_authenticated
  on public.product_related_links
  for select
  to authenticated
  using (true);

drop policy if exists product_related_links_write_owner
  on public.product_related_links;
create policy product_related_links_write_owner
  on public.product_related_links
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.products p
      where p.id = product_related_links.product_id
        and p.owner_id = auth.uid ()
    )
  )
  with check (
    exists (
      select 1
      from public.products p
      where p.id = product_related_links.product_id
        and p.owner_id = auth.uid ()
    )
  );

grant select on public.product_related_links to authenticated;
grant insert, update, delete on public.product_related_links to authenticated;

-- ---------------------------------------------------------------------------
-- Contador de rotación (proxy de ventas) + índices de soporte.
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists sales_count integer not null default 0;

comment on column public.products.sales_count is
  'Unidades pedidas históricas (proxy de rotación para recomendaciones).';

create index if not exists products_active_category_idx
  on public.products (category)
  where is_active = true and nullif(trim(category), '') is not null;

create index if not exists products_owner_active_sales_idx
  on public.products (owner_id, sales_count desc)
  where is_active = true;

create index if not exists products_active_sales_idx
  on public.products (sales_count desc)
  where is_active = true;

-- Backfill desde pedidos entregados / en tránsito / preparados (histórico).
update public.products p
set sales_count = coalesce(s.units, 0)
from (
  select
    tr.product_id,
    sum(greatest(coalesce(tr.cantidad, 0), 0))::integer as units
  from public.transaction_requests tr
  where tr.product_id is not null
    and tr.status in (
      'entregado',
      'en_transito',
      'pedido_listo',
      'en_preparacion',
      'confirmado'
    )
  group by tr.product_id
) s
where p.id = s.product_id
  and p.sales_count is distinct from coalesce(s.units, 0);

-- Mantener sales_count al pasar a entregado (incremento neto de cantidad).
create or replace function public.products_bump_sales_count_on_entregado ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.product_id is null then
    return new;
  end if;
  if new.status = 'entregado'
     and (tg_op = 'INSERT' or coalesce(old.status, '') is distinct from 'entregado') then
    update public.products
    set sales_count = sales_count + greatest(coalesce(new.cantidad, 0), 0)
    where id = new.product_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_products_bump_sales_count_on_entregado
  on public.transaction_requests;
create trigger trg_products_bump_sales_count_on_entregado
  after insert or update of status, cantidad
  on public.transaction_requests
  for each row
  execute function public.products_bump_sales_count_on_entregado ();

-- ---------------------------------------------------------------------------
-- RPC: get_related_products_fallback
-- ---------------------------------------------------------------------------
create or replace function public.get_related_products_fallback (
  p_product_id uuid,
  p_limit integer default 6
)
returns table (
  product_id uuid,
  tier integer,
  score real
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 6), 24));
  v_owner uuid;
  v_category text;
  v_name text;
  v_sku text;
  v_tokens text[];
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if p_product_id is null then
    return;
  end if;

  select
    pr.owner_id,
    nullif(trim(pr.category), ''),
    coalesce(pr.name, ''),
    coalesce(pr.sku, '')
  into v_owner, v_category, v_name, v_sku
  from public.products pr
  where pr.id = p_product_id;

  if not found then
    return;
  end if;

  -- Tokens cortos del título para similitud (nivel 3b).
  select coalesce(array_agg(x.t), array[]::text[])
  into v_tokens
  from (
    select raw.t
    from (
      select unnest(
        string_to_array(
          public.normalize_search_text (v_name || ' ' || v_sku),
          ' '
        )
      ) as t
    ) raw
    where char_length(raw.t) >= 4
    group by raw.t
    order by char_length(raw.t) desc
    limit 8
  ) x;

  return query
  with picked as (
    -- Nivel 1: vínculos manuales activos y comprables.
    select
      l.related_product_id as pid,
      1 as tier,
      (1000 - coalesce(l.sort_order, 0))::real
        + least(coalesce(r.sales_count, 0), 500)::real / 1000.0 as score
    from public.product_related_links l
    join public.products r on r.id = l.related_product_id
    where l.product_id = p_product_id
      and r.id <> p_product_id
      and r.is_active = true
      and coalesce(r.stock_covers_min_order, false) = true

    union all

    -- Nivel 2: misma categoría (mismo owner primero).
    select
      c.id as pid,
      2 as tier,
      (
        case when c.owner_id = v_owner then 200 else 100 end
        + least(coalesce(c.sales_count, 0), 500)
      )::real as score
    from public.products c
    where v_category is not null
      and c.id <> p_product_id
      and c.is_active = true
      and coalesce(c.stock_covers_min_order, false) = true
      and nullif(trim(c.category), '') = v_category
      and not exists (
        select 1
        from public.product_related_links l
        where l.product_id = p_product_id
          and l.related_product_id = c.id
      )

    union all

    -- Nivel 3a: populares del mismo proveedor (sin categoría o para rellenar).
    select
      o.id as pid,
      3 as tier,
      (500 + least(coalesce(o.sales_count, 0), 500))::real as score
    from public.products o
    where v_owner is not null
      and o.owner_id = v_owner
      and o.id <> p_product_id
      and o.is_active = true
      and coalesce(o.stock_covers_min_order, false) = true
      and (
        v_category is null
        or nullif(trim(o.category), '') is distinct from v_category
      )
      and not exists (
        select 1
        from public.product_related_links l
        where l.product_id = p_product_id
          and l.related_product_id = o.id
      )

    union all

    -- Nivel 3b: similitud de título/SKU (pg_trgm).
    select
      s.id as pid,
      4 as tier,
      greatest(
        similarity (
          public.normalize_search_text (v_name),
          public.normalize_search_text (s.name)
        ),
        word_similarity (
          public.normalize_search_text (v_name),
          public.normalize_search_text (s.name)
        ),
        similarity (
          public.normalize_search_text (v_sku),
          public.normalize_search_text (coalesce(s.sku, ''))
        ),
        case
          when cardinality(v_tokens) > 0
            and exists (
              select 1
              from unnest(v_tokens) tok
              where public.normalize_search_text (s.name) like '%' || tok || '%'
            )
          then 0.35
          else 0.0
        end
      )::real as score
    from public.products s
    where s.id <> p_product_id
      and s.is_active = true
      and coalesce(s.stock_covers_min_order, false) = true
      and (
        similarity (
          public.normalize_search_text (v_name),
          public.normalize_search_text (s.name)
        ) >= 0.22
        or word_similarity (
          public.normalize_search_text (v_name),
          public.normalize_search_text (s.name)
        ) >= 0.28
        or (
          nullif(trim(v_sku), '') is not null
          and similarity (
            public.normalize_search_text (v_sku),
            public.normalize_search_text (coalesce(s.sku, ''))
          ) >= 0.35
        )
        or (
          cardinality(v_tokens) > 0
          and exists (
            select 1
            from unnest(v_tokens) tok
            where public.normalize_search_text (s.name) like '%' || tok || '%'
          )
        )
      )
      and not exists (
        select 1
        from public.product_related_links l
        where l.product_id = p_product_id
          and l.related_product_id = s.id
      )

    union all

    -- Nivel 3c: rotación / sellos globales (featured o más vendidos).
    select
      g.id as pid,
      5 as tier,
      (
        case
          when pf.catalog_featured_until is not null
            and pf.catalog_featured_until > now() then 300
          else 0
        end
        + least(coalesce(g.sales_count, 0), 500)
        + least(coalesce(pf.catalog_paid_orders_30d, 0), 100)
      )::real as score
    from public.products g
    join public.profiles pf on pf.id = g.owner_id
    where g.id <> p_product_id
      and g.is_active = true
      and coalesce(g.stock_covers_min_order, false) = true
      and (
        (pf.catalog_featured_until is not null and pf.catalog_featured_until > now())
        or coalesce(g.sales_count, 0) > 0
        or coalesce(pf.catalog_paid_orders_30d, 0) >= 3
      )
      and not exists (
        select 1
        from public.product_related_links l
        where l.product_id = p_product_id
          and l.related_product_id = g.id
      )
  ),
  ranked as (
    select
      p.pid,
      min(p.tier) as tier,
      max(p.score) as score
    from picked p
    group by p.pid
  )
  select
    r.pid as product_id,
    r.tier::integer,
    r.score::real
  from ranked r
  order by r.tier asc, r.score desc, r.pid
  limit v_limit;
end;
$$;

comment on function public.get_related_products_fallback (uuid, integer) is
  'Productos relacionados: vínculos manuales → misma categoría → populares proveedor → similitud → rotación global.';

grant execute on function public.get_related_products_fallback (uuid, integer)
  to authenticated;
