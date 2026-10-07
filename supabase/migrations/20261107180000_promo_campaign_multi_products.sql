-- Vallas: varios productos por campaña (open_product).
-- product_ids es la fuente de verdad; product_id se mantiene como el primero
-- para compatibilidad con clientes / reportes antiguos.

alter table public.promo_campaigns
  add column if not exists product_ids uuid[] not null default '{}'::uuid[];

update public.promo_campaigns
set product_ids = array[product_id]
where product_id is not null
  and coalesce(cardinality(product_ids), 0) = 0;

comment on column public.promo_campaigns.product_ids is
  'Productos publicados del proveedor cuando action_type = open_product (1+).';

comment on column public.promo_campaigns.product_id is
  'Legacy/compat: primer elemento de product_ids. Preferir product_ids.';

alter table public.promo_campaigns
  drop constraint if exists promo_campaigns_destination_chk;

alter table public.promo_campaigns
  add constraint promo_campaigns_destination_chk
    check (
      (
        action_type = 'open_store'
        and importador_id is not null
        and product_id is null
        and coalesce(cardinality(product_ids), 0) = 0
      )
      or (
        action_type = 'open_product'
        and importador_id is not null
        and coalesce(cardinality(product_ids), 0) >= 1
      )
      or (
        action_type = any (
          array['none'::text, 'filter_importer'::text, 'external_url'::text]
        )
        and product_id is null
        and coalesce(cardinality(product_ids), 0) = 0
      )
    );

create or replace function public.promo_campaigns_validate_destination()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_id uuid;
  v_owner uuid;
  v_active boolean;
  v_raw uuid[];
  v_ids uuid[] := '{}'::uuid[];
begin
  if new.action_type is distinct from 'open_product' then
    new.product_ids := '{}'::uuid[];
    new.product_id := null;
    return new;
  end if;

  v_raw := coalesce(new.product_ids, '{}'::uuid[]);
  if cardinality(v_raw) = 0 and new.product_id is not null then
    v_raw := array[new.product_id];
  end if;

  foreach v_id in array v_raw
  loop
    if v_id is null then
      continue;
    end if;
    if not (v_id = any (v_ids)) then
      v_ids := array_append(v_ids, v_id);
    end if;
  end loop;

  if cardinality(v_ids) = 0 then
    raise exception 'Indique al menos un producto publicado'
      using errcode = '23514';
  end if;

  foreach v_id in array v_ids
  loop
    select p.owner_id, p.is_active
      into v_owner, v_active
    from public.products p
    where p.id = v_id;

    if v_owner is distinct from new.importador_id or v_active is not true then
      raise exception
        'Cada producto debe estar publicado y pertenecer al proveedor'
        using errcode = '23514';
    end if;
  end loop;

  new.product_ids := v_ids;
  new.product_id := v_ids[1];
  return new;
end;
$$;

drop trigger if exists promo_campaigns_validate_destination
  on public.promo_campaigns;

create trigger promo_campaigns_validate_destination
  before insert or update of action_type, importador_id, product_id, product_ids
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
        'product_ids', to_jsonb(coalesce(c.product_ids, '{}'::uuid[])),
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
