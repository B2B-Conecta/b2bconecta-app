-- Inicio minorista: solo IDs comprables; nunca expone pedidos, compradores o importes.
-- La agregación global vive fuera de los esquemas expuestos por la Data API.
create schema if not exists b2b_private;
revoke all on schema b2b_private from public, anon;
grant usage on schema b2b_private to authenticated;

create or replace function b2b_private.aliado_home_product_selection()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_again jsonb;
  v_best jsonb;
begin
  if v_uid is null or not exists (
    select 1 from public.profiles p
    where p.id = v_uid and p.role = 'aliado'
      and p.deactivated_at is null
      and p.account_access_status = 'active'
      and p.kyc_status = 'aprobado'
  ) then
    raise exception 'Acceso reservado a tiendas minoristas habilitadas' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(s.product_id order by s.last_delivery desc nulls last, s.product_id), '[]'::jsonb)
    into v_again
  from (
    select tr.product_id, max(tr.at_entregado) as last_delivery
    from public.transaction_requests tr
    join public.products p on p.id = tr.product_id and p.owner_id = tr.importador_id
    where tr.aliado_id = v_uid and tr.status = 'entregado'
      and not coalesce(tr.anulado_por_motolink, false)
      and tr.postventa_devolucion_at is null
      and p.is_active = true and p.stock_covers_min_order = true
      and public._importer_store_is_public(p.owner_id)
    group by tr.product_id
    order by last_delivery desc nulls last, tr.product_id
    limit 12
  ) s;

  select coalesce(jsonb_agg(s.product_id order by s.units desc, s.last_delivery desc, s.product_id), '[]'::jsonb)
    into v_best
  from (
    select tr.product_id, sum(tr.cantidad) as units, max(tr.at_entregado) as last_delivery
    from public.transaction_requests tr
    join public.products p on p.id = tr.product_id and p.owner_id = tr.importador_id
    where tr.status = 'entregado' and tr.cantidad > 0
      and tr.at_entregado >= now() - interval '30 days'
      and not coalesce(tr.anulado_por_motolink, false)
      and tr.postventa_devolucion_at is null
      and p.is_active = true and p.stock_covers_min_order = true
      and public._importer_store_is_public(p.owner_id)
    group by tr.product_id
    order by units desc, last_delivery desc, tr.product_id
    limit 12
  ) s;

  return jsonb_build_object('buy_again', v_again, 'best_sellers', v_best);
end;
$$;
revoke all on function b2b_private.aliado_home_product_selection() from public, anon;
grant execute on function b2b_private.aliado_home_product_selection() to authenticated;

create or replace function public.aliado_home_product_selection()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select b2b_private.aliado_home_product_selection();
$$;
revoke all on function public.aliado_home_product_selection() from public, anon;
grant execute on function public.aliado_home_product_selection() to authenticated;
comment on function public.aliado_home_product_selection() is
  'Inicio minorista: recompra propia y ranking por unidades entregadas en 30 días. Solo IDs de catálogo disponible.';
