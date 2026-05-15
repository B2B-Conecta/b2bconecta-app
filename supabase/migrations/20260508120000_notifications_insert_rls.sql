-- Permite INSERT en notifications cuando el actor es parte del pedido (triggers + cliente seguro).
-- Sin esto, los triggers SECURITY DEFINER siguen evaluando RLS como el usuario que hace UPDATE
-- y el INSERT a otro user_id falla → no hay notificaciones al aliado.

grant insert on public.notifications to authenticated;

drop policy if exists notifications_insert_tr_participant on public.notifications;

create policy notifications_insert_tr_participant
  on public.notifications for insert
  to authenticated
  with check (
    related_id is not null
    and exists (
      select 1
      from public.transaction_requests tr
      where tr.id::text = related_id
        and (
          (
            tr.aliado_id = user_id
            and tr.importador_id = auth.uid ()
          )
          or (
            tr.importador_id = user_id
            and tr.aliado_id = auth.uid ()
          )
          or (
            exists (
              select 1
              from public.profiles p
              where p.id = auth.uid ()
                and p.role = 'administrador'
            )
            and (
              tr.aliado_id = user_id
              or tr.importador_id = user_id
            )
          )
        )
    )
  );
