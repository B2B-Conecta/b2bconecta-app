-- Admin MotoLink: anular pedido ya aprobado (a en tránsito) con motivo, notificaciones, stock y plan de cuotas.

alter table public.transaction_requests
  add column if not exists anulado_por_motolink boolean not null default false;
alter table public.transaction_requests
  add column if not exists motolink_anulacion_motivo text;

comment on column public.transaction_requests.anulado_por_motolink is
  'MotoLink anuló un pedido tras aprobación (no es rechazo de validación ni cancelación de aliado).';
comment on column public.transaction_requests.motolink_anulacion_motivo is
  'Motivo registrado por un administrador al anular el pedido.';

-- Ampliar transición admin → rechazado con flags (solo vía RPC).
create or replace function public.transaction_requests_enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
  is_importer_owner boolean;
  is_aliado_owner boolean;
  v_days integer;
  v_hours integer;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) into is_admin;

  select
    new.owner_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'importador'
    )
  into is_importer_owner;

  select
    new.aliado_id = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'aliado'
    )
  into is_aliado_owner;

  if is_admin then
    if old.status = 'pendiente' and new.status in ('aprobado_admin', 'rechazado') then
      return new;
    end if;

    if old.status in (
      'aprobado_admin',
      'en_preparacion',
      'pedido_listo',
      'en_transito'
    ) and new.status = 'rechazado' then
      if coalesce(new.anulado_por_motolink, false) = true
         and new.motolink_anulacion_motivo is not null
         and char_length(trim(new.motolink_anulacion_motivo)) between 3 and 4000
      then
        return new;
      end if;
    end if;

    if old.status = 'pedido_listo' and new.status = 'en_transito' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'No puede marcar en tránsito sin factura del proveedor cargada.';
      end if;

      v_days := coalesce(new.transit_eta_days, 0);
      v_hours := coalesce(new.transit_eta_hours, 0);
      if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
        raise exception 'ETA inválido: días 0–365 y horas 0–23.';
      end if;

      return new;
    end if;

    raise exception 'Transición de estado no permitida para administrador';
  end if;

  if is_importer_owner then
    if old.status = 'aprobado_admin' and new.status = 'en_preparacion' then
      return new;
    end if;
    if old.status = 'en_preparacion' and new.status = 'pedido_listo' then
      if coalesce(trim(new.proveedor_factura_storage_path), '') = '' then
        raise exception 'Adjunte la factura digital del proveedor antes de marcar pedido listo.';
      end if;
      return new;
    end if;
    raise exception 'Transición de estado no permitida para importador';
  end if;

  if is_aliado_owner then
    if old.status = 'en_transito' and new.status = 'entregado' then
      return new;
    end if;
    if old.status = 'pendiente' and new.status = 'rechazado' then
      if coalesce(new.cancelado_por_aliado, false) = true
         and new.aliado_cancelacion_motivo is not null
         and char_length(trim(new.aliado_cancelacion_motivo)) > 0
         and char_length(trim(new.aliado_cancelacion_motivo)) <= 4000
      then
        return new;
      end if;
    end if;
    raise exception 'Transición de estado no permitida para el aliado';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

create or replace function public.admin_anula_pedido_por_motolink(
  p_request_id uuid,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t text;
  st text;
  v_pid uuid;
  v_owner uuid;
  q int;
  sdes timestamptz;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores MotoLink pueden anular un pedido en curso.';
  end if;

  t := trim(coalesce(p_motivo, ''));
  if char_length(t) < 3 then
    raise exception 'Debe indicar un motivo (al menos 3 caracteres).';
  end if;
  if char_length(t) > 4000 then
    raise exception 'El motivo no puede superar 4000 caracteres.';
  end if;

  select
    tr.status,
    tr.product_id,
    tr.owner_id,
    tr.cantidad,
    tr.stock_descontado_en
  into st, v_pid, v_owner, q, sdes
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if st is null then
    raise exception 'Pedido no encontrado.';
  end if;
  if st in ('pendiente', 'entregado', 'rechazado') then
    raise exception
      'No puede anular en este estado. Use anulación solo con pedido aprobado y en curso (no pendiente, no entregado ni ya cerrado).';
  end if;
  if st not in (
    'aprobado_admin',
    'en_preparacion',
    'pedido_listo',
    'en_transito'
  ) then
    raise exception 'Estado del pedido no admite anulación por MotoLink.';
  end if;

  if sdes is not null and v_pid is not null and v_owner is not null and q is not null and q > 0 then
    update public.products p
    set stock = p.stock + q
    where p.id = v_pid
      and p.owner_id = v_owner;
  end if;

  delete from public.payment_schedule
  where transaction_request_id = p_request_id;

  update public.transaction_requests
  set
    status = 'rechazado',
    anulado_por_motolink = true,
    motolink_anulacion_motivo = t,
    cancelado_por_aliado = false,
    stock_descontado_en = null,
    credit_plan_type = null,
    credit_plan_confirmed_at = null,
    credit_monto_bloqueado = null,
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_anula_pedido_por_motolink(uuid, text) to authenticated;

-- Notificaciones: anulación MotoLink vs otras bajas a rejected.
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
  mot text;
  body_importer text;
  mot2 text;
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
      if coalesce(new.cancelado_por_aliado, false) then
        mot := left(trim(coalesce(new.aliado_cancelacion_motivo, '')), 1200);
        perform public.notify_to_all_admins(
          'Solicitud cancelada por un aliado',
          format('Pedido %s. Motivo: %s', new.id::text, coalesce(mot, '')),
          'envio',
          new.id::text
        );
        body_importer := 'El aliado canceló la solicitud antes de la aprobación de MotoLink. Motivo: ' || coalesce(mot, '');
        insert into public.notifications (user_id, title, body, type, related_id)
        values (
          new.owner_id,
          'Solicitud cancelada por el aliado',
          left(body_importer, 2000),
          'envio',
          new.id::text
        );
      elsif coalesce(new.anulado_por_motolink, false) then
        mot2 := left(trim(coalesce(new.motolink_anulacion_motivo, '')), 1200);
        insert into public.notifications (user_id, title, body, type, related_id)
        values
          (
            new.aliado_id,
            'Pedido anulado por MotoLink',
            'MotoLink anuló un pedido que había estado aprobado. Motivo: ' || coalesce(mot2, ''),
            'envio',
            new.id::text
          ),
          (
            new.owner_id,
            'Pedido anulado por MotoLink',
            'MotoLink anuló un pedido asociado a su inventario. Motivo: ' || left(coalesce(mot2, ''), 1200),
            'envio',
            new.id::text
          );
        perform public.notify_to_all_admins(
          'Pedido anulado por administrador',
          format('Pedido %s. Motivo: %s', new.id::text, coalesce(mot2, '')),
          'envio',
          new.id::text
        );
      else
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
      end if;
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
    elsif new.status = 'pedido_listo' then
      perform public.notify_to_all_admins(
        'Pedido listo para recolección',
        'El importador confirmó que la mercancía está lista en despacho. Puede coordinar la recolección y marcar en tránsito cuando el transporte retire la carga.',
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
