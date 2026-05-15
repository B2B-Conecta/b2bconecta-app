-- Reconocimiento de asignación por transportista + notificación admin al subir respaldo efectivo.

alter table public.transaction_requests
  add column if not exists transportista_assignment_acknowledged_at timestamptz;

comment on column public.transaction_requests.transportista_assignment_acknowledged_at is
  'Marca de tiempo en que el transportista asignado confirmó recibir la asignación en la app.';

-- ---------------------------------------------------------------------------
-- Transportista: confirma que vio la asignación (pedido debe estar asignado a él).
-- ---------------------------------------------------------------------------
create or replace function public.transportista_acknowledge_assignment(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'transportista'
  ) then
    raise exception 'Solo el transportista asignado puede confirmar.';
  end if;

  update public.transaction_requests tr
  set
    transportista_assignment_acknowledged_at = now(),
    updated_at = now()
  where tr.id = p_request_id
    and tr.assigned_transportista_id = auth.uid()
    and tr.transportista_assignment_acknowledged_at is null
    and tr.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito'
    );

  get diagnostics n = row_count;
  if n = 0 then
    raise exception
      'No se pudo confirmar. Verifique que sea su pedido asignado y que aún no esté confirmado.';
  end if;
end;
$$;

revoke all on function public.transportista_acknowledge_assignment(uuid) from public;
grant execute on function public.transportista_acknowledge_assignment(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin: notificación cuando se registra foto respaldo efectivo (transportista/MotoLink).
-- ---------------------------------------------------------------------------
create or replace function public.notify_admins_efectivo_respaldo_registrado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old text;
  v_new text;
begin
  v_old := coalesce(trim(old.efectivo_respaldo_storage_path), '');
  v_new := coalesce(trim(new.efectivo_respaldo_storage_path), '');
  if v_new <> '' and v_old = '' and new.pago_metodo = 'efectivo' then
    perform public.notify_to_all_admins(
      'Evidencia: cobro en efectivo',
      'Se registró el respaldo fotográfico del cobro en efectivo. Revise el pedido en el panel.',
      'logistica',
      new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists tr_notify_efectivo_respaldo on public.transaction_requests;
create trigger tr_notify_efectivo_respaldo
after update of efectivo_respaldo_storage_path on public.transaction_requests
for each row
when (new.pago_metodo = 'efectivo')
execute procedure public.notify_admins_efectivo_respaldo_registrado();
