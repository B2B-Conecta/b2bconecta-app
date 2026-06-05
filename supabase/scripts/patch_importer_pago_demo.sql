-- =============================================================================
-- Parche: datos de pago demo para importadores (sin re-seed completo)
-- =============================================================================
-- Uso:
--   supabase db query --linked -f supabase/scripts/patch_importer_pago_demo.sql
--
-- Verifica columna + rellena accepted_pago_metodos y pago_metodo_instrucciones
-- para todos los perfiles role = importador.
-- =============================================================================

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'pago_metodo_instrucciones'
  ) then
    raise exception
      'Falta la columna pago_metodo_instrucciones. Ejecute antes: supabase db push';
  end if;
end;
$$;

update public.profiles p
set
  accepted_pago_metodos = array[
    'zelle_divisas',
    'pago_movil',
    'binance',
    'usdt',
    'transferencia',
    'efectivo'
  ]::text[],
  pago_metodo_instrucciones = jsonb_build_object(
    'zelle_divisas',
      format(
        E'Email Zelle: importador%s@zelle.demo\nTitular: %s\nBanco emisor (opcional): Bank of America',
        regexp_replace(coalesce(p.phone, ''), '.*-', ''),
        coalesce(p.business_name, 'Importador demo')
      ),
    'pago_movil',
      format(
        E'Banco: Banco de Venezuela\nTeléfono: %s\nCédula/RIF del titular: %s\nTitular: %s',
        coalesce(p.phone, '0414-0000000'),
        coalesce(p.rif, 'J-000000000'),
        coalesce(p.business_name, 'Importador demo')
      ),
    'transferencia',
      format(
        E'Banco: Banco Mercantil\nTipo de cuenta: Corriente\nNúmero: 0105-%s-01-1234567890\nTitular: %s\nRIF: %s',
        lpad(right(regexp_replace(coalesce(p.phone, ''), '\D', '', 'g'), 4), 4, '0'),
        coalesce(p.business_name, 'Importador demo'),
        coalesce(p.rif, 'J-000000000')
      ),
    'binance',
      format(
        E'Binance ID: %s\nEmail: importador%s@binance.demo\nTitular: %s\nMoneda: USDT',
        regexp_replace(coalesce(p.phone, ''), '.*-', ''),
        regexp_replace(coalesce(p.phone, ''), '.*-', ''),
        coalesce(p.business_name, 'Importador demo')
      ),
    'usdt',
      format(
        E'Red: TRC20\nWallet: T%sDemoWallet%s\nTitular: %s\nNota: Enviar solo USDT por TRC20',
        upper(regexp_replace(coalesce(p.rif, 'J000000000'), '[^A-Z0-9]', '', 'g')),
        regexp_replace(coalesce(p.phone, ''), '.*-', ''),
        coalesce(p.business_name, 'Importador demo')
      ),
    'efectivo',
      format(
        E'Entrega en almacén: %s, %s\nHorario: Lun–Vie 8:00 am – 4:00 pm\nContacto: %s · %s',
        coalesce(p.ciudad, 'Ciudad'),
        coalesce(p.direccion, 'Dirección fiscal del importador'),
        coalesce(p.business_name, 'Importador demo'),
        coalesce(p.phone, '0414-0000000')
      )
  )
where p.role = 'importador';

-- Diagnóstico: importadores sin instrucciones o con JSON vacío
select
  p.id,
  p.business_name,
  cardinality(coalesce(p.accepted_pago_metodos, array[]::text[])) as metodos,
  jsonb_object_keys(coalesce(p.pago_metodo_instrucciones, '{}'::jsonb)) as metodo_con_datos
from public.profiles p
where p.role = 'importador'
order by p.business_name;
