-- Reportes admin: paginación en snapshots de ventas e índices de soporte.

-- Cada snapshot filtra transaction_requests por importador y fecha.
create index if not exists transaction_requests_importador_created_idx
  on public.transaction_requests (importador_id, created_at desc);

-- Listado de importadores activos en el mismo orden que el reporte.
create index if not exists profiles_active_importador_name_idx
  on public.profiles ((coalesce(nullif(trim(business_name), ''), 'Importador')), id)
  where role = 'importador' and deactivated_at is null;

-- admin_postventa_resumen: últimas devoluciones por fecha.
create index if not exists order_postventa_casos_kind_created_idx
  on public.order_postventa_casos (kind, created_at desc);

drop function if exists public.admin_list_importer_sales_snapshots (integer);

create or replace function public.admin_list_importer_sales_snapshots (
  p_days integer default 30,
  p_limit integer default null,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days integer := greatest (1, least (coalesce(p_days, 30), 90));
  -- NULL conserva el listado completo que usa hoy la app.
  v_limit integer := case
    when p_limit is null then null
    else least (greatest (p_limit, 1), 200)
  end;
  v_offset integer := greatest (coalesce(p_offset, 0), 0);
  v_out jsonb;
begin
  perform public._assert_administrador ();

  select coalesce(
    jsonb_agg (
      public.mc_importer_sales_snapshot_json (x.id, v_days)
      order by x.sort_name, x.id
    ),
    '[]'::jsonb
  )
    into v_out
  from (
    select
      p.id,
      coalesce(nullif(trim(p.business_name), ''), 'Importador') as sort_name
    from public.profiles p
    where p.role = 'importador'
      and p.deactivated_at is null
    order by sort_name, p.id
    limit v_limit
    offset v_offset
  ) x;

  return v_out;
end;
$$;

comment on function public.admin_list_importer_sales_snapshots (integer, integer, integer) is
  'Admin: snapshot de ventas/rotación por importador, paginado (p_limit NULL = todos).';

revoke all on function public.admin_list_importer_sales_snapshots (integer, integer, integer)
  from public;
grant execute on function public.admin_list_importer_sales_snapshots (integer, integer, integer)
  to authenticated;
