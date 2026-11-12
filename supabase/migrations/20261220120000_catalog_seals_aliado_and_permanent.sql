-- Sellos Verificado / Destacado: también tiendas minoristas (aliado)
-- y vigencia permanente (p_days = 3650).

create or replace function public.admin_set_importer_catalog_featured (
  p_importador_id uuid,
  p_days integer
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_until timestamptz;
  v_n integer;
  v_role text;
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Perfil requerido' using errcode = '22023';
  end if;

  -- 0 quita; 7/15/30 vigencia corta; 3650 = permanente (~10 años).
  if p_days is null or p_days not in (0, 7, 15, 30, 3650) then
    raise exception 'featured_days:0,7,15,30,3650' using errcode = '22023';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = p_importador_id
    and p.role in ('importador', 'aliado')
    and p.deactivated_at is null;

  if v_role is null then
    raise exception 'Perfil no válido' using errcode = 'P0002';
  end if;

  if p_days = 0 then
    update public.profiles
    set catalog_featured_until = null
    where id = p_importador_id;
    return null;
  end if;

  -- Tope de 3 destacados solo entre mayoristas.
  if v_role = 'importador' then
    select count(*)::integer
      into v_n
    from public.profiles p
    where p.role = 'importador'
      and p.deactivated_at is null
      and p.catalog_featured_until is not null
      and p.catalog_featured_until > now()
      and p.id <> p_importador_id;

    if coalesce(v_n, 0) >= 3 then
      raise exception 'featured_limit:3' using errcode = 'P0001';
    end if;
  end if;

  v_until := now() + make_interval(days => p_days);

  update public.profiles
  set catalog_featured_until = v_until
  where id = p_importador_id;

  return v_until;
end;
$$;

comment on function public.admin_set_importer_catalog_featured (uuid, integer) is
  'Admin: Destacado 7/15/30/3650 días (máx. 3 mayoristas) o 0 para quitar. Acepta importador y aliado.';

create or replace function public.admin_set_importer_catalog_verified (
  p_importador_id uuid,
  p_verified boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz;
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Perfil requerido' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_importador_id
      and p.role in ('importador', 'aliado')
      and p.deactivated_at is null
  ) then
    raise exception 'Perfil no válido' using errcode = 'P0002';
  end if;

  if coalesce(p_verified, false) then
    v_at := now();
  else
    v_at := null;
  end if;

  update public.profiles
  set catalog_verified_at = v_at
  where id = p_importador_id;

  return v_at;
end;
$$;

comment on function public.admin_set_importer_catalog_verified (uuid, boolean) is
  'Admin: Verificado on/off para importador o aliado. No controla la vitrina.';
