-- Alcance del envío gratis del proveedor: estados elegidos, o todos si lo marca.

alter table public.profiles
  add column if not exists envio_gratis_todos boolean not null default false;

alter table public.profiles
  add column if not exists envio_gratis_estados text[] not null default '{}';

comment on column public.profiles.envio_gratis_todos is
  'Envío gratis en todos los estados solo cuando el proveedor lo elige.';

comment on column public.profiles.envio_gratis_estados is
  'Estados donde aplica el envío gratis. Vacío si no hay alcance parcial.';

create or replace function public.importador_set_envio_politica_web (
  p_tipo text,
  p_monto_minimo numeric,
  p_gratis_todos boolean,
  p_gratis_estados text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo text := upper(trim(coalesce(p_tipo, 'NO_DEFINIDO')));
  v_monto numeric;
  v_todos boolean := coalesce(p_gratis_todos, false);
  v_estados text[] := '{}';
  v_item text;
begin
  if auth.uid() is null then
    raise exception 'No autenticado' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'importador'
      and p.deactivated_at is null
  ) then
    raise exception 'Solo el proveedor puede configurar el envío'
      using errcode = '42501';
  end if;

  if v_tipo not in ('INCLUIDO', 'APARTE', 'A_CONVENIR', 'NO_DEFINIDO') then
    raise exception 'Política de envío no válida';
  end if;

  if p_monto_minimo is null or p_monto_minimo <= 0 or v_tipo = 'NO_DEFINIDO' then
    v_monto := null;
    v_todos := false;
  else
    v_monto := round(p_monto_minimo, 2);
  end if;

  if v_tipo = 'NO_DEFINIDO' or v_monto is null or v_todos then
    v_estados := '{}';
  else
    for v_item in
      select distinct left(btrim(value), 40)
      from unnest(coalesce(p_gratis_estados, '{}')) as t(value)
      where length(btrim(value)) > 0
      limit 24
    loop
      v_estados := array_append(v_estados, v_item);
    end loop;
  end if;

  update public.profiles
  set envio_tipo = v_tipo,
      monto_minimo_envio_gratis = v_monto,
      envio_gratis_todos = v_todos and v_monto is not null,
      envio_gratis_estados = v_estados
  where id = auth.uid();
end;
$$;

revoke all on function public.importador_set_envio_politica_web (text, numeric, boolean, text[]) from public;
grant execute on function public.importador_set_envio_politica_web (text, numeric, boolean, text[]) to authenticated;
