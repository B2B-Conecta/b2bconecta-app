-- Porcentaje de valla por producto, dentro de la misma campaña.
-- Clave ausente: hereda promo_campaigns.discount_percent.
-- 0 explícito: ese producto no lleva descuento de esta valla.
-- No toca products.price_usd ni otras campañas.

alter table public.promo_campaigns
  add column if not exists product_discount_percents jsonb not null default '{}'::jsonb;

create or replace function public.promo_product_discount_percents_ok (p jsonb)
returns boolean
language sql
immutable
as $$
  select
    jsonb_typeof (p) = 'object'
    and not exists (
      select 1
      from jsonb_each (p) e
      where e.key !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         or jsonb_typeof (e.value) <> 'number'
         or (e.value #>> '{}')::numeric < 0
         or (e.value #>> '{}')::numeric >= 100
    );
$$;

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_product_discount_percents_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_product_discount_percents_chk
  check (public.promo_product_discount_percents_ok (product_discount_percents));

comment on column public.promo_campaigns.product_discount_percents is
  'Mapa product_id → % de esta valla. Sin clave hereda discount_percent. 0 = sin descuento en ese SKU.';

-- % que aplica un producto en una campaña: override o general.
create or replace function public.promo_effective_product_discount_percent (
  p_overrides jsonb,
  p_product_id uuid,
  p_general numeric
)
returns numeric
language sql
immutable
as $$
  select case
    when p_overrides is not null
         and jsonb_typeof (p_overrides) = 'object'
         and p_overrides ? p_product_id::text
      then (p_overrides ->> p_product_id::text)::numeric
    else p_general
  end;
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
      and c.starts_at <= now()
      and c.ends_at >= now()
      and c.sponsor_type = 'importador'
      and p_product_id = any (coalesce(c.product_ids, '{}'::uuid[]))
    limit 1;

    if found then
      -- La valla atribuida manda: 0 o sin % no cae a otra campaña.
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
    and c.starts_at <= now()
    and c.ends_at >= now()
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
      and c.starts_at <= now()
      and c.ends_at >= now()
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
        'image_public_url', c.image_public_url,
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
    and c.starts_at <= now()
    and c.ends_at >= now()
    and btrim(c.image_public_url) <> ''
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
        'image_public_url', c.image_public_url,
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
    and c.starts_at <= now()
    and c.ends_at >= now()
    and btrim(c.image_public_url) <> ''
    and c.audience in ('importador', 'ambos');
$$;
