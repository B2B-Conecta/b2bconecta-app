-- El credit_score ya no sube automáticamente con cada entrega; queda como indicador
-- gestionado aparte y solo relevante con línea MotoLink asignada (UI).

create or replace function public.transaction_requests_on_entregado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  pc_before int;
  bn text;
  pm text;
  prev text;
  add_cred numeric;
begin
  if new.status = 'entregado' and (old.status is distinct from 'entregado') then
    select
      coalesce(primeros_pedidos_contado_entregados, 0),
      business_name
    into pc_before, bn
    from public.profiles
    where id = new.aliado_id and role = 'aliado';

    if new.stock_descontado_en is null then
      update public.products p
      set stock = p.stock - new.cantidad
      where p.id = new.product_id
        and p.owner_id = new.owner_id
        and p.stock >= new.cantidad;
      get diagnostics n = row_count;
      if n = 0 then
        raise exception 'Stock insuficiente para marcar entregado.';
      end if;
    end if;

    update public.profiles
    set primeros_pedidos_contado_entregados = least(
      coalesce(primeros_pedidos_contado_entregados, 0) + 1,
      3
    )
    where id = new.aliado_id
      and role = 'aliado'
      and coalesce(primeros_pedidos_contado_entregados, 0) < 3;

    pm := nullif(lower(trim(coalesce(new.pago_metodo, old.pago_metodo, ''))), '');
    prev := nullif(lower(trim(coalesce(new.pago_estado_revision, old.pago_estado_revision, ''))), '');
    add_cred := coalesce(new.precio_total, old.precio_total, 0);
    if pm = 'credito_sistema' and prev = 'aprobado' and add_cred > 0 then
      update public.profiles pr
      set credito_consumido_acumulado =
        coalesce(pr.credito_consumido_acumulado, 0) + add_cred
      where pr.id = new.aliado_id
        and pr.role = 'aliado';
    end if;

    if pc_before = 2 then
      perform public.notify_to_all_admins(
        'Fase contado completada',
        format(
          '%s completó los 3 pedidos en contado. Defina su línea de crédito en la pestaña Crédito.',
          coalesce(nullif(trim(bn), ''), 'Un aliado')
        ),
        'credito',
        new.aliado_id::text
      );
    end if;
  end if;
  return new;
end;
$$;
