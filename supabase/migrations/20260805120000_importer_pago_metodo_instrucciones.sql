-- Importador: datos de cuenta / instrucciones por método de pago (visible al aliado al transferir).

alter table public.profiles
  add column if not exists pago_metodo_instrucciones jsonb not null default '{}'::jsonb;

comment on column public.profiles.pago_metodo_instrucciones is
  'Importador: texto con datos de cuenta por método (clave = pago_metodo, valor = instrucciones para el aliado).';

create or replace function public.importador_set_pago_metodo_instrucciones (
  p_instrucciones jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_allowed text[] := public.motoconecta_all_pago_metodos ();
  v_clean jsonb := '{}'::jsonb;
  v_key text;
  v_val text;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar datos de pago';
  end if;

  if p_instrucciones is null then
    p_instrucciones := '{}'::jsonb;
  end if;

  if jsonb_typeof(p_instrucciones) <> 'object' then
    raise exception 'Formato de instrucciones no válido';
  end if;

  for v_key, v_val in
    select key, value #>> '{}'
    from jsonb_each(p_instrucciones)
  loop
    if trim(v_key) = any (v_allowed) then
      v_val := left(trim(coalesce(v_val, '')), 2000);
      if v_val <> '' then
        v_clean := v_clean || jsonb_build_object(trim(v_key), v_val);
      end if;
    end if;
  end loop;

  update public.profiles
  set pago_metodo_instrucciones = v_clean
  where id = v_uid;
end;
$$;

grant execute on function public.importador_set_pago_metodo_instrucciones (jsonb) to authenticated;
