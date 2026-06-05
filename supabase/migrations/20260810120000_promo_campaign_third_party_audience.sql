-- Vallas publicitarias de terceros (ej. agencia de transporte) visibles para aliados y/o importadores.

alter table public.promo_campaigns
  add column if not exists sponsor_type text not null default 'importador',
  add column if not exists audience text not null default 'aliado',
  add column if not exists advertiser_name text,
  add column if not exists external_url text;

update public.promo_campaigns
set
  sponsor_type = 'importador',
  audience = 'aliado'
where sponsor_type is null
   or audience is null;

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_filter_importer_chk;

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_action_type_check;

alter table public.promo_campaigns
  add constraint promo_campaigns_sponsor_type_chk
    check (sponsor_type = any (array['importador'::text, 'tercero'::text]));

alter table public.promo_campaigns
  add constraint promo_campaigns_audience_chk
    check (audience = any (array['aliado'::text, 'importador'::text, 'ambos'::text]));

alter table public.promo_campaigns
  add constraint promo_campaigns_action_type_chk
    check (
      action_type = any (
        array['none'::text, 'filter_importer'::text, 'external_url'::text]
      )
    );

alter table public.promo_campaigns
  add constraint promo_campaigns_sponsor_rules_chk
    check (
      (
        sponsor_type = 'importador'
        and importador_id is not null
        and audience = 'aliado'
        and action_type = any (array['none'::text, 'filter_importer'::text])
      )
      or (
        sponsor_type = 'tercero'
        and importador_id is null
        and audience = any (array['aliado'::text, 'importador'::text, 'ambos'::text])
        and action_type = any (array['none'::text, 'external_url'::text])
      )
    );

alter table public.promo_campaigns
  add constraint promo_campaigns_external_url_chk
    check (
      action_type is distinct from 'external_url'
      or (
        external_url is not null
        and btrim(external_url) <> ''
      )
    );

alter table public.promo_campaigns
  add constraint promo_campaigns_filter_importer_chk
    check (
      action_type is distinct from 'filter_importer'
      or importador_id is not null
    );

comment on column public.promo_campaigns.sponsor_type is
  'importador = campaña del proveedor en catálogo aliado; tercero = valla publicitaria externa.';

comment on column public.promo_campaigns.audience is
  'aliado | importador | ambos — quién ve la valla en la app.';

comment on column public.promo_campaigns.advertiser_name is
  'Nombre del anunciante (terceros), ej. agencia de transporte.';

comment on column public.promo_campaigns.external_url is
  'Enlace opcional al tocar la valla (terceros, action_type = external_url).';

create or replace function public.get_active_promo_campaigns_for_aliado ()
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
        'image_public_url', c.image_public_url,
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
    and c.starts_at <= now()
    and c.ends_at >= now()
    and btrim(c.image_public_url) <> '';
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
        'external_url', c.external_url
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

grant execute on function public.get_active_promo_campaigns_for_importador_ads () to authenticated;
