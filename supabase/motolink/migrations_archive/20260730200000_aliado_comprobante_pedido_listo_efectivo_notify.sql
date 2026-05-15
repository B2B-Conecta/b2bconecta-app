-- Comprobante aliado en `pedido_listo` (factura lista, pago antes de tránsito): Storage + RPC alineados.
-- Notificación al transportista cuando el aliado elige efectivo (evidencia / respaldo en Despacho).

-- ---------------------------------------------------------------------------
-- Storage: permitir INSERT de comprobante aliado también en pedido_listo
-- ---------------------------------------------------------------------------
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
      and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
      and tr.status in (
        'pendiente',
        'aprobado_admin',
        'en_preparacion',
        'pedido_listo',
        'en_transito',
        'entregado'
      )
  )
);

-- ---------------------------------------------------------------------------
-- RPC aliado: mismo conjunto de estados (incl. pedido_listo)
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
  base numeric;
  nuevo_total numeric;
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

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if p_metodo = 'efectivo' then
    nuevo_total := round(base * 1.04, 2);
  else
    nuevo_total := base;
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
    precio_total = nuevo_total,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que el pago no esté ya aprobado.';
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
  base numeric;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'aliado'
  ) then
    raise exception 'Solo el aliado puede declarar pago en efectivo.';
  end if;

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'efectivo',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = round(base * 1.04, 2),
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la declaración. Compruebe la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que pueda reenviar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo(uuid) to authenticated;

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
  base numeric;
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

  select tr.precio_base_aliado_total into base
  from public.transaction_requests tr
  where tr.id = p_request_id;

  update public.transaction_requests tr
  set
    pago_metodo = 'credito_sistema',
    comprobante_pago_storage_path = null,
    comprobante_pago_file_name = null,
    comprobante_pago_submitted_at = null,
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    pago_aprobado_at = null,
    precio_total = base,
    updated_at = now()
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid()
    and tr.status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and tr.document_type_preference is not null
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la solicitud. Compruebe la factura MotoLink, indique nota de entrega o factura '
      'fiscal en la ficha, y que pueda reintentar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_credito_sistema(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Transportista: aviso si el pedido ya es efectivo al asignar
-- ---------------------------------------------------------------------------
create or replace function public.notify_transportista_pedido_asignado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_body text;
begin
  if new.assigned_transportista_id is null then
    return new;
  end if;
  if old.assigned_transportista_id is not distinct from new.assigned_transportista_id then
    return new;
  end if;

  v_body :=
    'MotoLink le asignó un pedido. Abra Despacho para ver detalle, ruta y documentos de referencia.';
  if coalesce(trim(new.pago_metodo), '') = 'efectivo' then
    v_body := v_body
      || ' El aliado pagará en efectivo: adjunte en Despacho la foto de respaldo del cobro.';
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.assigned_transportista_id,
    'Asignación de despacho',
    v_body,
    'logistica',
    new.id::text
  );

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Transportista: aliado cambia / declara método efectivo con transportista ya asignado
-- ---------------------------------------------------------------------------
create or replace function public.notify_transportista_aliado_eligio_efectivo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.assigned_transportista_id,
    'Pago en efectivo',
    'El aliado indicó pago en efectivo en este pedido. En Despacho puede adjuntar la evidencia fotográfica del cobro en ruta.',
    'logistica',
    new.id::text
  );
  return new;
end;
$$;

drop trigger if exists tr_notify_transportista_efectivo on public.transaction_requests;
create trigger tr_notify_transportista_efectivo
after update of pago_metodo on public.transaction_requests
for each row
when (
  new.assigned_transportista_id is not null
  and coalesce(trim(new.pago_metodo), '') = 'efectivo'
  and (old.pago_metodo is distinct from new.pago_metodo)
)
execute function public.notify_transportista_aliado_eligio_efectivo();
