-- Búsqueda global admin (⌘K): usuarios + pedidos + productos (top N).

create or replace function public.admin_global_search (
  p_search_term text,
  p_limit int default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_q text;
  v_like text;
  v_compact text;
  v_limit int;
  v_users jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_products jsonb := '[]'::jsonb;
begin
  v_uid := public._require_admin ();
  v_q := lower(trim(coalesce(p_search_term, '')));
  if length(v_q) < 2 then
    return jsonb_build_object(
      'users', '[]'::jsonb,
      'orders', '[]'::jsonb,
      'products', '[]'::jsonb
    );
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 5), 10));
  v_like := '%' || v_q || '%';
  v_compact := regexp_replace(v_q, '[#\s\-]', '', 'g');

  select coalesce(jsonb_agg(row_to_json(u)::jsonb), '[]'::jsonb)
  into v_users
  from (
    select
      p.id,
      p.role,
      p.business_name,
      p.rif,
      p.cedula,
      p.phone,
      p.legal_contact_name,
      p.legal_contact_email,
      p.retailer_tier,
      p.account_access_status,
      p.logo_storage_path
    from public.profiles p
    where (
        lower(coalesce(p.business_name, '')) like v_like
        or lower(coalesce(p.legal_contact_name, '')) like v_like
        or lower(coalesce(p.legal_contact_email, '')) like v_like
        or lower(coalesce(p.rif, '')) like v_like
        or lower(coalesce(p.cedula, '')) like v_like
        or lower(coalesce(p.phone, '')) like v_like
        or p.id::text like v_like
      )
    order by
      case
        when lower(coalesce(p.business_name, '')) like v_q || '%' then 0
        when lower(coalesce(p.rif, '')) = v_q then 1
        else 2
      end,
      p.business_name nulls last
    limit v_limit
  ) u;

  select coalesce(jsonb_agg(row_to_json(o)::jsonb), '[]'::jsonb)
  into v_orders
  from (
    select
      tr.id,
      tr.status,
      tr.checkout_group_id,
      tr.precio_total_usd,
      tr.product_id,
      coalesce(pr.name, '') as product_name,
      coalesce(pr.sku, '') as product_sku,
      a.business_name as aliado_business_name,
      i.business_name as owner_business_name,
      tr.updated_at
    from public.transaction_requests tr
    left join public.products pr on pr.id = tr.product_id
    left join public.profiles a on a.id = tr.aliado_id
    left join public.profiles i on i.id = tr.importador_id
    where
      lower(coalesce(pr.name, '')) like v_like
      or lower(coalesce(pr.sku, '')) like v_like
      or lower(coalesce(a.business_name, '')) like v_like
      or lower(coalesce(i.business_name, '')) like v_like
      or lower(coalesce(a.rif, '')) like v_like
      or lower(coalesce(i.rif, '')) like v_like
      or tr.id::text like v_like
      or replace(lower(tr.id::text), '-', '') like '%' || v_compact || '%'
      or (
        tr.checkout_group_id is not null
        and (
          tr.checkout_group_id::text like v_like
          or replace(lower(tr.checkout_group_id::text), '-', '') like '%' || v_compact || '%'
        )
      )
    order by tr.updated_at desc
    limit v_limit
  ) o;

  select coalesce(jsonb_agg(row_to_json(p)::jsonb), '[]'::jsonb)
  into v_products
  from (
    select
      pr.id,
      pr.name as nombre,
      pr.sku,
      pr.price_usd as precio,
      pr.image_urls,
      pr.owner_id,
      own.business_name as owner_business_name,
      pr.is_active
    from public.products pr
    left join public.profiles own on own.id = pr.owner_id
    where coalesce(pr.is_active, true) is true
      and (
        lower(coalesce(pr.name, '')) like v_like
        or lower(coalesce(pr.sku, '')) like v_like
        or lower(coalesce(pr.category, '')) like v_like
        or lower(coalesce(own.business_name, '')) like v_like
        or pr.id::text like v_like
      )
    order by
      case
        when lower(coalesce(pr.sku, '')) = v_q then 0
        when lower(coalesce(pr.name, '')) like v_q || '%' then 1
        else 2
      end,
      pr.created_at desc nulls last
    limit v_limit
  ) p;

  return jsonb_build_object(
    'users', coalesce(v_users, '[]'::jsonb),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'products', coalesce(v_products, '[]'::jsonb)
  );
end;
$$;

comment on function public.admin_global_search (text, int) is
  'Admin ⌘K: top usuarios, pedidos y productos por término.';

revoke all on function public.admin_global_search (text, int) from public;
grant execute on function public.admin_global_search (text, int) to authenticated;
