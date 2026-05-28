-- E3: contexto de volumen mensual + tramo/tasa para UI (importador y admin).

create or replace function public.motoconecta_importer_commission_volume_context (
  p_importador_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_target uuid := coalesce(p_importador_id, v_uid);
  v_role text;
  v_volume numeric;
  v_override numeric;
  v_tier_rate numeric;
  v_effective numeric;
  v_tier_min numeric;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if v_target is null then
    raise exception 'importador inválido' using errcode = 'P0001';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'administrador' and v_target is distinct from v_uid then
    raise exception 'Sin permiso para consultar este importador'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_target
      and p.role = 'importador'
  ) then
    raise exception 'Importador no encontrado' using errcode = 'P0001';
  end if;

  v_volume := public.motoconecta_importer_monthly_sales_volume_usd (v_target);
  v_effective := public.motoconecta_commission_rate_for_importador (v_target);
  v_tier_rate := public.motoconecta_commission_rate_from_volume_tiers (v_volume);

  select p.commission_rate_pct
    into v_override
  from public.profiles p
  where p.id = v_target;

  select t.min_usd
    into v_tier_min
  from (
    select (elem ->> 'min_monthly_sales_usd')::numeric as min_usd
    from public.platform_settings ps
    cross join lateral jsonb_array_elements(ps.value) elem
    where ps.key = 'commission_volume_tiers'
      and jsonb_typeof(ps.value) = 'array'
  ) t
  where t.min_usd is not null
    and coalesce(v_volume, 0) >= t.min_usd
  order by t.min_usd desc
  limit 1;

  return jsonb_build_object(
    'importador_id',
    v_target,
    'volume_usd',
    coalesce(v_volume, 0),
    'effective_rate_pct',
    coalesce(v_effective, public.motoconecta_default_commission_rate ()),
    'override_rate_pct',
    v_override,
    'tier_rate_pct',
    coalesce(v_tier_rate, public.motoconecta_default_commission_rate ()),
    'tier_min_monthly_sales_usd',
    v_tier_min
  );
end;
$$;

grant execute on function public.motoconecta_importer_commission_volume_context (uuid) to authenticated;
