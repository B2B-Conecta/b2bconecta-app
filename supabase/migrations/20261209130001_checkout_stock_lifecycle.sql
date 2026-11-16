-- Checkout owns one inventory debit per line. A status/quantity transition
-- compensates that debit in the same transaction, regardless of who cancels.
alter table public.transaction_requests
  add column checkout_stock_debited_qty integer
  check (checkout_stock_debited_qty >= 0);

comment on column public.transaction_requests.checkout_stock_debited_qty is
  'Internal outstanding checkout stock debit; NULL = untracked legacy line, 0 = fully restored. Maintained only by the inventory trigger.';

-- Existing checkout RPCs have already deducted these open lines. Register the
-- debit without changing inventory. Closed lines (including manually repaired
-- QA cancellations) are intentionally excluded. No historical stock repair.
update public.transaction_requests
set checkout_stock_debited_qty = greatest(
  cantidad, coalesce(qty_adjustment_solicitada_snapshot, cantidad))
where checkout_group_id is not null
  and product_id is not null
  and status not in ('entregado', 'rechazado');

create function public.mc_checkout_stock_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_target integer;
  v_delta integer;
begin
  if tg_op = 'INSERT' then
    -- Ignore client-supplied bookkeeping. Legacy ungrouped requests are outside
    -- this checkout contract; they must not fabricate a refundable debit.
    new.checkout_stock_debited_qty := null;
    if new.checkout_group_id is null then
      return new;
    end if;
    if new.status <> 'pendiente' or new.cantidad is null or new.cantidad < 1 then
      raise exception 'Estado o cantidad de checkout inválidos.';
    end if;
    update public.products
    set stock = stock - new.cantidad
    where id = new.product_id
      and owner_id = new.importador_id
      and is_active
      and stock - stock_reserved >= new.cantidad;
    if not found then
      raise exception 'Stock insuficiente o producto no disponible.';
    end if;
    new.checkout_stock_debited_qty := new.cantidad;
    return new;
  end if;

  -- UPDATE: always derive bookkeeping from the locked OLD row, never a payload.
  new.checkout_stock_debited_qty := old.checkout_stock_debited_qty;
  if old.checkout_stock_debited_qty is null then
    return new;
  end if;
  if new.product_id is distinct from old.product_id then
    raise exception 'No se puede cambiar el producto de una línea de checkout.';
  end if;
  if old.status = 'rechazado' then
    if new.status <> 'rechazado' or new.cantidad is distinct from old.cantidad then
      raise exception 'El pedido cancelado ya está cerrado.';
    end if;
    return new;
  end if;
  if old.status = 'entregado' then
    if new.status is distinct from old.status or new.cantidad is distinct from old.cantidad then
      raise exception 'Gestione un pedido entregado mediante postventa.';
    end if;
    return new;
  end if;
  if new.status = 'rechazado' then
    v_target := 0;
  elsif new.cantidad is distinct from old.cantidad then
    if old.qty_adjustment_status is distinct from 'pendiente_aliado'
       or new.qty_adjustment_status is distinct from 'aceptado'
       or new.cantidad is distinct from old.qty_adjustment_offered
       or new.cantidad < 1 or new.cantidad >= old.cantidad then
      raise exception 'La cantidad solo cambia al aceptar una propuesta del proveedor.';
    end if;
    v_target := new.cantidad;
    -- Keep the frozen REF/Bs totals consistent with the accepted quantity.
    if new.discount_rules->>'checkout_pricing_version' = '1' then
      -- The quantity RPC scales the agreed net total proportionally. Do the
      -- same with the frozen net REF total (which may already include credit).
      new.total_ref := round(old.total_ref * new.cantidad / old.cantidad, 2);
      new.total_bs := case when new.tasa_bcv_aplicada > 0
        then round(new.total_ref * new.tasa_bcv_aplicada, 2) else null end;
    end if;
  else
    return new;
  end if;

  v_delta := old.checkout_stock_debited_qty - v_target;
  if v_delta < 0 then
    raise exception 'Débito de inventario inconsistente.';
  end if;
  if v_delta > 0 then
    update public.products set stock = stock + v_delta
    where id = old.product_id;
    if not found then
      raise exception 'No se encontró el producto para restituir el inventario.';
    end if;
  end if;
  new.checkout_stock_debited_qty := v_target;
  return new;
end;
$function$;

revoke all on function public.mc_checkout_stock_lifecycle() from public, anon, authenticated;

create trigger tr_checkout_stock_lifecycle
before insert or update on public.transaction_requests
for each row execute function public.mc_checkout_stock_lifecycle();

-- The trigger now performs the debit, including for the legacy checkout RPCs.
-- Remove only their existing inventory UPDATE; preserve every pricing, auth,
-- credit, delivery and notification rule and each function's existing grants.
-- Abort if an installed definition differs, rather than risking a double debit.
do $migration$
declare
  v_signature text;
  v_oid regprocedure;
  v_definition text;
  v_pattern constant text := 'update[[:space:]]+public\.products[[:space:]]+set[[:space:]]+stock[[:space:]]*=[[:space:]]*stock[[:space:]]*-[[:space:]]*rec\.cantidad[[:space:]]+where[[:space:]]+id[[:space:]]*=[[:space:]]*rec\.product_id[[:space:]]*;';
  v_matches integer;
begin
  foreach v_signature in array array[
    'public.aliado_checkout_multi_importador(jsonb,boolean,text,text)',
    'public.aliado_checkout_multi_importador(jsonb,boolean,text,text,jsonb)',
    'public.aliado_checkout_multi_importador_impl(jsonb,boolean,text,text,jsonb,jsonb)',
    'public.aliado_checkout_multi_importador_moneda(jsonb,boolean,text,text,jsonb,jsonb,jsonb,text)'
  ] loop
    v_oid := to_regprocedure(v_signature);
    if v_oid is null then
      raise exception 'Falta el checkout requerido: %', v_signature;
    end if;
    v_definition := pg_get_functiondef(v_oid);
    select count(*) into v_matches
    from regexp_matches(v_definition, v_pattern, 'gi');
    if v_matches <> 1 then
      raise exception 'Revise el descuento de stock antes de migrar: % (% coincidencias)', v_signature, v_matches;
    end if;
    execute regexp_replace(v_definition, v_pattern,
      '-- Inventory debit is atomic with INSERT: tr_checkout_stock_lifecycle.', 'i');
  end loop;
end;
$migration$;

notify pgrst, 'reload schema';
