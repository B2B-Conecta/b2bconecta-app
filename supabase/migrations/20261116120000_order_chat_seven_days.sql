-- Tras marcar el pedido como recibido, tienda y proveedor pueden seguir
-- escribiendo (texto, foto o video) durante 7 días. El administrador no
-- tiene ese límite. Un mensaje en un pedido recibido avisa también a
-- la administración.

create or replace function public.mc_notify_trm_insert ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_aliado uuid;
  v_imp uuid;
  v_status text;
  v_product text;
  v_name text;
  v_preview text;
  v_body text;
  v_admin uuid;
begin
  perform set_config('row_security', 'off', true);

  select tr.aliado_id, tr.importador_id, tr.status, nullif(btrim(pr.name), '')
    into v_aliado, v_imp, v_status, v_product
  from public.transaction_requests tr
  left join public.products pr on pr.id = tr.product_id
  where tr.id = new.transaction_request_id;

  if v_aliado is null then
    return new;
  end if;

  v_name := coalesce(public.mc_profile_label(new.author_id), 'Un usuario');
  v_preview := public.mc_message_preview(new.body, new.attachments);
  if v_product is not null then
    v_body := 'En el pedido de ' || v_product || ': ' || v_preview;
  else
    v_body := 'En tu pedido: ' || v_preview;
  end if;

  if new.author_role = 'aliado' and v_imp is not null then
    perform public.mc_insert_notification(
      v_imp,
      v_name,
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'importador' then
    perform public.mc_insert_notification(
      v_aliado,
      v_name,
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
  elsif new.author_role = 'administrador' then
    perform public.mc_insert_notification(
      v_aliado,
      'B2B Conecta',
      v_body,
      'mensaje',
      new.transaction_request_id::text
    );
    if v_imp is not null then
      perform public.mc_insert_notification(
        v_imp,
        'B2B Conecta',
        v_body,
        'mensaje',
        new.transaction_request_id::text
      );
    end if;
  end if;

  if new.author_role in ('aliado', 'importador')
     and v_status = 'entregado' then
    for v_admin in
      select adm.id
      from public.profiles adm
      where adm.role = 'administrador'
        and adm.deactivated_at is null
        and adm.id is distinct from new.author_id
        and adm.id is distinct from v_aliado
        and adm.id is distinct from v_imp
    loop
      perform public.mc_insert_notification(
        v_admin,
        v_name,
        v_body,
        'mensaje',
        new.transaction_request_id::text
      );
    end loop;
  end if;

  return new;
end;
$$;

drop policy if exists trm_insert_participants on public.transaction_request_messages;

create policy trm_insert_participants
  on public.transaction_request_messages for insert
  to authenticated
  with check (
    author_id = auth.uid ()
    and exists (
      select 1
      from public.transaction_requests tr
      where tr.id = transaction_request_id
        and (
          (
            exists (
              select 1
              from public.profiles p
              where p.id = auth.uid ()
                and p.role = 'administrador'
            )
            and author_role = 'administrador'
          )
          or (
            (
              (tr.aliado_id = auth.uid () and author_role = 'aliado')
              or (tr.importador_id = auth.uid () and author_role = 'importador')
            )
            and (
              tr.status not in ('entregado', 'rechazado')
              or (
                tr.status = 'entregado'
                and coalesce(tr.at_entregado, tr.updated_at)
                  >= now() - interval '7 days'
              )
            )
          )
        )
    )
  );
