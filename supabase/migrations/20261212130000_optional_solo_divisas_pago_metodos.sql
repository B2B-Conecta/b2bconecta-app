-- Solo-divisas también sin exigir métodos de pago configurados.

create or replace function public.importador_set_pago_solo_divisas (
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_bs text[] := public.motoconecta_pago_metodos_bolivares ();
  v_clean text[];
  v_m text;
  v_instr jsonb;
  v_saved text[];
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden configurar pagos en divisas';
  end if;

  if coalesce(p_enabled, false) then
    select p.accepted_pago_metodos
      into v_saved
    from public.profiles p
    where p.id = v_uid;

    -- Sin config previa: null (métodos opcionales). Con config: quitar Bs.
    if v_saved is null then
      v_clean := null;
    else
      v_clean := array(
        select m
        from unnest(v_saved) as m
        where not (m = any (v_bs))
      );
      if cardinality(v_clean) = 0 then
        v_clean := null;
      end if;
    end if;

    select coalesce(p.pago_metodo_instrucciones, '{}'::jsonb)
      into v_instr
    from public.profiles p
    where p.id = v_uid;

    foreach v_m in array v_bs loop
      v_instr := v_instr - v_m;
    end loop;

    update public.products pr
    set
      discount_rules = public.motoconecta_strip_usd_payment_discount_rules (pr.discount_rules)
    where pr.owner_id = v_uid
      and coalesce((pr.discount_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0;

    update public.profiles
    set
      pago_solo_divisas = true,
      accepted_pago_metodos = v_clean,
      pago_metodo_instrucciones = v_instr
    where id = v_uid;
  else
    update public.profiles
    set pago_solo_divisas = false
    where id = v_uid;
  end if;
end;
$$;

comment on function public.importador_set_pago_solo_divisas (boolean) is
  'Importador: solo pagos USD. No exige métodos configurados (siguen opcionales).';

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

  if p_metodos is null or cardinality(p_metodos) = 0 then
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
  'Importador: métodos aceptados. Lista vacía limpia la config; solo-divisas tampoco exige métodos.';
