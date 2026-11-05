-- Visibilidad de vallas: vigencia por día calendario (America/Caracas)
-- y creativo válido con imagen desktop o móvil.

-- Normaliza fines guardados a medianoche → fin del día Caracas.
update public.promo_campaigns c
set ends_at = (
  ((c.ends_at at time zone 'America/Caracas')::date + interval '1 day'
    - interval '1 second')
  at time zone 'America/Caracas'
)
where extract(hour from (c.ends_at at time zone 'America/Caracas')) = 0
  and extract(minute from (c.ends_at at time zone 'America/Caracas')) = 0
  and extract(second from (c.ends_at at time zone 'America/Caracas')) < 1;

create or replace function public.promo_campaign_is_live (
  p_starts timestamptz,
  p_ends timestamptz
)
returns boolean
language sql
stable
as $$
  select
    (timezone('America/Caracas', p_starts))::date
      <= (timezone('America/Caracas', now()))::date
    and (timezone('America/Caracas', p_ends))::date
      >= (timezone('America/Caracas', now()))::date;
$$;

comment on function public.promo_campaign_is_live (timestamptz, timestamptz) is
  'True si la valla cubre el día calendario actual en America/Caracas (inicio y fin inclusivos).';

create or replace function public.promo_campaign_has_creative (
  p_image_public_url text,
  p_mobile_image_public_url text
)
returns boolean
language sql
immutable
as $$
  select
    nullif(btrim(coalesce(p_image_public_url, '')), '') is not null
    or nullif(btrim(coalesce(p_mobile_image_public_url, '')), '') is not null;
$$;

create or replace function public.get_active_promo_campaigns_for_aliado()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'display_title', c.display_title,
        'campaign_type', c.campaign_type,
        'image_public_url', coalesce(
          nullif(btrim(c.image_public_url), ''),
          nullif(btrim(c.mobile_image_public_url), '')
        ),
        'mobile_image_public_url', c.mobile_image_public_url,
        'importador_id', c.importador_id,
        'product_id', c.product_id,
        'product_ids', to_jsonb(coalesce(c.product_ids, '{}'::uuid[])),
        'discount_percent', c.discount_percent,
        'product_discount_percents', coalesce(c.product_discount_percents, '{}'::jsonb),
        'starts_at', c.starts_at,
        'ends_at', c.ends_at,
        'action_type', c.action_type,
        'priority', c.priority,
        'sponsor_type', c.sponsor_type,
        'audience', c.audience,
        'advertiser_name', c.advertiser_name,
        'external_url', c.external_url
      )
      order by c.priority desc, c.created_at desc
    ),
    '[]'::jsonb
  )
  from public.promo_campaigns c
  where c.is_active = true
    and public.promo_campaign_is_live (c.starts_at, c.ends_at)
    and public.promo_campaign_has_creative (c.image_public_url, c.mobile_image_public_url)
    and c.audience in ('aliado', 'ambos');
$$;

create or replace function public.get_active_promo_campaigns_for_importador_ads ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'display_title', c.display_title,
        'campaign_type', c.campaign_type,
        'image_public_url', coalesce(
          nullif(btrim(c.image_public_url), ''),
          nullif(btrim(c.mobile_image_public_url), '')
        ),
        'mobile_image_public_url', c.mobile_image_public_url,
        'action_type', c.action_type,
        'priority', c.priority,
        'sponsor_type', c.sponsor_type,
        'audience', c.audience,
        'advertiser_name', c.advertiser_name,
        'external_url', c.external_url,
        'starts_at', c.starts_at,
        'ends_at', c.ends_at
      )
      order by c.priority desc, c.created_at desc
    ),
    '[]'::jsonb
  )
  from public.promo_campaigns c
  where c.sponsor_type = 'tercero'
    and c.is_active = true
    and public.promo_campaign_is_live (c.starts_at, c.ends_at)
    and public.promo_campaign_has_creative (c.image_public_url, c.mobile_image_public_url)
    and c.audience in ('importador', 'ambos');
$$;

