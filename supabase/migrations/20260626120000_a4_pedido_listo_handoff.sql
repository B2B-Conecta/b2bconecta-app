-- A4: estado intermedio `pedido_listo` (importador confirma mercancía lista en despacho).
-- Solo MotoLink puede pasar `pedido_listo` → `en_transito` (RPC admin).

alter table public.transaction_requests
  add column if not exists at_pedido_listo timestamptz;

comment on column public.transaction_requests.at_pedido_listo is
  'Cuando el importador marca pedido listo para recolección por MotoLink.';

alter table public.transaction_requests
  drop constraint if exists transaction_requests_status_check;

alter table public.transaction_requests
  add constraint transaction_requests_status_check
  check (
    status in (
      'pendiente',
      'aprobado_admin',
      'rechazado',
      'en_preparacion',
      'pedido_listo',
      'en_transito',
      'entregado'
    )
  );

drop policy if exists "tr_select_importer_fulfillment" on public.transaction_requests;
create policy "tr_select_importer_fulfillment"
on public.transaction_requests
for select
to authenticated
using (
  owner_id = auth.uid()
  and status in (
    'aprobado_admin',
    'en_preparacion',
    'pedido_listo',
    'en_transito',
    'entregado'
  )
);

create or replace function public.transaction_requests_set_lifecycle_timestamps()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'aprobado_admin' and new.at_aprobado_admin is null then
      new.at_aprobado_admin := now();
    elsif new.status = 'rechazado' and new.at_rechazado is null then
      new.at_rechazado := now();
    elsif new.status = 'en_preparacion' and new.at_en_preparacion is null then
      new.at_en_preparacion := now();
    elsif new.status = 'pedido_listo' and new.at_pedido_listo is null then
      new.at_pedido_listo := now();
    elsif new.status = 'en_transito' and new.at_en_transito is null then
      new.at_en_transito := now();
    elsif new.status = 'entregado' and new.at_entregado is null then
      new.at_entregado := now();
    end if;
  end if;
  return new;
end;
$$;

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
      if v_days = 0 and v_hours = 0 then
        raise exception 'Debe indicar transit_eta_days o transit_eta_hours (al menos uno).';
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
    raise exception 'Transición de estado no permitida para el aliado';
  end if;

  raise exception 'No autorizado a cambiar el estado del pedido';
end;
$$;

create or replace function public.admin_marca_pedido_en_transito(
  p_request_id uuid,
  p_transit_eta_days integer,
  p_transit_eta_hours integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
  inv text;
  fa text;
  v_days integer;
  v_hours integer;
begin
  if not exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'administrador'
  ) then
    raise exception 'Solo administradores pueden marcar en tránsito';
  end if;

  v_days := coalesce(p_transit_eta_days, 0);
  v_hours := coalesce(p_transit_eta_hours, 0);
  if v_days < 0 or v_days > 365 or v_hours < 0 or v_hours > 23 then
    raise exception 'Valores inválidos: días 0–365, horas 0–23.';
  end if;
  if v_days = 0 and v_hours = 0 then
    raise exception 'Indique al menos un día o una hora de tránsito estimado.';
  end if;

  select
    tr.status,
    tr.proveedor_factura_storage_path,
    tr.factura_aliado_storage_path
  into st, inv, fa
  from public.transaction_requests tr
  where tr.id = p_request_id;

  if st is null then
    raise exception 'Pedido no encontrado';
  end if;
  if st is distinct from 'pedido_listo' then
    raise exception 'Solo pedidos listos para recolección pueden pasar a en tránsito';
  end if;
  if coalesce(trim(inv), '') = '' then
    raise exception 'El importador debe adjuntar la factura digital antes.';
  end if;
  if coalesce(trim(fa), '') = '' then
    raise exception 'Adjunte la factura oficial al aliado antes.';
  end if;

  update public.transaction_requests
  set
    status = 'en_transito',
    transit_eta_days = v_days,
    transit_eta_hours = v_hours,
    transit_eta_set_at = now(),
    updated_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_marca_pedido_en_transito(uuid, integer, integer)
  to authenticated;

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

create or replace function public.transaction_requests_lock_supplier_invoice_after_confirmation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if
    old.status in ('en_preparacion', 'pedido_listo')
    and coalesce(trim(old.factura_aliado_storage_path), '') <> ''
    and (
      old.proveedor_factura_storage_path is distinct from new.proveedor_factura_storage_path
      or old.proveedor_factura_file_name is distinct from new.proveedor_factura_file_name
      or old.proveedor_factura_submitted_at is distinct from new.proveedor_factura_submitted_at
    )
  then
    raise exception
      'Factura del proveedor bloqueada: MotoLink ya confirmó la factura al aliado.';
  end if;

  if
    old.status = 'pedido_listo'
    and (
      old.proveedor_factura_storage_path is distinct from new.proveedor_factura_storage_path
      or old.proveedor_factura_file_name is distinct from new.proveedor_factura_file_name
      or old.proveedor_factura_submitted_at is distinct from new.proveedor_factura_submitted_at
    )
  then
    raise exception
      'Factura del proveedor bloqueada: el pedido ya está marcado como listo para recolección.';
  end if;

  return new;
end;
$$;
