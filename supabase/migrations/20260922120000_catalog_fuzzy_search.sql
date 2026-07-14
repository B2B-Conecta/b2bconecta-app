-- Catálogo: búsqueda flexible (plurales / typos leves) con pg_trgm.
-- RPC devuelve product_id + score; el cliente Flutter aplica el resto de filtros CatalogFilters.

-- En Supabase hosted, pg_trgm/unaccent viven en schema `extensions`.
-- No silenciar errores: sin la extensión los índices GIN fallan con gin_trgm_ops.
do $ext$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_trgm') then
    create extension pg_trgm with schema extensions;
  end if;
exception
  when duplicate_object then
    null;
end;
$ext$;

do $ext$
begin
  if not exists (select 1 from pg_extension where extname = 'unaccent') then
    create extension unaccent with schema extensions;
  end if;
exception
  when duplicate_object then
    null;
end;
$ext$;

-- Obliga a que el operator class exista antes de crear índices.
do $check$
begin
  if not exists (
    select 1
    from pg_opclass opc
    join pg_namespace n on n.oid = opc.opcnamespace
    where opc.opcname = 'gin_trgm_ops'
      and n.nspname in ('extensions', 'public')
  ) then
    raise exception
      'pg_trgm no disponible: gin_trgm_ops ausente. Habilite la extensión en Database → Extensions.';
  end if;
end;
$check$;

-- Wrapper inmutable para índices (patrón habitual con unaccent).
create or replace function public.immutable_unaccent (t text)
returns text
language sql
immutable
parallel safe
strict
set search_path = public, extensions
as $$
  select unaccent (t);
$$;

create or replace function public.normalize_search_text (t text)
returns text
language sql
immutable
parallel safe
set search_path = public, extensions
as $$
  select trim(both from lower(public.immutable_unaccent (coalesce(t, ''))));
$$;

comment on function public.normalize_search_text (text) is
  'Normaliza texto de búsqueda: minúsculas + sin acentos.';

-- Variante ligera de plural ES: quita s/es final en tokens largos (no es stemming completo).
create or replace function public.search_query_variants (p_query text)
returns text[]
language plpgsql
immutable
parallel safe
set search_path = public, extensions
as $$
declare
  v_norm text := public.normalize_search_text (p_query);
  v_stem text;
  v_out text[] := array[]::text[];
begin
  if v_norm is null or v_norm = '' then
    return v_out;
  end if;

  v_out := array_append(v_out, v_norm);

  if char_length(v_norm) > 4 and v_norm ~ 'es$' then
    v_stem := regexp_replace(v_norm, 'es$', '');
    if char_length(v_stem) >= 3 then
      v_out := array_append(v_out, v_stem);
    end if;
  elsif char_length(v_norm) > 4 and v_norm ~ 's$' and v_norm !~ 'us$' and v_norm !~ 'is$' then
    v_stem := regexp_replace(v_norm, 's$', '');
    if char_length(v_stem) >= 3 then
      v_out := array_append(v_out, v_stem);
    end if;
  elsif char_length(v_norm) >= 4 and v_norm !~ 's$' then
    -- Singular en query → también probar plural simple en catálogo.
    v_out := array_append(v_out, v_norm || 's');
    if v_norm ~ '[aeiou]$' then
      v_out := array_append(v_out, v_norm || 'es');
    end if;
  end if;

  return (
    select coalesce(array_agg(distinct x order by x), array[]::text[])
    from unnest(v_out) as x
    where nullif(trim(x), '') is not null
  );
end;
$$;

-- Índices trigram: operator class en schema extensions (Supabase hosted).
create index if not exists products_name_trgm_idx
  on public.products
  using gin (public.normalize_search_text (name) extensions.gin_trgm_ops);

create index if not exists products_compatibility_trgm_idx
  on public.products
  using gin (public.normalize_search_text (compatibility) extensions.gin_trgm_ops);

create index if not exists products_sku_trgm_idx
  on public.products
  using gin (public.normalize_search_text (sku) extensions.gin_trgm_ops);

create index if not exists products_description_trgm_idx
  on public.products
  using gin (public.normalize_search_text (description) extensions.gin_trgm_ops);

create index if not exists products_category_trgm_idx
  on public.products
  using gin (public.normalize_search_text (category) extensions.gin_trgm_ops);

