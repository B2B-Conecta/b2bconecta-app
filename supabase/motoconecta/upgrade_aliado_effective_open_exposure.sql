-- RPC requerida por SupabaseService.fetchOpenCreditExposureForAliado (pestaña Pedidos aliado).
-- Errores típicos sin esto: PostgREST PGRST202 — function public.aliado_effective_open_exposure not in schema cache.
-- Ejecutar en SQL Editor del proyecto (idempotente).

create or replace function public.aliado_effective_open_exposure (p_aliado_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid () is null then
    return 0;
  end if;
  if auth.uid () is distinct from p_aliado_id
     and not exists (
       select 1
       from public.profiles p
       where p.id = auth.uid ()
         and p.role = 'administrador'
     ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return coalesce(
    (
      select sum(tr.precio_total_usd)::numeric
      from public.transaction_requests tr
      where tr.aliado_id = p_aliado_id
        and tr.status = any (
          array[
            'pendiente'::text,
            'en_preparacion'::text,
            'enviado'::text
          ]
        )
    ),
    0::numeric
  );
end;
$$;

grant execute on function public.aliado_effective_open_exposure (uuid) to authenticated;
grant execute on function public.aliado_effective_open_exposure (uuid) to service_role;
