-- Aliado puede reemplazar comprobante mientras NO esté aprobado (pendiente, en_revision, rechazado).
-- Tras aprobación, no puede alterar el comprobante.

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
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'en_revision', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar el comprobante. Verifique factura MotoLink, pedido en preparación, '
      'que el pago no esté ya aprobado y que pueda reenviar o reemplazar si aplica.';
  end if;
end;
$$;

grant execute on function public.aliado_registra_comprobante_pago(uuid, text, text, text)
  to authenticated;
