-- Admin (no solo is_owner) puede corregir rol B2B: aliado ↔ importador.
-- Promover a administrador sigue reservado al propietario.

create or replace function public.owner_set_profile_role (
  p_profile_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  v_role := lower(trim(p_role));
  if v_role is null or v_role not in ('aliado', 'importador', 'administrador') then
    raise exception 'Rol no valido';
  end if;

  if v_role = 'administrador' then
    -- Solo el propietario crea / asigna cuentas de administración.
    perform public._owner_guard_target (p_profile_id);
  else
    -- Admin u owner: corregir registro equivocado (minorista ↔ mayorista).
    perform public._guard_account_operator_target (p_profile_id);
  end if;

  perform public._allow_profile_privilege ();

  update public.profiles
  set role = v_role
  where id = p_profile_id;
end;
$$;

comment on function public.owner_set_profile_role (uuid, text) is
  'Cambia el rol. Admin: aliado↔importador. Owner: también administrador.';
