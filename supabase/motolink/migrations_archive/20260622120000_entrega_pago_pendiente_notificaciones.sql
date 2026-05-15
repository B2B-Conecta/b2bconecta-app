-- Entrega confirmada por el aliado con factura MotoLink pero sin pago aprobado:
-- avisos al aliado, importador y administradores.

create or replace function public.notify_logistica_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  fac text;
  prev text;
  pago_pend boolean;
begin
  if old.status is distinct from new.status then
    if new.status = 'aprobado_admin' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values
        (
          new.aliado_id,
          'Pedido aprobado por MotoLink',
          'Su solicitud fue aprobada y pasará a preparación.',
          'envio',
          new.id::text
        ),
        (
          new.owner_id,
          'Pedido aprobado para su inventario',
          'MotoLink aprobó una solicitud asociada a su inventario.',
          'envio',
          new.id::text
        );
    elsif new.status = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values
        (
          new.aliado_id,
          'Pedido rechazado',
          'MotoLink rechazó su solicitud. Revise notas del pedido.',
          'envio',
          new.id::text
        ),
        (
          new.owner_id,
          'Pedido rechazado por MotoLink',
          'Una solicitud de su inventario fue rechazada.',
          'envio',
          new.id::text
        );
    elsif new.status = 'en_preparacion' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido en preparación',
        'El importador empezó la preparación de su pedido.',
        'envio',
        new.id::text
      );
      perform public.notify_to_all_admins(
        'Pedido en preparación',
        'Un importador marcó un pedido como en preparación.',
        'envio',
        new.id::text
      );
    elsif new.status = 'en_transito' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Pedido en tránsito',
        'Su pedido fue despachado y está en tránsito.',
        'envio',
        new.id::text
      );
    elsif new.status = 'entregado' then
      fac := coalesce(trim(new.factura_aliado_storage_path), '');
      prev := coalesce(nullif(trim(new.pago_estado_revision), ''), 'pendiente');
      pago_pend := fac <> '' and prev is distinct from 'aprobado';

      if pago_pend then
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Entrega confirmada · pago pendiente',
          'Registró la recepción del pedido. Sigue pendiente el comprobante de pago o su aprobación por MotoLink; complételo en la ficha del pedido.',
          'pago',
          new.id::text
        );
        perform public.notify_to_all_admins(
          'Entrega con pago pendiente',
          format(
            'El aliado confirmó la recepción del pedido %s; el pago aún no está aprobado por MotoLink.',
            new.id::text
          ),
          'pago',
          new.id::text
        );
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.owner_id,
          'Entrega confirmada · pago pendiente',
          'El aliado recibió el pedido. El comprobante de pago aún no fue aprobado por MotoLink.',
          'pago',
          new.id::text
        );
      else
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.aliado_id,
          'Pedido entregado',
          'El pedido fue marcado como entregado.',
          'envio',
          new.id::text
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;
