-- Importador: actualización masiva del % descuento USD en catálogo (usd_payment_discount_pct).

create or replace function public.importador_bulk_set_usd_payment_discount (
  p_pct numeric,
  p_scope text default 'con_descuento'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid ();
  v_role text;
  v_scope text := lower(trim(coalesce(p_scope, '')));
  v_count integer;
begin
  if v_uid is null then
    raise exception 'No autenticado';
  end if;

  select p.role
    into v_role
  from public.profiles p
  where p.id = v_uid;

  if v_role is distinct from 'importador' then
    raise exception 'Solo los importadores pueden actualizar descuentos del catálogo';
  end if;

  if v_scope not in ('con_descuento', 'todos') then
    raise exception 'Alcance no válido. Use con_descuento o todos.';
  end if;

  if p_pct is null or p_pct <= 0 or p_pct >= 100 then
    raise exception 'Indique un porcentaje mayor a 0 y menor a 100.';
  end if;

  update public.products pr
  set
    discount_rules = (
      coalesce(pr.discount_rules, '{}'::jsonb)
      - 'applied_usd_payment_discount_pct'
      - 'applied_usd_payment_discount_metodo'
    ) || jsonb_build_object('usd_payment_discount_pct', round(p_pct::numeric, 4))
  where pr.owner_id = v_uid
    and (
      v_scope = 'todos'
      or coalesce((pr.discount_rules ->> 'usd_payment_discount_pct')::numeric, 0) > 0
    );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.importador_bulk_set_usd_payment_discount (numeric, text) to authenticated;
