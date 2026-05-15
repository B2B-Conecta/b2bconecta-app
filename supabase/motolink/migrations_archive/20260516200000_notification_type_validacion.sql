-- Tipo dedicado para "solicitud por validar" (admin): deep link a pestaña Por validar.

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in ('pago', 'kyc', 'mensaje', 'envio', 'validacion'));

create or replace function public.notify_new_transaction_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.owner_id,
    'Nueva solicitud de pedido',
    'Un aliado creó una nueva solicitud sobre su inventario.',
    'envio',
    new.id::text
  );

  perform public.notify_to_all_admins(
    'Nueva solicitud por validar',
    'Se creó una nueva solicitud de pedido pendiente de revisión.',
    'validacion',
    new.id::text
  );
  return new;
end;
$$;
