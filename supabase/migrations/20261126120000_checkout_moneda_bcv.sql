-- Moneda de pago congelada al confirmar el carrito.
-- El bolívar del catálogo no se guarda en products: es precio REF × tasa BCV.
-- total_ref de cada línea es precio_total_usd (ya con oferta y saldo a favor).

alter table public.transaction_requests
  add column if not exists metodo_pago_moneda text,
  add column if not exists tasa_bcv_aplicada numeric,
  add column if not exists total_ref numeric(14, 2),
  add column if not exists total_bs numeric(14, 2);

alter table public.transaction_requests
  drop constraint if exists transaction_requests_metodo_pago_moneda_chk;

alter table public.transaction_requests
  add constraint transaction_requests_metodo_pago_moneda_chk
  check (
    metodo_pago_moneda is null
    or metodo_pago_moneda in ('DIVISAS', 'BOLIVARES')
  );

comment on column public.transaction_requests.metodo_pago_moneda is
  'DIVISAS o BOLIVARES, elegido al confirmar el carrito.';

comment on column public.transaction_requests.tasa_bcv_aplicada is
  'Tasa BCV (VES por 1 REF) leída de app_global_config al confirmar.';

comment on column public.transaction_requests.total_ref is
  'Total REF de la línea. Igual a precio_total_usd en el momento del congelamiento.';

comment on column public.transaction_requests.total_bs is
  'total_ref × tasa_bcv_aplicada. No usa un precio en Bs del producto.';

comment on column public.transaction_requests.precio_total_usd is
  'Total REF de la línea (total_ref).';

create or replace function public.aliado_freeze_checkout_moneda (
  p_checkout_group_id uuid,
  p_moneda text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_moneda text := upper(trim(coalesce(p_moneda, '')));
  v_tasa numeric;
  v_updated int;
begin
  if v_uid is null then
    raise exception 'No hay sesión activa.';
  end if;
  if v_moneda not in ('DIVISAS', 'BOLIVARES') then
    raise exception 'Moneda de pago inválida.';
  end if;

  select c.value_numeric
    into v_tasa
  from public.app_global_config c
  where c.key = 'tasa_bcv';

  if v_moneda = 'BOLIVARES' and coalesce(v_tasa, 0) <= 0 then
    raise exception 'No hay tasa BCV vigente para pago en bolívares.';
  end if;

  update public.transaction_requests tr
  set
    metodo_pago_moneda = v_moneda,
    tasa_bcv_aplicada = case
      when coalesce(v_tasa, 0) > 0 then v_tasa
      else null
    end,
    total_ref = round(tr.precio_total_usd, 2),
    total_bs = case
      when coalesce(v_tasa, 0) <= 0 then null
      else round(tr.precio_total_usd * v_tasa, 2)
    end
  where tr.checkout_group_id = p_checkout_group_id
    and tr.aliado_id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'No se encontró el pedido para congelar la moneda.';
  end if;
end;
$$;

comment on function public.aliado_freeze_checkout_moneda (uuid, text) is
  'Congela DIVISAS o BOLIVARES, la tasa BCV vigente y los totales del checkout.';

revoke all on function public.aliado_freeze_checkout_moneda (uuid, text) from public;
grant execute on function public.aliado_freeze_checkout_moneda (uuid, text) to authenticated;
