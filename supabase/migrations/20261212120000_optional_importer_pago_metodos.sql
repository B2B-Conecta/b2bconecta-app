-- Métodos de pago del importador: opcionales.
-- Permite guardar sin métodos (null = default de plataforma) y publicar precios REF/USD sin cuentas.

create or replace function public.importador_set_accepted_pago_metodos (
  p_metodos text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_solo boolean;
  v_clean text[];
  v_m text;
  v_allowed text[] := public.motoconecta_all_pago_metodos ();
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role, coalesce(p.pago_solo_divisas, false)
    into v_role, v_solo
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar métodos de pago';
  end if;

  -- Vacío / null: sin configuración explícita (catálogo y precios siguen disponibles).
  if p_metodos is null or cardinality(p_metodos) = 0 then
    if v_solo then
      raise exception
        'Con pagos solo en USD debe tener al menos un método en divisas activo.';
    end if;
    update public.profiles
    set accepted_pago_metodos = null
    where id = v_uid;
    return;
  end if;

  v_clean := array[]::text[];

  foreach v_m in array p_metodos loop
    if trim(v_m) = any (v_allowed) then
      if v_solo and trim(v_m) = any (v_bs) then
        continue;
      end if;
      if not (trim(v_m) = any (v_clean)) then
        v_clean := array_append(v_clean, trim(v_m));
      end if;
    end if;
  end loop;

  if cardinality(v_clean) = 0 then
    if v_solo then
      raise exception
        'Con pagos solo en USD debe tener al menos un método en divisas activo.';
    end if;
    update public.profiles
    set accepted_pago_metodos = null
    where id = v_uid;
    return;
  end if;

  update public.profiles
  set accepted_pago_metodos = v_clean
  where id = v_uid;
end;
$$;

comment on function public.importador_set_accepted_pago_metodos (text[]) is
  'Importador: métodos aceptados. Lista vacía limpia la config (opcional). Solo-divisas sigue exigiendo al menos un método USD.';
