-- Owner: borrar de Auth una cuenta de prueba (libera el correo).
-- Si hay pedidos, valoraciones o cortes, se rechaza: use baja lógica.

create or replace function public.owner_hard_delete_profile (
  p_profile_id uuid,
  p_confirm text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_confirm text := lower(trim(coalesce(p_confirm, '')));
begin
  perform public._owner_guard_target (p_profile_id);

  select lower(trim(u.email::text))
    into v_email
  from auth.users u
  where u.id = p_profile_id;

  if v_email is null then
    raise exception 'Usuario de Auth no encontrado';
  end if;

  if v_confirm is distinct from v_email then
    raise exception 'Escriba el correo de la cuenta para confirmar el borrado';
  end if;

  if exists (
    select 1
    from public.transaction_requests tr
    where tr.aliado_id = p_profile_id
       or tr.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene pedidos. Use baja lógica para conservarlos.';
  end if;

  if exists (
    select 1
    from public.commission_settlements cs
    where cs.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene cortes de comisión. Use baja lógica para conservarlos.';
  end if;

  if exists (
    select 1
    from public.order_ratings r
    where r.aliado_id = p_profile_id
       or r.importador_id = p_profile_id
  ) then
    raise exception
      'Esta cuenta tiene valoraciones. Use baja lógica para conservarlos.';
  end if;

  update public.commission_settlements
  set created_by = null
  where created_by = p_profile_id;

  update public.commission_settlements
  set issued_by = null
  where issued_by = p_profile_id;

  update public.order_ratings
  set
    comment_hidden_by = null
  where comment_hidden_by = p_profile_id;

  update public.order_ratings
  set submitted_by_admin_id = null
  where submitted_by_admin_id = p_profile_id;

  update public.profile_documents
  set reviewed_by = null
  where reviewed_by = p_profile_id;

  update public.transaction_requests
  set confirmado_por = null
  where confirmado_por = p_profile_id;

  delete from public.products p
  where p.owner_id = p_profile_id;

  delete from auth.identities i
  where i.user_id = p_profile_id;

  delete from auth.users u
  where u.id = p_profile_id;

  if not found then
    raise exception 'No se pudo borrar el usuario de Auth';
  end if;
end;
$$;

revoke all on function public.owner_hard_delete_profile (uuid, text) from public;

grant execute on function public.owner_hard_delete_profile (uuid, text)
  to authenticated;

comment on function public.owner_hard_delete_profile (uuid, text) is
  'Owner: borra auth.users y el perfil. Libera el correo. Rechaza si hay pedidos.';
