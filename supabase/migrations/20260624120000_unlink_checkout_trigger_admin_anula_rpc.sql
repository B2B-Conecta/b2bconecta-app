-- 1) Centralizar desvinculación del carrito al pasar a rechazado (cualquier origen: RPC, admin, etc.).
--    Los RPC existentes pueden seguir asignando original/checkout; idempotente con este BEFORE UPDATE.

create or replace function public.tr_transaction_requests_unlink_checkout_on_rechazado ()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.status = 'rechazado' and old.status is distinct from 'rechazado' then
      if old.checkout_group_id is not null then
        new.original_checkout_group_id :=
          coalesce(new.original_checkout_group_id, old.checkout_group_id);
      end if;
      new.checkout_group_id := null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_tr_unlink_checkout_on_rechazado on public.transaction_requests;

create trigger tr_tr_unlink_checkout_on_rechazado
before update on public.transaction_requests
for each row
execute function public.tr_transaction_requests_unlink_checkout_on_rechazado ();

-- 2) Columnas MotoLink anulación (apps/admin ya las leen desde el modelo Dart).
alter table public.transaction_requests
  add column if not exists anulado_por_motolink boolean not null default false;

alter table public.transaction_requests
  add column if not exists motolink_anulacion_motivo text;

comment on column public.transaction_requests.anulado_por_motolink is
  'True cuando MotoLink anula el pedido (post-aprobación) con motivo.';
comment on column public.transaction_requests.motolink_anulacion_motivo is
  'Motivo de anulación registrado por MotoLink.';

-- 3) RPC llamada desde la app admin (antes ausente en migraciones del repo).
create or replace function public.admin_anula_pedido_por_motolink (
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
  v_importador uuid;
  v_status text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_product text;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa';
  end if;

  select role
    into v_role
  from public.profiles
  where id = v_uid;

  if v_role is distinct from 'administrador' then
    raise exception 'Solo personal MotoLink puede anular pedidos';
  end if;

  if p_request_id is null then
    raise exception 'Pedido inválido';
  end if;

  if length(v_motivo) < 3 then
    raise exception 'Indique un motivo de anulación de al menos 3 caracteres';
  end if;

  select
    tr.aliado_id,
    tr.importador_id,
    tr.status,
    coalesce(pr.name, 'Pedido')
    into v_aliado, v_importador, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = p_request_id
  for update of tr;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  if v_status in ('pendiente', 'entregado', 'rechazado') then
    raise exception
      'Solo se puede anular pedidos en curso (no pendientes de primera gestión, ni entregados ni ya cerrados)';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    at_rechazado = now(),
    anulado_por_motolink = true,
    motolink_anulacion_motivo = v_motivo,
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
    'administrador',
    format('Pedido anulado por MotoLink. Motivo: %s', v_motivo)
  );

  insert into public.notifications (user_id, title, body, type, related_id)
  values
    (
      v_aliado,
      'Pedido anulado por MotoLink',
      format(
        'MotoLink anuló el pedido «%s». Revisa el motivo en el detalle.',
        v_product
      ),
      'envio',
      p_request_id
    ),
    (
      v_importador,
      'Pedido anulado por MotoLink',
      format(
        'MotoLink anuló «%s» con un pedido asignado a tu inventario. Revisa el motivo.',
        v_product
      ),
      'envio',
      p_request_id
    );
end;
$$;

grant execute on function public.admin_anula_pedido_por_motolink (uuid, text)
  to authenticated;
