-- Un solo corte coherente: límite, imputado y saldo activo (exposición) para "Disponible" en el perfil.
create or replace function public.aliado_motolink_cupo_snapshot()
returns table (
  limite_asignado numeric(14,2),
  imputado_acumulado numeric(14,2),
  saldo_activo_exposicion numeric(14,2)
)
language sql
stable
set search_path = public
as $$
  select
    coalesce(p.credit_limit, 0)::numeric(14,2),
    coalesce(p.credito_consumido_acumulado, 0)::numeric(14,2),
    coalesce(public.aliado_effective_open_exposure(p.id), 0)::numeric(14,2)
  from public.profiles p
  where p.id = auth.uid() and p.role = 'aliado'
$$;

grant execute on function public.aliado_motolink_cupo_snapshot() to authenticated;

comment on function public.aliado_motolink_cupo_snapshot is
  'Corte consistente. Disponible en app: límite mostrado − saldo_activo_exposicion − imputado_acumulado (imputado sube al cerrar el plan, no por cuota).';
