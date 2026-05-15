-- Aliado declara pago en efectivo sin comprobante bancario (revisión MotoLink + respaldo foto transportista).

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
    and tr.status = 'en_preparacion'
    and coalesce(trim(tr.factura_aliado_storage_path), '') <> ''
    and coalesce(tr.pago_estado_revision, 'pendiente') in ('pendiente', 'rechazado');

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo registrar la declaración. Verifique factura MotoLink, pedido en preparación '
      'y que pueda reenviar si el pago fue rechazado.';
  end if;
end;
$$;

grant execute on function public.aliado_declara_pago_efectivo(uuid) to authenticated;
