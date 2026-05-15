-- Evita un "Nuevo pedido" por cada fila cuando un mismo carrito (checkout_group_id)
-- incluye varias líneas hacia el mismo importador. La primera fila del par
-- (grupo + importador) dispara la notificación; las demás se omiten.

create or replace function public.mc_notify_tr_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_es_duplicado_misma_linea_importador boolean;
begin
  perform set_config ('row_security', 'off', true);

  if new.checkout_group_id is not null then
    select exists (
      select 1
      from public.transaction_requests tr
      where tr.checkout_group_id = new.checkout_group_id
        and tr.importador_id = new.importador_id
        and tr.id <> new.id
    )
    into v_es_duplicado_misma_linea_importador;

    if v_es_duplicado_misma_linea_importador then
      return new;
    end if;
  end if;

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