create index if not exists products_custom_fields_trgm_idx
  on public.products
  using gin (public.normalize_search_text (custom_fields::text) extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Busca IDs de productos (texto fuzzy + ubicación del importador).
-- SECURITY INVOKER: respeta RLS de products / profiles.
-- ---------------------------------------------------------------------------
create or replace function public.search_catalog_product_ids (
  p_query text,
  p_limit integer default 800,
  p_similarity_threshold real default 0.28
)
returns table (
  product_id uuid,
  score real
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 800), 2000));
  v_thr real := greatest(0.15, least(coalesce(p_similarity_threshold, 0.28), 0.9));
  v_variants text[];
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  v_variants := public.search_query_variants (p_query);
  if v_variants is null or cardinality(v_variants) = 0 then
    return;
  end if;

  return query
  with variants as (
    select unnest(v_variants) as q
  ),
  loc_owners as (
    select p.id
    from public.profiles p
    cross join variants v
    where p.role = 'importador'
      and (
        public.normalize_search_text (p.estado) like '%' || v.q || '%'
        or public.normalize_search_text (p.ciudad) like '%' || v.q || '%'
        or word_similarity (v.q, public.normalize_search_text (coalesce(p.estado, ''))) >= v_thr
        or word_similarity (v.q, public.normalize_search_text (coalesce(p.ciudad, ''))) >= v_thr
      )
    limit 120
  ),
  scored as (
    select
      pr.id as pid,
      max(
        greatest(
          case
            when public.normalize_search_text (pr.name) like '%' || v.q || '%' then 1.0
            when public.normalize_search_text (pr.sku) like '%' || v.q || '%' then 0.98
            when public.normalize_search_text (coalesce(pr.compatibility, '')) like '%' || v.q || '%' then 0.92
            when public.normalize_search_text (coalesce(pr.category, '')) like '%' || v.q || '%' then 0.88
            when public.normalize_search_text (coalesce(pr.description, '')) like '%' || v.q || '%' then 0.85
            when public.normalize_search_text (coalesce(pr.custom_fields::text, '')) like '%' || v.q || '%' then 0.8
            else 0.0
          end,
          word_similarity (v.q, public.normalize_search_text (pr.name)),
          similarity (v.q, public.normalize_search_text (pr.name)),
          word_similarity (v.q, public.normalize_search_text (coalesce(pr.compatibility, ''))),
          word_similarity (v.q, public.normalize_search_text (coalesce(pr.sku, ''))),
          word_similarity (v.q, public.normalize_search_text (coalesce(pr.category, ''))),
          word_similarity (v.q, public.normalize_search_text (coalesce(pr.description, ''))),
          word_similarity (
            v.q,
            public.normalize_search_text (coalesce(pr.custom_fields::text, ''))
          ),
          case when pr.owner_id in (select lo.id from loc_owners lo) then 0.75 else 0.0 end
        )
      )::real as match_score
    from public.products pr
    cross join variants v
    where
      public.normalize_search_text (pr.name) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.sku, '')) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.compatibility, '')) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.category, '')) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.description, '')) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.custom_fields::text, '')) like '%' || v.q || '%'
      or word_similarity (v.q, public.normalize_search_text (pr.name)) >= v_thr
      or similarity (v.q, public.normalize_search_text (pr.name)) >= v_thr
      or word_similarity (
        v.q,
        public.normalize_search_text (coalesce(pr.compatibility, ''))
      ) >= v_thr
      or word_similarity (
        v.q,
        public.normalize_search_text (coalesce(pr.sku, ''))
      ) >= v_thr
      or word_similarity (
        v.q,
        public.normalize_search_text (coalesce(pr.category, ''))
      ) >= v_thr
      or word_similarity (
        v.q,
        public.normalize_search_text (coalesce(pr.description, ''))
      ) >= v_thr
      or word_similarity (
        v.q,
        public.normalize_search_text (coalesce(pr.custom_fields::text, ''))
      ) >= v_thr
      or pr.owner_id in (select lo.id from loc_owners lo)
    group by pr.id
  )
  select s.pid, s.match_score
  from scored s
  where s.match_score >= least(v_thr, 0.5)
  order by s.match_score desc, s.pid
  limit v_limit;
end;
$$;

comment on function public.search_catalog_product_ids (text, integer, real) is
  'Catálogo: IDs de products por búsqueda flexible (trgm + plural ligero + ubicación importador).';

grant execute on function public.immutable_unaccent (text) to authenticated;
grant execute on function public.normalize_search_text (text) to authenticated;
grant execute on function public.search_query_variants (text) to authenticated;
grant execute on function public.search_catalog_product_ids (text, integer, real) to authenticated;
