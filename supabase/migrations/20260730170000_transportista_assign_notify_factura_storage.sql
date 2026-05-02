-- Notificación in-app al transportista cuando MotoLink lo asigna a un pedido.
-- Lectura de factura MotoLink al aliado en Storage para transportista asignado.

create or replace function public.notify_transportista_pedido_asignado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.assigned_transportista_id is null then
    return new;
  end if;
  if old.assigned_transportista_id is not distinct from new.assigned_transportista_id then
    return new;
  end if;

  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.assigned_transportista_id,
    'Asignación de despacho',
    'MotoLink le asignó un pedido. Abra Despacho para ver detalle, ruta y documentos de referencia.',
    'logistica',
    new.id::text
  );

  return new;
end;
$$;

drop trigger if exists tr_notify_transportista_asignado on public.transaction_requests;
create trigger tr_notify_transportista_asignado
after update of assigned_transportista_id on public.transaction_requests
for each row
when (
  new.assigned_transportista_id is not null
  and (
    old.assigned_transportista_id is null
    or old.assigned_transportista_id is distinct from new.assigned_transportista_id
  )
)
execute function public.notify_transportista_pedido_asignado();

-- Factura MotoLink (`order-ally-invoices`): transportista asignado puede generar URL firmada.
drop policy if exists "order_ally_inv_select" on storage.objects;
create policy "order_ally_inv_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'order-ally-invoices'
  and (
    exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.aliado_id = auth.uid()
    )
    or exists (
      select 1 from public.transaction_requests tr
      where tr.id::text = (storage.foldername(name))[1]
        and tr.assigned_transportista_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'administrador'
    )
  )
);
