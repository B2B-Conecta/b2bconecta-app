-- Permite al usuario borrar sus propias filas (eliminar una, varias o todas en el cliente).

drop policy if exists "notifications_delete_own" on public.notifications;

create policy "notifications_delete_own"
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());