create or replace function public.get_active_promo_product_discounts ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(
      p.product_id::text,
      jsonb_build_object(
        'campaign_id', p.campaign_id,
        'discount_percent', p.discount_percent,
        'display_title', p.display_title
      )
    ),
    '{}'::jsonb
  )
  from (
    select distinct on (pid)
      pid as product_id,
      c.id as campaign_id,
      public.promo_effective_product_discount_percent (
        c.product_discount_percents,
        pid,
        c.discount_percent
      ) as discount_percent,
      c.display_title
    from public.promo_campaigns c
    cross join lateral unnest(coalesce(c.product_ids, '{}'::uuid[])) as pid
    where c.is_active = true
      and public.promo_campaign_is_live (c.starts_at, c.ends_at)
      and c.sponsor_type = 'importador'
      and c.audience in ('aliado', 'ambos')
      and public.promo_effective_product_discount_percent (
        c.product_discount_percents,
        pid,
        c.discount_percent
      ) > 0
      and public.promo_effective_product_discount_percent (
        c.product_discount_percents,
        pid,
        c.discount_percent
      ) < 100
    order by
      pid,
      c.priority desc,
      public.promo_effective_product_discount_percent (
        c.product_discount_percents,
        pid,
        c.discount_percent
      ) desc,
      c.created_at desc
  ) p;
$$;

create or replace function public.promo_resolve_discount_for_product (
  p_product_id uuid,
  p_importador_id uuid,
  p_preferred_campaign_id uuid default null
)
returns table (
  campaign_id uuid,
  discount_percent numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_eff numeric;
begin
  if p_preferred_campaign_id is not null then
    select
      c.id,
      public.promo_effective_product_discount_percent (
        c.product_discount_percents,
        p_product_id,
        c.discount_percent
      )
    into v_id, v_eff
    from public.promo_campaigns c
    where c.id = p_preferred_campaign_id
      and c.importador_id = p_importador_id
      and c.is_active = true
      and public.promo_campaign_is_live (c.starts_at, c.ends_at)
      and c.sponsor_type = 'importador'
      and p_product_id = any (coalesce(c.product_ids, '{}'::uuid[]))
    limit 1;

    if found then
      if v_eff is not null and v_eff > 0 and v_eff < 100 then
        campaign_id := v_id;
        discount_percent := v_eff;
        return next;
      end if;
      return;
    end if;
  end if;

  return query
  select
    c.id,
    public.promo_effective_product_discount_percent (
      c.product_discount_percents,
      p_product_id,
      c.discount_percent
    )
  from public.promo_campaigns c
  where c.importador_id = p_importador_id
    and c.is_active = true
    and public.promo_campaign_is_live (c.starts_at, c.ends_at)
    and c.sponsor_type = 'importador'
    and p_product_id = any (coalesce(c.product_ids, '{}'::uuid[]))
    and public.promo_effective_product_discount_percent (
      c.product_discount_percents,
      p_product_id,
      c.discount_percent
    ) > 0
    and public.promo_effective_product_discount_percent (
      c.product_discount_percents,
      p_product_id,
      c.discount_percent
    ) < 100
  order by
    c.priority desc,
    public.promo_effective_product_discount_percent (
      c.product_discount_percents,
      p_product_id,
      c.discount_percent
    ) desc,
    c.created_at desc
  limit 1;
end;
$$;

create or replace function public.get_active_promo_campaigns_for_importador ()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'display_title', c.display_title,
        'internal_title', c.internal_title,
        'campaign_type', c.campaign_type,
        'image_public_url', coalesce(
          nullif(btrim(c.image_public_url), ''),
          nullif(btrim(c.mobile_image_public_url), '')
        ),
        'mobile_image_public_url', c.mobile_image_public_url,
        'starts_at', c.starts_at,
        'ends_at', c.ends_at,
        'priority', c.priority
      )
      order by c.priority desc, c.created_at desc
    ),
    '[]'::jsonb
  )
  from public.promo_campaigns c
  where c.importador_id = auth.uid ()
    and c.sponsor_type = 'importador'
    and c.is_active = true
    and public.promo_campaign_is_live (c.starts_at, c.ends_at)
    and public.promo_campaign_has_creative (c.image_public_url, c.mobile_image_public_url);
$$;

grant execute on function public.promo_campaign_is_live (timestamptz, timestamptz)
  to authenticated;
grant execute on function public.promo_campaign_has_creative (text, text)
  to authenticated;
grant execute on function public.get_active_promo_campaigns_for_aliado ()
  to authenticated;
grant execute on function public.get_active_promo_campaigns_for_importador_ads ()
  to authenticated;
grant execute on function public.get_active_promo_campaigns_for_importador ()
  to authenticated;
grant execute on function public.get_active_promo_product_discounts ()
  to authenticated;

notify pgrst, 'reload schema';
