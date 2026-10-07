-- Destino de valla: vitrina del proveedor o un producto publicado de ese proveedor.
-- Las acciones none, filter_importer y external_url no cambian.
-- product_id queda en null en las filas existentes.

alter table public.promo_campaigns
  add column if not exists product_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'promo_campaigns_product_id_fkey'
      and conrelid = 'public.promo_campaigns'::regclass
  ) then
    alter table public.promo_campaigns
      add constraint promo_campaigns_product_id_fkey
      foreign key (product_id)
      references public.products (id)
      on delete restrict;
  end if;
end $$;

create index if not exists promo_campaigns_product_id_idx
  on public.promo_campaigns (product_id)
  where product_id is not null;

comment on column public.promo_campaigns.product_id is
  'Producto publicado del proveedor cuando action_type = open_product. Null en vitrina y en las acciones anteriores.';

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_action_type_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_action_type_chk
    check (
      action_type = any (
        array[
          'none'::text,
          'filter_importer'::text,
          'external_url'::text,
          'open_store'::text,
          'open_product'::text
        ]
      )
    );

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_sponsor_rules_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_sponsor_rules_chk
    check (
      (
        sponsor_type = 'importador'
        and importador_id is not null
        and audience = 'aliado'
        and action_type = any (
          array[
            'none'::text,
            'filter_importer'::text,
            'open_store'::text,
            'open_product'::text
          ]
        )
      )
      or (
        sponsor_type = 'tercero'
        and importador_id is null
        and audience = any (array['aliado'::text, 'importador'::text, 'ambos'::text])
        and action_type = any (array['none'::text, 'external_url'::text])
      )
    );

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_destination_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_destination_chk
    check (
      (
        action_type = 'open_store'
        and importador_id is not null
        and product_id is null
      )
      or (
        action_type = 'open_product'
        and importador_id is not null
        and product_id is not null
      )
      or (
        action_type = any (
          array['none'::text, 'filter_importer'::text, 'external_url'::text]
        )
        and product_id is null
      )
    );

create or replace function public.promo_campaigns_validate_destination()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_owner uuid;
  v_active boolean;
begin
  if new.action_type is distinct from 'open_product' then
    return new;
  end if;

  select p.owner_id, p.is_active
    into v_owner, v_active
  from public.products p
  where p.id = new.product_id;

  if v_owner is distinct from new.importador_id or v_active is not true then
    raise exception 'El producto debe estar publicado y pertenecer al proveedor'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists promo_campaigns_validate_destination
  on public.promo_campaigns;

create trigger promo_campaigns_validate_destination
  before insert or update of action_type, importador_id, product_id
  on public.promo_campaigns
  for each row
  execute function public.promo_campaigns_validate_destination();

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
