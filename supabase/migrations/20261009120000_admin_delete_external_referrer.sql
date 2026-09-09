-- Admin puede borrar un vendedor externo para liberar el código (p. ej. rehacer una prueba).
-- Los perfiles referidos quedan: referred_by_external_id pasa a null (ON DELETE SET NULL).

create or replace function public.admin_delete_external_referrer (p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._require_admin ();

  if p_id is null then
    raise exception 'ID requerido.';
  end if;

  delete from public.external_referrers e
  where e.id = p_id;

  if not found then
    raise exception 'Vendedor externo no encontrado.';
  end if;
end;
$$;

grant execute on function public.admin_delete_external_referrer (uuid)
  to authenticated;
