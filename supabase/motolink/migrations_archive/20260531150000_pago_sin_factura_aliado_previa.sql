-- Permite declarar pago / subir comprobante sin tener aún la factura MotoLink al aliado.
-- Tránsito sigue exigiendo factura + pago aprobado (admin_order_pre_transit_section / triggers).

create or replace function public.aliado_declara_pago_credito_sistema(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
  pc int;
  lim numeric;
  preact boolean;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede solicitar pago con crédito del sistema.';
  end if;

  select
    coalesce(primeros_pedidos_contado_entregados, 0),
    credit_limit,
    coalesce(credito_preactivado_por_admin, false)
  into pc, lim, preact
  from public.profiles
  where id = auth.uid();

  if pc < 3 and not preact then
    raise exception 'El pago con crédito del sistema solo aplica tras completar la fase de contado.';
  end if;
  if lim is null or lim <= 0 then
    raise exception 'Debe tener un límite de crédito asignado por MotoLink para usar esta modalidad.';
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Verifique que el pedido siga activo (no rechazado) '
      'y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_credito_sistema(uuid) to authenticated;

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
  if p_metodo not in (
    'pago_movil', 'zelle_divisas', 'transferencia', 'efectivo', 'credito_sistema'
  ) then
    raise exception 'Método de pago no válido.';
  end if;
  if p_metodo = 'credito_sistema' then
    raise exception 'El crédito del sistema se solicita con la acción dedicada, sin archivo de comprobante.';
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
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique que el pedido no esté rechazado '
      'y que el pago no esté ya aprobado.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;

create or replace function public.aliado_declara_pago_efectivo(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede declarar pago en efectivo.';
  end if;

  update public.transaction_requests tr
  set
    pago_metodo = 'efectivo',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la declaración. Verifique que el pedido siga activo (no rechazado) '
      'y que pueda reenviar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo(uuid) to authenticated;

-- Aprobar / rechazar pago en las mismas fases operativas (no solo en_preparacion).
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
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para este pedido.';
  end if;
end;
$$;

grant execute on function public.admin_aprobar_pago_aliado(uuid) to authenticated;

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
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'en_transito',
      'entregado'
    )
    and pago_estado_revision = 'en_revision';

  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'No hay comprobante en revisión para rechazar.';
  end if;
end;
$$;

grant execute on function public.admin_rechazar_comprobante_pago(uuid, text) to authenticated;

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
      and tr.status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'en_transito',
        'entregado'
      )
  )
);
