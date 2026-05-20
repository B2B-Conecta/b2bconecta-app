-- RPC llamado desde la app (aliado cancela pedido en estado `pendiente` con motivo).

alter table public.transaction_requests
  add column if not exists cancelado_por_aliado boolean not null default false;

alter table public.transaction_requests
  add column if not exists aliado_cancelacion_motivo text;

comment on column public.transaction_requests.cancelado_por_aliado is
  'True cuando el aliado cancela explícitamente antes de avanzar el flujo.';
comment on column public.transaction_requests.aliado_cancelacion_motivo is
  'Motivo registrado cuando el aliado cancela un pedido en pendiente.';

create or replace function public.aliado_cancela_pedido_pendiente (
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
  v_aliado uuid;
  v_owner uuid;
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

  if v_role is distinct from 'aliado' then
    raise exception 'Solo el aliado puede cancelar este pedido de esta forma';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Debe indicar un motivo de al menos 3 caracteres';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    coalesce(pr.name, 'Pedido')
    into v_aliado, v_owner, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_aliado is distinct from v_uid then
    raise exception 'Este pedido no corresponde a su cuenta';
  end if;

  if v_status is distinct from 'pendiente' then
    raise exception 'Solo puede cancelar mientras el pedido está pendiente';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    cancelado_por_aliado = true,
    aliado_cancelacion_motivo = v_motivo,
    importador_cancelacion_motivo = null,
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
    'aliado',
    format('Pedido cancelado por el aliado. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_owner,
      'Pedido cancelado por el aliado',
      format('El aliado canceló "%s". Revisa el motivo en el detalle del pedido.', v_product),
      'envio',
      p_request_id
    );

  insert into public.notifications (user_id, title, body, type, related_id)
  select
    p.id,
    'Cancelación por aliado',
    format('El aliado canceló "%s". Revisa seguimiento y motivo.', v_product),
    'supervision',
    p_request_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

grant execute on function public.aliado_cancela_pedido_pendiente (uuid, text)
  to authenticated;
