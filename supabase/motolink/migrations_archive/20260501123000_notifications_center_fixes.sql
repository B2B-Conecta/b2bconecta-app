-- Ajustes de robustez para notificaciones in-app:
-- 1) garantiza tabla en publicación realtime
-- 2) amplía eventos de pedidos/pagos/notas para aliado/importador/admin

do $$
begin
  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

create or replace function public.notify_to_all_admins(
  p_title text,
  p_body text,
  p_type text,
  p_related_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, type, related_id)
  select p.id, p_title, p_body, p_type, p_related_id
  from public.profiles p
  where p.role = 'administrador';
end;
$$;

create or replace function public.notify_pago_revision_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.pago_estado_revision is distinct from new.pago_estado_revision then
    if new.pago_estado_revision = 'aprobado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values
        (
          new.aliado_id,
          'Pago aprobado',
          'MotoLink aprobó su comprobante de pago del pedido.',
          'pago',
          new.id::text
        ),
        (
          new.owner_id,
          'Pago validado por MotoLink',
          'El comprobante del aliado fue aprobado para un pedido de su inventario.',
          'pago',
          new.id::text
        );
    elsif new.pago_estado_revision = 'rechazado' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Comprobante rechazado',
        'MotoLink rechazó su comprobante. Revise la nota y vuelva a cargarlo.',
        'pago',
        new.id::text
      );
    elsif new.pago_estado_revision = 'en_revision' then
      perform public.notify_to_all_admins(
        'Comprobante por revisar',
        'Un aliado envió un comprobante y requiere revisión.',
        'pago',
        new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.notify_logistica_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
  return new;
end;
$$;

create or replace function public.notify_transaction_request_notes_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.notas_admin is distinct from new.notas_admin then
    if coalesce(btrim(new.notas_admin), '') <> '' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values
        (
          new.aliado_id,
          'Nueva nota de MotoLink',
          'MotoLink agregó una nota al pedido. Revise el detalle.',
          'mensaje',
          new.id::text
        ),
        (
          new.owner_id,
          'Nota administrativa en pedido',
          'MotoLink agregó una nota en un pedido de su inventario.',
          'mensaje',
          new.id::text
        );
    end if;
  end if;

  if old.pago_comprobante_rechazo_nota is distinct from new.pago_comprobante_rechazo_nota then
    if coalesce(btrim(new.pago_comprobante_rechazo_nota), '') <> '' then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        new.aliado_id,
        'Nota sobre comprobante',
        'MotoLink dejó una observación sobre su comprobante de pago.',
        'pago',
        new.id::text
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_transaction_request_notes_change on public.transaction_requests;
create trigger trg_notify_transaction_request_notes_change
after update of notas_admin, pago_comprobante_rechazo_nota on public.transaction_requests
for each row
execute function public.notify_transaction_request_notes_change();

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
    'envio',
    new.id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_new_transaction_request_insert on public.transaction_requests;
create trigger trg_notify_new_transaction_request_insert
after insert on public.transaction_requests
for each row
execute function public.notify_new_transaction_request_insert();

create or replace function public.notify_new_kyc_document_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.notify_to_all_admins(
    'Nuevo documento KYC cargado',
    'Un aliado cargó/actualizó un documento KYC en su expediente.',
    'kyc',
    new.id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_new_kyc_document_insert on public.profile_documents;
create trigger trg_notify_new_kyc_document_insert
after insert on public.profile_documents
for each row
execute function public.notify_new_kyc_document_insert();
