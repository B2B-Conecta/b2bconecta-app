-- Deja de ofrecer Binance como método de pago. USDT (y el resto) se mantienen.
-- Pedidos históricos con pago_metodo = 'binance' siguen legibles en UI.

create or replace function public.motoconecta_all_pago_metodos ()
returns text[]
language sql
immutable
as $$
  select array[
    'zelle_divisas',
    'pago_movil',
    'usdt',
    'transferencia',
    'efectivo'
  ]::text[];
$$;

comment on function public.motoconecta_all_pago_metodos () is
  'Métodos de pago activos de B2B Conecta. Binance quedó fuera; USDT cubre cripto.';

-- Quitar Binance de la configuración de importadores.
update public.profiles
set accepted_pago_metodos = array_remove(accepted_pago_metodos, 'binance')
where accepted_pago_metodos is not null
  and 'binance' = any (accepted_pago_metodos);

update public.profiles
set accepted_pago_metodos = null
where accepted_pago_metodos is not null
  and cardinality(accepted_pago_metodos) = 0;

update public.profiles
set pago_metodo_instrucciones = pago_metodo_instrucciones - 'binance'
where pago_metodo_instrucciones ? 'binance';

-- Transportistas del importador.
update public.importer_carriers
set accepted_pago_metodos = array_remove(accepted_pago_metodos, 'binance')
where accepted_pago_metodos is not null
  and 'binance' = any (accepted_pago_metodos);

update public.importer_carriers
set pago_metodo_instrucciones = pago_metodo_instrucciones - 'binance'
where pago_metodo_instrucciones ? 'binance';
