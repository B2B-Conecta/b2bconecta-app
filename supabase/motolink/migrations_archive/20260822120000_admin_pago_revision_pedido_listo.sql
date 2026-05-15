-- El aliado puede registrar comprobante en `pedido_listo` (pago antes de tránsito).
-- Los RPC de aprobar/rechazar deben aceptar el mismo estado; si no, el UPDATE no
-- coincide y se lanza erróneamente «No hay comprobante en revisión».

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
    pago_pendiente_ultimo_recordatorio_at = null,
    updated_at = now()
  where id = p_request_id
    and status in (
      'pendiente',
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
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
      'pedido_listo',
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
