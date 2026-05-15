-- Factura oficial MotoLink al aliado + comprobante de pago + aprobación antes de en_tránsito.

alter table public.transaction_requests
  add column if not exists factura_aliado_storage_path text,
  add column if not exists factura_aliado_file_name text,
  add column if not exists factura_aliado_submitted_at timestamptz,
  add column if not exists pago_metodo text,
  add column if not exists comprobante_pago_storage_path text,
  add column if not exists comprobante_pago_file_name text,
  add column if not exists comprobante_pago_submitted_at timestamptz,
  add column if not exists pago_estado_revision text,
  add column if not exists pago_comprobante_rechazo_nota text,
  add column if not exists pago_aprobado_at timestamptz;

alter table public.transaction_requests
  drop constraint if exists transaction_requests_pago_metodo_check;

alter table public.transaction_requests
  add constraint transaction_requests_pago_metodo_check
  check (
    pago_metodo is null
    or pago_metodo in ('pago_movil', 'zelle_divisas', 'transferencia')
  );

alter table public.transaction_requests
  drop constraint if exists transaction_requests_pago_estado_revision_check;

alter table public.transaction_requests
  add constraint transaction_requests_pago_estado_revision_check
  check (
    pago_estado_revision is null
    or pago_estado_revision in ('pendiente', 'en_revision', 'aprobado', 'rechazado')
  );

-- ---------------------------------------------------------------------------
-- Transiciones: en_preparacion → en_transito requiere factura proveedor,
-- factura oficial al aliado, pago aprobado y ETA.
-- ---------------------------------------------------------------------------

create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
  etd integer;
  eth integer;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;
      if coalesce(trim(new.factura_aliado_storage_path), '') = '' then
        raise exception 'Debe adjuntar la factura oficial al aliado antes de marcar en tránsito.';
      end if;
      if coalesce(new.pago_estado_revision, '') is distinct from 'aprobado' then
        raise exception 'El pago del aliado debe estar aprobado antes de marcar en tránsito.';
      end if;
      etd := coalesce(new.transit_eta_days, 0);
      eth := coalesce(new.transit_eta_hours, 0);
      if etd < 0 or etd > 365 or eth < 0 or eth > 23 then
        raise exception 'ETA de tránsito inválido: días 0–365, horas 0–23.';
      end if;
      if etd = 0 and eth = 0 then
        raise exception 'Debe indicar días y/o horas de tránsito (al menos uno mayor que 0).';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

create or replace function public.admin_marca_pedido_en_transito(
  p_request_id uuid,
  p_transit_eta_days integer,
  p_transit_eta_hours integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
  inv text;
  fa text;
  pe text;
  v_days integer;
  v_hours integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden marcar en tránsito';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);

  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'Valores inválidos: días 0–365, horas 0–23.';
  end if;
  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día o una hora de tránsito estimado.';
  end if;

  select
    tr.status,
    tr.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path,
    tr.pago_estado_revision
  into st, inv, fa, pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'en_preparacion' then
    raise exception 'Solo pedidos en preparación pueden pasar a en tránsito';
  end if;
  if coalesce(trim(inv), '') = '' then
    raise exception 'El importador debe adjuntar la factura digital antes.';
  end if;
  if coalesce(trim(fa), '') = '' then
    raise exception 'Adjunte la factura oficial al aliado antes.';
  end if;
  if coalesce(pe, '') is distinct from 'aprobado' then
    raise exception 'Apruebe primero el pago del aliado (comprobante).';
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    updated_at = now()
  where id = p_request_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: aliado registra método + comprobante (tras factura MotoLink).
-- ---------------------------------------------------------------------------

create or replace function public.aliado_registra_comprobante_pago(
  p_request_id uuid,
  p_metodo text,
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
begin
  if p_metodo not in ('pago_movil', 'zelle_divisas', 'transferencia') then
    raise exception 'Método de pago no válido.';
  end if;
  if coalesce(trim(p_storage_path), '') = '' or coalesce(trim(p_file_name), '') = '' then
    raise exception 'Debe indicar ruta y nombre del comprobante.';
  end if;
  if p_storage_path not like p_request_id::text || '/%' then
    raise exception 'Ruta de archivo inválida.';
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = p_metodo,
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = p_file_name,
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status = 'en_preparacion'
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique que exista la factura MotoLink, '
      'que el pedido esté en preparación y que pueda volver a enviar si fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: MotoLink aprueba pago
-- ---------------------------------------------------------------------------

create or replace function public.admin_aprobar_pago_aliado(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden aprobar el pago';
  end if;

  update public.transaction_requests
  set
    pago_estado_revision = 'aprobado',
    pago_aprobado_at = now(),
    updated_at = now()
  where id = p_request_id
    and status = 'en_preparacion'
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para este pedido.';
  end if;
end;
$$;

grant execute on function public.admin_aprobar_pago_aliado(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: MotoLink rechaza comprobante (el aliado puede reenviar)
-- ---------------------------------------------------------------------------

create or replace function public.admin_rechazar_comprobante_pago(
  p_request_id uuid,
  p_nota text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden rechazar el comprobante';
  end if;

  update public.transaction_requests
  set
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'rechazado',
    pago_comprobante_rechazo_nota = nullif(trim(p_nota), ''),
    pago_aprobado_at = null,
    updated_at = now()
  where id = p_request_id
    and status = 'en_preparacion'
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para rechazar.';
  end if;
end;
$$;

grant execute on function public.admin_rechazar_comprobante_pago(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: factura oficial MotoLink (solo admin sube; aliado y admin leen)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('order-ally-invoices', 'order-ally-invoices', false)
on conflict (id) do nothing;

drop policy if exists "order_ally_inv_select" on storage.objects;
create policy "order_ally_inv_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-ally-invoices'
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
  )
);

drop policy if exists "order_ally_inv_insert_admin" on storage.objects;
create policy "order_ally_inv_insert_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-ally-invoices'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists "order_ally_inv_delete_admin" on storage.objects;
create policy "order_ally_inv_delete_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-ally-invoices'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  )
);

-- ---------------------------------------------------------------------------
-- Storage: comprobante de pago (sube el aliado; aliado y admin leen)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('order-payment-proofs', 'order-payment-proofs', false)
on conflict (id) do nothing;

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
  )
);

drop policy if exists "order_pay_proof_insert_aliado" on storage.objects;
create policy "order_pay_proof_insert_aliado"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid()
      and tr.status = 'en_preparacion'
  )
);

drop policy if exists "order_pay_proof_delete_aliado" on storage.objects;
create policy "order_pay_proof_delete_aliado"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'order-payment-proofs'
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.aliado_id = auth.uid()
  )
);
