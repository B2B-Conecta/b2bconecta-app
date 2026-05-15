-- Bug: en PL/pgSQL no se puede usar el mismo identificador para la variable INTO (`so`)
-- y el alias de tabla (`so`): «record so is not assigned yet» al evaluar so.id en el SELECT.

create or replace function public.importer_advance_sub_order(
  p_sub_order_id uuid,
  p_new_status text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  so record;
  inv text;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'importador'
  ) then
    raise exception 'Solo importadores pueden actualizar este sub-pedido.';
  end if;

  select
    s.id,
    s.importador_id,
    s.status,
    s.proveedor_factura_storage_path,
    tr.status as master_status
  into so
  from public.sub_orders s
  join public.transaction_requests tr on tr.id = s.parent_order_id
  where s.id = p_sub_order_id
  for update of s;

  if so.id is null then
    raise exception 'Sub-pedido no encontrado.';
  end if;
  if so.importador_id is distinct from auth.uid() then
    raise exception 'Este sub-pedido no pertenece a su inventario.';
  end if;

  if so.status = 'pendiente' and p_new_status = 'preparando' then
    if so.master_status not in ('aprobado_admin', 'en_preparacion') then
      raise exception
        'El pedido maestro aún no fue aprobado por MotoLink, o ya no admite marcar en preparación.';
    end if;
    update public.sub_orders
    set status = 'preparando', updated_at = now()
    where id = p_sub_order_id;
    return;
  end if;

  if so.status = 'preparando' and p_new_status = 'listo' then
    if so.master_status not in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo'
    ) then
      raise exception
        'El pedido maestro no está en una fase donde pueda marcar listo para recolección.';
    end if;
    inv := coalesce(trim(so.proveedor_factura_storage_path), '');
    if inv = '' then
      raise exception 'Adjunte la factura digital del proveedor antes de marcar listo.';
    end if;
    update public.sub_orders
    set status = 'listo', updated_at = now()
    where id = p_sub_order_id;
    return;
  end if;

  raise exception 'Transición de sub-pedido no permitida.';
end;
$$;
