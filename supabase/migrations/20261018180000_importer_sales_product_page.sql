-- Listado paginado de ventas/rotación para catálogos grandes (100–1M SKUs).
-- El snapshot del importador vuelve a un preview de 8 filas.

create or replace function public.importador_sales_snapshot (p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_from timestamptz;
  v_snap jsonb;
  v_top_total integer := 0;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid
    and p.deactivated_at is null;

  if v_role is distinct from 'importador' then
    raise exception 'Solo importadores' using errcode = '42501';
  end if;

  v_snap := public.mc_importer_sales_snapshot_json (v_uid, v_days, 8);
  v_from := now() - make_interval(days => v_days);

  select coalesce(count(distinct tr.product_id), 0)::integer
    into v_top_total
  from public.transaction_requests tr
  where tr.importador_id = v_uid
    and tr.created_at >= v_from
    and tr.status is distinct from 'rechazado';

  return v_snap || jsonb_build_object (
    'top_total', v_top_total,
    'low_total', coalesce((v_snap ->> 'products_active')::integer, 0)
  );
end;
$$;

create or replace function public.importador_sales_product_page (
  p_days integer default 30,
  p_kind text default 'top',
  p_search text default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  v_kind text := lower(trim(coalesce(p_kind, 'top')));
  v_search text;
  v_limit integer := least (greatest (coalesce(p_limit, 25), 1), 50);
  v_offset integer := least (greatest (coalesce(p_offset, 0), 0), 50000);
  v_from timestamptz;
  v_total integer := 0;
  v_items jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid
    and p.deactivated_at is null;

  if v_role is distinct from 'importador' then
    raise exception 'Solo importadores' using errcode = '42501';
  end if;

  if v_kind not in ('top', 'low') then
    v_kind := 'top';
  end if;

  v_search := nullif(trim(p_search), '');
  if v_search is not null then
    v_search := left(v_search, 80);
    v_search := replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_');
  end if;

  v_from := now() - make_interval(days => v_days);

  if v_kind = 'top' then
    select count(*)::integer
      into v_total
    from (
      select tr.product_id
      from public.transaction_requests tr
      left join public.products pr on pr.id = tr.product_id
      where tr.importador_id = v_uid
        and tr.created_at >= v_from
        and tr.status is distinct from 'rechazado'
        and (
          v_search is null
          or coalesce(pr.name, '') ilike '%' || v_search || '%' escape '\'
        )
      group by tr.product_id
    ) t;

    select coalesce(
      jsonb_agg (
        jsonb_build_object (
          'product_id', s.product_id,
          'name', s.product_name,
          'units', s.units,
          'revenue', s.revenue
        )
        order by s.units desc, s.revenue desc
      ),
      '[]'::jsonb
    )
      into v_items
    from (
      select
        tr.product_id,
        coalesce(nullif(trim(pr.name), ''), 'Producto') as product_name,
        sum(tr.cantidad)::integer as units,
        sum(tr.precio_total_usd)::numeric as revenue
      from public.transaction_requests tr
      left join public.products pr on pr.id = tr.product_id
      where tr.importador_id = v_uid
        and tr.created_at >= v_from
        and tr.status is distinct from 'rechazado'
        and (
          v_search is null
          or coalesce(pr.name, '') ilike '%' || v_search || '%' escape '\'
        )
      group by tr.product_id, pr.name
      order by units desc, revenue desc
      limit v_limit
      offset v_offset
    ) s;
  else
    select count(*)::integer
      into v_total
    from public.products p
    where p.owner_id = v_uid
      and coalesce(p.is_active, true)
      and (
        v_search is null
        or coalesce(p.name, '') ilike '%' || v_search || '%' escape '\'
      );

    select coalesce(
      jsonb_agg (
        jsonb_build_object (
          'product_id', s.product_id,
          'name', s.product_name,
          'units', s.units
        )
        order by s.units asc, s.product_name asc
      ),
      '[]'::jsonb
    )
      into v_items
    from (
      select
        p.id as product_id,
        coalesce(nullif(trim(p.name), ''), 'Producto') as product_name,
        coalesce(x.units, 0)::integer as units
      from public.products p
      left join (
        select tr.product_id, sum(tr.cantidad)::integer as units
        from public.transaction_requests tr
        where tr.importador_id = v_uid
          and tr.created_at >= v_from
          and tr.status is distinct from 'rechazado'
        group by tr.product_id
      ) x on x.product_id = p.id
      where p.owner_id = v_uid
        and coalesce(p.is_active, true)
        and (
          v_search is null
          or coalesce(p.name, '') ilike '%' || v_search || '%' escape '\'
        )
      order by coalesce(x.units, 0) asc, p.name asc
      limit v_limit
      offset v_offset
    ) s;
  end if;

  return jsonb_build_object (
    'kind', v_kind,
    'days', v_days,
    'total', coalesce(v_total, 0),
    'limit', v_limit,
    'offset', v_offset,
    'items', coalesce(v_items, '[]'::jsonb)
  );
end;
$$;

comment on function public.importador_sales_product_page (integer, text, text, integer, integer) is
  'Página de más vendidos o poca rotación (búsqueda + offset, máx. 50 por página).';

revoke all on function public.importador_sales_product_page (integer, text, text, integer, integer)
  from public;
grant execute on function public.importador_sales_product_page (integer, text, text, integer, integer)
  to authenticated;
