-- Evitar "éxito silencioso" si aún no existe profiles (p. ej. marcar términos
-- antes del primer Guardar Perfil).

create or replace function public.profile_accept_terms (p_version text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_version text := nullif(trim(p_version), '');
  v_updated int;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;
  if v_version is null then
    raise exception 'Versión de términos requerida';
  end if;

  update public.profiles
  set
    terms_accepted_at = now(),
    terms_version = v_version
  where id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception
      'Debe guardar su perfil antes de registrar la aceptación de términos.';
  end if;
end;
$$;

grant execute on function public.profile_accept_terms (text) to authenticated;
