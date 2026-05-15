-- Notificación cuando MotoLink publica/actualiza la factura oficial al aliado.
-- Cubre pedido simple y maestro multi-importador.

create or replace function public.notify_factura_aliado_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_master boolean;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.factura_aliado_storage_path is distinct from new.factura_aliado_storage_path
     and coalesce(trim(new.factura_aliado_storage_path), '') <> '' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Factura MotoLink disponible',
      'MotoLink publicó la factura oficial de su pedido. Ya puede revisarla y gestionar el pago en la ficha.',
      'pago',
      new.id::text
    );

    v_master := coalesce(new.is_master_order, false);
    perform public.notify_tr_importer_recipients(
      new.id,
      v_master,
      new.owner_id,
      'Factura MotoLink publicada',
      'MotoLink publicó la factura oficial al aliado para este pedido.',
      'pago',
      new.id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists tr_notify_factura_aliado_uploaded on public.transaction_requests;
create trigger tr_notify_factura_aliado_uploaded
after update on public.transaction_requests
for each row
execute procedure public.notify_factura_aliado_uploaded();
