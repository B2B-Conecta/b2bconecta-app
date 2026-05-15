-- MotoConecta order lifecycle: allow pedido_listo + en_transito + aprobado_admin, migrate enviado → en_transito,
-- notify counterparty on new order + status changes, expose aliado_marca_pedido_entregado, refresh cupo RPC.

-- ---------------------------------------------------------------------------
-- 1. Relax status CHECK (greenfield had only 5 values; app expects full cycle)
-- ---------------------------------------------------------------------------
alter table public.transaction_requests
  drop constraint if exists transaction_requests_status_check;

alter table public.transaction_requests
  add constraint transaction_requests_status_check check (
    status = any (
      array[
        'pendiente'::text,
        'aprobado_admin'::text,
        'en_preparacion'::text,
        'pedido_listo'::text,
        'en_transito'::text,
        'enviado'::text,
        'entregado'::text,
        'rechazado'::text
      ]
    )
  );

-- Legacy “enviado” → “en tránsito” (MotoConecta usa en_transito tras despacho).
update public.transaction_requests
set status = 'en_transito'
where status = 'enviado';

-- ---------------------------------------------------------------------------
-- 2. Cupo abierto: mismos estados operativos que la app (incl. listo / tránsito).
-- ---------------------------------------------------------------------------
create or replace function public.aliado_effective_open_exposure (p_aliado_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    return 0;
  end if;
  if auth.uid () is distinct from p_aliado_id
     and not exists (
       select 1
       from public.profiles p
       where p.id = auth.uid ()
         and p.role = 'administrador'
     ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return coalesce(
    (
      select sum(tr.precio_total_usd)::numeric
      from public.transaction_requests tr
      where tr.aliado_id = p_aliado_id
        and tr.status = any (
          array[
            'pendiente'::text,
            'en_preparacion'::text,
            'pedido_listo'::text,
            'en_transito'::text,
            'enviado'::text
          ]
        )
    ),
    0::numeric
  );
end;
$$;

grant execute on function public.aliado_effective_open_exposure (uuid) to authenticated;
grant execute on function public.aliado_effective_open_exposure (uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Aliado cierra: en_transito | enviado (legacy) → entregado
-- ---------------------------------------------------------------------------
create or replace function public.aliado_marca_pedido_entregado (p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  update public.transaction_requests tr
  set status = 'entregado'::text
  where tr.id = p_request_id
    and tr.aliado_id = auth.uid ()
    and tr.status = any (array['en_transito'::text, 'enviado'::text]);

  if not found then
    raise exception
      'No se puede marcar como entregado (estado o permiso inválido).'
      using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.aliado_marca_pedido_entregado (uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Notificaciones: nuevo pedido + cambios de estado (contraparte)
-- ---------------------------------------------------------------------------
create or replace function public.mc_notify_tr_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, type, related_id)
  values (
    new.importador_id,
    'Nuevo pedido',
    'Un aliado solicitó un pedido. Revíselo en Pedidos.',
    'pedido',
    new.id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_mc_notify_tr_insert on public.transaction_requests;

create trigger trg_mc_notify_tr_insert
after insert on public.transaction_requests
for each row
execute function public.mc_notify_tr_insert ();

create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'update' then
    return new;
  end if;
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status in (
    'en_preparacion'::text,
    'pedido_listo'::text,
    'en_transito'::text,
    'enviado'::text
  )
  then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      case new.status
        when 'en_preparacion' then 'Pedido en preparación'
        when 'pedido_listo' then 'Listo para despacho'
        when 'en_transito' then 'Pedido en tránsito'
        else 'Actualización de pedido'
      end,
      case new.status
        when 'en_preparacion' then
          'El importador confirmó la solicitud y está preparando tu pedido.'
        when 'pedido_listo' then
          'El importador marcó el pedido como listo para despacho.'
        when 'en_transito' then
          'El pedido fue despachado y va en camino a tu taller.'
        else
          'Hay un cambio de estado en tu pedido.'
      end,
      'pedido',
      new.id::text
    );
  elsif new.status = 'entregado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido recibido',
      'El aliado confirmó la recepción del pedido en su taller.',
      'pedido',
      new.id::text
    );
  elsif new.status = 'rechazado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.aliado_id,
      'Pedido rechazado',
      'Un pedido pasó a rechazado. Revíselo en Pedidos.',
      'pedido',
      new.id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_mc_notify_tr_status on public.transaction_requests;

create trigger trg_mc_notify_tr_status
after update of status on public.transaction_requests
for each row
execute function public.mc_notify_tr_status_changed ();
