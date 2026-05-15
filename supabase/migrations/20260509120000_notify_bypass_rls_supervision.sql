-- 1) Desactiva RLS dentro de las funciones que insertan notifications (el invocador sigue siendo
--    importador/aliado; sin esto el INSERT puede fallar silenciosamente según políticas).
-- 2) Supervisión: un aviso a cada perfil administrador ante cada cambio de estado.

create or replace function public.mc_notify_trm_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
begin
  perform set_config ('row_security', 'off', true);

  select tr.aliado_id, tr.importador_id
    into v_aliado, v_imp
  from public.transaction_requests tr
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  if new.author_role = 'aliado' and v_imp is not null then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_imp,
      'Nuevo mensaje',
      'Tiene un nuevo mensaje en un pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'importador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje del importador',
      'Tiene un nuevo mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'administrador' then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      v_aliado,
      'Nuevo mensaje',
      'El equipo dejó un mensaje en su pedido.',
      'mensaje',
      new.transaction_request_id::text
    );
    if v_imp is not null then
      insert into public.notifications (user_id, title, body, type, related_id)
      values (
        v_imp,
        'Nuevo mensaje',
        'El equipo dejó un mensaje en un pedido.',
        'mensaje',
        new.transaction_request_id::text
      );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.mc_notify_tr_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config ('row_security', 'off', true);

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

create or replace function public.mc_notify_tr_status_changed ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config ('row_security', 'off', true);

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
          'Hay un cambio de estado en su pedido.'
      end,
      'pedido',
      new.id::text
    );
  elsif new.status = 'entregado'::text then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      new.importador_id,
      'Pedido recibido en taller',
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

  -- Solo supervisión (no sustituye avisos aliado/importador).
  insert into public.notifications (user_id, title, body, type, related_id)
  select
    adm.id,
    'Supervisión · cambio de estado',
    format(
      'Pedido %s: %s → %s',
      substring (new.id::text, 1, 8) || '…',
      old.status,
      new.status
    ),
    'supervision',
    new.id::text
  from public.profiles adm
  where adm.role = 'administrador';

  return new;
end;
$$;
