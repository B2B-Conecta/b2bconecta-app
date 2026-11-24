create function b2b_private.guard_customer_pickup() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.customer_delivery_mode='PICKUP' then
    if new.importer_carrier_id is not null or new.importer_carrier_driver_id is not null
      or coalesce(new.carrier_fee_usd_snapshot,0)<>0 or coalesce(new.shipping_cost_usd,0)<>0
      or new.shipping_included is distinct from true then
      raise exception 'El retiro en tienda no admite cargos ni transportista.' using errcode='23514';
    end if;
    if new.status in ('en_transito','enviado') then
      raise exception 'El retiro se confirma desde Pedido listo, sin envío en tránsito.' using errcode='23514';
    end if;
  end if;
  return new;
end $$;
create trigger zz_guard_customer_pickup before insert or update on public.transaction_requests
  for each row execute function b2b_private.guard_customer_pickup();
revoke all on function b2b_private.guard_customer_pickup() from public,anon,authenticated;

create or replace function public.aliado_marca_pedido_entregado(p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'No autenticado' using errcode='42501'; end if;
  update public.transaction_requests tr set status='entregado'
  where tr.id=p_request_id and tr.aliado_id=auth.uid()
    and (tr.status in ('en_transito','enviado') or (tr.customer_delivery_mode='PICKUP' and tr.status='pedido_listo'));
  if not found then raise exception 'No se puede confirmar la recepción (estado o permiso inválido).'; end if;
end $$;
create or replace function public.aliado_marca_pedidos_entregados_importador_en_grupo(p_checkout_group_id uuid,p_importador_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_n integer;
begin
  if auth.uid() is null then raise exception 'No autenticado' using errcode='42501'; end if;
  update public.transaction_requests tr set status='entregado',updated_at=now()
  where tr.checkout_group_id=p_checkout_group_id and tr.importador_id=p_importador_id and tr.aliado_id=auth.uid()
    and (tr.status in ('en_transito','enviado') or (tr.customer_delivery_mode='PICKUP' and tr.status='pedido_listo'));
  get diagnostics v_n=row_count;
  if v_n<1 then raise exception 'No se puede confirmar la recepción (estado o permiso inválido).'; end if;
  return v_n;
end $$;
revoke all on function public.aliado_marca_pedido_entregado(uuid),public.aliado_marca_pedidos_entregados_importador_en_grupo(uuid,uuid) from public,anon;
grant execute on function public.aliado_marca_pedido_entregado(uuid),public.aliado_marca_pedidos_entregados_importador_en_grupo(uuid,uuid) to authenticated;
