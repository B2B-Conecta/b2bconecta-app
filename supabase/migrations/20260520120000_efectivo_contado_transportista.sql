-- Efectivo (pago_metodo), respaldo foto transportista/admin, rol transportista, RLS.

-- ---------------------------------------------------------------------------
-- Perfiles: rol transportista (despacho / cobro en ruta)
-- ---------------------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('importador', 'aliado', 'administrador', 'transportista'));

-- ---------------------------------------------------------------------------
-- transaction_requests: método efectivo + foto respaldo cobro efectivo
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  add column if not exists efectivo_respaldo_storage_path text,
  add column if not exists efectivo_respaldo_file_name text,
  add column if not exists efectivo_respaldo_submitted_at timestamptz,
  add column if not exists efectivo_respaldo_registered_by uuid references public.profiles (id);

alter table public.transaction_requests
  drop constraint if exists transaction_requests_pago_metodo_check;

alter table public.transaction_requests
  add constraint transaction_requests_pago_metodo_check
  check (
    pago_metodo is null
    or pago_metodo in (
      'pago_movil',
      'zelle_divisas',
      'transferencia',
      'efectivo'
    )
  );

-- ---------------------------------------------------------------------------
-- RPC: aliado — incluye efectivo
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
  if p_metodo not in ('pago_movil', 'zelle_divisas', 'transferencia', 'efectivo') then
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

-- ---------------------------------------------------------------------------
-- RPC: transportista o admin registra foto respaldo de cobro en efectivo
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
begin
  if uid is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = uid and p.role in ('administrador', 'transportista')
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
      (tr.status = 'en_preparacion' and tr.pago_estado_revision = 'aprobado')
      or tr.status = 'en_transito'
    );

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el respaldo. Verifique método efectivo, pago aprobado (si aplica), '
      'estado del pedido y que aún no exista un respaldo.';
  end if;
end;
$$;

grant execute on function public.registrar_respaldo_cobro_efectivo(uuid, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: transportista ve pedidos (mismo alcance que admin para despacho)
-- ---------------------------------------------------------------------------
drop policy if exists "tr_select_transportista_all" on public.transaction_requests;
create policy "tr_select_transportista_all"
on public.transaction_requests
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.id = auth.uid()
      and pr.role = 'transportista'
  )
);

-- ---------------------------------------------------------------------------
-- Storage: lectura transportista en comprobantes
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
      where p.id = auth.uid() and p.role in ('administrador', 'transportista')
    )
  )
);

-- Subida respaldo efectivo (admin / transportista), prefijo en ruta
drop policy if exists "order_pay_proof_insert_efectivo_respaldo" on storage.objects;
create policy "order_pay_proof_insert_efectivo_respaldo"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'order-payment-proofs'
  and name like '%/efectivo_respaldo_%'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('administrador', 'transportista')
  )
  and exists (
    select 1 from public.transaction_requests tr
    where tr.id::text = (storage.foldername(name))[1]
      and tr.pago_metodo = 'efectivo'
  )
);
