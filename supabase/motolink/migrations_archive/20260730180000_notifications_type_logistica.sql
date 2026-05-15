-- Permitir tipo `logistica` (asignación transportista, etc.) en notifications.

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'pago',
    'kyc',
    'mensaje',
    'envio',
    'validacion',
    'logistica'
  ));
