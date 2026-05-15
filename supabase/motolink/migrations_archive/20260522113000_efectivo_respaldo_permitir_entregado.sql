-- Permite registrar respaldo de efectivo también cuando el pedido ya está entregado.

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
      or tr.status in ('en_transito', 'entregado')
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
