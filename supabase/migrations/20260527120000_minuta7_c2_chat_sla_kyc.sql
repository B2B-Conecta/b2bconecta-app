-- Minuta #7 — Bloque C2: documentos KYC contraparte, cron SLA 12 h, endurecimiento tablas.

-- ---------------------------------------------------------------------------
-- 1) profile_documents (si no existe en el proyecto)
-- ---------------------------------------------------------------------------
create table if not exists public.profile_documents (
  id uuid not null default gen_random_uuid () primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  doc_type text not null,
  storage_path text not null,
  file_name text,
  created_at timestamptz not null default now(),
  is_current boolean not null default true,
  review_status text not null default 'pendiente'
    check (
      review_status = any (
        array[
          'pendiente'::text,
          'en_revision'::text,
          'aprobado'::text,
          'rechazado'::text
        ]
      )
    ),
  review_note text,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles (id)
);

create index if not exists profile_documents_profile_idx
  on public.profile_documents (profile_id, doc_type, is_current);

alter table public.profile_documents enable row level security;

drop policy if exists profile_documents_select_own on public.profile_documents;
create policy profile_documents_select_own
on public.profile_documents
for select
to authenticated
using (profile_id = auth.uid ());

drop policy if exists profile_documents_insert_own on public.profile_documents;
create policy profile_documents_insert_own
on public.profile_documents
for insert
to authenticated
with check (profile_id = auth.uid ());

drop policy if exists profile_documents_select_admin on public.profile_documents;
create policy profile_documents_select_admin
on public.profile_documents
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

drop policy if exists profile_documents_select_counterparty on public.profile_documents;
create policy profile_documents_select_counterparty
on public.profile_documents
for select
to authenticated
using (
  is_current = true
  and review_status = 'aprobado'::text
  and exists (
    select 1
    from public.transaction_requests tr
    where (
      tr.aliado_id = auth.uid ()
      and tr.importador_id = profile_documents.profile_id
    )
    or (
      tr.importador_id = auth.uid ()
      and tr.aliado_id = profile_documents.profile_id
    )
  )
);

-- ---------------------------------------------------------------------------
-- 2) Storage bucket profile-documents (lectura contraparte vía signed URL + RLS metadata)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-documents',
  'profile-documents',
  false,
  10485760,
  array[
    'application/pdf'::text,
    'image/jpeg'::text,
    'image/png'::text,
    'image/webp'::text
  ]
)
on conflict (id) do nothing;

drop policy if exists profile_documents_storage_select on storage.objects;
create policy profile_documents_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-documents'
  and (
    (storage.foldername (name))[1] = auth.uid ()::text
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid ()
        and p.role = 'administrador'::text
    )
    or exists (
      select 1
      from public.profile_documents pd
      where pd.storage_path = name
        and pd.is_current = true
        and pd.review_status = 'aprobado'::text
        and exists (
          select 1
          from public.transaction_requests tr
          where (
            tr.aliado_id = auth.uid ()
            and tr.importador_id = pd.profile_id
          )
          or (
            tr.importador_id = auth.uid ()
            and tr.aliado_id = pd.profile_id
          )
        )
    )
  )
);

drop policy if exists profile_documents_storage_insert on storage.objects;
create policy profile_documents_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-documents'
  and (storage.foldername (name))[1] = auth.uid ()::text
);

-- ---------------------------------------------------------------------------
-- 3) SLA: tabla de deduplicación solo service_role; mensajes más legibles
-- ---------------------------------------------------------------------------
alter table public.sla_importer_pending_alert_sent enable row level security;

revoke all on table public.sla_importer_pending_alert_sent from anon;
revoke all on table public.sla_importer_pending_alert_sent from authenticated;

create or replace function public.run_importer_sla_admin_alerts ()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  v_count int := 0;
  v_imp_name text;
begin
  perform set_config ('row_security', 'off', true);

  for rec in
    select
      tr.checkout_group_id,
      tr.importador_id,
      min(tr.created_at) as first_pending_at
    from public.transaction_requests tr
    where tr.status = 'pendiente'::text
      and tr.checkout_group_id is not null
    group by tr.checkout_group_id, tr.importador_id
    having min(tr.created_at) + interval '12 hours' < now ()
  loop
    if exists (
      select 1
      from public.sla_importer_pending_alert_sent s
      where s.checkout_group_id = rec.checkout_group_id
        and s.importador_id = rec.importador_id
    ) then
      continue;
    end if;

    insert into public.sla_importer_pending_alert_sent (
      checkout_group_id,
      importador_id
    )
    values (rec.checkout_group_id, rec.importador_id);

    select nullif(trim(p.business_name), '')
    into v_imp_name
    from public.profiles p
    where p.id = rec.importador_id;

    insert into public.notifications (
      user_id, title, body, type, related_id
    )
    select
      adm.id,
      'Supervisión · SLA proveedor (12 h)',
      format(
        'El importador %s no confirmó el carrito en más de 12 h (ref. %s).',
        coalesce(v_imp_name, 'sin nombre'),
        substring(rec.checkout_group_id::text, 1, 8) || '…'
      ),
      'supervision',
      rec.checkout_group_id::text
    from public.profiles adm
    where adm.role = 'administrador'::text;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.run_importer_sla_admin_alerts () to service_role;

-- ---------------------------------------------------------------------------
-- 4) pg_cron: SLA cada 15 minutos
-- ---------------------------------------------------------------------------
do $cron$
begin
  create extension if not exists pg_cron with schema extensions;
exception
  when insufficient_privilege then
    raise notice 'pg_cron: sin privilegio para crear extensión (omitir en local).';
  when others then
    raise notice 'pg_cron: %', sqlerrm;
end;
$cron$;

do $schedule$
declare
  v_job_id bigint;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron no instalado; programe run_importer_sla_admin_alerts manualmente.';
    return;
  end if;

  select jobid
  into v_job_id
  from cron.job
  where jobname = 'motoconecta_importer_sla_12h'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'motoconecta_importer_sla_12h',
    '*/15 * * * *',
    $cmd$select public.run_importer_sla_admin_alerts();$cmd$
  );
exception
  when undefined_table then
    raise notice 'cron.job no disponible; omitiendo schedule SLA.';
  when others then
    raise notice 'pg_cron SLA schedule: %', sqlerrm;
end;
$schedule$;
