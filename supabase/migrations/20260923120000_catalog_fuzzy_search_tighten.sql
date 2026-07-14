-- Endurece búsqueda fuzzy del catálogo: menos falsos positivos.
-- Cambios clave:
-- 1) Fuzzy (trgm) solo sobre name (+ sku estricto); no description/custom_fields/category.
-- 2) Ubicación importador solo por substring (sin word_similarity).
-- 3) Umbral por defecto más alto (0.45).
-- 4) Queries cortas (< 4): solo match literal (LIKE), sin fuzzy.

create or replace function public.search_catalog_product_ids (
  p_query text,
  p_limit integer default 800,
  p_similarity_threshold real default 0.45
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
  v_thr real := greatest(0.4, least(coalesce(p_similarity_threshold, 0.45), 0.9));
  v_variants text[];
  v_primary text;
  v_allow_fuzzy boolean;
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  v_variants := public.search_query_variants (p_query);
  if v_variants is null or cardinality(v_variants) = 0 then
    return;
  end if;

  v_primary := public.normalize_search_text (p_query);
  v_allow_fuzzy := char_length(v_primary) >= 4;

  return query
  with variants as (
    select unnest(v_variants) as q
  ),
  loc_owners as (
    -- Solo coincidencia literal de ubicación (evita inundar catálogo por fuzzy de ciudad).
    select distinct p.id
    from public.profiles p
    cross join variants v
    where p.role = 'importador'
      and (
        public.normalize_search_text (coalesce(p.estado, '')) like '%' || v.q || '%'
        or public.normalize_search_text (coalesce(p.ciudad, '')) like '%' || v.q || '%'
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
            when public.normalize_search_text (coalesce(pr.sku, '')) like '%' || v.q || '%' then 0.96
            when public.normalize_search_text (coalesce(pr.compatibility, '')) like '%' || v.q || '%'
              then 0.9
            else 0.0
          end,
          case
            when v_allow_fuzzy then
              word_similarity (v.q, public.normalize_search_text (pr.name))
            else 0.0
          end,
          case
            when v_allow_fuzzy
              and nullif(trim(pr.sku), '') is not null
            then word_similarity (v.q, public.normalize_search_text (pr.sku)) * 0.9
            else 0.0
          end,
          case
            when pr.owner_id in (select lo.id from loc_owners lo) then 0.72
            else 0.0
          end
        )
      )::real as match_score
    from public.products pr
    cross join variants v
    where
      -- Match fuerte: substring en campos relevantes
      public.normalize_search_text (pr.name) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.sku, '')) like '%' || v.q || '%'
      or public.normalize_search_text (coalesce(pr.compatibility, '')) like '%' || v.q || '%'
      -- Fuzzy solo sobre el nombre (typos), umbral alto
      or (
        v_allow_fuzzy
        and word_similarity (v.q, public.normalize_search_text (pr.name)) >= v_thr
      )
      -- SKU fuzzy un poco más estricto
      or (
        v_allow_fuzzy
        and nullif(trim(pr.sku), '') is not null
        and word_similarity (v.q, public.normalize_search_text (pr.sku)) >= (v_thr + 0.05)
      )
      or pr.owner_id in (select lo.id from loc_owners lo)
    group by pr.id
  )
  select s.pid, s.match_score
  from scored s
  where s.match_score >= case
      when v_allow_fuzzy then v_thr
      else 0.72
    end
  order by s.match_score desc, s.pid
  limit v_limit;
end;
$$;

comment on function public.search_catalog_product_ids (text, integer, real) is
  'Catálogo: búsqueda flexible acotada (name/sku/compat + ubicación literal; umbral alto).';

grant execute on function public.search_catalog_product_ids (text, integer, real) to authenticated;
