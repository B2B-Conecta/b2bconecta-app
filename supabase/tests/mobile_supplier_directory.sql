-- Ejecutar en sandbox. Todos los cambios de prueba se revierten.
begin;
select set_config('test.supplier_product_id', (
  select x.id::text from public.products x join public.profiles p on p.id = x.owner_id
  where x.is_active and p.role = 'importador' and p.deactivated_at is null
    and coalesce(nullif(btrim(p.account_access_status), ''), 'active') = 'active'
  order by x.id limit 1), true);
update public.products set custom_fields =
  '{"marca":"B2B_PUBLIC_QA_BRAND_2311","col_brand":"B2B_PRIVATE_QA_BRAND_2311","_aliado_visible_keys":["marca"]}'::jsonb
  where id = current_setting('test.supplier_product_id')::uuid;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object('sub', (
  select id::text from public.profiles where role = 'aliado' order by id limit 1), 'role', 'authenticated')::text, true);
do $$
declare
  all_rows jsonb := public.aliado_supplier_directory(p_limit => 100);
  page_rows jsonb := public.aliado_supplier_directory(p_limit => 2);
  rated jsonb := public.aliado_supplier_directory(p_filter => 'rated');
  purchased jsonb := public.aliado_supplier_directory(p_filter => 'purchased', p_limit => 100);
  public_brand jsonb := public.aliado_supplier_directory(p_query => 'b2b_public_qa_brand_2311');
  hidden_brand jsonb := public.aliado_supplier_directory(p_query => 'B2B_PRIVATE_QA_BRAND_2311');
  expected integer;
  rejected boolean := false;
begin
  assert (all_rows ->> 'total')::integer > 0, 'Directorio vacío inesperado';
  assert jsonb_array_length(page_rows -> 'items') = least(2, (all_rows ->> 'total')::integer), 'Límite de página';
  assert page_rows -> 'items' -> 0 ->> 'id' = all_rows -> 'items' -> 0 ->> 'id', 'Orden inestable';
  if (all_rows ->> 'total')::integer > 2 then
    assert public.aliado_supplier_directory(p_limit => 1, p_offset => 2) -> 'items' -> 0 ->> 'id'
      = all_rows -> 'items' -> 2 ->> 'id', 'Desplazamiento incorrecto';
  end if;
  assert not exists (select 1 from jsonb_array_elements(rated -> 'items') e
    where coalesce((e ->> 'rating_count_received_rolling100')::integer, 0) <= 0), 'Valoraciones inventadas';
  assert not exists (select 1 from jsonb_array_elements(purchased -> 'items') e
    where (e ->> 'purchased')::boolean is not true), 'Filtro de historial incorrecto';
  select count(*) into expected from jsonb_array_elements(all_rows -> 'items') e
    where (e ->> 'purchased')::boolean;
  assert (purchased ->> 'total')::integer = expected, 'Total de historial incorrecto';
  assert not exists (select 1 from jsonb_array_elements(all_rows -> 'items') e
    where (e ->> 'purchased')::boolean <> exists (
      select 1 from public.transaction_requests t where t.aliado_id = auth.uid()
        and t.importador_id = (e ->> 'id')::uuid and not coalesce(t.cancelado_por_aliado, false)
        and t.status not in ('rechazado', 'cancelado')
        and (t.status in ('aprobado_admin', 'en_preparacion', 'pedido_listo', 'en_transito', 'enviado', 'entregado') or t.pago_aprobado_at is not null)
    )), 'Historial de otro usuario o pedido sin confirmar';
  assert (public_brand ->> 'total')::integer = 1, 'Marca publicada no encontrada';
  assert (hidden_brand ->> 'total')::integer = 0, 'Filtración de marca ERP privada';
  assert (public.aliado_supplier_directory(p_query => 'ZZZZ_NO_SUPPLIER_2311') ->> 'total')::integer = 0, 'Búsqueda sin coincidencias';
  assert not has_function_privilege('anon', 'public.aliado_supplier_directory(text,text,text,text,integer,integer)', 'execute'), 'Acceso anónimo';
  begin perform public.aliado_supplier_directory(p_filter => 'bad');
  exception when invalid_parameter_value then rejected := true; end;
  assert rejected, 'Filtro inválido aceptado';
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  rejected := false;
  begin perform public.aliado_supplier_directory();
  exception when insufficient_privilege then rejected := true; end;
  assert rejected, 'Sesión inválida aceptada';
end;
$$;
reset role;
select 'PASS: directorio, paginación, historial personal, marcas visibles y control de acceso' as result;
rollback;
