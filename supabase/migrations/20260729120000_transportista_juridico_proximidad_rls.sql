-- Transportista jurídico: expediente (RIF + documentos), base operativa (coords),
-- asignación a pedidos, RPC de proximidad a almacenes importador, RLS acotado.

-- ---------------------------------------------------------------------------
-- Tabla transportista_info (1:1 con profiles.id donde role = transportista)
-- ---------------------------------------------------------------------------
create table if not exists public.transportista_info (
  id uuid primary key references public.profiles (id) on delete cascade,
  rif text,
  documento_constitutivo_storage_path text,
  rif_documento_storage_path text,
  otros_documentos_storage_path text,
  base_operativa_latitude double precision not null,
  base_operativa_longitude double precision not null,
  location_updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint transportista_info_base_lat_range
    check (base_operativa_latitude >= -90 and base_operativa_latitude <= 90),
  constraint transportista_info_base_lon_range
    check (base_operativa_longitude >= -180 and base_operativa_longitude <= 180)
);

comment on table public.transportista_info is
  'Expediente jurídico y ubicación de base operativa del transportista (persona jurídica).';
comment on column public.transportista_info.rif is
  'RIF de la empresa transportista (expediente fiscal).';
comment on column public.transportista_info.documento_constitutivo_storage_path is
  'Ruta en Storage (bucket acordado con la app) del documento constitutivo.';
comment on column public.transportista_info.rif_documento_storage_path is
  'Ruta escaneada del documento de RIF u homologo.';
comment on column public.transportista_info.otros_documentos_storage_path is
  'Ruta opcional a archivo ZIP o PDF único con anexos legales.';

create index if not exists transportista_info_base_coords_idx
  on public.transportista_info (base_operativa_latitude, base_operativa_longitude);

-- Pedido maestro: transportista asignado por MotoLink (logística / cobro en ruta)
alter table public.transaction_requests
  add column if not exists assigned_transportista_id uuid
    references public.profiles (id) on delete set null;

create index if not exists transaction_requests_assigned_transportista_id_idx
  on public.transaction_requests (assigned_transportista_id)
  where assigned_transportista_id is not null;

comment on column public.transaction_requests.assigned_transportista_id is
  'Transportista autorizado a ver el pedido y registrar respaldos; solo MotoLink asigna.';

-- ---------------------------------------------------------------------------
-- Distancia Haversine (km), WGS84
-- ---------------------------------------------------------------------------
create or replace function public.haversine_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
) returns double precision
language sql
immutable
parallel safe
as $$
  select case
    when lat1 is null or lon1 is null or lat2 is null or lon2 is null then null
    else (
      2 * 6371.0 * asin(least(
        1.0::double precision,
        sqrt(
          power(sin(radians(lat2 - lat1) / 2.0), 2)
          + cos(radians(lat1)) * cos(radians(lat2))
            * power(sin(radians(lon2 - lon1) / 2.0), 2)
        )
      ))
    )
  end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: ranking de transportistas por proximidad media (y máxima) a almacenes
-- Importadores = profiles.role importador; ubicación = latitude/longitude del perfil.
-- Solo administrador.
-- ---------------------------------------------------------------------------
create or replace function public.rpc_rank_transportistas_by_importer_proximity(
  p_importer_profile_ids uuid[],
  p_limit integer default 20
)
returns table (
  transportista_id uuid,
  business_name text,
  avg_distance_km double precision,
  max_distance_km double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  lim int := coalesce(nullif(p_limit, 0), 20);
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo MotoLink puede consultar el ranking de proximidad.';
  end if;

  if p_importer_profile_ids is null or cardinality(p_importer_profile_ids) = 0 then
    raise exception 'Debe indicar al menos un importador (almacén).';
  end if;

  if lim < 1 or lim > 100 then
    raise exception 'p_limit debe estar entre 1 y 100.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = any (p_importer_profile_ids)
      and p.role = 'importador'
  ) then
    raise exception 'Ningún id corresponde a un perfil importador.';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id = any (p_importer_profile_ids)
      and p.role = 'importador'
      and (p.latitude is null or p.longitude is null)
  ) then
    raise exception
      'Cada importador indicado debe tener latitud y longitud en su perfil (base / almacén).';
  end if;

  return query
  with wh_ok as (
    select distinct p.latitude, p.longitude
    from public.profiles p
    where p.id = any (p_importer_profile_ids)
      and p.role = 'importador'
      and p.latitude is not null
      and p.longitude is not null
  )
  select
    x.transportista_id,
    x.business_name,
    x.avg_distance_km,
    x.max_distance_km
  from (
    select
      ti.id as transportista_id,
      coalesce(pr.business_name, pr.id::text) as business_name,
      (
        select avg(
          public.haversine_km(
            ti.base_operativa_latitude,
            ti.base_operativa_longitude,
            w.latitude,
            w.longitude
          )
        )
        from wh_ok w
      ) as avg_distance_km,
      (
        select max(
          public.haversine_km(
            ti.base_operativa_latitude,
            ti.base_operativa_longitude,
            w.latitude,
            w.longitude
          )
        )
        from wh_ok w
      ) as max_distance_km
    from public.transportista_info ti
    join public.profiles pr on pr.id = ti.id and pr.role = 'transportista'
  ) x
  where x.avg_distance_km is not null
  order by x.avg_distance_km asc, x.max_distance_km asc
  limit lim;
end;
$$;

revoke all on function public.rpc_rank_transportistas_by_importer_proximity(uuid[], integer)
  from public;
