-- Aliado puede cancelar pedido mientras esté en pending (antes de aprobación MotoLink), con motivo.
-- Distingue de rechazo admin con cancelado_por_aliado + notificaciones.

alter table public.transaction_requests
  add column if not exists cancelado_por_aliado boolean not null default false;
alter table public.transaction_requests
  add column if not exists aliado_cancelacion_motivo text;

comment on column public.transaction_requests.cancelado_por_aliado is
  'True si el aliado canceló con motivo; status → rechazado, distinto a rechazo de MotoLink.';
comment on column public.transaction_requests.aliado_cancelacion_motivo is
  'Texto que el aliado indicó al cancelar; obligatorio vía RPC si cancela.';

-- Permite a aliado: pendiente → rechazado con flags (solo a través de RPC que setea columnas).
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

create or replace function public.aliado_cancela_pedido_pendiente(
  p_request_id uuid,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_st text;
  t text;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.';
  end if;

  t := trim(coalesce(p_motivo, ''));
  if t is null or char_length(t) < 3 then
    raise exception 'Debe indicar un motivo de cancelación (al menos 3 caracteres).';
  end if;
  if char_length(t) > 4000 then
    raise exception 'El motivo no puede superar 4000 caracteres.';
  end if;

  select tr.aliado_id, tr.status
  into v_aliado, v_st
  from public.transaction_requests tr
  where tr.id = p_request_id
  for update;

  if v_aliado is null then
    raise exception 'Pedido no encontrado.';
  end if;
  if v_aliado is distinct from auth.uid() then
    raise exception 'Solo el aliado dueño del pedido puede cancelarlo.';
  end if;
  if v_st is distinct from 'pendiente' then
    raise exception 'Solo puede cancelar mientras el pedido está pendiente de aprobación de MotoLink.';
  end if;

  update public.transaction_requests
  set
    status = 'rechazado',
    cancelado_por_aliado = true,
    aliado_cancelacion_motivo = t,
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.aliado_cancela_pedido_pendiente(uuid, text) to authenticated;

-- Notificaciones: no confundir cancelación aliada con rechazo de MotoLink (restante = 20260626120000).
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
