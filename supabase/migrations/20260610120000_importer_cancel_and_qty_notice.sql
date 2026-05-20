-- C4 Punto 11: cancelación por proveedor (importador) con motivo + trazabilidad.

alter table public.transaction_requests
  add column if not exists importador_cancelacion_motivo text;

comment on column public.transaction_requests.importador_cancelacion_motivo is
  'Motivo registrado cuando el importador cancela un pedido en gestión.';

create or replace function public.importer_cancela_pedido_en_gestion (
  p_request_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_owner uuid;
  v_aliado uuid;
  v_status text;
  v_product text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo el importador puede cancelar este pedido';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Debe indicar un motivo de al menos 3 caracteres';
  end if;

  select
    tr.importador_id,
    tr.aliado_id,
    tr.status,
    coalesce(pr.name, 'Pedido')
    into v_owner, v_aliado, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_owner is distinct from v_uid then
    raise exception 'Este pedido no pertenece a su inventario';
  end if;

  if v_status not in ('pendiente', 'en_preparacion', 'pedido_listo') then
    raise exception
      'Solo se puede cancelar mientras el pedido está pendiente, en preparación o listo para despacho';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    importador_cancelacion_motivo = v_motivo,
    original_checkout_group_id = coalesce(original_checkout_group_id, checkout_group_id),
    checkout_group_id = null,
    updated_at = now()
  where id = p_request_id;

  insert into public.transaction_request_messages (
    transaction_request_id,
    author_id,
    author_role,
    body
  )
  values (
    p_request_id,
    v_uid,
    'importador',
    format('Pedido cancelado por proveedor. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_aliado,
      'Pedido cancelado por el proveedor',
      format('El proveedor canceló "%s". Revisa el motivo en el detalle del pedido.', v_product),
      'envio',
      p_request_id
    );

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    p.id,
    'Cancelación por proveedor',
    format('El importador canceló "%s". Revisa seguimiento y motivo.', v_product),
    'supervision',
    p_request_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

grant execute on function public.importer_cancela_pedido_en_gestion (uuid, text)
  to authenticated;