grant execute on function public.rpc_rank_transportistas_by_importer_proximity(uuid[], integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: MotoLink asigna transportista a un pedido
-- ---------------------------------------------------------------------------
create or replace function public.admin_assign_transportista_pedido(
  p_request_id uuid,
  p_transportista_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo MotoLink puede asignar transportista.';
  end if;

  if p_transportista_id is not null then
    if not exists (
      select 1 from public.profiles p
      where p.id = p_transportista_id and p.role = 'transportista'
    ) then
      raise exception 'El usuario indicado no es un transportista.';
    end if;
    if not exists (
      select 1 from public.transportista_info t where t.id = p_transportista_id
    ) then
      raise exception 'El transportista debe completar su expediente (transportista_info).';
    end if;
  end if;

  update public.transaction_requests tr
  set
    assigned_transportista_id = p_transportista_id,
    updated_at = now()
  where tr.id = p_request_id;

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Pedido no encontrado.';
  end if;
end;
$$;

revoke all on function public.admin_assign_transportista_pedido(uuid, uuid) from public;
grant execute on function public.admin_assign_transportista_pedido(uuid, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: transportista_info
-- ---------------------------------------------------------------------------
alter table public.transportista_info enable row level security;

drop policy if exists "transportista_info_select_own_or_admin" on public.transportista_info;
create policy "transportista_info_select_own_or_admin"
on public.transportista_info
for select
to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

drop policy if exists "transportista_info_insert_own_transportista" on public.transportista_info;
create policy "transportista_info_insert_own_transportista"
on public.transportista_info
for insert
to authenticated
with check (
  id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'transportista'
  )
);

drop policy if exists "transportista_info_update_own_or_admin" on public.transportista_info;
create policy "transportista_info_update_own_or_admin"
on public.transportista_info
for update
to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
)
with check (
  id = auth.uid()
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

-- ---------------------------------------------------------------------------
-- Pedidos: transportista solo ve filas asignadas explícitamente
-- ---------------------------------------------------------------------------
drop policy if exists "tr_select_transportista_all" on public.transaction_requests;
create policy "tr_select_transportista_assigned"
on public.transaction_requests
for select
to authenticated
using (
  assigned_transportista_id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'transportista'
  )
);

-- ---------------------------------------------------------------------------
-- profile_documents: permitir expediente al transportista (bucket profile-documents)
-- ---------------------------------------------------------------------------
drop policy if exists "profile_documents_insert_transportista_self"
  on public.profile_documents;
create policy "profile_documents_insert_transportista_self"
on public.profile_documents
for insert
to authenticated
with check (
  profile_id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'transportista'
  )
);

drop policy if exists "profile_documents_delete_own_transportista"
  on public.profile_documents;
create policy "profile_documents_delete_own_transportista"
on public.profile_documents
for delete
to authenticated
using (
  profile_id = auth.uid()
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'transportista'
  )
);

-- Storage profile-documents: subida carpeta propia para transportista
drop policy if exists "profile_docs_insert_own_transportista" on storage.objects;
create policy "profile_docs_insert_own_transportista"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-documents'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'transportista'
  )
);

-- ---------------------------------------------------------------------------
-- Storage order-payment-proofs: transportista solo en pedidos asignados
-- ---------------------------------------------------------------------------
drop policy if exists "order_pay_proof_select" on storage.objects;
create policy "order_pay_proof_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.aliado_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
    )
    or exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.assigned_transportista_id = auth.uid()
    )
  )
);

drop policy if exists "order_pay_proof_insert_efectivo_respaldo" on storage.objects;
create policy "order_pay_proof_insert_efectivo_respaldo"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-payment-proofs'
  and name like '%/efectivo_respaldo_%'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.pago_metodo = 'efectivo'
  )
  and (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
    )
    or exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.assigned_transportista_id = auth.uid()
    )
  )
);

-- ---------------------------------------------------------------------------
-- Respaldo efectivo: transportista solo en pedidos asignados (admin sin cambio)
-- ---------------------------------------------------------------------------
create or replace function public.registrar_respaldo_cobro_efectivo(
  p_request_id uuid,
  p_storage_path text,
  p_file_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  uid uuid := auth.uid();
  is_admin boolean;
begin
  if uid is null then
    raise exception 'Sesión requerida.';
  end if;
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'administrador'
  ) into is_admin;
  if not is_admin and not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role = 'transportista'
  ) then
    raise exception 'Solo MotoLink o transportista pueden registrar este respaldo.';
  end if;

  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del archivo.';
  end if;
  if p_storage_path not like p_request_id::text || '/%' then
    raise exception 'Ruta de archivo inválida.';
  end if;
  if strpos(p_storage_path, 'efectivo_respaldo_') = 0 then
    raise exception 'Use el prefijo efectivo_respaldo_ en el nombre del archivo.';
  end if;

  update public.transaction_requests tr
  set
    efectivo_respaldo_storage_path = p_storage_path,
    efectivo_respaldo_file_name = p_file_name,
    efectivo_respaldo_submitted_at = now(),
    efectivo_respaldo_registered_by = uid,
    updated_at = now()
  where tr.id = p_request_id
    and tr.pago_metodo = 'efectivo'
    and tr.efectivo_respaldo_storage_path is null
    and (
      is_admin
      or tr.assigned_transportista_id = uid
    )
    and (
      (tr.status = 'en_preparacion' and tr.pago_estado_revision = 'aprobado')
      or tr.status in ('en_transito', 'entregado')
    );

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el respaldo. Verifique método efectivo, asignación (transportista), '
      'pago aprobado (si aplica), estado del pedido y que aún no exista un respaldo.';
  end if;
end;
$$;
