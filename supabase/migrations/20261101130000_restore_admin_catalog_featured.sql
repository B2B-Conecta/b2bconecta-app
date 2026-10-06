-- Restaura destacado/verificado manual de mayoristas (admin).
-- La vitrina del proveedor sigue siendo estándar para importadores activos;
-- este flag solo prioriza y muestra sello en catálogo (máx. 3).

create or replace function public.mc_guard_catalog_featured_until ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.catalog_featured_until is not distinct from old.catalog_featured_until then
    return new;
  end if;
  perform public._assert_administrador ();
  return new;
end;
$$;

drop trigger if exists mc_tr_guard_catalog_featured_until on public.profiles;

create trigger mc_tr_guard_catalog_featured_until
before update of catalog_featured_until on public.profiles
for each row
execute function public.mc_guard_catalog_featured_until ();

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
begin
  perform public._assert_administrador ();

  if p_importador_id is null then
    raise exception 'Importador requerido' using errcode = '22023';
  end if;

  if p_days is null or p_days not in (0, 7, 15, 30) then
    raise exception 'featured_days:7,15,30' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_importador_id
      and p.role = 'importador'
      and p.deactivated_at is null
  ) then
    raise exception 'Importador no válido' using errcode = 'P0002';
  end if;

  if p_days = 0 then
    update public.profiles
    set catalog_featured_until = null
    where id = p_importador_id;
    return null;
  end if;

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

  v_until := now() + make_interval(days => p_days);

  update public.profiles
  set catalog_featured_until = v_until
  where id = p_importador_id;

  return v_until;
end;
$$;

comment on function public.admin_set_importer_catalog_featured (uuid, integer) is
  'Admin: marca un importador como destacado/verificado 7/15/30 días (máx. 3) o p_days=0 para quitar. No controla la vitrina.';

revoke all on function public.admin_set_importer_catalog_featured (uuid, integer)
  from public;
grant execute on function public.admin_set_importer_catalog_featured (uuid, integer)
  to authenticated;

comment on column public.profiles.catalog_featured_until is
  'Hasta cuándo el importador aparece como destacado/verificado en catálogo (admin). Independiente de la vitrina, que es estándar.';
