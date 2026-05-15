-- No enviar expediente KYC a revisión MotoLink hasta completar las primeras entregas en contado
-- (misma regla que CashPhasePolicy.entregasRequeridas en la app).

create or replace function public.aliado_submit_kyc_for_review()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text;
  pce integer;
  req constant integer := 3;
begin
  select
    kyc_status,
    coalesce(primeros_pedidos_contado_entregados, 0)
  into st, pce
  from public.profiles
  where id = auth.uid() and role = 'aliado';
  if st is null then
    raise exception 'Perfil aliado no encontrado';
  end if;
  if st not in ('pendiente', 'rechazado', 'en_revision') then
    raise exception 'No puede enviar a revisión en este estado';
  end if;

  if pce < req then
    raise exception
      'Complete la fase inicial de contado (3 entregas registradas) antes de enviar documentación a revisión MotoLink.';
  end if;

  update public.profile_documents
  set review_status = 'en_revision'
  where profile_id = auth.uid()
    and is_current
    and review_status = 'pendiente';
end;
$$;
