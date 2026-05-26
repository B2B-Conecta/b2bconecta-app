-- E1.2: campañas promocionales nativas (banner + popup) en catálogo aliado.

create table if not exists public.promo_campaigns (
  id uuid not null default gen_random_uuid () primary key,
  internal_title text not null,
  display_title text,
  campaign_type text not null
    check (campaign_type = any (array['banner'::text, 'popup'::text])),
  image_storage_path text not null,
  image_public_url text not null,
  importador_id uuid references public.profiles (id) on delete set null,
  action_type text not null default 'filter_importer'
    check (action_type = any (array['none'::text, 'filter_importer'::text])),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  priority integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint promo_campaigns_dates_chk check (ends_at >= starts_at),
  constraint promo_campaigns_filter_importer_chk check (
    action_type <> 'filter_importer'
    or importador_id is not null
  )
);

create index if not exists promo_campaigns_active_idx
  on public.promo_campaigns (is_active, starts_at, ends_at, priority desc);

comment on table public.promo_campaigns is
  'Campañas publicitarias nativas (E1.2) visibles en catálogo aliado.';

alter table public.promo_campaigns enable row level security;

drop policy if exists promo_campaigns_select_admin on public.promo_campaigns;
create policy promo_campaigns_select_admin
on public.promo_campaigns
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_insert_admin on public.promo_campaigns;
create policy promo_campaigns_insert_admin
on public.promo_campaigns
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_update_admin on public.promo_campaigns;
create policy promo_campaigns_update_admin
on public.promo_campaigns
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_delete_admin on public.promo_campaigns;
create policy promo_campaigns_delete_admin
on public.promo_campaigns
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

grant select, insert, update, delete on public.promo_campaigns to authenticated;
grant all on public.promo_campaigns to service_role;

-- ---------------------------------------------------------------------------
-- RPC: campañas activas para aliado (banner + popup)
-- ---------------------------------------------------------------------------
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
        'priority', c.priority
      )
      order by c.priority desc, c.created_at desc
    ),
    '[]'::jsonb
  )
  from public.promo_campaigns c
  where c.is_active = true
    and c.starts_at <= now()
    and c.ends_at >= now()
    and btrim(c.image_public_url) <> '';
$$;

grant execute on function public.get_active_promo_campaigns_for_aliado () to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: creativos públicos (lectura vía URL pública)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'promo-campaigns',
  'promo-campaigns',
  true,
  5242880,
  array[
    'image/jpeg'::text,
    'image/png'::text,
    'image/webp'::text
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists promo_campaigns_storage_admin_insert on storage.objects;
create policy promo_campaigns_storage_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_storage_admin_update on storage.objects;
create policy promo_campaigns_storage_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
)
with check (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);

drop policy if exists promo_campaigns_storage_admin_delete on storage.objects;
create policy promo_campaigns_storage_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'promo-campaigns'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid ()
      and p.role = 'administrador'::text
  )
);
