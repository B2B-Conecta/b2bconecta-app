-- Morosidad y recordatorios: usar factura del importador (proveedor_factura_*)
-- en lugar de factura MotoLink admin→aliado (factura_aliado_*, legado).

create or replace function public.tr_is_moroso_pago_pendiente (p_row public.transaction_requests)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_row.status <> 'entregado'::text then
    return false;
  end if;
  if coalesce(p_row.proveedor_factura_storage_path, '') = '' then
    return false;
  end if;
  return coalesce(p_row.pago_estado_revision, '') <> 'aprobado';
end;
$$;

comment on function public.tr_is_moroso_pago_pendiente (public.transaction_requests) is
  'Entregado con factura del importador y pago sin aprobar (sin factura_aliado legado).';

drop trigger if exists trg_clear_aliado_pago_reminder_tr on public.transaction_requests;

create trigger trg_clear_aliado_pago_reminder_tr
after update of status, pago_estado_revision, proveedor_factura_storage_path
  on public.transaction_requests
for each row
execute function public.tr_clear_aliado_pago_reminder_on_tr_update ();
