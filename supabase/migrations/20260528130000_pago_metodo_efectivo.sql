-- Permite «efectivo» al registrar método y comprobante (MotoConecta).

create or replace function public.aliado_registra_comprobante_pago (
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
  v_aliado uuid;
  v_status text;
  v_pe text;
begin
  if auth.uid () is null then
    raise exception 'No autenticado';
  end if;

  select tr.aliado_id, tr.status, tr.pago_estado_revision
    into v_aliado, v_status, v_pe
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if v_aliado is null then
    raise exception 'Pedido no encontrado';
  end if;
  if v_aliado is distinct from auth.uid () then
    raise exception 'No autorizado';
  end if;
  if v_status = 'rechazado' then
    raise exception 'El pedido está rechazado';
  end if;
  if trim(p_metodo) not in (
    'zelle_divisas',
    'pago_movil',
    'binance',
    'transferencia',
    'efectivo'
  ) then
    raise exception 'Método de pago no permitido';
  end if;
  if v_pe is not null and trim(v_pe) = 'aprobado' then
    raise exception 'El pago ya fue confirmado; no puede modificar el comprobante';
  end if;

  update public.transaction_requests
  set
    pago_metodo = trim(p_metodo),
    comprobante_pago_storage_path = p_storage_path,
    comprobante_pago_file_name = nullif(trim(p_file_name), ''),
    comprobante_pago_submitted_at = now(),
    pago_estado_revision = 'en_revision',
    pago_comprobante_rechazo_nota = null,
    updated_at = now()
  where id = p_request_id;
end;
$$;
