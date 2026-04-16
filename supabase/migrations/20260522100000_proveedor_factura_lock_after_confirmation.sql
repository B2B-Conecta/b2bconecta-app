-- Bloquea reemplazo de factura del proveedor cuando MotoLink ya confirmó la factura al aliado.

create or replace function public.transaction_requests_lock_supplier_invoice_after_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if
    old.status = 'en_preparacion'
    and coalesce(trim(old.factura_aliado_storage_path), '') <> ''
    and (
      old.proveedor_factura_storage_path is distinct from new.proveedor_factura_storage_path
      or old.proveedor_factura_file_name is distinct from new.proveedor_factura_file_name
      or old.proveedor_factura_submitted_at is distinct from new.proveedor_factura_submitted_at
    )
  then
    raise exception
      'Factura del proveedor bloqueada: MotoLink ya confirmó la factura al aliado.';
  end if;

  return new;
end;
$$;

drop trigger if exists tr_transaction_requests_lock_supplier_invoice_after_confirmation
  on public.transaction_requests;

create trigger tr_transaction_requests_lock_supplier_invoice_after_confirmation
  before update on public.transaction_requests
  for each row
  execute procedure public.transaction_requests_lock_supplier_invoice_after_confirmation();
